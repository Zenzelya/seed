#!/bin/bash
set -euo pipefail

echo "🧹 Останавливаем Docker сервисы..."
sudo systemctl stop docker.service docker.socket || true

echo "🗑️ Удаляем Docker CE и связанные пакеты..."
sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "🗑️ Удаляем Docker Desktop (если установлен)..."
sudo apt-get purge -y docker-desktop || true

echo "🧹 Удаляем все docker файлы и конфиги..."
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
sudo rm -rf ~/.docker

echo "🧹 Удаляем docker desktop конфиги пользователя..."
rm -rf ~/.config/docker
rm -rf ~/.docker

echo "🧹 Удаляем systemd service docker desktop (если есть)..."
sudo rm -f /etc/systemd/system/docker-desktop.service
sudo systemctl daemon-reload

echo "✅ Docker и Docker Desktop удалены из системы."
