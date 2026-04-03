#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created .env from .env.example. Edit secrets before exposing publicly."
fi

docker compose -f docker-compose.free.yml up -d --build

echo "Backend deployed."
echo "Check: docker compose -f docker-compose.free.yml ps"
echo "Health: curl http://127.0.0.1:8000/health"
