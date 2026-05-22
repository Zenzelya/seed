#!/bin/sh
set -e

echo "[entrypoint] Installing/updating requirements..."
pip install --quiet --no-cache-dir -r requirements.txt

echo "[entrypoint] Executing command: $@"
exec "$@"
