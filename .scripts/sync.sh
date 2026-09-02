#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

echo "📁 Project root: $PROJECT_ROOT"
echo "🔄 [Sync] Updating submodules..."

git submodule sync --recursive
git submodule update --remote --merge --recursive

echo "✅ Sync completed"