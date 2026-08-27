#!/usr/bin/env bash

# Exit on error.
set -e

SCRIPT_DIR="$(readlink -f "$(dirname "$0")")"
WEB_APP_DIR="$SCRIPT_DIR/.."

# Store the original directory
ORIGINAL_DIR=$(pwd)

# Set up trap to ensure we return to original directory
trap 'cd "$ORIGINAL_DIR"' EXIT

cd "$WEB_APP_DIR"

start_time=$(date +%s)

echo "[Build]: Extracting and compiling translations"
npm run translate --prefix ../../

echo "[Build]: Building app"
if [ "${DOCUMENSO_SKIP_TYPECHECK:-false}" = "true" ]; then
  # The Vercel container builder has a tighter memory ceiling than the
  # supported long-lived container hosts. Type checking is performed in CI;
  # skip the duplicate build-time check here so the production bundle can be
  # produced within that ceiling.
  cross-env NODE_ENV=production react-router build
else
  npm run build:app
fi

echo "[Build]: Building server"
npm run build:server

# Copy over the entry point for the server.
cp server/main.js build/server/main.js

# Copy over all web.js translations
cp -r ../../packages/lib/translations build/server/hono/packages/lib/translations

# Time taken
end_time=$(date +%s)

echo "[Build]: Done in $((end_time - start_time)) seconds"
