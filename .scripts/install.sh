#!/usr/bin/env bash

set -e

echo "⚙️ [Install] Preparing environment..."
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

sudo apt update -y || sudo yum update -y

echo "📦 Ensuring git is installed..."

git --version

echo "🚀 Running bootstrap..."

bash .scripts/bootstrap.sh

echo "✅ Environment ready"