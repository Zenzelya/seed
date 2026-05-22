#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

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

# Запустить и добавить в автозапуск
if ! systemctl is-active --quiet docker; then
    sudo systemctl enable --now docker
    ok "Docker запущен"
fi

# Добавить пользователя в группу docker
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
    ok "Context переключён на default (нативный daemon)"
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

# PATH в .bashrc
if ! grep -q '\.local/bin' "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    ok "PATH добавлен в .bashrc"
fi

# ─────────────────────────────────────────
# 5. Клонирование репозиториев
# ─────────────────────────────────────────
step "Клонирование репозиториев..."

bash "$SCRIPT_DIR/clone_projects.sh"

# ─────────────────────────────────────────
# 6. backend .env
# ─────────────────────────────────────────
step "Настройка backend .env..."

BACKEND_ENV="$PROJECT_ROOT/backend/.env"
ENV_TEMPLATE="$SCRIPT_DIR/backend.env"

if [ ! -f "$BACKEND_ENV" ]; then
    if [ -f "$ENV_TEMPLATE" ]; then
        cp "$ENV_TEMPLATE" "$BACKEND_ENV"
        ok "backend/.env создан из шаблона"
    else
        warn "Шаблон $ENV_TEMPLATE не найден — создай backend/.env вручную"
    fi
else
    ok "backend/.env уже существует"
fi

# ─────────────────────────────────────────
# 7. Parser venv
# ─────────────────────────────────────────
step "Настройка parser venv..."

PARSER_DIR="$PROJECT_ROOT/parser"
if [ -d "$PARSER_DIR" ] && [ -f "$PARSER_DIR/requirements.txt" ]; then
    if [ ! -d "$PARSER_DIR/venv" ]; then
        python3 -m venv "$PARSER_DIR/venv"
        "$PARSER_DIR/venv/bin/pip" install -q --upgrade pip
        "$PARSER_DIR/venv/bin/pip" install -q -r "$PARSER_DIR/requirements.txt"
        ok "Parser venv создан и зависимости установлены"
    else
        ok "Parser venv уже существует"
    fi
else
    warn "parser/ не найден или нет requirements.txt — пропускаю"
fi

# ─────────────────────────────────────────
# 8. Node.js (nvm)
# ─────────────────────────────────────────
step "Настройка Node.js через nvm..."

NODE_VERSION=$(grep -m1 'FROM node:' "$PROJECT_ROOT/docker/frontend.Dockerfile" \
    | sed 's/FROM node:\([0-9]*\).*/\1/')
info "Версия Node в контейнере: $NODE_VERSION"

# Записать .nvmrc в корень проекта
echo "$NODE_VERSION" > "$PROJECT_ROOT/.nvmrc"

# Установить nvm если нет
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

# Загрузить nvm в текущую сессию
# shellcheck source=/dev/null
source "$NVM_DIR/nvm.sh"

# Установить нужную версию и сделать дефолтной
SYSTEM_NODE=$(node -v 2>/dev/null | sed 's/v\([0-9]*\).*/\1/' || echo "0")
if [ "$SYSTEM_NODE" != "$NODE_VERSION" ]; then
    info "Системный Node: ${SYSTEM_NODE:-не установлен}, нужен: $NODE_VERSION"
    nvm install "$NODE_VERSION"
    nvm alias default "$NODE_VERSION"
    nvm use "$NODE_VERSION"
    ok "Node $NODE_VERSION установлен и назначен дефолтным"
else
    ok "Node $NODE_VERSION уже активен"
fi

# ─────────────────────────────────────────
# 9. Lazydocker
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
# Done
# ─────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Готово!                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}source ~/.bashrc${NC}     — обновить окружение"
echo -e "  ${CYAN}doc all${NC}              — запустить все контейнеры"
echo -e "  ${CYAN}doc rebuild${NC}          — пересобрать"
echo ""
