#!/usr/bin/env bash

set -e

echo "🔄 [Sync] Updating submodules..."

git submodule sync --recursive
git submodule update --remote --recursive

echo "✅ Sync completed"