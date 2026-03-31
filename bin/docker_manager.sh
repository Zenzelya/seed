#!/bin/bash

# ==============================================================================
# Название:     docker_manager.sh
# Описание:     Скрипт для установки и управления Docker, использующий
#               централизованный файл конфигурации docker-setup.conf.
# ==============================================================================

set -euo pipefail
IFS=$'\n\t'

# === Конфигурация ===
LOG_FILE="/tmp/docker_manager.log"
SCRIPT_DIR=$(dirname "$(realpath "$0")")
CONFIG_FILE="${SCRIPT_DIR}/docker-setup.conf"

# Проверка и загрузка конфигурации
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "Ошибка: Не найден файл конфигурации: $CONFIG_FILE"
    exit 1
fi

DOCKER_DAEMON_JSON="/etc/docker/daemon.json"
CURRENT_USER=$(logname || echo "$USER")
USER_HOME=$(getent passwd "$CURRENT_USER" | cut -d: -f6)
DOCKER_DESKTOP_SETTINGS="$USER_HOME/.docker/desktop/settings.json"
DOCKER_DESKTOP_BIN="/opt/docker-desktop/bin/docker-desktop"

# === Логирование и Очистка ===
# Перенаправляем вывод в лог и на экран
exec > >(tee -i "$LOG_FILE") 2>&1

cleanup() {
    local exit_code=$?
    rm -f /tmp/docker-desktop.deb
    if [ $exit_code -ne 0 ]; then
        echo -e "\n[!] Скрипт завершился с ошибкой (код $exit_code). Проверьте лог: $LOG_FILE"
    fi
}
trap cleanup EXIT

# === Вспомогательные функции ===
check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "Ошибка: запустите через sudo"
        exit 1
    fi
}

check_deps() {
    local deps=(whiptail jq curl grep gpg lsb-release)
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "[*] Установка зависимости: $cmd"
            apt-get update && apt-get install -y "$cmd"
        fi
    done
}

# === Логика установки ===
install_engine() {
    echo "[*] Установка Docker Engine..."
    apt-get update
    apt-get install -y ca-certificates curl gnupg lsb-release
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    whiptail --title "Успех" --msgbox "Docker Engine (CE) успешно установлен!" 8 45
}

install_desktop() {
    # Если версия не задана в конфиге, ищем последнюю автоматически
    local ver="${DOCKER_DESKTOP_VERSION:-}"
    local url=""

    if [[ -n "$ver" ]]; then
        echo "[*] Версия зафиксирована в конфиге: $ver"
        url="https://desktop.docker.com/linux/main/amd64/${ver}/docker-desktop-amd64.deb"
    else
        echo "[*] Поиск последней версии Docker Desktop..."
        # Парсим страницу Release Notes, ищем первую ссылку на .deb для amd64
        # || echo "" предотвращает падение скрипта из-за set -e, если grep ничего не найдет
        url=$(curl -fsSL "https://docs.docker.com/desktop/release-notes/" | \
              grep -oP 'https://desktop\.docker\.com/linux/main/amd64/\d+/docker-desktop-amd64\.deb' | \
              head -n 1 || echo "")

        if [[ -z "$url" ]]; then
            whiptail --title "Ошибка" --msgbox "Не удалось автоматически определить последнюю версию.\nПроверьте интернет или раскомментируйте DOCKER_DESKTOP_VERSION в конфиге." 10 70
            return 1
        fi
        echo "[*] Найдена ссылка: $url"
    fi

    echo "[*] Загрузка пакета..."
    curl -Lo /tmp/docker-desktop.deb "$url"
    
    apt-get update
    # apt-get install сам разрешает зависимости для .deb пакета
    apt-get install -y /tmp/docker-desktop.deb
    whiptail --title "Успех" --msgbox "Docker Desktop успешно установлен!" 8 45
}

# === Оптимизация ===
apply_tuning() {
    echo "[*] Применение оптимизаций..."
    systemctl stop docker.service docker.socket || true

    mkdir -p "$(dirname "$DOCKER_DAEMON_JSON")"
    cat <<EOF > "$DOCKER_DAEMON_JSON"
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "${LOG_MAX_SIZE}", "max-file": "${LOG_MAX_FILE}" },
  "default-address-pools": [{ "base": "${DEFAULT_ADDRESS_POOL_BASE}", "size": ${DEFAULT_ADDRESS_POOL_SIZE} }],
  "exec-opts": ["native.cgroupdriver=systemd"],
  "features": { "buildkit": true }
}
EOF

    sudo -u "$CURRENT_USER" mkdir -p "$(dirname "$DOCKER_DESKTOP_SETTINGS")"
    # Создаем файл настроек от имени пользователя, чтобы избежать проблем с правами
    sudo -u "$CURRENT_USER" bash -c "cat > '$DOCKER_DESKTOP_SETTINGS'" <<EOF
{
  "cpus": ${DD_CPUS},
  "memoryMiB": ${DD_MEMORY_MIB},
  "swapMiB": ${DD_SWAP_MIB}
}
EOF
    systemctl start docker
    whiptail --title "Готово" --msgbox "Настройки из $CONFIG_FILE применены." 8 78
}

# === Удаление ===
remove_desktop() {
    if whiptail --title "Remove Desktop" --yesno "Удалить Docker Desktop (без удаления контейнеров и настроек)?" 10 70; then
        apt-get remove -y docker-desktop || true
        whiptail --title "Удаление" --msgbox "Docker Desktop удален." 8 45
    fi
}

purge_docker() {
    if whiptail --title "Purge" --yesno "Удалить Docker и ВСЕ данные?" 10 60; then
        systemctl stop docker.service docker.socket || true
        apt-get purge -y docker-ce docker-ce-cli containerd.io docker-desktop || true
        apt-get autoremove -y
        rm -rf /var/lib/docker /etc/docker "$USER_HOME/.docker"
        whiptail --title "Очистка" --msgbox "Система очищена." 8 45
    fi
}

# === Главное меню ===
main_menu() {
    while true; do
        CHOICE=$(whiptail --title "Docker Manager" --menu "Меню:" 19 60 8 \
            "1" "Install Engine" \
            "2" "Install Desktop" \
            "3" "Optimization" \
            "4" "Status" \
            "5" "Run Desktop" \
            "6" "Remove Desktop (Keep data)" \
            "7" "Purge (Full Delete)" \
            "0" "Exit" 3>&1 1>&2 2>&3) || exit 0

        case $CHOICE in
            1) install_engine ;;
            2) install_desktop ;;
            3) apply_tuning ;;
            4) whiptail --msgbox "Docker: $(systemctl is-active docker)" 8 45 ;;
            5)
                if [[ -x "$DOCKER_DESKTOP_PATH" ]]; then
                    sudo -u "$CURRENT_USER" DISPLAY=${DISPLAY:-":0"} "$DOCKER_DESKTOP_PATH" &>/dev/null &
                else
                    whiptail --msgbox "Не установлен или путь в конфиге неверный!\n($DOCKER_DESKTOP_PATH)" 8 78
                fi
                ;;
            6) remove_desktop ;;
            7) purge_docker ;;
            0) break ;;
        esac
    done
}

# Старт
check_root
check_deps
main_menu