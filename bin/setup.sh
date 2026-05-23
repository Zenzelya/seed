#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

# shellcheck source=lib-ports.sh
source "$SCRIPT_DIR/lib-ports.sh"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
step()  { echo -e "${GREEN}[+]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
fail()  { echo -e "${RED}[-]${NC} $1"; exit 1; }
info()  { echo -e "${CYAN}[*]${NC} $1"; }
ok()    { echo -e "${GREEN}[✓]${NC} $1"; }

echo ""
echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              Setup Script            ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
echo ""

# ─────────────────────────────────────────
# 1. Docker Engine
# ─────────────────────────────────────────
step "Проверка Docker Engine..."

if ! dpkg -l docker-ce &>/dev/null || dpkg -l docker-ce | grep -q '^rc'; then
    info "Устанавливаю Docker Engine..."
    sudo apt-get update -q
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
        docker-compose-plugin docker-buildx-plugin
    ok "Docker Engine установлен"
else
    ok "Docker Engine уже установлен"
fi

if ! systemctl is-active --quiet docker; then
    sudo systemctl enable --now docker
    ok "Docker запущен"
fi

if ! groups "$USER" | grep -q docker; then
    sudo usermod -aG docker "$USER"
    warn "Пользователь добавлен в группу docker. Нужен повторный вход или: newgrp docker"
else
    ok "Пользователь уже в группе docker"
fi

# ─────────────────────────────────────────
# 2. Docker context
# ─────────────────────────────────────────
step "Настройка Docker context..."

current_context=$(docker context show 2>/dev/null || echo "unknown")
if [ "$current_context" != "default" ]; then
    docker context use default
    ok "Context переключён на default"
else
    ok "Docker context: default"
fi

# ─────────────────────────────────────────
# 3. daemon.json
# ─────────────────────────────────────────
step "Настройка Docker daemon..."

DAEMON_JSON="/etc/docker/daemon.json"
if [ ! -f "$DAEMON_JSON" ]; then
    sudo mkdir -p /etc/docker
    sudo tee "$DAEMON_JSON" > /dev/null <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "default-address-pools": [
    { "base": "172.80.0.0/16", "size": 24 }
  ]
}
EOF
    sudo systemctl reload docker
    ok "daemon.json создан"
else
    ok "daemon.json уже существует"
fi

# ─────────────────────────────────────────
# 4. doc команда
# ─────────────────────────────────────────
step "Установка команды doc..."

DOC_TARGET="$HOME/.local/bin/doc"
mkdir -p "$HOME/.local/bin"
cp "$SCRIPT_DIR/doc" "$DOC_TARGET"
chmod +x "$DOC_TARGET"
ok "doc установлен → $DOC_TARGET"

if ! grep -q '\.local/bin' "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    ok "PATH добавлен в .bashrc"
fi

# ─────────────────────────────────────────
# 5. Выбор сервисов
# ─────────────────────────────────────────
step "Конструктор сервисов..."

echo ""
echo -e "  ${CYAN}Выбери сервисы (через +):${NC}"
echo -e "    0 — backend   (NestJS)"
echo -e "    1 — frontend  (Angular)   порт 4200"
echo -e "    2 — frontend  (Next.js)   порт 3000"
echo -e "    3 — fastapi   (Python parser)"
echo -e "    4 — postgres"
echo -e "    5 — redis"
echo -e "  ${YELLOW}Выбирай 1 или 2, не оба сразу${NC}"
echo ""
read -r -p "  Ввод [0+1+4+5]: " SEL_INPUT
SEL_INPUT="${SEL_INPUT:-0+1+4+5}"

if ! [[ "$SEL_INPUT" =~ ^[0-5](\+[0-5])*$ ]]; then
    fail "Неверный ввод '${SEL_INPUT}'. Используй цифры 0–5 через +"
fi

if [[ "$SEL_INPUT" == *1* ]] && [[ "$SEL_INPUT" == *2* ]]; then
    fail "Нельзя выбрать Angular (1) и Next.js (2) одновременно"
fi

SEL="$SEL_INPUT"
ok "Сервисы: ${SEL}"

# ─────────────────────────────────────────
# 6. Слот и корневой .env
# ─────────────────────────────────────────
step "Назначение портов..."

ROOT_ENV="$PROJECT_ROOT/.env"
ENV_EXAMPLE="$PROJECT_ROOT/.env.example"
PROJECT_NAME=$(basename "$PROJECT_ROOT")

if [ ! -f "$ROOT_ENV" ]; then
    [ ! -f "$ENV_EXAMPLE" ] && fail ".env.example не найден"

    # Найти первый свободный слот
    SLOT=$(find_free_slot "$SEL")
    ports_for_slot "$SLOT"

    # Создать .env из шаблона с подстановкой значений
    sed \
        -e "s|^COMPOSE_PROJECT_NAME=.*|COMPOSE_PROJECT_NAME=${PROJECT_NAME}|" \
        -e "s|^COMPOSE_SERVICES=.*|COMPOSE_SERVICES=${SEL}|" \
        -e "s|^POSTGRES_DB=.*|POSTGRES_DB=${PROJECT_NAME}|" \
        -e "s|^DB_PORT=.*|DB_PORT=${DB_PORT}|" \
        -e "s|^REDIS_PORT=.*|REDIS_PORT=${REDIS_PORT}|" \
        -e "s|^API_PORT=.*|API_PORT=${API_PORT}|" \
        -e "s|^API_DEBUG_PORT=.*|API_DEBUG_PORT=${API_DEBUG_PORT}|" \
        -e "s|^FRONT_PORT=.*|FRONT_PORT=${FRONT_PORT}|" \
        -e "s|^PARSER_PORT=.*|PARSER_PORT=${PARSER_PORT}|" \
        "$ENV_EXAMPLE" > "$ROOT_ENV"

    # Зарегистрировать слот
    mkdir -p "${HOME}/.config"
    touch "$PROJECTS_CONF"
    if grep -q "^${PROJECT_NAME}:" "$PROJECTS_CONF" 2>/dev/null; then
        sed -i "s|^${PROJECT_NAME}:.*|${PROJECT_NAME}:${SLOT}|" "$PROJECTS_CONF"
    else
        echo "${PROJECT_NAME}:${SLOT}" >> "$PROJECTS_CONF"
    fi

    ok ".env создан (слот ${SLOT})"
    info "  DB=${DB_PORT}  Redis=${REDIS_PORT}  API=${API_PORT}  Front=${FRONT_PORT}"
else
    ok ".env уже существует"
    SLOT=$(( $(grep '^DB_PORT=' "$ROOT_ENV" | cut -d= -f2) - 5432 ))
    ports_for_slot "$SLOT"
    info "  Слот ${SLOT}: DB=${DB_PORT}  Redis=${REDIS_PORT}  API=${API_PORT}  Front=${FRONT_PORT}"
fi

# ─────────────────────────────────────────
# 7. docker-compose.yml
# ─────────────────────────────────────────
step "Генерация docker-compose.yml..."

rm -f "$PROJECT_ROOT/docker-compose.yml"
build_compose "$SEL"
ok "docker-compose.yml создан (сервисы: ${SEL})"

# ─────────────────────────────────────────
# 8. Клонирование репозиториев
# ─────────────────────────────────────────
step "Клонирование репозиториев..."

bash "$SCRIPT_DIR/clone_projects.sh"

# ─────────────────────────────────────────
# 9. backend/.env
# ─────────────────────────────────────────
step "Настройка backend/.env..."

BACKEND_ENV="$PROJECT_ROOT/backend/.env"
BACKEND_TMPL="$SCRIPT_DIR/backend.env"

if [[ $SEL == *0* ]]; then
    if [ ! -f "$BACKEND_ENV" ]; then
        if [ -f "$BACKEND_TMPL" ]; then
            POSTGRES_DB=$(grep '^POSTGRES_DB=' "$ROOT_ENV" | cut -d= -f2)
            POSTGRES_USER=$(grep '^POSTGRES_USER=' "$ROOT_ENV" | cut -d= -f2)
            POSTGRES_PASSWORD=$(grep '^POSTGRES_PASSWORD=' "$ROOT_ENV" | cut -d= -f2)
            export API_PORT FRONT_PORT
            envsubst '${API_PORT} ${FRONT_PORT}' < "$BACKEND_TMPL" \
                | sed \
                    -e "s|^POSTGRES_DB=.*|POSTGRES_DB=${POSTGRES_DB}|" \
                    -e "s|^POSTGRES_USER=.*|POSTGRES_USER=${POSTGRES_USER}|" \
                    -e "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${POSTGRES_PASSWORD}|" \
                > "$BACKEND_ENV"
            ok "backend/.env создан"
        else
            warn "Шаблон bin/backend.env не найден — создай backend/.env вручную"
        fi
    else
        sed -i \
            -e "s|^API_URL=.*|API_URL=http://localhost:${API_PORT}|" \
            -e "s|^FRONT_URL=.*|FRONT_URL=http://localhost:${FRONT_PORT}|" \
            -e "s|^CORS_ORIGIN=.*|CORS_ORIGIN=http://localhost:${FRONT_PORT}|" \
            -e "s|^GOOGLE_CALLBACK_URL=.*|GOOGLE_CALLBACK_URL=http://localhost:${API_PORT}/auth/google/callback|" \
            "$BACKEND_ENV"
        ok "backend/.env обновлён (внешние URL)"
    fi
else
    info "Backend не выбран — пропускаю"
fi

# ─────────────────────────────────────────
# 10. frontend/.env
# ─────────────────────────────────────────
step "Настройка frontend/.env..."

FRONTEND_ENV="$PROJECT_ROOT/frontend/.env"

if [[ $SEL == *1* ]] || [[ $SEL == *2* ]]; then
    if [[ $SEL == *1* ]]; then
        FRONTEND_TMPL="$SCRIPT_DIR/frontend-angular.env"
        FRONTEND_TYPE="Angular"
    else
        FRONTEND_TMPL="$SCRIPT_DIR/frontend-nextjs.env"
        FRONTEND_TYPE="Next.js"
    fi
    if [ ! -f "$FRONTEND_ENV" ]; then
        if [ -f "$FRONTEND_TMPL" ]; then
            export API_PORT
            envsubst '${API_PORT}' < "$FRONTEND_TMPL" > "$FRONTEND_ENV"
            ok "frontend/.env создан (${FRONTEND_TYPE})"
        else
            warn "Шаблон ${FRONTEND_TMPL} не найден — создай frontend/.env вручную"
        fi
    else
        if [[ $SEL == *1* ]]; then
            sed -i -e "s|^API_URL=.*|API_URL=http://localhost:${API_PORT}|" "$FRONTEND_ENV"
        else
            sed -i -e "s|^NEXT_PUBLIC_API_URL=.*|NEXT_PUBLIC_API_URL=http://localhost:${API_PORT}|" "$FRONTEND_ENV"
        fi
        ok "frontend/.env обновлён (${FRONTEND_TYPE})"
    fi
else
    info "Frontend не выбран — пропускаю"
fi

# ─────────────────────────────────────────
# 11. Parser venv
# ─────────────────────────────────────────
step "Настройка parser venv..."

PARSER_DIR="$PROJECT_ROOT/parser"
if [[ $SEL == *3* ]]; then
    if [ -d "$PARSER_DIR" ] && [ -f "$PARSER_DIR/requirements.txt" ]; then
        if [ ! -d "$PARSER_DIR/venv" ]; then
            python3 -m venv "$PARSER_DIR/venv"
            "$PARSER_DIR/venv/bin/pip" install -q --upgrade pip
            "$PARSER_DIR/venv/bin/pip" install -q -r "$PARSER_DIR/requirements.txt"
            ok "Parser venv создан"
        else
            ok "Parser venv уже существует"
        fi
    else
        warn "parser/ не найден или нет requirements.txt — пропускаю"
    fi
else
    info "FastAPI не выбран — пропускаю"
fi

# ─────────────────────────────────────────
# 12. Node.js (nvm)
# ─────────────────────────────────────────
step "Настройка Node.js через nvm..."

NODE_VERSION=$(grep -m1 'FROM node:' "$PROJECT_ROOT/docker/frontend.Dockerfile" \
    | sed 's/FROM node:\([0-9]*\).*/\1/' 2>/dev/null || echo "22")
info "Версия Node: $NODE_VERSION"

echo "$NODE_VERSION" > "$PROJECT_ROOT/.nvmrc"

NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ ! -f "$NVM_DIR/nvm.sh" ]; then
    info "Устанавливаю nvm..."
    NVM_LATEST=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest \
        | grep '"tag_name"' | sed 's/.*"\(v[^"]*\)".*/\1/')
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_LATEST}/install.sh" | bash
    ok "nvm ${NVM_LATEST} установлен"
else
    ok "nvm уже установлен"
fi

# shellcheck source=/dev/null
source "$NVM_DIR/nvm.sh"

SYSTEM_NODE=$(node -v 2>/dev/null | sed 's/v\([0-9]*\).*/\1/' || echo "0")
if [ "$SYSTEM_NODE" != "$NODE_VERSION" ]; then
    nvm install "$NODE_VERSION"
    nvm alias default "$NODE_VERSION"
    nvm use "$NODE_VERSION"
    ok "Node $NODE_VERSION установлен и назначен дефолтным"
else
    ok "Node $NODE_VERSION уже активен"
fi

# ─────────────────────────────────────────
# 13. Lazydocker
# ─────────────────────────────────────────
step "Установка lazydocker..."

if command -v lazydocker &>/dev/null; then
    ok "lazydocker уже установлен"
else
    LD_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazydocker/releases/latest" \
        | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
    curl -sL "https://github.com/jesseduffield/lazydocker/releases/download/v${LD_VERSION}/lazydocker_${LD_VERSION}_Linux_x86_64.tar.gz" \
        | tar xz -C "$HOME/.local/bin" lazydocker
    ok "lazydocker ${LD_VERSION} установлен"
fi

# ─────────────────────────────────────────
# Готово
# ─────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Готово!                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}source ~/.bashrc${NC}          — обновить окружение"
echo -e "  ${CYAN}doc all${NC}                   — запустить контейнеры"
echo -e "  ${CYAN}bin/reset-ports.sh${NC}        — пересчитать порты вручную"
echo ""
