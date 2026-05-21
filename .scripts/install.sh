#!/usr/bin/env bash

set -e

echo "⚙️ [Install] Preparing environment..."

sudo apt update -y || sudo yum update -y

echo "📦 Ensuring git is installed..."

git --version

echo "🚀 Running bootstrap..."

bash .scripts/bootstrap.sh

echo "✅ Environment ready"