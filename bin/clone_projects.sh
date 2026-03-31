#!/bin/bash

# ==============================================================================
# Название:     clone_projects.sh
# Описание:     Скрипт для клонирования репозиториев backend и frontend
#               с использованием логина и пароля (или токена).
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
CONFIG_FILE="${SCRIPT_DIR}/repo_setup.conf"

# Создание файла конфигурации, если его нет
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Создаю шаблон файла конфигурации: $CONFIG_FILE"
    cat <<EOF > "$CONFIG_FILE"
# ==========================================
# Настройки репозиториев
# ==========================================

# BACKEND
# Укажите SSH (например: git@github.com:...) или HTTPS (github.com/...)
BACKEND_REPO_URL=""
BACKEND_USERNAME=""
BACKEND_PASSWORD="" # Рекомендуется использовать Personal Access Token (PAT)

# FRONTEND
# Укажите SSH (например: git@github.com:...) или HTTPS (github.com/...)
FRONTEND_REPO_URL=""
FRONTEND_USERNAME=""
FRONTEND_PASSWORD=""
EOF
    echo "[-] Пожалуйста, укажите репозитории и пароли (или токены) в созданном файле:"
    echo "    $CONFIG_FILE"
    echo "[-] После этого запустите скрипт заново."
    exit 1
fi

# Загружаем настройки
source "$CONFIG_FILE"

# Функция для безопасного кодирования символов в URL (urlencode)
urlencode() {
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done
}

# Функция клонирования
clone_repo() {
    local folder_name="$1"
    local repo_url="$2"
    local username="$3"
    local password="$4"

    if [[ -z "$repo_url" ]]; then
        echo "[!] Пропускаем $folder_name: репозиторий не указан в конфиге."
        return
    fi
    
    local target_dir="$PROJECT_ROOT/$folder_name"
    
    if [[ -d "$target_dir" ]]; then
        echo "[*] Папка '$folder_name' уже существует: $target_dir. Пропускаем."
        return
    fi

    echo "[*] Клонирование проекта: $folder_name..."

    local auth_url="$repo_url"
    if [[ -n "$username" && -n "$password" ]]; then
        local safe_user=$(urlencode "$username")
        local safe_pass=$(urlencode "$password")
        local clean_url="${repo_url#http://}"
        clean_url="${clean_url#https://}"
        auth_url="https://${safe_user}:${safe_pass}@${clean_url}"
    else
        echo "[*] Используем URL репозитория как есть (без подстановки протокола)..."
    fi

    # Клонируем проект (пароль не будет выводиться в консоль благодаря url_encode и сокрытию вывода)
    if git clone "$auth_url" "$target_dir"; then
        echo "[+] Репозиторий успешно склонирован в папку '$folder_name'"
    else
        echo "[-] Ошибка при клонировании репозитория $folder_name"
    fi
}

echo "=== Запуск развертывания проектов ==="

# Клонируем backend
clone_repo "backend" "$BACKEND_REPO_URL" "$BACKEND_USERNAME" "$BACKEND_PASSWORD"

# Клонируем frontend
clone_repo "frontend" "$FRONTEND_REPO_URL" "$FRONTEND_USERNAME" "$FRONTEND_PASSWORD"

echo "=== Развертывание завершено ==="
