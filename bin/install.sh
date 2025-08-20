#!/bin/bash
set -euo pipefail

OS_TYPE="$(uname -s)"
CONFIG_FILE="./config.json"

# Проверка наличия jq
if ! command -v jq >/dev/null 2>&1; then
  echo "❌ jq не установлен."
  read -rp "Установить jq сейчас? [Y/n]: " install_jq
  install_jq=${install_jq:-Y}
  if [[ "$install_jq" =~ ^[Yy]$ ]]; then
    echo "⬇️ Устанавливаем jq..."
    sudo apt-get update && sudo apt-get install -y jq
    echo "✅ jq установлен."
  else
    echo "⚠️ jq необходим для работы скрипта. Прерываем выполнение."
    exit 1
  fi
fi

# === Получение ссылок ===
get_latest_links() {
    local base_url="https://docs.docker.com/desktop/release-notes/"
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local tmp_file="$script_dir/docker_release_notes.tmp"
    local config_file="$script_dir/config.json"

    echo "[*] Скачиваем HTML страницу..."
    if ! curl -fsSL "$base_url" \
        -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) Chrome/114.0.0.0 Safari/537.36" \
        -H "Accept: text/html" \
        --compressed \
        -o "$tmp_file"; then
        echo -e "\e[31m[!] Ошибка загрузки страницы\e[0m" >&2
        return 1
    fi

    echo "[*] Ищем ссылки на checksums.txt..."
    mapfile -t checksums_links < <(grep -oP 'https://desktop\.docker\.com/linux/main/amd64/\d{6,8}/checksums\.txt' "$tmp_file" | sort -u)

    echo "[*] Ищем ссылки на .deb..."
    mapfile -t deb_links < <(grep -oP 'https://desktop\.docker\.com/linux/main/amd64/\d{6,8}/docker-desktop-amd64\.deb' "$tmp_file" | sort -u)

    if [[ ${#checksums_links[@]} -eq 0 || ${#deb_links[@]} -eq 0 ]]; then
        echo -e "\e[31m[!] Недостаточно ссылок найдено.\e[0m" >&2
        return 1
    fi

    local -A checksums_map deb_map
    for link in "${checksums_links[@]}"; do
        local id
        id=$(echo "$link" | grep -oP '\d{6,8}')
        checksums_map["$id"]="$link"
    done

    for link in "${deb_links[@]}"; do
        local id
        id=$(echo "$link" | grep -oP '\d{6,8}')
        deb_map["$id"]="$link"
    done

    local max_id=""
    for id in "${!checksums_map[@]}"; do
        if [[ "${deb_map[$id]+isset}" == "isset" ]]; then
            if [[ -z "$max_id" || "$id" -gt "$max_id" ]]; then
                max_id="$id"
            fi
        fi
    done

    if [[ -z "$max_id" ]]; then
        echo -e "\e[31m[!] Не найден общий XXXXXX.\e[0m" >&2
        return 1
    fi

    echo "{ \"docker_desktop_version_linux\": \"$max_id\" }" > "$config_file"
    echo -e "\e[32m[+] Версия Docker Desktop: $max_id\e[0m"
    echo -e "\e[36m[✓] Сохранено в $config_file\e[0m"
}

# === Проверки ===
check_docker_installed() {
  command -v docker >/dev/null 2>&1
}

check_docker_desktop_installed_linux() {
  if pgrep -fl 'Docker Desktop' >/dev/null; then
    return 0  # установлен
  else
    return 1  # не установлен
  fi
}

get_docker_version() {
  docker --version | awk '{print $3}' | sed 's/,//'
}

get_latest_docker_version_linux() {
  apt-cache policy docker-ce | grep Candidate | awk '{print $2}'
}

# === Установка Docker CE ===
install_docker_linux() {
  echo "🐧 Установка Docker CE..."
  sudo apt-get update
  sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  echo "✅ Docker CE установлен."
}

update_docker_linux() {
  echo "🔄 Обновляем Docker CE..."
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  echo "✅ Docker CE обновлён."
}

# === Docker Desktop ===
uninstall_docker_desktop_linux() {
  echo "🗑️ Удаляем Docker Desktop..."
  sudo apt-get remove -y docker-desktop
  sudo rm -rf /usr/local/bin/com.docker.cli
  sudo apt-get autoremove -y
  echo "✅ Docker Desktop удалён."
}

install_docker_desktop_linux() {
  echo "🔍 Определяем последнюю версию Docker Desktop..."
  get_latest_links || {
    echo "❌ Не удалось получить последнюю версию."
    return 1
  }

  local ver
  ver=$(jq -r '.docker_desktop_version_linux' "$CONFIG_FILE")
  local deb_file="docker-desktop-amd64.deb"
  local deb_url="https://desktop.docker.com/linux/main/amd64/${ver}/docker-desktop-amd64.deb"

  echo "⬇️ Скачиваем Docker Desktop $ver..."
  curl -Lo "$deb_file" "$deb_url" || {
    echo "❌ Ошибка скачивания: $deb_url"
    return 1
  }

  echo "🔍 Проверяем $deb_file..."
  LANG=C file "$deb_file" | grep -q "Debian binary package" || {
    echo "❌ Неверный пакет. Файл имеет тип: $(file -b "$deb_file")"
    rm -f "$deb_file"
    return 1
  }

  echo "📦 Установка $deb_file..."
  sudo apt-get update
  sudo apt-get install -y "./$deb_file" || {
    echo "❌ Ошибка установки."
    rm -f "$deb_file"
    return 1
  }

  rm -f "$deb_file"
  echo "✅ Docker Desktop $ver установлен."
}

# === Главное меню ===
main_menu() {
  while true; do
    echo -e "\n=== Меню Docker ==="
    echo "1. Установить Docker CE"
    echo "2. Обновить Docker CE"
    echo "3. Установить Docker Desktop"
    echo "4. Обновить Docker Desktop"
    echo "5. Проверить версии"
    echo "0. Выход"
    
    read -rp "Выбор [0-5]: " choice
    
    case $choice in
      1)
        check_docker_installed && echo "⚠️ Docker уже установлен." || install_docker_linux
        ;;
      2)
        check_docker_installed && update_docker_linux || echo "❌ Docker не установлен."
        ;;
      3)
        check_docker_desktop_installed_linux && echo "⚠️ Docker Desktop уже установлен." || install_docker_desktop_linux
        ;;
      4)
        if check_docker_desktop_installed_linux; then
          echo "🔄 Обновляем Docker Desktop..."
          uninstall_docker_desktop_linux
          install_docker_desktop_linux
        else
          echo "❌ Docker Desktop не установлен."
        fi
        ;;
      5)
        check_docker_installed && echo "🧾 Docker: $(get_docker_version)" || echo "❌ Docker не установлен."
        check_docker_desktop_installed_linux && echo "🧾 Docker Desktop установлен" || echo "🚫 Docker Desktop не установлен"
        ;;
      0)
        echo "👋 Выход."
        exit 0
        ;;
      *)
        echo "❌ Неверный выбор."
        ;;
    esac
  done
}

main() {
  case "$OS_TYPE" in
    Linux)
      echo "🧭 Обнаружена ОС: Linux"
      main_menu
      ;;
    *)
      echo "❌ ОС $OS_TYPE не поддерживается."
      exit 1
      ;;
  esac
}

main "$@"