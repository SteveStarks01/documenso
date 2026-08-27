#!/bin/sh

# 🚀 Starting Documenso...
printf "🚀 Starting Documenso...\n\n"

# 🔐 Check certificate configuration
printf "🔐 Checking certificate configuration...\n"

CERT_PATH="${NEXT_PRIVATE_SIGNING_LOCAL_FILE_PATH:-/opt/documenso/cert.p12}"

if [ -f "$CERT_PATH" ] && [ -r "$CERT_PATH" ]; then
    printf "✅ Certificate file found and readable - document signing is ready!\n"
else
    printf "⚠️ Certificate not found or not readable\n"
    printf "💡 Tip: Documenso will still start, but document signing will be unavailable\n"
    printf "🔧 Check: http://localhost:3000/api/certificate-status for detailed status\n"
fi

printf "\n📚 Useful Links:\n"
printf "📖 Documentation: https://docs.documenso.com\n"
printf "🐳 Self-hosting guide: https://docs.documenso.com/developers/self-hosting\n"
printf "🔐 Certificate setup: https://docs.documenso.com/developers/self-hosting/signing-certificate\n"
printf "🏥 Health check: http://localhost:3000/api/health\n"
printf "📊 Certificate status: http://localhost:3000/api/certificate-status\n"
printf "👥 Community: https://github.com/documenso/documenso\n\n"

printf "🗄️  Running database migrations...\n"

# Vercel's Neon integration supplies standard database variable names. Map
# those to Documenso's private Prisma names only when the latter were not
# explicitly configured, so managed database connections work at runtime.
if [ -z "${NEXT_PRIVATE_DATABASE_URL:-}" ] && [ -n "${DATABASE_URL:-}" ]; then
    export NEXT_PRIVATE_DATABASE_URL="$DATABASE_URL"
fi

if [ -z "${NEXT_PRIVATE_DIRECT_DATABASE_URL:-}" ]; then
    export NEXT_PRIVATE_DIRECT_DATABASE_URL="${DATABASE_URL_UNPOOLED:-${NEXT_PRIVATE_DATABASE_URL:-}}"
fi

if [ -z "${NEXT_PRIVATE_DATABASE_URL:-}" ]; then
    printf "❌ A database connection is required. Set DATABASE_URL or NEXT_PRIVATE_DATABASE_URL.\n"
    exit 1
fi

# Vercel requires a container to accept TCP connections shortly after it is
# started. Run the idempotent migration in the background so the HTTP server
# can become healthy immediately; the first deployment may briefly show the
# app while the schema finishes initializing.
npx prisma migrate deploy --schema ../../packages/prisma/schema.prisma &
MIGRATION_PID=$!

printf "🌟 Starting Documenso server...\n"
# Keep Documenso on a loopback port while the readiness proxy binds Vercel's
# externally supplied PORT immediately.
HOSTNAME=127.0.0.1 PORT="${DOCUMENSO_UPSTREAM_PORT:-3000}" node build/server/main.js &
SERVER_PID=$!

# Keep the container tied to the web server. Surface a migration failure in
# the runtime logs without terminating a server that has already started.
(
    wait "$MIGRATION_PID" || printf "❌ Database migration failed; inspect runtime logs.\n"
) &

exec node /app/docker/vercel-proxy.js
