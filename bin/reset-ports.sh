#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

# shellcheck source=lib-ports.sh
source "$SCRIPT_DIR/lib-ports.sh"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
step() { echo -e "${GREEN}[+]${NC} $1"; }
info() { echo -e "${CYAN}[*]${NC} $1"; }

ENV_FILE="$PROJECT_ROOT/.env"

if [ ! -f "$ENV_FILE" ]; then
    _lib_fail ".env не найден. Сначала запусти: bin/setup.sh"
    exit 1
fi

SEL=$(grep '^COMPOSE_SERVICES=' "$ENV_FILE" 2>/dev/null | cut -d= -f2 || true)
if [ -z "$SEL" ]; then
    _lib_fail "COMPOSE_SERVICES не найден в .env. Запусти: bin/setup.sh"
    exit 1
fi

case "${1:-}" in
    --auto)
        auto_fix_ports
        ;;
    "")
        step "Ищу первый свободный слот..."
        SLOT=$(find_free_slot "$SEL")
        step "Применяю слот ${SLOT}..."
        apply_slot "$SLOT" "$SEL"
        ;;
    [0-9]*)
        SLOT="$1"
        step "Применяю слот ${SLOT} принудительно..."
        apply_slot "$SLOT" "$SEL"
        ;;
    *)
        echo "Использование: bin/reset-ports.sh [--auto | SLOT]"
        echo ""
        echo "  (без аргументов)  найти первый свободный слот и применить"
        echo "  --auto            проверить текущие порты, сменить только если заняты"
        echo "  SLOT              форсировать конкретный слот (0 = базовые порты)"
        echo ""
        echo "  Текущий выбор сервисов: ${SEL}"
        exit 1
        ;;
esac
