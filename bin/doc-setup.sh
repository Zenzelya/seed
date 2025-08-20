#!/bin/bash
set -euo pipefail

CONFIG_PATH="/etc/docker/daemon.json"
BACKUP_PATH="/etc/docker/daemon.json.bak"
DOCKER_DESKTOP_PATH="/opt/docker-desktop/bin/docker-desktop"

# Проверка root
if [[ "$EUID" -ne 0 ]]; then
  echo "❌ Скрипт должен запускаться с root правами. Используйте sudo."
  exit 1
fi

# Проверка docker CLI
if ! command -v docker >/dev/null 2>&1; then
  echo "❌ Docker CLI не найден. Установите Docker перед запуском."
  exit 1
fi

# Остановка всех контейнеров
echo "🛑 Остановка всех запущенных контейнеров..."
docker ps -q | xargs -r docker stop

# Остановка Docker Desktop (если запущен)
if pgrep -f 'docker-desktop' >/dev/null 2>&1; then
  echo "🧯 Остановка Docker Desktop..."
  pkill -f 'docker-desktop'
  sleep 5
fi

# Остановка Docker Engine
echo "🛑 Остановка docker.service..."
systemctl stop docker

# Резервная копия конфигурации
if [[ -f "$CONFIG_PATH" ]]; then
  echo "📦 Создание резервной копии: $BACKUP_PATH"
  cp "$CONFIG_PATH" "$BACKUP_PATH"
fi

# Применение новых настроек
echo "🛠 Применение новых настроек в $CONFIG_PATH"
cat > "$CONFIG_PATH" <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "default-address-pools": [
    {
      "base": "172.80.0.0/16",
      "size": 24
    }
  ],
  "default-runtime": "runc",
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65535,
      "Soft": 65535
    }
  },
  "exec-opts": ["native.cgroupdriver=systemd"],
  "default-shm-size": "64m",
  "features": {
    "buildkit": true
  }
}
EOF

# Настройка лимитов Docker Desktop
CURRENT_USER=$(logname)
DOCKER_DESKTOP_SETTINGS="/home/$CURRENT_USER/.docker/desktop/settings.json"

echo "🧰 Применение рекомендуемых лимитов CPU/Memory/Swap для Docker Desktop..."

sudo -u "$CURRENT_USER" mkdir -p "$(dirname "$DOCKER_DESKTOP_SETTINGS")"

cat > "$DOCKER_DESKTOP_SETTINGS" <<EOF
{
  "cpus": 4,
  "memoryMiB": 4096,
  "swapMiB": 2048
}
EOF

echo "✅ Лимиты ресурсов применены к $DOCKER_DESKTOP_SETTINGS"

# Запуск Docker Engine
echo "▶️ Запуск docker.service..."
systemctl start docker

# Запуск Docker Desktop GUI
DISPLAY_ENV=${DISPLAY:-":0"}
echo "▶️ Попытка запустить Docker Desktop GUI от пользователя $CURRENT_USER..."

if [[ -x "$DOCKER_DESKTOP_PATH" ]]; then
  sudo -u "$CURRENT_USER" DISPLAY="$DISPLAY_ENV" "$DOCKER_DESKTOP_PATH" &>/dev/null &
  echo "✅ Docker Desktop GUI запущен"
else
  echo "⚠️ Не найден бинарь Docker Desktop: $DOCKER_DESKTOP_PATH"
fi

# Финальный вывод
echo "✅ Скрипт завершён. Текущие настройки:"
cat "$CONFIG_PATH"

echo "📦 Статус docker.service:"
systemctl status docker --no-pager | head -20

if pgrep -f docker-desktop >/dev/null; then
  echo "📦 Docker Desktop работает. PID:"
  pgrep -fa docker-desktop
else
  echo "⚠️ Docker Desktop не запущен (проверьте GUI вручную)"
fi
