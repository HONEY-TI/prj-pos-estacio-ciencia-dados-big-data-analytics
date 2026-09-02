#!/usr/bin/env bash

echo "🧪 [Validate] Checking submodule state..."
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

git submodule status

echo "📌 Checking for uninitialized modules..."

git submodule foreach 'git status'

echo "✅ Validation completed"