#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Promote Develop -> Main
#
# Fluxo permitido:
#
# develop -----------------> main
#
# Nunca:
#
# main --------------------> develop
#
# Regras:
#
# - Não cria commits
# - Não altera arquivos
# - Não usa stash
# - Não cria branches
# - Não faz merge manual
# - Merge somente através da Pull Request
#
###############################################################################

require() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Erro: comando '$1' não encontrado."
        exit 1
    }
}

fail() {
    echo
    echo "❌ $1"
    exit 1
}

###############################################################################
# Pré requisitos
###############################################################################

require git
require gh

gh auth status >/dev/null \
    || fail "GitHub CLI não autenticado."

git rev-parse --is-inside-work-tree >/dev/null \
    || fail "Não é um repositório Git."

git remote get-url origin >/dev/null \
    || fail "Remote origin não encontrado."

git ls-remote --exit-code origin >/dev/null \
    || fail "Remote origin indisponível."

gh repo view >/dev/null \
    || fail "Repositório GitHub não encontrado."


###############################################################################
# Bloquear stash
###############################################################################

if [[ -n "$(git stash list)" ]]; then
    fail "
Existem entradas no stash.

Esta operação nunca utiliza:
git stash
git stash push
git stash pop
git stash apply

Remova os stash manualmente antes de continuar.
"
fi


###############################################################################
# Verificar operações Git pendentes
###############################################################################

GIT_DIR=$(git rev-parse --git-dir)

if [[ \
-f "$GIT_DIR/MERGE_HEAD" ||
-f "$GIT_DIR/CHERRY_PICK_HEAD" ||
-d "$GIT_DIR/rebase-merge" ||
-d "$GIT_DIR/rebase-apply"
]]
then
    fail "Existe operação Git pendente."
fi


###############################################################################
# Garantir repositório limpo
###############################################################################

if [[ -n "$(git status --porcelain)" ]]; then
    fail "
Existem alterações locais.

A promoção develop -> main exige working tree limpa.

Nenhuma alteração será escondida utilizando stash.
"
fi


###############################################################################
# Atualizar referências remotas
###############################################################################

echo "Atualizando referências..."

git fetch origin


###############################################################################
# Atualizar develop
###############################################################################

echo "Atualizando develop..."

git checkout develop

git pull origin develop


###############################################################################
# Atualizar main
###############################################################################

echo "Atualizando main..."

git checkout main

git pull origin main


###############################################################################
# Confirmar branch destino
###############################################################################

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [[ "$CURRENT_BRANCH" != "main" ]]; then
    fail "
Branch atual inválida.

Esperado:
main

Atual:
$CURRENT_BRANCH
"
fi


###############################################################################
# Verificar commits develop -> main
###############################################################################

COMMITS=$(git log origin/main..origin/develop --oneline)


if [[ -z "$COMMITS" ]]; then
    echo
    echo "Nenhuma alteração encontrada para promover da develop para main."
    exit 0
fi


###############################################################################
# Estatísticas
###############################################################################

FILES=$(git diff \
origin/main..origin/develop \
--name-only)


STATS=$(git diff \
origin/main..origin/develop \
--shortstat)


###############################################################################
# Nome inteligente
###############################################################################

SMART_NAME="Atualização Geral"


if echo "$COMMITS" | grep -Ei "auth|login|token|jwt"; then

    SMART_NAME="Atualizar autenticação"

elif echo "$COMMITS" | grep -Ei "payment|billing"; then

    SMART_NAME="Release de pagamentos"

elif echo "$COMMITS" | grep -Ei "api|endpoint|controller"; then

    SMART_NAME="Correções da API"

elif echo "$COMMITS" | grep -Ei "docker|infra|deploy"; then

    SMART_NAME="Atualização de infraestrutura"

elif echo "$COMMITS" | grep -Ei "cache|performance"; then

    SMART_NAME="Melhorias de performance"

elif echo "$COMMITS" | grep -Ei "docs|markdown"; then

    SMART_NAME="Atualização de documentação"

fi


###############################################################################
# Buscar PR develop -> main existente
###############################################################################

echo "Buscando PR existente..."

PR_NUMBER=$(
gh pr list \
--base main \
--head develop \
--state open \
--json number \
--jq '.[0].number'
)


###############################################################################
# Criar PR caso não exista
###############################################################################

if [[ -z "$PR_NUMBER" ]]; then

    echo "Criando PR develop -> main"

    gh pr create \
    --base main \
    --head develop \
    --title "Release"


    PR_NUMBER=$(
    gh pr view develop \
    --json number \
    --jq .number
    )

fi


###############################################################################
# Validar direção da PR
###############################################################################

PR_BASE=$(
gh pr view "$PR_NUMBER" \
--json baseRefName \
--jq .baseRefName
)


PR_HEAD=$(
gh pr view "$PR_NUMBER" \
--json headRefName \
--jq .headRefName
)


if [[ "$PR_BASE" != "main" ||
      "$PR_HEAD" != "develop" ]]
then

    fail "
Fluxo inválido detectado.

Permitido:

develop -> main

Encontrado:

$PR_HEAD -> $PR_BASE
"

fi


###############################################################################
# Atualizar PR
###############################################################################

TITLE="PR #${PR_NUMBER} ${SMART_NAME}"


BODY=$(cat <<EOF
# 🚀 Promoção da Develop para Main

## Pull Request

PR #${PR_NUMBER} ${SMART_NAME}

---

## Objetivo

Promover alterações aprovadas da branch \`develop\`
para a branch \`main\`.

Esta promoção não cria novos commits.

Todos os commits já existem na branch \`develop\`.

---

## Estatísticas

${STATS}

Origem: develop

Destino: main

---

## Commits promovidos

${COMMITS}

---

## Arquivos alterados

<details>

${FILES}

</details>

---

## Checklist

- [ ] Código revisado
- [ ] Testes aprovados
- [ ] CI aprovado
- [ ] Sem conflitos

---

## Referência

PR #${PR_NUMBER} ${SMART_NAME}
EOF
)


gh pr edit "$PR_NUMBER" \
--title "$TITLE" \
--body "$BODY"


###############################################################################
# Verificar conflitos
###############################################################################

MERGEABLE=$(
gh pr view "$PR_NUMBER" \
--json mergeable \
--jq .mergeable
)


if [[ "$MERGEABLE" == "CONFLICTING" ]]; then
    fail "PR possui conflitos. Merge cancelado."
fi


###############################################################################
# Merge somente pela PR validada
###############################################################################

echo "Realizando merge da PR #${PR_NUMBER}"

gh pr merge "$PR_NUMBER" --merge


###############################################################################
# Validação final
###############################################################################

git fetch origin


REMAINING=$(
git log origin/main..origin/develop --oneline
)


if [[ -n "$REMAINING" ]]; then

    fail "
Promoção incompleta.

Ainda existem commits em:

develop

que não chegaram em:

main
"

fi


###############################################################################
# Final
###############################################################################

echo
echo "================================="
echo "Promoção concluída com sucesso"
echo
echo "$TITLE"
echo "Fluxo: develop -> main"
echo "================================="