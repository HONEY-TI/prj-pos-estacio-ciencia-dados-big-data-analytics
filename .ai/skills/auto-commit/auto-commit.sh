#!/usr/bin/env bash
set -euo pipefail

BRANCH=$(git rev-parse --abbrev-ref HEAD)

log() {
  echo "[$1] $2"
}

validate() {
  command -v git >/dev/null || exit 1
  git rev-parse --is-inside-work-tree >/dev/null || exit 1
  git config user.name >/dev/null || exit 1
  git config user.email >/dev/null || exit 1
  git remote get-url origin >/dev/null || exit 1
}

scope() {
  case "$1" in
    src/domain/*) echo "domain" ;;
    src/application/*) echo "app" ;;
    src/infrastructure/*) echo "infra" ;;
    src/presentation/*) echo "presentation" ;;
    test/*|tests/*|*.spec.*|*.test.*) echo "tests" ;;
    *.md) echo "docs" ;;
    *.json|*.yaml|*.yml|*.env*) echo "config" ;;
    Dockerfile*|docker-*) echo "docker" ;;
    .github/*) echo "ci" ;;
    *) dirname "$1" | tr '/' '-' ;;
  esac
}

# Regra obrigatória 3: nunca commitar binário sem verificação.
# Arquivos binários reportam "-" nas colunas de add/del do --numstat.
is_binary() {
  local file="$1"
  local numstat
  numstat=$(git diff --numstat -- "$file" 2>/dev/null || true)
  if [[ -z "$numstat" ]]; then
    numstat=$(git diff --numstat --cached -- "$file" 2>/dev/null || true)
  fi
  [[ "$numstat" == -$'\t'-$'\t'* ]]
}

# Refinamento semântico pelo conteúdo do diff (segue a ordem da tabela da skill)
type() {
  local diff="$1"
  local default="$2"

  grep -qE '^\+.*(test|spec|describe|it\(|expect\()' <<< "$diff" && echo test && return
  grep -qE '^\+.*(interface |type |enum |abstract class)' <<< "$diff" && echo refactor && return
  grep -qE '^\+.*(@Injectable|@Controller|@Module)' <<< "$diff" && echo feat && return
  grep -qE '^\+.*(function |async |=>|class )' <<< "$diff" && echo feat && return
  grep -qiE '^\+.*(fix|bug|erro|error|correct)' <<< "$diff" && echo fix && return
  grep -qiE '^\+.*(password|secret|token|apikey)' <<< "$diff" && echo security && return
  grep -qE '^\+.*(console\.|logger\.|log\()' <<< "$diff" && echo chore && return
  grep -qE '^-' <<< "$diff" && echo refactor && return

  echo "$default"
}

commit_file() {
  local file="$1"
  local status diff commit_type action file_name file_scope binary=false

  status=$(git status --porcelain=v1 -- "$file" | cut -c1-2)
  file_name=$(basename "$file")
  file_scope=$(scope "$file")

  case "$status" in
    "A "|"??") commit_type="feat"; action="adicionar" ;;
    "M "|" M") commit_type="fix"; action="atualizar" ;;
    "D "|" D") commit_type="chore"; action="remover" ;;
    R*) commit_type="refactor"; action="renomear" ;;
    *) commit_type="chore"; action="alterar" ;;
  esac

  if is_binary "$file"; then
    binary=true
    # Arquivos binários não passam pela análise de diff de conteúdo;
    # tratados separadamente como determina a skill.
    [[ "$commit_type" == "fix" ]] && commit_type="chore"
    log "BIN" "Arquivo binário detectado: $file — commit tratado separadamente"
  else
    diff=$(git diff -- "$file" || true)
    commit_type=$(type "$diff" "$commit_type")
  fi

  git add "$file"

  if $binary; then
    git commit \
      -m "$commit_type($file_scope): $action arquivo binário $file_name" \
      -m "## Alteração

Arquivo binário:
\`$file\`

## Resumo

- Tipo: $commit_type
- Escopo: $file_scope
- Ação: $action
- Observação: arquivo binário, sem análise de diff de conteúdo

Commit criado automaticamente pela skill auto-commit."
  else
    git commit \
      -m "$commit_type($file_scope): $action $file_name" \
      -m "## Alteração

Arquivo:
\`$file\`

## Resumo

- Tipo: $commit_type
- Escopo: $file_scope
- Ação: $action

## Detalhes

$(grep '^+[^+]' <<< "$diff" | head -10 | sed 's/^/- /')

Commit criado automaticamente pela skill auto-commit."
  fi
}

commit_submodules() {
  git submodule foreach --quiet \
  'git status --porcelain | grep -q . && echo $displaypath || true' |
  while read -r sub; do
    cd "$sub"
    bash "$(git rev-parse --show-toplevel)/auto-commit.sh" --no-push
    git push origin HEAD
    cd - >/dev/null
    git add "$sub"
    git commit \
      -m "chore(deps): atualizar submodule $(basename "$sub")" \
      -m "Atualização automática da referência do submodule."
  done
}

commit_files() {
  git status --porcelain=v1 -uall -z |
  while IFS= read -r -d '' entry; do
    file="${entry:3}"
    [[ -d "$file/.git" ]] && continue
    commit_file "$file"
  done
}

main() {
  validate
  git submodule update --init --recursive
  commit_submodules
  commit_files

  [[ "${1:-}" == "--no-push" ]] && exit 0

  git push origin "$BRANCH"
}

main "$@"
