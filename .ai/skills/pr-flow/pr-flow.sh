#!/usr/bin/env bash
#
# pr-flow.sh — implementação de referência da skill "pr-flow"
#
# ATENÇÃO: a skill pr-flow.md determina que o fluxo seja executado AO VIVO
# por Agente, comando a comando, analisando cada diff antes de decidir tipo/
# escopo/agrupamento — "nunca gerando um script para rodar depois". Este
# arquivo NÃO substitui isso: é uma implementação de referência para quem
# quiser rodar o mesmo fluxo manualmente ou via CI, fora de uma sessão com
# Agente. As decisões de tipo/escopo por diff aqui são heurísticas simples
# (bem mais grosseiras que a análise ao vivo) — revise os commits gerados.
#
# Uso:
#   PR_NAME="Retry Button Reutilizavel" ./pr-flow.sh
#
# Variáveis de ambiente:
#   PR_NAME              (obrigatória) título da PR
#   FEATURE_NAME          (opcional) nome da feature; default = PR_NAME
#   BRANCH_NAME           (opcional) nome de branch explícito; default = feature/<slug-da-pr>
#   MAIN_BRANCH           (opcional) força a branch de destino
#   BACKLOG_FEATURES_DIR  (opcional) default .backlog/features
#   BACKLOG_PR_DIR         (opcional) default .backlog/pull-request
#   COMMIT_MODE            (opcional) "file" | "grouped"; default: automático pelo nº de arquivos
#   FILE_MODE_THRESHOLD    (opcional) default 8
#
# Merge: sempre squash, com o commit final nomeado com o título da PR
# ("PR (#<PR_NUMBER>) <PR_NAME>") — não configurável via variável de
# ambiente; a branch de destino nunca recebe os commits individuais, só o
# commit final do squash. O histórico detalhado fica preservado no PR
# fechado do GitHub.

set -euo pipefail

# ---------------------------------------------------------------------------
# 0. Entradas e defaults
# ---------------------------------------------------------------------------

: "${PR_NAME:?PR_NAME é obrigatório. Ex.: PR_NAME=\"Minha Feature\" ./pr-flow.sh}"
FEATURE_NAME_INPUT="${FEATURE_NAME:-$PR_NAME}"
BACKLOG_FEATURES_DIR="${BACKLOG_FEATURES_DIR:-.backlog/features}"
BACKLOG_PR_DIR="${BACKLOG_PR_DIR:-.backlog/pull-request}"
FILE_MODE_THRESHOLD="${FILE_MODE_THRESHOLD:-8}"

slugify() {
  echo "$1" \
    | iconv -t ascii//TRANSLIT 2>/dev/null \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' \
    | cut -c1-50
}

PR_SLUG="$(slugify "$PR_NAME")"
FEATURE_TEXT_SLUG="$(slugify "$FEATURE_NAME_INPUT")"
FEATURE_NAME="${BRANCH_NAME:-feature/${PR_SLUG}}"

log() { echo "[pr-flow] $*"; }
die() { echo "[pr-flow] ERRO: $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Pré-requisitos
# ---------------------------------------------------------------------------

command -v git >/dev/null 2>&1 || die "git não encontrado"
command -v gh  >/dev/null 2>&1 || die "gh não encontrado"
gh auth status >/dev/null 2>&1 || die "gh não autenticado (rode: gh auth login)"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "não estamos dentro de um repositório git"
git remote get-url origin >/dev/null 2>&1 || die "remote 'origin' não configurado"
git ls-remote --exit-code origin >/dev/null 2>&1 || die "origin inacessível (rede/credenciais)"
gh repo view >/dev/null 2>&1 || die "gh não enxerga o repositório (permissão insuficiente?)"

GIT_DIR="$(git rev-parse --git-dir)"
if [ -d "$GIT_DIR/rebase-merge" ] || [ -d "$GIT_DIR/rebase-apply" ] \
   || [ -f "$GIT_DIR/MERGE_HEAD" ] || [ -f "$GIT_DIR/CHERRY_PICK_HEAD" ]; then
  die "há uma operação git pendente (rebase/merge/cherry-pick) — resolva antes de continuar"
fi

# ---------------------------------------------------------------------------
# 1. Estado do repositório
# ---------------------------------------------------------------------------

if [ -z "$(git status --porcelain=v1 -uall)" ]; then
  log "nada modificado — encerrando sem criar branch/PR/documentação"
  exit 0
fi

# ---------------------------------------------------------------------------
# 2. Branch de destino
# ---------------------------------------------------------------------------

if [ -n "${MAIN_BRANCH:-}" ]; then
  TARGET_BRANCH="$MAIN_BRANCH"
elif git show-ref --verify --quiet refs/heads/develop; then
  TARGET_BRANCH="develop"
elif git ls-remote --exit-code --heads origin develop >/dev/null 2>&1; then
  TARGET_BRANCH="develop"
else
  TARGET_BRANCH="main"
fi
log "branch de destino: $TARGET_BRANCH"

# ---------------------------------------------------------------------------
# 3.1 Garantir documentação da feature (numeração sequencial feature-<NN>-<slug>.md)
# ---------------------------------------------------------------------------

mkdir -p "$BACKLOG_FEATURES_DIR"

# 1) já existe uma feature com este mesmo texto de slug (qualquer número)?
EXISTING_FEATURE_DOC="$(ls "$BACKLOG_FEATURES_DIR"/feature-*-"${FEATURE_TEXT_SLUG}".md 2>/dev/null | head -n1 || true)"

if [ -n "$EXISTING_FEATURE_DOC" ]; then
  FEATURE_DOC="$EXISTING_FEATURE_DOC"
  FEATURE_SLUG="$(basename "$FEATURE_DOC" .md | sed -E 's/^feature-//')"
  log "feature '$FEATURE_SLUG' já existe — não sobrescrevendo nem renumerando ($FEATURE_DOC)"
else
  # 2) calcular o próximo número sequencial (2 dígitos) a partir dos arquivos existentes
  LAST_NUM="$(ls "$BACKLOG_FEATURES_DIR"/feature-*.md 2>/dev/null \
    | sed -E 's#.*/feature-([0-9]+)-.*#\1#' \
    | sort -n | tail -1 || true)"
  NEXT_NUM="$(printf "%02d" $(( ${LAST_NUM:-0} + 1 )))"
  FEATURE_SLUG="${NEXT_NUM}-${FEATURE_TEXT_SLUG}"
  FEATURE_DOC="${BACKLOG_FEATURES_DIR}/feature-${FEATURE_SLUG}.md"

  log "feature '$FEATURE_SLUG' não existe — criando esqueleto em $FEATURE_DOC"
  cat > "$FEATURE_DOC" <<EOF
---
name: feature-${FEATURE_SLUG}
file: feature-${FEATURE_SLUG}.md
description: >
  Rascunho gerado automaticamente por pr-flow.sh a partir de "${PR_NAME}".
  Revisar manualmente: contexto, objetivo e critérios de aceite.
---

# Feature: ${FEATURE_NAME_INPUT}

## Contexto / Problema

_(preencher)_

## Objetivo

_(preencher)_

## Critérios de aceite

- [ ] _(preencher)_
EOF
fi

# ---------------------------------------------------------------------------
# 4. Sincronizar destino e criar feature branch
# ---------------------------------------------------------------------------

STASHED=0
if ! git diff --quiet || ! git diff --cached --quiet; then
  git stash push -u -m "pr-flow: stash automático antes do checkout"
  STASHED=1
fi

git checkout "$TARGET_BRANCH"
git submodule update --init --recursive
git checkout -b "$FEATURE_NAME"

if [ "$STASHED" -eq 1 ]; then
  git stash pop || true
fi

# ---------------------------------------------------------------------------
# 4.1 Garantir documentação da PR
# ---------------------------------------------------------------------------

mkdir -p "$BACKLOG_PR_DIR"
PR_DOC="${BACKLOG_PR_DIR}/${PR_SLUG}.md"

write_pr_doc() {
  local pr_number="$1" status="$2" body_file="${3:-}"
  cat > "$PR_DOC" <<EOF
---
name: ${PR_SLUG}
pr: ${pr_number}
title: "PR (#${pr_number}) ${PR_NAME}"
branch: ${FEATURE_NAME}
base: ${TARGET_BRANCH}
extends: feature-${FEATURE_SLUG}
status: ${status}
---

EOF
  if [ -n "$body_file" ] && [ -f "$body_file" ]; then
    cat "$body_file" >> "$PR_DOC"
  fi
}

if [ ! -f "$PR_DOC" ]; then
  write_pr_doc "" "draft"
  log "documentação de PR criada em $PR_DOC"
else
  log "documentação de PR já existe em $PR_DOC — será atualizada"
fi

# ---------------------------------------------------------------------------
# 5.0 / 5.1 PR existente ou criação
# ---------------------------------------------------------------------------

EXISTING_PR_JSON="$(gh pr list --head "$FEATURE_NAME" --state open \
  --json number,baseRefName,mergeable --jq '.[0] // empty' || true)"

if [ -n "$EXISTING_PR_JSON" ]; then
  PR_NUMBER="$(echo "$EXISTING_PR_JSON" | jq -r '.number')"
  BASE_REF="$(echo "$EXISTING_PR_JSON" | jq -r '.baseRefName')"
  MERGEABLE="$(echo "$EXISTING_PR_JSON" | jq -r '.mergeable')"

  [ "$BASE_REF" = "$TARGET_BRANCH" ] || die "PR #$PR_NUMBER existente tem base '$BASE_REF', esperado '$TARGET_BRANCH'"
  [ "$MERGEABLE" != "CONFLICTING" ] || die "PR #$PR_NUMBER já está CONFLICTING com $TARGET_BRANCH"

  gh pr edit "$PR_NUMBER" --title "PR (#${PR_NUMBER}) ${PR_NAME}"
  log "reaproveitando PR existente #$PR_NUMBER"
else
  git commit --allow-empty \
    -m "chore: iniciar feature ${FEATURE_NAME}" \
    -m "Commit inicial vazio para permitir abertura do PR antes dos commits de conteúdo."
  git push -u origin "$FEATURE_NAME"

  gh pr create --draft \
    --base "$TARGET_BRANCH" --head "$FEATURE_NAME" \
    --title "$PR_NAME" \
    --body "_PR aberto antes dos commits de conteúdo; corpo será atualizado com estatísticas._"

  PR_NUMBER="$(gh pr view "$FEATURE_NAME" --json number --jq .number)"
  gh pr edit "$PR_NUMBER" --title "PR (#${PR_NUMBER}) ${PR_NAME}"
  log "PR draft #$PR_NUMBER criado"
fi

[ -n "${PR_NUMBER:-}" ] || die "PR_NUMBER não definido — abortando sem commitar"

write_pr_doc "$PR_NUMBER" "draft"

# ---------------------------------------------------------------------------
# 6. Commits — modo por-arquivo ou agrupado
# ---------------------------------------------------------------------------

CHANGED_FILES=()
while IFS= read -r line; do
  CHANGED_FILES+=("${line:3}")
done < <(git status --porcelain=v1 -uall)

NUM_FILES="${#CHANGED_FILES[@]}"

if [ -n "${COMMIT_MODE:-}" ]; then
  MODE="$COMMIT_MODE"
elif [ "$NUM_FILES" -le "$FILE_MODE_THRESHOLD" ]; then
  MODE="file"
else
  MODE="grouped"
fi
log "modo de commit: $MODE ($NUM_FILES arquivo(s), limiar=$FILE_MODE_THRESHOLD)"

# Heurística MUITO simplificada de tipo/escopo — a versão ao vivo da skill
# analisa cada diff individualmente; aqui usamos uma aproximação genérica.
guess_type() {
  local file="$1"
  case "$file" in
    *test*|*spec*)        echo "test" ;;
    *.md|docs/*|README*)  echo "docs" ;;
    *)                     if git status --porcelain=v1 -- "$file" | grep -q '^??'; then
                              echo "feat"
                            else
                              echo "fix"
                            fi ;;
  esac
}

guess_scope() {
  local file="$1"
  local dir
  dir="$(dirname "$file")"
  echo "$dir" | tr '/' '-' | sed -E 's/^-+|-+$//g'
}

if [ "$MODE" = "file" ]; then
  for f in "${CHANGED_FILES[@]}"; do
    [ -e "$f" ] || continue
    TYPE="$(guess_type "$f")"
    SCOPE="$(guess_scope "$f")"
    ACTION="update"
    git status --porcelain=v1 -- "$f" | grep -q '^??' && ACTION="add"

    git add -- "$f"
    git commit -m "${TYPE}(${SCOPE}): ${ACTION} $(basename "$f")" \
      -m "Refs: #${PR_NUMBER}"
  done
else
  declare -A GROUPS
  for f in "${CHANGED_FILES[@]}"; do
    scope="$(guess_scope "$f")"
    GROUPS["$scope"]+="$f"$'\n'
  done

  for scope in "${!GROUPS[@]}"; do
    files="${GROUPS[$scope]}"
    mapfile -t group_files <<< "$(echo -n "$files")"
    [ "${#group_files[@]}" -eq 0 ] && continue

    TYPE="feat"
    N=0
    ADD_LINES=0
    DEL_LINES=0
    LIST=""
    for f in "${group_files[@]}"; do
      [ -e "$f" ] || continue
      N=$((N + 1))
      LIST+="- ${f}"$'\n'
      TYPE="$(guess_type "$f")"
    done

    [ "$N" -eq 0 ] && continue

    git add -- "${group_files[@]}"
    STATS="$(git diff --cached --shortstat -- "${group_files[@]}" || true)"

    git commit -m "${TYPE}(${scope}): atualizar ${N} arquivo(s)" -m "$(cat <<EOF
Arquivos alterados:
${LIST}
Resumo:
- Escopo: ${scope}
- Arquivos: ${N}
${STATS}

Refs: #${PR_NUMBER}
EOF
)"
  done
fi

# ---------------------------------------------------------------------------
# 7. Push
# ---------------------------------------------------------------------------

git push origin "$FEATURE_NAME"

# ---------------------------------------------------------------------------
# 8. Estatísticas determinísticas
# ---------------------------------------------------------------------------

TOTAL_COMMITS="$(git rev-list --count "$TARGET_BRANCH".."$FEATURE_NAME")"
TOTAL_ARQUIVOS="$(git diff --name-only "$TARGET_BRANCH".."$FEATURE_NAME" | wc -l | tr -d ' ')"

COMMITS_LIST="$(git log "$TARGET_BRANCH".."$FEATURE_NAME" --no-merges \
  --pretty=format:'%s|%ad' --date=format:'%d/%m/%Y %H:%M' \
  | grep -v '^chore: iniciar feature' || true)"

MODO_TEXTO="por arquivo"
[ "$MODE" = "grouped" ] && MODO_TEXTO="agrupados por contexto"

COMMITS_MD=""
while IFS='|' read -r subject date; do
  [ -z "$subject" ] && continue
  COMMITS_MD+="- **${subject}**"$'\n'"  > _${date}_"$'\n'
done <<< "$COMMITS_LIST"

# ---------------------------------------------------------------------------
# 9. Atualizar o PR e tirar do draft
# ---------------------------------------------------------------------------

BODY_FILE="$(mktemp)"
cat > "$BODY_FILE" <<EOF
## 📋 Descrição
Implementação da **${PR_NAME}** via feature branch \`${FEATURE_NAME}\`, com commits atômicos e
semânticos ${MODO_TEXTO}.

Feature relacionada: \`${FEATURE_DOC}\`

---
## 📊 Estatísticas
| Métrica | Valor |
|---|---|
| 🌿 Branch de origem | \`${FEATURE_NAME}\` |
| 🎯 Branch de destino | \`${TARGET_BRANCH}\` |
| 📝 Total de commits | ${TOTAL_COMMITS} |
| 📁 Arquivos alterados | ${TOTAL_ARQUIVOS} |
---

## Checklist
- [x] Commits separados por contexto
- [x] Referência do PR incluída nos commits de conteúdo
- [x] Alterações revisadas e enviadas para a branch
- [ ] Revisão funcional
- [ ] Validação em ambiente Linux/jail
---
## 📝 feature Commits
${COMMITS_MD}
EOF

gh pr edit "$PR_NUMBER" --body-file "$BODY_FILE"
gh pr ready "$PR_NUMBER"

write_pr_doc "$PR_NUMBER" "open" "$BODY_FILE"
rm -f "$BODY_FILE"

git add "$PR_DOC"
git commit -m "docs(backlog): atualizar status do PR #${PR_NUMBER} para open" \
  -m "Refs: #${PR_NUMBER}" || true
git push origin "$FEATURE_NAME"

log "PR #$PR_NUMBER atualizado e fora do draft"

# ---------------------------------------------------------------------------
# 10. Verificar conflitos e mesclar (squash, subject = título da PR)
# ---------------------------------------------------------------------------

MERGEABLE="$(gh pr view "$PR_NUMBER" --json mergeable --jq .mergeable)"

if [ "$MERGEABLE" = "CONFLICTING" ]; then
  log "PR #$PR_NUMBER está CONFLICTING — não será mesclado. Resolva manualmente."
  log "fluxo concluído para PR #$PR_NUMBER (${PR_NAME}) — sem merge (conflito)"
  exit 0
fi

MERGE_SUBJECT="PR (#${PR_NUMBER}) ${PR_NAME}"

# Merge nunca é automático: sempre pede confirmação explícita, mesmo sem conflito.
CONFIRM_MERGE=""
if [ -n "${AUTO_CONFIRM_MERGE:-}" ]; then
  # Uso não-interativo (ex.: CI): defina AUTO_CONFIRM_MERGE=y ou =n explicitamente.
  CONFIRM_MERGE="$AUTO_CONFIRM_MERGE"
else
  echo
  echo "PR #$PR_NUMBER (\"$PR_NAME\")"
  echo "  origem:     $FEATURE_NAME"
  echo "  destino:    $TARGET_BRANCH"
  echo "  estratégia: squash (commit final: \"$MERGE_SUBJECT\")"
  read -r -p "Mesclar agora? [y/N] " CONFIRM_MERGE
fi

case "$CONFIRM_MERGE" in
  y|Y|yes|YES|s|S|sim|SIM)
    gh pr merge "$PR_NUMBER" --squash --delete-branch \
      --subject "$MERGE_SUBJECT" \
      --body ""

    git checkout "$TARGET_BRANCH"
    git pull origin "$TARGET_BRANCH"

    write_pr_doc "$PR_NUMBER" "merged"
    git add "$PR_DOC"
    git commit -m "docs(backlog): atualizar status do PR #${PR_NUMBER} para merged" \
      -m "Refs: #${PR_NUMBER}" || true
    git push origin "$TARGET_BRANCH"

    log "PR #$PR_NUMBER mesclado (squash) em $TARGET_BRANCH como \"$MERGE_SUBJECT\""

    # -------------------------------------------------------------------
    # 11. Limpeza (só roda após merge confirmado)
    # -------------------------------------------------------------------
    git checkout "$TARGET_BRANCH"
    git pull origin "$TARGET_BRANCH"
    git submodule update --init --recursive
    git branch -d "$FEATURE_NAME" 2>/dev/null || git branch -D "$FEATURE_NAME" 2>/dev/null || true

    log "fluxo concluído para PR #$PR_NUMBER (${PR_NAME})"
    ;;
  *)
    log "merge não confirmado — PR #$PR_NUMBER permanece aberto em $FEATURE_NAME, sem mesclar"
    ;;
esac
