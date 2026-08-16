#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# auto-pr-commit.sh
#
# Versão CI-ONLY, determinística, do fluxo de PR automático — SEM nenhum
# agente no loop. Não invoca (nem depende de) as skills `auto-commit` ou
# `auto-pr-commit` em nenhum momento; toda a decisão de tipo/escopo de commit
# é feita por heurísticas de texto/regex neste próprio arquivo.
#
# Use este script quando o fluxo precisa rodar sozinho (GitHub Action, cron,
# webhook, etc.), sem Claude ou qualquer outro agente disponível. Se você
# está rodando isso via Claude Code / Claude Tag / outro ambiente com agente,
# use as skills `auto-pr-commit.md` + `auto-commit.md` em vez deste script —
# elas tomam as decisões olhando o diff real, em vez de regex fixas.
#
# ⚠️ Caminho intencionalmente separado: mudanças nas skills (.md) NÃO se
# refletem aqui automaticamente, e vice-versa. Se as regras de tipo/escopo
# mudarem de um lado, considere replicar manualmente no outro.
#
# Fluxo: detectar mudanças → resolver branch de destino (develop → main) →
#        gerar nome inteligente → feature branch → push inicial vazio →
#        ABRIR O PR (draft) PRIMEIRO → commits (submodules primeiro, cada um
#        já referenciando "Refs: #PR") → push → atualizar estatísticas no PR
#        → tirar do draft → merge na branch de destino → deletar APENAS a
#        feature branch (local + remota)
#
# IMPORTANTE: o PR é criado ANTES de qualquer commit de conteúdo, para que
# cada commit possa referenciar "Refs: #<numero>" desde a própria mensagem.
#
# ─────────────────────────────────────────────────────────────────────────────
# SUBCOMANDOS (úteis pra dividir em jobs de CI diferentes; opcional)
# ─────────────────────────────────────────────────────────────────────────────
#   bash auto-pr-commit.sh                    # fluxo completo
#   bash auto-pr-commit.sh "feature/meu-nome" # idem, com nome manual
#   bash auto-pr-commit.sh open ["nome"]      # só abre PR + feature branch
#   bash auto-pr-commit.sh commit             # só commita
#   bash auto-pr-commit.sh finish             # push + stats + merge + limpeza
#
# Variáveis opcionais:
#   MAIN_BRANCH=develop        força a branch de destino (senão: develop -> main)
#   MERGE_STRATEGY=--merge     --merge | --squash | --rebase
#   COMMIT_MODE=auto           auto | per-file | grouped
#   COMMIT_MODE_THRESHOLD=8    nº de arquivos a partir do qual "auto" vira "grouped"
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

MERGE_STRATEGY="${MERGE_STRATEGY:---merge}"
COMMIT_MODE="${COMMIT_MODE:-auto}"
COMMIT_MODE_THRESHOLD="${COMMIT_MODE_THRESHOLD:-8}"

_GIT_DIR="$(git rev-parse --git-dir 2>/dev/null || echo .git)"
STATE_FILE="${_GIT_DIR}/auto-pr-commit-ci.state"

# ─────────────────────────────────────────────────────────────────────────────
# FUNÇÕES AUXILIARES
# ─────────────────────────────────────────────────────────────────────────────

_log() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "$1"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

_save_state() {
  cat > "$STATE_FILE" <<EOF
FEATURE_NAME=$(printf '%q' "$FEATURE_NAME")
TARGET_BRANCH=$(printf '%q' "$TARGET_BRANCH")
PR_NUMBER=$(printf '%q' "$PR_NUMBER")
PR_TITLE_PLACEHOLDER=$(printf '%q' "$PR_TITLE_PLACEHOLDER")
COMMIT_MODE=$(printf '%q' "$COMMIT_MODE")
COMMIT_MODE_THRESHOLD=$(printf '%q' "$COMMIT_MODE_THRESHOLD")
EOF
  echo "  💾 Estado salvo em: $STATE_FILE"
}

_load_state() {
  if [[ ! -f "$STATE_FILE" ]]; then
    echo "❌ Nenhum estado encontrado em $STATE_FILE."
    echo "   Rode primeiro: bash auto-pr-commit.sh open"
    exit 1
  fi
  # shellcheck disable=SC1090
  source "$STATE_FILE"
}

# Resolve a branch de destino: respeita MAIN_BRANCH se definido,
# senão tenta 'develop' (local ou remota), caindo para 'main'.
_resolve_target_branch() {
  if [[ -n "${MAIN_BRANCH:-}" ]]; then
    echo "$MAIN_BRANCH"
    return
  fi

  if git show-ref --verify --quiet refs/heads/develop; then
    echo "develop"
    return
  fi

  if git ls-remote --exit-code --heads origin develop &>/dev/null; then
    echo "develop"
    return
  fi

  echo "main"
}

# Gera o nome da feature analisando os arquivos modificados (roda ANTES de
# qualquer commit, então ainda vê o working tree sujo original)
_generate_feature_name() {
  local files
  files=$(git status --porcelain=v1 -uall | awk '{print $2}' | grep -v '/$' || true)

  if [[ -z "$files" ]]; then
    echo "feature/atualizacao-geral"
    return
  fi

  local adds dels mods action
  adds=$(git status --porcelain=v1 -uall | grep -cE '^(A|\?\?)' || true)
  dels=$(git status --porcelain=v1 -uall | grep -cE '^.?D'      || true)
  mods=$(git status --porcelain=v1 -uall | grep -cE '^.?M'      || true)
  adds="${adds:-0}"; dels="${dels:-0}"; mods="${mods:-0}"

  if   [[ "$adds" -gt "$mods" && "$adds" -gt "$dels" ]]; then action="adicionar"
  elif [[ "$dels" -gt "$mods" ]]; then action="remover"
  else action="atualizar"
  fi

  local scope=""
  local domain_c app_c infra_c pres_c test_c config_c docker_c ci_c
  domain_c=$(echo "$files" | grep -c 'src/domain/'          || true)
  app_c=$(echo "$files"    | grep -c 'src/application/'     || true)
  infra_c=$(echo "$files"  | grep -c 'src/infrastructure/'  || true)
  pres_c=$(echo "$files"   | grep -c 'src/presentation/'    || true)
  test_c=$(echo "$files"   | grep -cE 'test/|\.spec\.'      || true)
  config_c=$(echo "$files" | grep -cE '\.(json|yaml|yml|env)$' || true)
  docker_c=$(echo "$files" | grep -cE 'Dockerfile|docker-'  || true)
  ci_c=$(echo "$files"     | grep -c '\.github/'            || true)
  domain_c="${domain_c:-0}"; app_c="${app_c:-0}"; infra_c="${infra_c:-0}"
  pres_c="${pres_c:-0}"; test_c="${test_c:-0}"; config_c="${config_c:-0}"
  docker_c="${docker_c:-0}"; ci_c="${ci_c:-0}"

  local max=0
  for pair in "$domain_c:dominio" "$app_c:aplicacao" "$infra_c:infraestrutura" \
              "$pres_c:apresentacao" "$test_c:testes" "$config_c:configuracao" \
              "$docker_c:docker" "$ci_c:ci"; do
    local cnt="${pair%%:*}" name="${pair##*:}"
    if [[ "$cnt" -gt "$max" ]]; then max="$cnt"; scope="$name"; fi
  done

  if [[ -z "$scope" || "$max" -eq 0 ]]; then
    local top_file
    top_file=$(echo "$files" | head -1)
    scope=$(dirname "$top_file" | tr '/' '-' | sed 's/^\.\-//' | sed 's/^\./geral/')
    [[ -z "$scope" ]] && scope="geral"
  fi

  local module=""
  local all_diff
  all_diff=$(git diff 2>/dev/null || true)

  if   echo "$all_diff" | grep -qiE 'auth|login|token|jwt|session'; then module="autenticacao"
  elif echo "$all_diff" | grep -qiE 'user|usuario|perfil|profile'; then module="usuarios"
  elif echo "$all_diff" | grep -qiE 'payment|pagamento|billing|invoice'; then module="pagamentos"
  elif echo "$all_diff" | grep -qiE 'report|relatorio|dashboard|chart'; then module="relatorios"
  elif echo "$all_diff" | grep -qiE 'email|smtp|notification|notificacao'; then module="notificacoes"
  elif echo "$all_diff" | grep -qiE 'upload|file|arquivo|storage|s3'; then module="arquivos"
  elif echo "$all_diff" | grep -qiE 'api|endpoint|route|rota|controller'; then module="api"
  elif echo "$all_diff" | grep -qiE 'database|banco|migration|schema|model'; then module="banco-dados"
  elif echo "$all_diff" | grep -qiE 'cache|redis|memcache'; then module="cache"
  elif echo "$all_diff" | grep -qiE 'queue|fila|worker|job|task'; then module="filas"
  fi

  local name_part
  if [[ -n "$module" ]]; then
    name_part="${action}-${module}"
  else
    name_part="${action}-${scope}"
  fi

  name_part=$(echo "$name_part" \
    | sed 's/ã/a/g; s/â/a/g; s/á/a/g; s/à/a/g; s/ê/e/g; s/é/e/g; s/í/i/g' \
    | sed 's/õ/o/g; s/ô/o/g; s/ó/o/g; s/ú/u/g; s/ç/c/g' \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9-]/-/g' \
    | sed 's/--*/-/g; s/^-//; s/-$//' \
    | cut -c1-50)

  echo "feature/${name_part}"
}

# Decide o modo de commit: respeita COMMIT_MODE se != auto; em "auto", conta
# os arquivos alterados (excluindo submodules) e compara com o limiar.
_resolve_commit_mode() {
  local dir="${1:-.}"

  if [[ "$COMMIT_MODE" == "per-file" || "$COMMIT_MODE" == "grouped" ]]; then
    echo "$COMMIT_MODE"
    return
  fi

  local n
  n=$(git -C "$dir" status --porcelain=v1 -uall | wc -l | tr -d ' ')

  if [[ "$n" -gt "$COMMIT_MODE_THRESHOLD" ]]; then
    echo "grouped"
  else
    echo "per-file"
  fi
}

_detect_type() {
  local diff="$1" raw="$2"
  if   echo "$diff" | grep -qE '^\+.*(test|spec|describe|it\(|expect\()'; then echo "test"
  elif echo "$diff" | grep -qE '^\+.*(interface |type |enum |abstract class)'; then echo "refactor"
  elif echo "$diff" | grep -qE '^\+.*(@Injectable|@Controller|@Module)'; then echo "feat"
  elif echo "$diff" | grep -qiE '^\+.*(password|secret|token|apiKey)'; then echo "security"
  elif echo "$diff" | grep -qiE '^\+.*(fix|bug|erro|error|correct)'; then echo "fix"
  elif echo "$diff" | grep -qE '^\+.*(console\.|logger\.|log\()'; then echo "chore"
  elif echo "$diff" | grep -qE '^-' && ! echo "$diff" | grep -qE '^\+[^+]'; then echo "refactor"
  else echo "$raw"
  fi
}

# Escopo de um arquivo, com refinamento de 2 níveis: dentro de
# src/domain|application|infrastructure|presentation, se houver um
# subdiretório imediato, ele vira parte do escopo (ex.: domain-auth em vez
# de só domain), para não misturar contextos independentes no mesmo grupo.
_detect_scope() {
  local f="$1"
  case "$f" in
    src/domain/*/*)          echo "domain-$(echo "$f" | cut -d/ -f3)" ;;
    src/domain/*)            echo "domain" ;;
    src/application/*/*)     echo "app-$(echo "$f" | cut -d/ -f3)" ;;
    src/application/*)       echo "app" ;;
    src/infrastructure/*/*)  echo "infra-$(echo "$f" | cut -d/ -f3)" ;;
    src/infrastructure/*)    echo "infra" ;;
    src/presentation/*/*)    echo "presentation-$(echo "$f" | cut -d/ -f3)" ;;
    src/presentation/*)      echo "presentation" ;;
    .github/*)               echo "ci" ;;
    Dockerfile*|docker-*)    echo "docker" ;;
    test/*|tests/*|*.spec.*|*.test.*) echo "tests" ;;
    *.md)                    echo "docs" ;;
    *.json|*.yaml|*.yml|*.env*) echo "config" ;;
    *)
      if [[ "$f" != */* ]]; then
        echo "root"
      else
        dirname "$f" | tr '/' '-' | sed 's/^\.\-//'
      fi
      ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
# MODO PER-FILE — um commit por arquivo
# ─────────────────────────────────────────────────────────────────────────────
_commit_files_per_file() {
  local dir="${1:-.}"
  local count=0

  git -C "$dir" reset -q

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    local xy="${line:0:2}"
    local file="${line:3}"
    file="${file%\"}"
    file="${file#\"}"
    [[ -z "$file" ]] && continue

    if [[ -d "$dir/$file/.git" ]]; then continue; fi
    if git -C "$dir" config --file .gitmodules "submodule.$file.path" &>/dev/null; then continue; fi

    local raw_type action
    case "$xy" in
      "A "|"??")  raw_type="feat";     action="add"    ;;
      "M "|" M")  raw_type="fix";      action="update" ;;
      "D "|" D")  raw_type="chore";    action="remove" ;;
      R*)         raw_type="refactor"; action="rename" ;;
      *)          raw_type="chore";    action="update" ;;
    esac

    local diff type scope filename added removed
    diff=$(git -C "$dir" diff -- "$file" 2>/dev/null || true)
    if [[ -z "$diff" ]]; then
      diff=$(git -C "$dir" diff --cached -- "$file" 2>/dev/null || true)
    fi

    type=$(_detect_type "$diff" "$raw_type")
    scope=$(_detect_scope "$file")
    filename=$(basename "$file")
    added=$(echo "$diff"   | grep -c '^+[^+]' || true); added="${added:-0}"
    removed=$(echo "$diff" | grep -c '^-[^-]' || true); removed="${removed:-0}"

    local short_msg="${type}(${scope}): ${action} ${filename}"
    local body
    body="## Alterações em \`${file}\`

### Resumo
- **Ação:** ${action}
- **Tipo:** ${type}
- **Escopo:** ${scope}
- **Linhas adicionadas:** ${added}
- **Linhas removidas:** ${removed}

### Principais mudanças
$(echo "$diff" | grep '^+[^+]' | head -8 | sed 's/^+/- /' || echo '- Sem diff textual disponível')

### Motivação
Alteração incluída como parte da feature \`${FEATURE_NAME}\`.

Refs: #${PR_NUMBER}"

    git -C "$dir" add -- "$file"
    git -C "$dir" commit -m "$short_msg" -m "$body"
    echo "  ✅ ${type}(${scope}): ${file}  (Refs: #${PR_NUMBER})"

    count=$((count + 1))
  done < <(git -C "$dir" status --porcelain=v1 -uall)

  echo "  📦 ${count} arquivo(s) commitado(s) individualmente"
}

# ─────────────────────────────────────────────────────────────────────────────
# MODO GROUPED — um commit por grupo de arquivos relacionados (mesmo escopo)
# ─────────────────────────────────────────────────────────────────────────────
_commit_files_grouped() {
  local dir="${1:-.}"

  git -C "$dir" reset -q

  declare -A GROUP_FILES=()
  local order=()

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local xy="${line:0:2}"
    local file="${line:3}"
    file="${file%\"}"; file="${file#\"}"
    [[ -z "$file" ]] && continue

    if [[ -d "$dir/$file/.git" ]]; then continue; fi
    if git -C "$dir" config --file .gitmodules "submodule.$file.path" &>/dev/null; then continue; fi

    local scope
    scope=$(_detect_scope "$file")

    if [[ -z "${GROUP_FILES[$scope]:-}" ]]; then
      order+=("$scope")
      GROUP_FILES[$scope]="$file"
    else
      GROUP_FILES[$scope]="${GROUP_FILES[$scope]}"$'\n'"$file"
    fi
  done < <(git -C "$dir" status --porcelain=v1 -uall)

  local group_count=0

  for scope in "${order[@]}"; do
    local files_multiline="${GROUP_FILES[$scope]}"
    local -a files=()
    while IFS= read -r f; do
      [[ -n "$f" ]] && files+=("$f")
    done <<< "$files_multiline"

    local n_files="${#files[@]}"
    [[ "$n_files" -eq 0 ]] && continue

    local diff
    diff=$(git -C "$dir" diff -- "${files[@]}" 2>/dev/null || true)
    if [[ -z "$diff" ]]; then
      diff=$(git -C "$dir" diff --cached -- "${files[@]}" 2>/dev/null || true)
    fi

    local adds=0 dels=0 mods=0
    while IFS= read -r line; do
      case "${line:0:2}" in
        "A "|"??") adds=$((adds+1)) ;;
        "D "|" D") dels=$((dels+1)) ;;
        *)         mods=$((mods+1)) ;;
      esac
    done < <(git -C "$dir" status --porcelain=v1 -uall -- "${files[@]}")

    local action raw_type
    if   [[ "$adds" -ge "$mods" && "$adds" -ge "$dels" ]]; then action="adicionar"; raw_type="feat"
    elif [[ "$dels"  -gt "$mods" ]];                            then action="remover";   raw_type="chore"
    else                                                             action="atualizar"; raw_type="fix"
    fi

    local type
    type=$(_detect_type "$diff" "$raw_type")

    local added removed
    added=$(echo "$diff"   | grep -c '^+[^+]' || true); added="${added:-0}"
    removed=$(echo "$diff" | grep -c '^-[^-]' || true); removed="${removed:-0}"

    local short_msg="${type}(${scope}): ${action} ${n_files} arquivo(s)"

    local file_list=""
    for f in "${files[@]}"; do
      file_list="${file_list}- ${f}"$'\n'
    done

    local body
    body="Arquivos alterados:
${file_list}
Resumo:
- Ação: ${action}
- Tipo: ${type}
- Escopo: ${scope}
- Arquivos: ${n_files}
- Linhas adicionadas: ${added}
- Linhas removidas: ${removed}

Refs: #${PR_NUMBER}"

    git -C "$dir" add -- "${files[@]}"
    git -C "$dir" commit -m "$short_msg" -m "$body"
    echo "  ✅ ${type}(${scope}): ${n_files} arquivo(s)  (Refs: #${PR_NUMBER})"

    group_count=$((group_count + 1))
  done

  echo "  📦 ${group_count} grupo(s)/commit(s) criado(s)"
}

_commit_files() {
  local dir="${1:-.}"
  local mode
  mode=$(_resolve_commit_mode "$dir")

  echo "  🔀 Modo de commit para '${dir}': ${mode}"

  if [[ "$mode" == "grouped" ]]; then
    _commit_files_grouped "$dir"
  else
    _commit_files_per_file "$dir"
  fi
}

_collect_type_scope() {
  git log "$TARGET_BRANCH".."$FEATURE_NAME" --no-merges --pretty=format:'%s' \
    | grep -v '^chore: iniciar feature' \
    | sed -nE 's/^([a-zA-Z]+)\(([^)]+)\):.*/\1|\2/p'
}

# ─────────────────────────────────────────────────────────────────────────────
# ETAPA "open" — checagens + branch + PR draft (sem nenhum commit de conteúdo)
# ─────────────────────────────────────────────────────────────────────────────
_cmd_open() {
  _log "🔍 ETAPA 1 — Verificar estado do repositório"

  if ! command -v git &>/dev/null; then echo "❌ git não encontrado."; exit 1; fi
  if ! command -v gh  &>/dev/null; then echo "❌ GitHub CLI (gh) não encontrado. Instale em: https://cli.github.com"; exit 1; fi
  if ! gh auth status &>/dev/null; then echo "❌ GitHub CLI não autenticado. Execute: gh auth login"; exit 1; fi
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then echo "❌ Este diretório não é um repositório git."; exit 1; fi
  if ! git remote get-url origin &>/dev/null; then echo "❌ Remote 'origin' não configurado."; exit 1; fi
  if ! git ls-remote --exit-code origin &>/dev/null; then echo "❌ Não foi possível acessar 'origin' (rede ou credenciais)."; exit 1; fi
  if ! gh repo view &>/dev/null; then echo "❌ 'gh' não enxerga este repositório (permissão para abrir PR?)."; exit 1; fi

  local git_dir
  git_dir=$(git rev-parse --git-dir)
  if [[ -d "$git_dir/rebase-merge" || -d "$git_dir/rebase-apply" || \
        -f "$git_dir/MERGE_HEAD" || -f "$git_dir/CHERRY_PICK_HEAD" ]]; then
    echo "❌ Há uma operação Git pendente (rebase/merge/cherry-pick). Resolva antes de continuar."
    exit 1
  fi

  local current_branch changed_count
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  echo "  📍 Branch atual: $current_branch"

  changed_count=$(git status --porcelain=v1 -uall | wc -l | tr -d ' ')
  echo "  📋 Arquivos modificados: $changed_count"

  if [[ "$changed_count" -eq 0 ]]; then
    echo "  ℹ️  Nenhuma alteração detectada. Nada a commitar."
    exit 0
  fi

  local resolved_mode
  resolved_mode=$(_resolve_commit_mode ".")
  echo "  🔀 Modo de commit (COMMIT_MODE=${COMMIT_MODE}, limiar=${COMMIT_MODE_THRESHOLD}): ${resolved_mode}"

  _log "🌿 ETAPA 2 — Resolver branch de destino e criar feature branch"

  TARGET_BRANCH=$(_resolve_target_branch)
  echo "  🎯 Branch de destino resolvida: $TARGET_BRANCH"

  if [[ -n "${1:-}" ]]; then
    FEATURE_NAME="$1"
    echo "  📌 Nome informado manualmente: $FEATURE_NAME"
  else
    FEATURE_NAME=$(_generate_feature_name)
    echo "  🧠 Nome gerado automaticamente: $FEATURE_NAME"
  fi

  if [[ "$current_branch" != "$TARGET_BRANCH" ]]; then
    echo "  ⚠️  Não está na $TARGET_BRANCH. Fazendo stash (se houver algo) e checkout..."
    local stashed=0
    if ! git diff --quiet || ! git diff --cached --quiet; then
      git stash push -u -m "auto-pr-commit-ci: stash antes de criar feature"
      stashed=1
    fi
    git checkout "$TARGET_BRANCH"
    git pull origin "$TARGET_BRANCH"
    if [[ "$stashed" -eq 1 ]]; then git stash pop; fi
  else
    git pull origin "$TARGET_BRANCH"
  fi

  git submodule update --init --recursive
  git checkout -b "$FEATURE_NAME"
  echo "  ✅ Branch criada: $FEATURE_NAME"

  _log "📬 ETAPA 3 — Abrir o PR (draft) antes dos commits"

  local existing_pr
  existing_pr=$(gh pr list --head "$FEATURE_NAME" --state open --json number --jq '.[0].number' 2>/dev/null || true)

  if [[ -n "$existing_pr" && "$existing_pr" != "null" ]]; then
    PR_NUMBER="$existing_pr"
    PR_TITLE_PLACEHOLDER=$(gh pr view "$PR_NUMBER" --json title --jq .title)
    echo "  ♻️  PR já existente reaproveitado: #${PR_NUMBER}"
  else
    git commit --allow-empty \
      -m "chore: iniciar feature ${FEATURE_NAME}" \
      -m "Commit inicial vazio para permitir a abertura do PR antes dos commits.
Os commits desta feature serão adicionados em seguida, já referenciando
este PR em cada mensagem."
    git push -u origin "$FEATURE_NAME"
    echo "  ✅ Branch publicada: origin/$FEATURE_NAME"

    PR_TITLE_PLACEHOLDER=$(echo "$FEATURE_NAME" \
      | sed 's|feature/||' \
      | tr '-' ' ' \
      | sed 's/\b./\u&/g')

    local pr_url
    pr_url=$(gh pr create \
      --draft \
      --base "$TARGET_BRANCH" \
      --head "$FEATURE_NAME" \
      --title "$PR_TITLE_PLACEHOLDER" \
      --body "_PR aberto automaticamente antes dos commits. O corpo será atualizado com estatísticas assim que os commits forem realizados._")

    PR_NUMBER=$(gh pr view "$FEATURE_NAME" --json number --jq .number)
    echo "  ✅ PR #${PR_NUMBER} criado como draft: ${pr_url}"
  fi

  echo "  🔗 A partir de agora, todo commit deve citar 'Refs: #${PR_NUMBER}'"

  _save_state
}

# ─────────────────────────────────────────────────────────────────────────────
# ETAPA "commit"
# ─────────────────────────────────────────────────────────────────────────────
_cmd_commit() {
  _load_state

  _log "🔗 ETAPA 4 — Submodules"

  local modified_subs
  modified_subs=$(git submodule foreach --quiet \
    'git status --porcelain -uall | grep -q . && echo $displaypath' 2>/dev/null || true)

  if [[ -n "$modified_subs" ]]; then
    while IFS= read -r sub; do
      [[ -z "$sub" ]] && continue
      echo "  🔗 Processando submodule: $sub"
      (
        cd "$sub"
        _commit_files "."
        git push origin HEAD
        echo "  ✅ Push do submodule '$sub' realizado."
      )
      git add "$sub"
      git commit \
        -m "chore(deps): atualizar referência do submodule $(basename "$sub")" \
        -m "## Atualização de Submodule

### Submodule: \`$sub\`
Ponteiro atualizado após commits internos realizados na feature \`$FEATURE_NAME\`.

### Impacto
- Sem alteração de interface pública
- Referência do repositório pai sincronizada com HEAD do submodule

Refs: #${PR_NUMBER}"
      echo "  ✅ Referência de '$sub' commitada no pai. (Refs: #${PR_NUMBER})"
    done <<< "$modified_subs"
  else
    echo "  ℹ️  Nenhum submodule com modificações."
  fi

  _log "📦 ETAPA 5 — Commits no repositório pai"
  _commit_files "."
}

# ─────────────────────────────────────────────────────────────────────────────
# ETAPA "finish" — push + estatísticas + merge + limpeza
# ─────────────────────────────────────────────────────────────────────────────
_cmd_finish() {
  _load_state

  _log "⬆️  ETAPA 6 — Push da feature branch"
  git push origin "$FEATURE_NAME"
  echo "  ✅ Push realizado: origin/$FEATURE_NAME"

  _log "📊 ETAPA 7 — Atualizar PR #${PR_NUMBER} com estatísticas e sair do draft"

  local commit_count files_changed shortstat total_added total_removed
  commit_count=$(git rev-list --count "$TARGET_BRANCH".."$FEATURE_NAME")
  files_changed=$(git diff --name-only "$TARGET_BRANCH".."$FEATURE_NAME" | wc -l | tr -d ' ')

  shortstat=$(git diff --shortstat "$TARGET_BRANCH".."$FEATURE_NAME" || true)
  total_added=$(echo "$shortstat" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || true); total_added="${total_added:-0}"
  total_removed=$(echo "$shortstat" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || true); total_removed="${total_removed:-0}"

  local type_scope type_table scope_table dominant_type
  type_scope=$(_collect_type_scope)
  type_table=$(echo "$type_scope" | awk -F'|' '$1!=""{c[$1]++} END{for (t in c) printf "| `%s` | %d |\n", t, c[t]}' | sort)
  scope_table=$(echo "$type_scope" | awk -F'|' '$2!=""{c[$2]++} END{for (s in c) printf "| `%s` | %d |\n", s, c[s]}' | sort)
  dominant_type=$(echo "$type_scope" | awk -F'|' '$1!=""{c[$1]++} END{max=0; for (t in c) if (c[t]>max){max=c[t]; best=t} print best}')

  local pr_title
  if [[ -n "$dominant_type" ]]; then
    pr_title="${dominant_type}: ${PR_TITLE_PLACEHOLDER}"
  else
    pr_title="$PR_TITLE_PLACEHOLDER"
  fi

  local commit_log
  commit_log=$(git log "$TARGET_BRANCH".."$FEATURE_NAME" \
    --no-merges --reverse \
    --grep="^chore: iniciar feature" --invert-grep \
    --pretty=format:'<details>
<summary><code>%h</code> %s <sub>_(%ad)_</sub></summary>

%b
</details>
' \
    --date=format:'%d/%m/%Y %H:%M')

  local pr_body
  pr_body="## 📋 Descrição

Implementação da **${PR_TITLE_PLACEHOLDER}** via feature branch \`${FEATURE_NAME}\` (script CI-only, sem agente), com commits semânticos — cada commit já referencia este PR (\`Refs: #${PR_NUMBER}\`) desde o momento em que foi criado.

---

## 📊 Estatísticas gerais

| Métrica | Valor |
|---|---|
| 🌿 Branch de origem | \`${FEATURE_NAME}\` |
| 🎯 Branch de destino | \`${TARGET_BRANCH}\` |
| 📝 Total de commits | ${commit_count} |
| 📁 Arquivos alterados | ${files_changed} |
| ➕ Linhas adicionadas | ${total_added} |
| ➖ Linhas removidas | ${total_removed} |

### 📦 Commits por tipo

| Tipo | Qtd. |
|---|---|
${type_table}

### 🗂️ Commits por escopo

| Escopo | Qtd. |
|---|---|
${scope_table}

---

## 📝 Commits desta feature

${commit_log}

---

## ✅ Checklist

- [ ] Código revisado
- [ ] Testes passando
- [ ] Sem conflitos com \`${TARGET_BRANCH}\`
- [ ] Submodules atualizados (se aplicável)
- [ ] Documentação atualizada (se aplicável)

---

> 🤖 Pull Request gerado automaticamente pelo script **auto-pr-commit.sh** (CI-only, sem agente; destino: \`${TARGET_BRANCH}\`). PR aberto ANTES dos commits — cada commit já referencia \`#${PR_NUMBER}\` desde a criação."

  gh pr edit "$PR_NUMBER" --title "$pr_title" --body "$pr_body"
  gh pr ready "$PR_NUMBER"
  echo "  ✅ PR #${PR_NUMBER} atualizado com estatísticas e marcado como pronto para revisão."

  _log "🔀 ETAPA 8 — Mesclar PR #${PR_NUMBER} na ${TARGET_BRANCH}"

  local mergeable
  mergeable=$(gh pr view "$PR_NUMBER" --json mergeable --jq .mergeable)
  if [[ "$mergeable" == "CONFLICTING" ]]; then
    echo "  ❌ PR #${PR_NUMBER} está com conflitos. Resolva antes de mesclar. Abortando merge."
    exit 1
  fi

  gh pr merge "$PR_NUMBER" $MERGE_STRATEGY --delete-branch

  echo "  ✅ PR #${PR_NUMBER} mesclado em '${TARGET_BRANCH}'."
  echo "  🗑️  Branch remota '${FEATURE_NAME}' deletada pelo GitHub."

  _log "🧹 ETAPA 9 — Limpeza da feature branch local"

  git checkout "$TARGET_BRANCH"
  git pull origin "$TARGET_BRANCH"
  git submodule update --init --recursive

  if git branch --list "$FEATURE_NAME" | grep -q .; then
    git branch -d "$FEATURE_NAME" 2>/dev/null || git branch -D "$FEATURE_NAME"
    echo "  🗑️  Branch local '${FEATURE_NAME}' deletada."
  fi

  rm -f "$STATE_FILE"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🎉 FLUXO CONCLUÍDO COM SUCESSO"
  echo ""
  echo "  📌 PR #${PR_NUMBER}: ${pr_title}"
  echo "  🔀 Mesclado em:      ${TARGET_BRANCH}"
  echo "  🗑️  Branch removida:  ${FEATURE_NAME} (local + remota)"
  echo "  📍 Branch atual:     ${TARGET_BRANCH} (sincronizada)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ─────────────────────────────────────────────────────────────────────────────
# DISPATCHER
# ─────────────────────────────────────────────────────────────────────────────
case "${1:-}" in
  open)
    shift
    _cmd_open "${1:-}"
    ;;
  commit)
    _cmd_commit
    ;;
  finish)
    _cmd_finish
    ;;
  *)
    _cmd_open "${1:-}"
    _cmd_commit
    _cmd_finish
    ;;
esac