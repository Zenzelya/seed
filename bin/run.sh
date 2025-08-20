#!/bin/bash
set -e

case "$1" in
  api)
     docker compose --profile api up --build
    ;;
  all)
    docker compose --profile api --profile frontend up --build
    ;;
  *)
    echo "❌ Неизвестная команда: $1"
    echo "Доступные команды: api, all"
    exit 1
    ;;
esac
