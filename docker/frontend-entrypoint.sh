#!/bin/sh
set -e

echo ">>> Installing dependencies..."
yarn install --production=false

echo ">>> Executing command: $@"
exec "$@"
