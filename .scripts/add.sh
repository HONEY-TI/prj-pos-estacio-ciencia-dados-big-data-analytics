#!/usr/bin/env bash

set -e

if [ $# -ne 1 ]; then
  echo "❌ Usage: $0 <repository-url>"
  exit 1
fi

# Vai para a raiz do projeto (pai de .scripts)
cd "$(dirname "$0")/.."

REPO_URL="$1"
SUBMODULE_NAME="$(basename "$REPO_URL" .git)"

echo "🚀 [Insights] Adding git submodule '$SUBMODULE_NAME'..."

git submodule add "$REPO_URL" "$SUBMODULE_NAME"

echo "📦 Syncing submodules..."
git submodule sync --recursive
git submodule update --init --recursive

git add .gitmodules "$SUBMODULE_NAME"

echo "✅ Submodule '$SUBMODULE_NAME' added successfully!"
echo "Next step:"
echo "  git commit -m \"Add submodule $SUBMODULE_NAME\""