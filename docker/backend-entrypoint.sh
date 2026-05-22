#!/bin/sh
set -e

STAMP=/app/node_modules/.install-stamp
if [ ! -d /app/node_modules ] || [ ! -f "$STAMP" ] || [ /app/package.json -nt "$STAMP" ]; then
  echo ">>> package.json changed or node_modules missing, running npm install..."
  npm install --prefer-offline 2>&1
  touch "$STAMP"
fi

echo ">>> Executing: $@"
exec "$@"
