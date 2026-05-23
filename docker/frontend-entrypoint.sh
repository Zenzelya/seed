#!/bin/sh
set -e

if [ -f package.json ] && [ ! -f node_modules/.package-lock.json ] && [ ! -d node_modules/.bin ]; then
    echo ">>> npm install"
    npm install
fi

echo ">>> Executing: $@"
exec "$@"
