#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../backend"
[ -d .venv ] && source .venv/bin/activate
exec uvicorn main:app --host 0.0.0.0 --port "${API_PORT:-8000}"
