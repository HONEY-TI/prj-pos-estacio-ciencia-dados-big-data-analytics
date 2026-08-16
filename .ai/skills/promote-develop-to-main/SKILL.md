---
name: promote-develop-to-main
file: promote-develop-to-main.sh
description: >
  Promove alterações aprovadas da branch develop para main através de Pull Request.
  Não cria commits, não altera arquivos e não modifica histórico.
  A origem sempre é develop e o destino sempre é main.
  O título da PR é gerado automaticamente utilizando o número da própria PR
  e um nome inteligente baseado nos commits promovidos.
---

# 🚀 Skill: Promover Develop para Main

## 🎯 Objetivo

Esta skill realiza exclusivamente a promoção de código já aprovado.

Fluxo obrigatório:

```text
develop  ───────────────▶  main

origem                  destino
```

A branch `develop` contém todos os commits realizados durante o desenvolvimento.

A branch `main` recebe somente alterações aprovadas através desta Pull Request.

---

# 🔒 Regra principal de direção

A promoção possui fluxo único:

```text
develop → main
```

Nunca permitir:

```text
main → develop
```

Qualquer tentativa de inversão deve interromper a execução imediatamente.

---

# 🚫 Proibições

Esta skill nunca deve:

- criar commits;
- criar commit vazio;
- criar branch temporária;
- alterar arquivos;
- usar stash;
- fazer squash;
- criar tags;
- modificar histórico Git;
- realizar merge manual;
- executar:

Esta skill nunca deve utilizar stash.

Proibido executar:

```bash
git stash
git stash save
git stash push
git stash pop
git stash apply
git stash drop
git stash clear

```bash
git checkout main
git merge develop
```

A promoção acontece exclusivamente através do Pull Request.

---

# 🚫 Execução Bash

A ferramenta Bash deve receber somente comandos Bash válidos.

Nunca enviar:

```xml
<parameter name="command">
```

ou qualquer outro formato de marcação.

A execução deve conter apenas comandos diretamente executáveis.

---

# ⚙️ Pré-requisitos

Antes de qualquer operação validar:

```bash
command -v git
command -v gh

gh auth status

git rev-parse --is-inside-work-tree

git remote get-url origin

git ls-remote --exit-code origin

gh repo view
```

Caso qualquer validação falhe:

- interromper imediatamente;
- não continuar o processo.

---

# 🔍 Verificação de operações Git pendentes

Antes da promoção verificar:

- merge;
- rebase;
- cherry-pick.

Executar:

```bash
GIT_DIR=$(git rev-parse --git-dir)

if [[ \
-d "$GIT_DIR/rebase-merge" || \
-d "$GIT_DIR/rebase-apply" || \
-f "$GIT_DIR/MERGE_HEAD" || \
-f "$GIT_DIR/CHERRY_PICK_HEAD"
]]
then
    echo "Operação Git pendente encontrada."
    exit 1
fi
```

---

# 🔄 Atualização das branches

Atualizar referências:

```bash
git fetch origin
```

Atualizar `develop`:

```bash
git checkout develop
git pull origin develop
```

Atualizar `main`:

```bash
git checkout main
git pull origin main
```

Nenhuma alteração deve ser criada.

---

# 🔎 Verificar commits disponíveis

Comparar sempre:

```bash
git log origin/main..origin/develop --oneline
```

Resultado esperado:

```text
origin/develop possui commits novos
```

Caso não existam commits:

```text
Nenhuma alteração encontrada para promover da develop para a main.
```

Encerrar.

---

# 📊 Coleta de estatísticas

Calcular:

## Quantidade de commits

```bash
git log origin/main..origin/develop --oneline
```

## Arquivos alterados

```bash
git diff --name-only origin/main..origin/develop
```

## Linhas alteradas

```bash
git diff --shortstat origin/main..origin/develop
```

Informações usadas na documentação da PR.

---

# 🧠 Geração de nome inteligente

O nome da promoção deve ser criado analisando os commits.

Exemplos:

| Contexto encontrado | Nome gerado |
|-|-|
| auth, login, token, jwt | Atualizar autenticação |
| payment, billing | Release de pagamentos |
| api, endpoint, controller | Correções da API |
| docker, infra, deploy | Atualização de infraestrutura |
| performance, cache | Melhorias de performance |
| docs, markdown | Atualização de documentação |

Caso não encontre padrão:

```text
Atualização Geral
```

---

# 🔍 Verificar Pull Request existente

Buscar somente PR:

```text
head: develop
base: main
```

Comando:

```bash
gh pr list \
--base main \
--head develop \
--state open \
--json number \
--jq '.[0].number'
```

Se existir:

- reutilizar PR.

Caso contrário:

Criar:

```bash
gh pr create \
--base main \
--head develop \
--title "Release"
```

---

# 🛡️ Validação obrigatória da PR

Após obter o número:

```bash
PR_NUMBER=$(gh pr view develop --json number --jq .number)
```

Validar:

```bash
PR_BASE=$(gh pr view "$PR_NUMBER" \
--json baseRefName \
--jq .baseRefName)

PR_HEAD=$(gh pr view "$PR_NUMBER" \
--json headRefName \
--jq .headRefName)
```

Valores obrigatórios:

```text
PR_BASE=main

PR_HEAD=develop
```

Caso contrário:

```text
❌ Fluxo inválido.

Esperado:

develop → main
```

Interromper.

---

# 🏷️ Título da Pull Request

O título final deve sempre seguir:

```text
PR #<NUMERO> <NOME_INTELIGENTE>
```

Exemplo:

```text
PR #248 Atualizar autenticação
```

Atualização:

```bash
gh pr edit "$PR_NUMBER" \
--title "PR #$PR_NUMBER $SMART_NAME"
```

---

# 📝 Corpo da Pull Request

Formato obrigatório:

```markdown
# 🚀 Promoção da Develop para Main

## Pull Request

PR #<NUMBER> <SMART_NAME>

---

## Objetivo

Promover alterações aprovadas da branch `develop`
para a branch `main`.

Esta promoção não cria novos commits.

Todos os commits já foram realizados anteriormente
na branch `develop`.

---

## Estatísticas

| Métrica | Valor |
|---|---|
| Origem | develop |
| Destino | main |
| Commits | XX |
| Arquivos | XX |
| Linhas adicionadas | XX |
| Linhas removidas | XX |

---

## Commits promovidos

(lista automática)

---

## Arquivos alterados

<details>

(lista automática)

</details>

---

## Checklist

- [ ] Código revisado
- [ ] Testes aprovados
- [ ] CI aprovado
- [ ] Sem conflitos
- [ ] Pronto para produção

---

## Referência

PR #<NUMBER> <SMART_NAME>
```

---

# ⚔️ Verificação de conflitos

Antes do merge:

```bash
MERGEABLE=$(gh pr view "$PR_NUMBER" \
--json mergeable \
--jq .mergeable)
```

Se retornar:

```text
CONFLICTING
```

Interromper.

Nunca tentar resolver automaticamente.

---

# 🚀 Merge

Somente após todas as validações:

```bash
gh pr merge "$PR_NUMBER" --merge
```

---

# 🔍 Validação final

Após o merge:

```bash
git fetch origin

git log origin/main..origin/develop --oneline
```

Resultado esperado:

```text
develop → main concluído
```

---

# ✅ Resultado esperado

Ao finalizar:

✔ `develop` permanece intacta  
✔ `main` recebe os commits aprovados  
✔ nenhum commit adicional criado  
✔ nenhuma branch temporária criada  
✔ nenhum arquivo alterado  
✔ PR documentada automaticamente  
✔ fluxo garantido:

```text
develop
   |
   | Pull Request
   ↓
main
```