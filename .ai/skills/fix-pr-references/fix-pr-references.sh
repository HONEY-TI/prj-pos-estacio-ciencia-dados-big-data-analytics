#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# fix-pr-references.sh
# Corrige retroativamente commits já existentes (locais e remotos) que não
# referenciam o Pull Request ao qual pertencem — usando `git notes`.
#
# NUNCA reescreve hashes de commit, NUNCA faz push --force, NUNCA altera
# histórico existente. Submodules são sempre processados ANTES do
# repositório pai.
#
# Por padrão roda em modo DRY-RUN (só mostra a prévia, não escreve nada).
# Escrita real só acontece com --apply.
#
# Uso:
#   bash fix-pr-references.sh                 # dry-run (prévia) em tudo
#   bash fix-pr-references.sh --apply          # aplica de fato (submodules + pai)
#   bash fix-pr-references.sh --apply --limit 5   # aplica só nos 5 PRs mais recentes por repo
#   bash fix-pr-references.sh --apply --skip-submodules  # só o repositório pai
#   bash fix-pr-references.sh --apply --only-path caminho/do/submodule  # só um submodule
#
# Variáveis opcionais:
#   NOTES_REF=pr-refs   nome da ref de notes usada (default: pr-refs)
#   PR_LIMIT=1000       máximo de PRs consultados por repositório
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

NOTES_REF="${NOTES_REF:-pr-refs}"
PR_LIMIT="${PR_LIMIT:-1000}"

APPLY=0
LIMIT=0
SKIP_SUBMODULES=0
ONLY_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)            APPLY=1; shift ;;
    --limit)             LIMIT="$2"; shift 2 ;;
    --skip-submodules)   SKIP_SUBMODULES=1; shift ;;
    --only-path)         ONLY_PATH="$2"; shift 2 ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "❌ Argumento desconhecido: $1"
      exit 1
      ;;
  esac
done

# ─────────────────────────────────────────────────────────────────────────────
# FUNÇÕES AUXILIARES
# ─────────────────────────────────────────────────────────────────────────────

_log() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "$1"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

_check_prereqs() {
  local dir="$1"
  command -v git &>/dev/null || { echo "❌ git não encontrado."; exit 1; }
  command -v gh  &>/dev/null || { echo "❌ GitHub CLI (gh) não encontrado. https://cli.github.com"; exit 1; }
  gh auth status &>/dev/null || { echo "❌ gh não autenticado. Execute: gh auth login"; exit 1; }
  git -C "$dir" rev-parse --is-inside-work-tree &>/dev/null \
    || { echo "❌ '$dir' não é um repositório git."; exit 1; }
  git -C "$dir" remote get-url origin &>/dev/null \
    || { echo "❌ '$dir' não tem remote 'origin' configurado."; exit 1; }

  local git_dir
  git_dir=$(git -C "$dir" rev-parse --git-dir)
  for pending in rebase-merge rebase-apply MERGE_HEAD CHERRY_PICK_HEAD; do
    if [[ -e "$git_dir/$pending" ]]; then
      echo "❌ '$dir' tem uma operação Git pendente ($pending). Resolva antes de continuar."
      exit 1
    fi
  done
}

# Lista de PRs (all states) de um repositório, em JSON, respeitando PR_LIMIT/--limit
_list_prs() {
  local dir="$1"
  local limit="${LIMIT:-$PR_LIMIT}"
  [[ "$limit" -eq 0 ]] && limit="$PR_LIMIT"
  gh -R "$(git -C "$dir" remote get-url origin | sed -E 's#.*[:/]([^/]+/[^/.]+)(\.git)?$#\1#')" \
    pr list --state all --limit "$limit" \
    --json number,title,mergeCommit,commits,baseRefName,headRefName,state
}

# Processa um único repositório (submodule ou pai): prévia + (se --apply) escrita
_process_repo() {
  local dir="$1"
  local label="$2"

  _log "📂 Repositório: ${label}  (${dir})"
  _check_prereqs "$dir"

  echo "  🔄 Buscando notas remotas existentes (refs/notes/*)..."
  git -C "$dir" fetch origin 'refs/notes/*:refs/notes/*' &>/dev/null || true

  echo "  🔍 Levantando PRs (all states, limite ${LIMIT:-$PR_LIMIT})..."
  local prs_json
  prs_json=$(_list_prs "$dir")

  local pr_count
  pr_count=$(echo "$prs_json" | jq 'length')

  # Tabulação: para cada commit de cada PR, classifica sem escrever nada
  local tmp_plan
  tmp_plan=$(mktemp)
  echo "$prs_json" | jq -c '.[]' | while read -r pr; do
    local number title base head state commits
    number=$(echo "$pr" | jq -r '.number')
    title=$(echo "$pr" | jq -r '.title')
    base=$(echo "$pr" | jq -r '.baseRefName')
    head=$(echo "$pr" | jq -r '.headRefName')
    state=$(echo "$pr" | jq -r '.state')
    commits=$(echo "$pr" | jq -r '.commits[]?.oid // empty')

    if [[ -z "$commits" ]]; then
      # PR sem commits rastreáveis via API (ex.: squash com branch já deletada
      # e sem merge commit reconhecível) — tenta cair no mergeCommit
      local merge_oid
      merge_oid=$(echo "$pr" | jq -r '.mergeCommit.oid // empty')
      if [[ -n "$merge_oid" ]] && git -C "$dir" rev-parse --verify -q "${merge_oid}^{commit}" &>/dev/null; then
        echo "SQUASH|${merge_oid}|${number}|${title}|${base}|${head}|${state}" >> "$tmp_plan"
      else
        echo "UNREACHABLE|-|${number}|${title}|${base}|${head}|${state}" >> "$tmp_plan"
      fi
      continue
    fi

    while IFS= read -r sha; do
      [[ -z "$sha" ]] && continue
      if ! git -C "$dir" rev-parse --verify -q "${sha}^{commit}" &>/dev/null; then
        echo "UNREACHABLE|${sha}|${number}|${title}|${base}|${head}|${state}" >> "$tmp_plan"
        continue
      fi
      local existing
      existing=$(git -C "$dir" notes --ref="$NOTES_REF" show "$sha" 2>/dev/null || true)
      if echo "$existing" | grep -q "Refs: #${number}\b"; then
        echo "ALREADY_NOTED|${sha}|${number}|${title}|${base}|${head}|${state}" >> "$tmp_plan"
      elif [[ -n "$existing" ]]; then
        echo "APPEND|${sha}|${number}|${title}|${base}|${head}|${state}" >> "$tmp_plan"
      else
        echo "NEW|${sha}|${number}|${title}|${base}|${head}|${state}" >> "$tmp_plan"
      fi
    done <<< "$commits"
  done

  local new_count append_count already_count squash_count unreachable_count
  new_count=$(grep -c '^NEW|'          "$tmp_plan" || true); new_count="${new_count:-0}"
  append_count=$(grep -c '^APPEND|'    "$tmp_plan" || true); append_count="${append_count:-0}"
  already_count=$(grep -c '^ALREADY_NOTED|' "$tmp_plan" || true); already_count="${already_count:-0}"
  squash_count=$(grep -c '^SQUASH|'    "$tmp_plan" || true); squash_count="${squash_count:-0}"
  unreachable_count=$(grep -c '^UNREACHABLE|' "$tmp_plan" || true); unreachable_count="${unreachable_count:-0}"

  echo ""
  echo "  📊 Prévia — ${label} (nada foi escrito ainda)"
  echo "  PRs encontrados:                 ${pr_count}"
  echo "  Commits a anotar (novos):        ${new_count}"
  echo "  Commits a receber append:        ${append_count}"
  echo "  Commits já anotados (pulados):   ${already_count}"
  echo "  PRs squashed (commit único):     ${squash_count}"
  echo "  Commits/merges não alcançáveis:  ${unreachable_count}"

  if [[ "$APPLY" -eq 0 ]]; then
    echo ""
    echo "  ℹ️  Modo dry-run (padrão). Nada foi escrito. Rode com --apply para gravar as notas."
    rm -f "$tmp_plan"
    return 0
  fi

  echo ""
  echo "  ✍️  Aplicando (--apply ativo) em ${label}..."

  local written=0
  while IFS='|' read -r kind sha number title base head state; do
    case "$kind" in
      NEW)
        git -C "$dir" notes --ref="$NOTES_REF" add -f -m "Refs: #${number} (${title})
Base: ${base} <- Head: ${head}
Status: ${state}" "$sha" &>/dev/null
        written=$((written + 1))
        ;;
      APPEND)
        git -C "$dir" notes --ref="$NOTES_REF" append -m "Refs: #${number} (${title})
Base: ${base} <- Head: ${head}
Status: ${state}" "$sha" &>/dev/null
        written=$((written + 1))
        ;;
      SQUASH)
        git -C "$dir" notes --ref="$NOTES_REF" add -f -m "Refs: #${number} (${title}) [merge/squash commit]
Base: ${base} <- Head: ${head}
Status: ${state}
Nota: commits atômicos originais não estão mais alcançáveis; apenas o commit
de squash/merge foi anotado." "$sha" &>/dev/null
        written=$((written + 1))
        ;;
      ALREADY_NOTED|UNREACHABLE)
        : # nada a fazer
        ;;
    esac
  done < "$tmp_plan"
  rm -f "$tmp_plan"

  echo "  📝 ${written} nota(s) escrita(s)/atualizada(s) localmente."

  echo "  ⬆️  Publicando refs/notes/${NOTES_REF}..."
  if ! git -C "$dir" push origin "refs/notes/${NOTES_REF}" 2>/tmp/fix-pr-refs-push-err; then
    if grep -qi 'non-fast-forward\|fetch first\|rejected' /tmp/fix-pr-refs-push-err; then
      echo "  ⚠️  Push rejeitado (outra pessoa também anotou). Sincronizando via merge de notas..."
      git -C "$dir" fetch origin "refs/notes/${NOTES_REF}:refs/notes/${NOTES_REF}-remote"
      if git -C "$dir" notes --ref="$NOTES_REF" merge -s cat_sort_uniq "refs/notes/${NOTES_REF}-remote"; then
        git -C "$dir" push origin "refs/notes/${NOTES_REF}"
        echo "  ✅ Notas mescladas (cat_sort_uniq) e publicadas."
      else
        echo "  ❌ Conflito no merge de notas que a estratégia automática não resolveu."
        echo "     Resolva manualmente com: git notes --ref=${NOTES_REF} merge --commit / --abort"
        exit 1
      fi
    else
      cat /tmp/fix-pr-refs-push-err
      exit 1
    fi
  else
    echo "  ✅ refs/notes/${NOTES_REF} publicada em origin."
  fi

  echo ""
  echo "  🎉 Repositório '${label}' concluído: ${written} nota(s), ref publicada."
}

# ─────────────────────────────────────────────────────────────────────────────
# ETAPA 0 — Verificar jq (necessário para parsear JSON do gh)
# ─────────────────────────────────────────────────────────────────────────────
command -v jq &>/dev/null || { echo "❌ jq não encontrado. Instale antes de continuar."; exit 1; }

if [[ "$APPLY" -eq 0 ]]; then
  _log "🔎 MODO DRY-RUN — nenhuma nota será escrita, nenhum push será feito"
else
  _log "✍️  MODO APLICAÇÃO (--apply) — notas serão escritas e publicadas"
fi

# ─────────────────────────────────────────────────────────────────────────────
# ETAPA 1 — Descobrir submodules e definir a ordem (submodules primeiro)
# ─────────────────────────────────────────────────────────────────────────────
_log "🔗 ETAPA 1 — Detectar submodules"

ROOT_DIR="$(git rev-parse --show-toplevel)"
SUBMODULE_PATHS=""

if [[ "$SKIP_SUBMODULES" -eq 0 ]] && [[ -f "$ROOT_DIR/.gitmodules" ]]; then
  SUBMODULE_PATHS=$(git config --file "$ROOT_DIR/.gitmodules" --get-regexp path | awk '{print $2}')
fi

if [[ -n "$ONLY_PATH" ]]; then
  SUBMODULE_PATHS=$(echo "$SUBMODULE_PATHS" | grep -F "$ONLY_PATH" || true)
fi

if [[ -n "$SUBMODULE_PATHS" ]]; then
  echo "  Submodules detectados (serão processados antes do repositório pai):"
  echo "$SUBMODULE_PATHS" | sed 's/^/    - /'
else
  echo "  ℹ️  Nenhum submodule a processar."
fi

# ─────────────────────────────────────────────────────────────────────────────
# ETAPA 2 — Processar cada submodule (nesta ordem), depois o pai
# ─────────────────────────────────────────────────────────────────────────────
if [[ -n "$SUBMODULE_PATHS" ]]; then
  while IFS= read -r sub; do
    [[ -z "$sub" ]] && continue
    sub_dir="${ROOT_DIR}/${sub}"
    if [[ ! -d "$sub_dir/.git" && ! -f "$sub_dir/.git" ]]; then
      echo "  ⚠️  Submodule '$sub' não está inicializado (rode 'git submodule update --init'). Pulando."
      continue
    fi
    _process_repo "$sub_dir" "submodule:${sub}"
  done <<< "$SUBMODULE_PATHS"
fi

if [[ -z "$ONLY_PATH" ]]; then
  _process_repo "$ROOT_DIR" "repositório pai"
fi

_log "🎉 FLUXO CONCLUÍDO"
if [[ "$APPLY" -eq 0 ]]; then
  echo "  Isso foi um dry-run. Nenhuma nota foi escrita, nenhum push foi feito."
  echo "  Rode novamente com --apply para gravar de fato."
else
  echo "  Notas gravadas e publicadas em refs/notes/${NOTES_REF} em cada repositório processado."
  echo "  Nenhum hash de commit foi alterado. Nenhum push --force foi executado."
fi