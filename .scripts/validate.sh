#!/usr/bin/env bash

echo "🧪 [Validate] Checking submodule state..."

git submodule status

echo "📌 Checking for uninitialized modules..."

git submodule foreach 'git status'

echo "✅ Validation completed"