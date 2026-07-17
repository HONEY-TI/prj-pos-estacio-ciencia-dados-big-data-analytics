#!/bin/bash

set -e

if [ $# -ne 1 ]; then
  echo "❌ Usage: $0 <repository-url>"
  exit 1
fi

SUBMODULE="$0"

echo "🔴 Removendo submodule: $SUBMODULE"

# 1. desativa submodule
git submodule deinit -f "$SUBMODULE" || true

# 2. remove do git index
git rm -f "$SUBMODULE" || true

# 3. remove metadata interna
rm -rf ".git/modules/$SUBMODULE"

# 4. remove pasta local (caso ainda exista)
rm -rf "$SUBMODULE"

echo "🧹 Limpando .gitmodules"

# 5. remove entrada do .gitmodules
if [ -f .gitmodules ]; then
    git config -f .gitmodules --remove-section "submodule.$SUBMODULE" || true
fi

# 6. commit e push
git add .gitmodules || true

git commit -m "Remove submodule $SUBMODULE"

git push origin main

echo "✅ Submodule removido e enviado para o GitHub"