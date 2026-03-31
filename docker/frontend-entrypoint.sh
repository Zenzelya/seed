#!/bin/sh
set -e

echo ">>> Cleaning node_modules..."
rm -rf node_modules

echo ">>> Installing dependencies..."
yarn install --production=false

echo ">>> Starting json-server in background..."
yarn json-server --watch db.json --host 0.0.0.0 --port 3001 &

echo ">>> Executing command: $@"
exec "$@"
