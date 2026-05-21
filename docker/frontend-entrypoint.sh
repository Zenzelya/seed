#!/bin/sh
set -e

echo ">>> Cleaning node_modules..."
rm -rf node_modules

echo ">>> Installing dependencies..."
yarn install --production=false

echo ">>> Executing command: $@"
exec "$@"
