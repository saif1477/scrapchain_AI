#!/usr/bin/env bash
# One-shot local setup: backend + demo (no Docker needed).
set -euo pipefail
cd "$(dirname "$0")/../backend"
python3 -m venv .venv 2>/dev/null || true
source .venv/bin/activate
pip install -q -r requirements.txt
echo "✅ Setup done. Run: bash scripts/run_backend.sh"
