#!/bin/sh
set -e

echo "[entrypoint] Installing/updating requirements..."
pip install --quiet --no-cache-dir -r requirements.txt

echo "[entrypoint] Starting uvicorn..."
exec uvicorn main:app --host 0.0.0.0 --port 8000 --reload
