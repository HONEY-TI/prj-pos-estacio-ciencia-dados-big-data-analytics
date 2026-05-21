#!/usr/bin/env bash

set -e

echo "🚀 [Insights] Starting full repository bootstrap..."

if [ -f .gitmodules ]; then
  echo "📦 Syncing git submodules..."
  git submodule sync --recursive
  git submodule update --init --recursive
else
  echo "ℹ️ No submodules found"
fi

echo "✅ Bootstrap completed successfully"
