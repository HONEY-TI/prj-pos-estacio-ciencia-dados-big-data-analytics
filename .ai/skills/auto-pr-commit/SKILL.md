---
name: pr-flow
file: pr-flow.sh
description: >
  Executar commits (por arquivo OU agrupados por contexto, conforme o tamanho do changeset),
  criar feature branch, ABRIR O PULL REQUEST ANTES de qualquer commit de conteúdo (para que cada
  commit já referencie "Refs: #PR"), atualizar o PR com estatísticas agregadas, e mesclar —
  sempre com destino `develop` (fallback `main`, com override manual via MAIN_BRANCH), por
  **squash merge**, de modo que o histórico da branch de destino fique com um único commit por
  PR, com a mensagem igual ao título da PR. Recebe como entrada o **nome da PR já predefinido**
  (não é inferido do diff) e mantém documentação local em
  `.backlog/pull-request/<slug-da-pr>.md`, que sempre aponta (`extends:`) para uma feature em
  `.backlog/features/feature-<NN>-<slug-da-feature>.md` (numeração sequencial de 2 dígitos,
  ex.: `feature-01-retry-button-reutilizavel.md`) — se a feature ainda não existir, é criada
  automaticamente com o próximo número disponível. Todo o fluxo é executado ao vivo por Agente
  via ferramenta de bash, comando a comando, analisando cada diff — nunca gerando um script para
  rodar depois. A lógica de commit por arquivo (tipo, escopo, formato de mensagem, submodules) é
  a mesma da skill `auto-commit` — esta skill acrescenta gestão de branch/PR, documentação em
  `.backlog` e a opção de agrupar commits por contexto.
---

# 🧠 Skill: Commit Inteligente + Feature Branch + Pull Request + Documentação `.backlog`

> **Changelog desta revisão** (correção de inconsistências identificadas em auditoria):
> 1. O `stash` deixou de ser o caminho padrão para trocar de branch com working tree sujo — agora
>    é usado **apenas como fallback**, quando o checkout direto da feature branch não é possível
>    sem conflito (ver passo 4).
> 2. A ordem do fluxo foi explicitada: o PR nasce **depois** da criação de branch/submodule/docs
>    de Feature e PR, e **antes** de qualquer commit de conteúdo. Nunca foi "PR antes de tudo".
> 3. O passo 11 (Limpeza) executava `git pull origin "$TARGET_BRANCH"`, que na prática é
>    `git pull origin develop` — o exato comando proibido na seção "🚫 Execução de comandos Bash".
>    Corrigido para `git fetch` + `git merge --ff-only`, que nunca cria merge commit implícito e
>    não viola a proibição.

> Esta skill **invoca** a skill `auto-commit` no modo por-arquivo (passo 6): Agente lê o arquivo
> `auto-commit` naquele momento do fluxo e executa o que está descrito nele, em vez de aplicar de
> memória uma versão resumida. Por isso as tabelas de tipo/escopo e o formato de mensagem não são
> duplicados aqui — mudar `auto-commit` já muda o comportamento desta skill também. O que é
> exclusivo deste arquivo: nome de PR predefinido, documentação em `.backlog/pull-request` e
> `.backlog/features` (com numeração sequencial), abrir o PR antes dos commits, `Refs: #PR`, a
> escolha entre modo por-arquivo/agrupado, o modo agrupado em si (que não existe em
> `auto-commit`), e o squash merge final com a mensagem igual ao título da PR.

---

## 📥 Entradas da skill

| Entrada                  | Obrigatória? | Descrição                                                                                                                                                                                                             |
| ------------------------ | ------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `PR_NAME`                | **Sim**      | Nome/título da PR, já definido por quem chama a skill (ex.: `"Atualizar Aplicacao Assistant Auth"`). Usado como título do PR no GitHub, como base do slug da feature branch, do arquivo em `.backlog/pull-request/` e, ao final, como mensagem do commit de squash na branch de destino. |
| `FEATURE_NAME`           | Não          | Nome da feature à qual esta PR pertence. Se omitido, assume o **mesmo texto de `PR_NAME`** (uma PR = uma feature, caso mais comum). Informe explicitamente quando várias PRs implementam a mesma feature em partes.   |
| Nome de branch explícito | Não          | Se o usuário informar a branch diretamente, ela tem prioridade sobre o slug gerado a partir de `PR_NAME` (ver passo 3).                                                                                               |

Se `PR_NAME` não for informado ao acionar esta skill, Agente **para antes de qualquer comando de
bash** e pergunta pelo nome da PR — todo o resto do fluxo (branch, título do PR, documentação em
`.backlog`, mensagem final do squash) depende dele, então não há heurística segura para
adivinhá-lo.

---

## 🗂️ Documentação em `.backlog`

Esta skill mantém dois arquivos Markdown fora do fluxo do GitHub, versionados no próprio repo:

- **`.backlog/features/feature-<NN>-<slug-da-feature>.md`** — documento da feature (contexto,
  objetivo, contrato, critérios de aceite). `<NN>` é um número sequencial de 2 dígitos
  (`01`, `02`, `03`, ...), calculado a partir dos arquivos já existentes em
  `.backlog/features/` (maior número encontrado + 1; `01` se o diretório estiver vazio). Não é
  recriado se já existir uma feature com o mesmo texto de slug — nesse caso o número já
  atribuído anteriormente é reaproveitado, nunca renumerado.
- **`.backlog/pull-request/<slug-da-pr>.md`** — documento da PR, com frontmatter `extends:
feature-<NN>-<slug-da-feature>` apontando para o arquivo acima. É sempre criado (se não existir)
  ou atualizado (se já existir) por esta skill.

Caminhos configuráveis via `BACKLOG_FEATURES_DIR` (padrão `.backlog/features`) e
`BACKLOG_PR_DIR` (padrão `.backlog/pull-request`), mesma lógica de override de `MAIN_BRANCH`.

Formato do frontmatter da PR:

```yaml
---
name: <slug-da-pr>
pr: <PR_NUMBER> # preenchido só depois do passo 5.1
title: "PR(#<PR_NUMBER>)-<PR_NAME>"
branch: <FEATURE_NAME-da-branch>
base: <TARGET_BRANCH>
extends: feature-<NN>-<slug-da-feature>
status: draft # draft → open → merged
---
```

Formato mínimo do frontmatter da feature (quando criada por esta skill, e não já existente):

```yaml
---
name: feature-<NN>-<slug-da-feature>
file: feature-<NN>-<slug-da-feature>.md
description: >
  <preenchido a partir de PR_NAME/contexto do diff — revisar manualmente depois>
---
```

com corpo mínimo (`## Contexto / Problema`, `## Objetivo`, `## Critérios de aceite`) marcado como
rascunho a ser complementado — esta skill nunca inventa critérios de aceite a partir do diff,
apenas cria o esqueleto para não deixar o `extends:` da PR apontando para um arquivo inexistente.

---

## 🚫 Proibido narrar conformidade

O agente NUNCA deve escrever frases como:

- "Understood, I will strictly follow..."
- "Entendido, vou seguir o formato..."
- "Let me execute the provided commands..."
- Qualquer texto que apenas confirme que vai obedecer a uma instrução, antes de agir.

A resposta a uma instrução de formato/processo é APLICAR o formato na próxima ação, não anunciar
que vai aplicar. Se a próxima ação é uma chamada de ferramenta, ela deve vir diretamente, sem
preâmbulo de texto reconhecendo a instrução recebida.

Exceção: uma única frase curta de status operacional é aceitável apenas quando resume o que JÁ
foi feito ou o que vai ser feito tecnicamente (ex.: "PR #42 criado, iniciando commits"), nunca
quando apenas repete/confirma uma regra do prompt.

## 🚫 Execução de comandos Bash

- é proibido executar `git pull origin develop` (ou `git pull origin "$TARGET_BRANCH"`) em
  **qualquer** passo do fluxo, incluindo a limpeza final. Sincronização com o remoto usa sempre
  `git fetch` + `git merge --ff-only` (ver passo 11) — nunca um `pull` implícito, que poderia
  gerar merge commit sem revisão.
- **É proibido executar qualquer comando que deixe a branch local desatualizada em relação ao
  remoto correspondente sem sincronizar em seguida.** Isso inclui, sem se limitar a: um
  `checkout`/`fetch` que troca de branch mas não atualiza a referência local antes de basear
  algo nela; um merge/rebase que é abortado sem que a branch volte a um estado sincronizado
  conhecido; ou qualquer sequência que termine deixando `$TARGET_BRANCH` ou `$FEATURE_NAME`
  local apontando para um commit mais antigo que o que já foi enviado ao remoto na mesma sessão.
  Sempre que uma branch local for referenciada como base de outra operação (checkout -b, merge,
  push), ela precisa já refletir o estado mais recente conhecido do remoto (via `fetch` +
  `merge --ff-only`, nunca `pull`).
- A ferramenta de Bash deve receber **exclusivamente comandos Bash válidos**.
- Nunca enviar XML, HTML ou qualquer outro formato de marcação (além de markdown na comunicação
  com o usuário) para a ferramenta de Bash.
- Nunca envolver comandos em blocos de parâmetro/tag como se fossem parte do próprio comando.

---

## 🔀 Escolha do modo de commit

Antes de tocar em qualquer arquivo, Agente decide o modo com uma regra simples e transparente:

| Condição                                                     | Modo escolhido                                |
| ------------------------------------------------------------ | --------------------------------------------- |
| Usuário pediu explicitamente "um commit por arquivo"         | **por-arquivo**                               |
| Usuário pediu explicitamente "agrupar" / "commits agrupados" | **agrupado**                                  |
| Nº de arquivos alterados ≤ 8                                 | **por-arquivo** (o detalhamento vale o custo) |
| Nº de arquivos alterados > 8                                 | **agrupado** (reduz ruído e tokens)           |

Agente informa ao usuário, em uma linha, qual modo foi escolhido e por quê, antes de prosseguir.

> Nota: independente do modo escolhido aqui, os commits atômicos (por-arquivo ou agrupados)
> continuam existindo normalmente na feature branch e no PR durante a revisão — o que muda com o
> squash merge (passo 10) é que, **na branch de destino**, todo esse histórico é condensado em um
> único commit ao mesclar. O detalhamento por commit continua visível no PR até lá.

---

## ⚙️ Pré-requisitos

Antes de qualquer commit, Agente verifica ao vivo (um comando por vez, parando se algo falhar):

```bash
command -v git                         # git instalado
command -v gh                          # gh instalado
gh auth status                         # gh autenticado
git rev-parse --is-inside-work-tree    # está dentro de um repo git
git remote get-url origin              # remote origin configurado
git ls-remote --exit-code origin       # origin acessível (rede/credenciais)
gh repo view                           # gh enxerga o repo (permissão p/ abrir PR)
git rev-parse --git-dir                # localizar .git p/ checar operações pendentes
```

Se qualquer um falhar, Agente **para e explica** o que precisa ser corrigido — nunca segue em
frente "torcendo para dar certo". Também checa se há rebase/merge/cherry-pick pendente
(`rebase-merge`, `rebase-apply`, `MERGE_HEAD`, `CHERRY_PICK_HEAD` dentro de `.git`) e aborta se
houver.

---

## 🚀 Fluxo da Skill

### 1. Verificar estado do repositório

```bash
git rev-parse --abbrev-ref HEAD
git status --porcelain=v1 -uall
```

Se não houver nada modificado, Agente informa e encerra — não cria branch, PR nem documentação
`.backlog` à toa.

### 2. Resolver a branch de destino

```bash
if [ -n "$MAIN_BRANCH" ]; then
  TARGET_BRANCH="$MAIN_BRANCH"
elif git show-ref --verify --quiet refs/heads/develop; then
  TARGET_BRANCH="develop"
elif git ls-remote --exit-code --heads origin develop &>/dev/null; then
  TARGET_BRANCH="develop"
else
  TARGET_BRANCH="main"
fi
```

Essa é a única fonte de verdade da branch alvo — usada em todo o resto do fluxo (checkout, sync,
PR `--base`, merge).

### 3. Definir nome da feature branch e slugs

- Se o usuário informar um nome de branch explicitamente, Agente usa esse nome (normalizado:
  minúsculo, sem acento, `a-z0-9/-`) — prioridade máxima.
- Caso contrário (caso padrão desta skill), a branch é derivada de `PR_NAME`:

```bash
slugify() {
  echo "$1" | iconv -t ascii//TRANSLIT 2>/dev/null \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' \
    | cut -c1-50
}

PR_SLUG="$(slugify "$PR_NAME")"
FEATURE_TEXT_SLUG="$(slugify "${FEATURE_NAME:-$PR_NAME}")"
FEATURE_NAME="feature/${PR_SLUG}"
```

`PR_SLUG` nomeia o arquivo em `.backlog/pull-request/`, `FEATURE_TEXT_SLUG` é a parte textual do
nome da feature (sem o número, resolvido no passo 3.1), e `FEATURE_NAME` (variável já usada no
restante do fluxo original) passa a ser sempre `feature/<slug-da-pr>` — a heurística antiga de
nomear a branch a partir do diff (ação dominante + palavra-chave de módulo) **não se aplica mais
nesta skill**, pois o nome já chega pronto via `PR_NAME`.

### 3.1 Garantir a documentação da feature em `.backlog/features/` (numeração sequencial)

```bash
mkdir -p "${BACKLOG_FEATURES_DIR:-.backlog/features}"
FDIR="${BACKLOG_FEATURES_DIR:-.backlog/features}"

# 1) já existe uma feature com este mesmo texto de slug (qualquer número)?
EXISTING_FEATURE_DOC="$(ls "$FDIR"/feature-*-"${FEATURE_TEXT_SLUG}".md 2>/dev/null | head -n1)"

if [ -n "$EXISTING_FEATURE_DOC" ]; then
  FEATURE_DOC="$EXISTING_FEATURE_DOC"
  FEATURE_SLUG="$(basename "$FEATURE_DOC" .md | sed -E 's/^feature-//')"
  echo "existe: $FEATURE_DOC"
else
  # 2) calcular o próximo número sequencial (2 dígitos) a partir dos arquivos existentes
  LAST_NUM="$(ls "$FDIR"/feature-*.md 2>/dev/null \
    | sed -E 's#.*/feature-([0-9]+)-.*#\1#' \
    | sort -n | tail -1)"
  NEXT_NUM="$(printf "%02d" $(( ${LAST_NUM:-0} + 1 )))"
  FEATURE_SLUG="${NEXT_NUM}-${FEATURE_TEXT_SLUG}"
  FEATURE_DOC="$FDIR/feature-${FEATURE_SLUG}.md"
  echo "criar: $FEATURE_DOC"
fi
```

- Se já existir uma feature com o mesmo texto de slug, Agente **não sobrescreve e não renumera**
  — apenas reaproveita o número já atribuído.
- Se não existir, Agente cria um esqueleto mínimo (`feature-<NN>-<slug>.md`, frontmatter com
  `name`/`file` já no formato numerado, `Contexto/Problema`, `Objetivo`, `Critérios de aceite`
  em rascunho, a partir do que for possível inferir do diff e de `PR_NAME`) e avisa em uma linha
  que a feature foi criada como `feature-<NN>-<slug>.md` e deve ser revisada por um humano.
- `NN` nunca é reaproveitado de uma feature diferente nem preenche lacunas deixadas por features
  removidas — é sempre `maior número existente + 1`.

### 4. Sincronizar destino e criar a feature branch (stash como fallback, não padrão)

```bash
git fetch origin "$TARGET_BRANCH"
git submodule update --init --recursive

# Tenta primeiro criar a feature branch diretamente a partir do destino atualizado. O git
# preserva automaticamente as mudanças não commitadas na nova branch quando não há conflito —
# não precisa de stash nesse caso.
if git checkout -b "$FEATURE_NAME" "origin/$TARGET_BRANCH" 2>/dev/null; then
  :
elif git checkout -b "$FEATURE_NAME" "$TARGET_BRANCH" 2>/dev/null; then
  :
else
  # Fallback: só entra aqui se o checkout direto falhou por conflito real entre as mudanças
  # não commitadas e o destino (ex.: mesmo arquivo modificado em ambos). Stash é a exceção,
  # não a regra.
  git stash push -u
  git checkout "$TARGET_BRANCH"
  git checkout -b "$FEATURE_NAME"
  git stash pop
fi
```

Agente informa em uma linha se precisou do fallback de stash (e por quê, se souber — geralmente
conflito de merge no checkout direto), para transparência do fluxo.

### 4.1 Garantir a documentação da PR em `.backlog/pull-request/`

```bash
mkdir -p "${BACKLOG_PR_DIR:-.backlog/pull-request}"
PR_DOC="${BACKLOG_PR_DIR:-.backlog/pull-request}/${PR_SLUG}.md"
test -f "$PR_DOC" && echo "existe" || echo "criar"
```

- Se não existir, Agente cria com o frontmatter descrito na seção "Documentação em `.backlog`"
  acima (`extends: feature-<NN>-<slug-da-feature>`), `status: draft` e `pr:` ainda vazio
  (preenchido no passo 5.1).
- Se já existir (reexecução da skill para a mesma PR), Agente **reaproveita** o arquivo e só
  atualiza `status`/`pr` conforme o fluxo avança — nunca recria do zero.
- Este arquivo é commitado junto com o restante do changeset (é conteúdo do repositório, segue
  as mesmas regras de commit do passo 6 — normalmente cai no escopo `docs`/`backlog`).

### 5.0 Revisar PR já existente para esta branch (antes de decidir criar um novo)

```bash
gh pr list --head "$FEATURE_NAME" --state open --json number,baseRefName,mergeable --jq '.[0]'
```

Se existir um PR aberto para `$FEATURE_NAME`, Agente **não cria um novo** — reaproveita o número,
mas antes verifica:

- **`baseRefName` bate com `$TARGET_BRANCH`?** Se não bater, avisa o usuário e para — mesclar
  numa base diferente da resolvida no passo 2 pode não ser o que se espera.
- **`mergeable` já é `CONFLICTING`?** Se sim, avisa antes de continuar — não faz sentido empilhar
  commits novos num PR que já está conflitante com o destino.
- Se ambos os pontos estiverem ok, segue para o passo 6 usando esse `PR_NUMBER`, e atualiza
  `pr:`/`status:` em `$PR_DOC` se ainda estiverem vazios.

Se não existir PR aberto para a branch, segue para 5.1 (criação).

### 5.1 ⭐ Abrir o Pull Request (draft) — ANTES de qualquer commit de conteúdo

```bash
git commit --allow-empty -m "chore: iniciar feature ${FEATURE_NAME}" \
  -m "Commit inicial vazio para permitir abertura do PR antes dos commits de conteúdo."
git push -u origin "$FEATURE_NAME"

gh pr create --draft \
  --base "$TARGET_BRANCH" --head "$FEATURE_NAME" \
  --title "PR(#$PR_NUMBER)-$PR_NAME" \
  --body "_PR aberto antes dos commits de conteúdo; corpo será atualizado com estatísticas._"

PR_NUMBER=$(gh pr view "$FEATURE_NAME" --json number --jq .number)
gh pr edit "$PR_NUMBER" --title "PR (#${PR_NUMBER}) ${PR_NAME}"
```

O título inicial usa `$PR_NAME`; após a criação, ele é normalizado para `PR (#<PR_NUMBER>) <PR_NAME>`.
A partir daqui,
`PR_NUMBER` é conhecido e usado em todos os commits seguintes e no frontmatter de `$PR_DOC`.
Draft é usado propositalmente: o PR existe e é rastreável, mas não sinaliza "pronto para
revisão" enquanto só tem o commit vazio.

Atualiza `$PR_DOC` com `pr: $PR_NUMBER`.

Labels/reviewers, se solicitados, são aplicados aqui, um por vez, avisando se algum falhar:

```bash
gh pr edit "$PR_NUMBER" --add-label "<label>"
gh pr edit "$PR_NUMBER" --add-reviewer "<usuario>"
```

> Se `PR_NUMBER` não estiver definido em nenhum momento a partir daqui, Agente **para e não
> commita nada** — commitar sem o PR já existir quebra a premissa do fluxo.

### 6. Processar submodules e arquivos do repositório pai

- **Modo por-arquivo**: Agente **invoca a skill `auto-commit`** neste ponto — não "aplica de
  cabeça" as mesmas regras, mas efetivamente lê `auto-commit` e executa o fluxo dela passo a
  passo (pré-requisitos já foram checados no passo 0 desta skill, não precisa repetir):
  1. Ler/reler `auto-commit` (via `view` ou equivalente) antes de começar a commitar, mesmo que
     já tenha sido lida antes na sessão — garante que a versão executada é a atual do arquivo,
     não uma lembrança da conversa.
  2. Executar o "Fluxo da Skill" de `auto-commit` (submodules primeiro, depois arquivo por
     arquivo do repositório pai, incluindo `$PR_DOC` e, se criado, `$FEATURE_DOC`) exatamente
     como descrito lá — mesmas tabelas de tipo/escopo, mesmo formato de commit.
  3. Único acréscimo desta chamada: o `PR_NUMBER` resolvido no passo 5 desta skill é passado
     como contexto, então cada commit gerado por `auto-commit` inclui `Refs: #${PR_NUMBER}` (a
     própria seção "Uso dentro de outro fluxo" de `auto-commit` cobre esse comportamento).
  4. Quando `auto-commit` sinalizar que terminou os commits, Agente retoma o fluxo desta skill
     no passo 7 (push) — `auto-commit` não dá push nem mexe em PR quando chamada com `PR_NUMBER`
     no contexto, isso fica por conta de quem chamou.

  Isso é uma chamada real, não um resumo: se `auto-commit` mudar (nova regra de tipo, novo
  escopo), o comportamento aqui muda junto, automaticamente, porque o passo 1 relê o arquivo.

- **Modo agrupado**: exclusivo desta skill, não passa por `auto-commit` — ver seção 6B abaixo.
  Submodules continuam sempre primeiro, também usando o agrupamento quando fizer sentido dentro
  do submodule. `$PR_DOC`/`$FEATURE_DOC` entram no grupo `docs`/`backlog`.

#### 6B. Modo agrupado (exclusivo desta skill)

1. **Agrupar**: cada arquivo de `git status --porcelain=v1 -uall` é associado a um escopo, usando
   a mesma tabela de escopo de `auto-commit` (incluindo o refinamento de dois níveis, ex.:
   `domain-auth` vs. `domain-payment`).
2. **Analisar uma vez por grupo** (não por arquivo):

```bash
git diff -- <arquivos do grupo>
```

3. Determinar o tipo do grupo pela mesma tabela de tipos de `auto-commit`, por predominância
   entre os arquivos do grupo (empate: `security > fix > feat > refactor > test > chore`).
4. `git add -- arquivo1 arquivo2 arquivo3` (nunca `git add .`) e:

```bash
git commit -m "<tipo>(<escopo>): <ação> <N> arquivo(s)" -m "<corpo>

Refs: #${PR_NUMBER}"
```

Formato do corpo (lista real de arquivos, não só a contagem):

```markdown
Arquivos alterados:

- src/domain/user.ts
- src/domain/role.ts
- src/domain/user-repository.ts

Resumo:

- Ação: atualizar
- Tipo: refactor
- Escopo: domain
- Arquivos: 3
- Linhas adicionadas: 42
- Linhas removidas: 8
```

> Se um grupo estiver claramente misturando contextos independentes (ex.: `domain-auth` e
> `domain-payment` caíram os dois em `domain` por não terem sido pré-refinados), Agente divide o
> commit em vez de forçar tudo junto — coerência da mudança tem prioridade sobre reduzir a
> contagem de commits.

> Nota: mesmo no modo agrupado, os commits individuais continuam existindo e sendo referenciados
> no PR (passo 9) — o squash (passo 10) só condensa tudo em um commit **no momento do merge**,
> não durante o desenvolvimento.

### 7. Push da feature branch com os commits reais

```bash
git push origin "$FEATURE_NAME"
```

### 8. Recalcular estatísticas de forma determinística

Antes de escrever o corpo do PR, Agente roda estes comandos e usa a **saída deles**, não a soma
mental acumulada ao longo da conversa — isso evita erro de contagem em changesets grandes com
muitas chamadas de bash:

```bash
git rev-list --count "$TARGET_BRANCH".."$FEATURE_NAME"
git diff --name-only "$TARGET_BRANCH".."$FEATURE_NAME" | wc -l
git diff --shortstat "$TARGET_BRANCH".."$FEATURE_NAME"
git log "$TARGET_BRANCH".."$FEATURE_NAME" --no-merges \
  --pretty=format:'%s|%ad' --date=format:'%d/%m/%Y %H:%M' \
  | grep -v '^chore: iniciar feature'
```

A última saída (`subject|data`) alimenta diretamente a lista de commits do corpo do PR (passo 9)
— um bloco por commit, com o subject em negrito e a data em itálico logo abaixo — e também as
tabelas de "commits por tipo"/"commits por escopo", contando direto dessa lista, não do que foi
"lembrado" durante os commits. Essa lista de commits individuais fica só no corpo do PR — ela não
sobrevive ao squash do passo 10, que é justamente o objetivo: o histórico detalhado vive no PR
(rastreável no GitHub), e a branch de destino recebe um único commit limpo.

### 9. Atualizar o PR com estatísticas reais e tirá-lo do draft

O título permanece no formato `PR (#${PR_NUMBER}) ${PR_NAME}`. O corpo segue este template fixo:

```markdown
## 📋 Descrição

Implementação da **${PR_NAME}** via feature branch `${FEATURE_NAME}`, com commits atômicos e
semânticos ${MODO_TEXTO}.

Feature relacionada: `${FEATURE_DOC}`

---

## 📊 Estatísticas

| Métrica               | Valor              |
| --------------------- | ------------------ |
| 🌿 Branch de origem   | `${FEATURE_NAME}`  |
| 🎯 Branch de destino  | `${TARGET_BRANCH}` |
| 📝 Total de commits   | ${TOTAL_COMMITS}   |
| 📁 Arquivos alterados | ${TOTAL_ARQUIVOS}  |

---

## Checklist

- [x] Commits separados por contexto
- [x] Referência do PR incluída nos commits de conteúdo
- [x] Alterações revisadas e enviadas para a branch
- [ ] Revisão funcional
- [ ] Validação em ambiente Linux/jail

---

## 📝 feature Commits

- **<subject do feature>**
  > _<data DD/MM/AAAA HH:MM>_
- **<subject do feature>**
  > _<data DD/MM/AAAA HH:MM>_
```

Onde `MODO_TEXTO` é `"por arquivo"` (modo por-arquivo) ou `"agrupados por contexto"` (modo
agrupado), e as duas últimas linhas do checklist **nunca são marcadas automaticamente** — ficam
para revisão humana.

```bash
gh pr edit "$PR_NUMBER" --body "<corpo acima já preenchido>"
gh pr ready "$PR_NUMBER"
```

Em seguida, Agente atualiza `$PR_DOC`: `status: open`, e o corpo do arquivo local passa a
espelhar o mesmo conteúdo enviado ao GitHub (evita que a documentação em `.backlog` fique
desatualizada em relação ao PR real). Esta atualização de `$PR_DOC` entra em um commit próprio
(`docs` ou dentro do grupo `docs` do passo 6B, conforme o modo).

### 10. Verificar conflitos e mesclar (squash, mensagem = título da PR)

```bash
gh pr view "$PR_NUMBER" --json mergeable --jq .mergeable
```

- Se `CONFLICTING` → Agente **avisa e não tenta mesclar** (nenhuma pergunta é feita — não há o
  que confirmar).
- Caso contrário → Agente **pergunta ao usuário (Y/N) antes de mesclar**, mostrando PR, branch de
  origem/destino e a estratégia fixa desta skill: **squash**, com a mensagem do commit final
  igual ao título da PR (`PR (#${PR_NUMBER}) ${PR_NAME}`):
  - **Y** → executa:
    ```bash
    gh pr merge "$PR_NUMBER" --squash --delete-branch \
      --subject "PR (#${PR_NUMBER}) ${PR_NAME}" \
      --body ""
    ```
    Isso substitui, no commit resultante em `$TARGET_BRANCH`, todas as mensagens dos commits
    individuais (por-arquivo ou agrupados, incluindo o `chore: iniciar feature ...` vazio) por
    uma única mensagem: o título da PR. O histórico detalhado por commit continua preservado no
    PR fechado do GitHub (não é perdido, só não fica na branch de destino). Agente então
    atualiza `$PR_DOC` para `status: merged` em um commit direto na branch de destino (passo 11
    já está de volta em `$TARGET_BRANCH` nesse ponto).
  - **N** → não mescla. O PR permanece aberto (`ready`, fora do draft) e `$PR_DOC` permanece em
    `status: open`. O passo 11 (limpeza) não roda — a feature branch não é removida enquanto o
    PR não for mesclado.

> **Decisão de design**: o merge nunca é automático — mesmo sem conflito, esta skill sempre para
> e pede confirmação explícita antes de mesclar. O PR serve como rastreabilidade e changelog
> detalhado (commit a commit), mas o merge em si passa por um gate humano simples de Y/N, não
> por confiança cega no `mergeable`. A estratégia é sempre squash com `--subject` = título da PR
> — não é configurável por `--merge`/`--rebase` nesta skill, pois o objetivo explícito é que a
> branch de destino tenha exatamente um commit por PR, nomeado com o título da PR. Se a resposta
> for `N`, o fluxo termina no PR pronto para revisão, sem mesclar.

### 11. Limpeza

```bash
git checkout "$TARGET_BRANCH"
git fetch origin "$TARGET_BRANCH"
git merge --ff-only "origin/$TARGET_BRANCH"
git submodule update --init --recursive
git branch -d "$FEATURE_NAME" 2>/dev/null || git branch -D "$FEATURE_NAME"
```

Este passo só roda quando o merge foi confirmado (Y) no passo 10. Apenas a feature branch é
removida (local + remota via `--delete-branch`, já disparado pelo `gh pr merge` do passo 10). A
branch de destino nunca é tocada além de `checkout`/`fetch`/`merge --ff-only`/atualização de
`status: merged` em `$PR_DOC`. O `--ff-only` garante que, se o destino local não puder avançar de
forma linear, o comando **falha em vez de criar um merge commit silencioso** — Agente avisa e
para nesse caso. Isso substitui o antigo `git pull origin "$TARGET_BRANCH"`, que violava a
proibição de `pull` desta skill (ver "🚫 Execução de comandos Bash").

---

## 🔒 Regras obrigatórias

- **`PR_NAME` é obrigatório**: sem ele, Agente para antes do primeiro comando e pergunta — não
  há heurística segura para nome de PR/branch/documentação/mensagem final de merge.
- **Nunca alterar o conteúdo dos arquivos de código** — a skill só detecta, agrupa/analisa,
  adiciona ao stage, commita, dá push e mescla. Os únicos arquivos que esta skill _escreve_ são
  `$PR_DOC` e, quando ausente, `$FEATURE_DOC`.
- **`$PR_DOC` sempre existe ao final do fluxo, com `extends:` apontando para
  `feature-<NN>-<slug-da-feature>`** — se a feature não existir, é criada como rascunho, com o
  próximo número sequencial disponível, antes de qualquer commit de conteúdo.
- **`$FEATURE_DOC` nunca é sobrescrito se já existir, e seu número `<NN>` nunca é trocado** — só
  é criado (com número novo) quando ausente; se já existir uma feature com o mesmo slug textual,
  o número já atribuído é reaproveitado.
- **O PR é sempre aberto ANTES dos commits de conteúdo**, como `draft`, e **depois** da criação
  de branch/submodule/Feature doc/PR doc; após obter o número, o título fica
  `PR (#<PR_NUMBER>) <PR_NAME>` (a menos que um PR já exista para a branch — ver passo 5.0).
- **Todo commit de conteúdo (pai e submodules) cita `Refs: #<PR_NUMBER>`**
- **Nunca commitar em massa sem revisar**: `git add .` é proibido em ambos os modos
- **Nunca commitar sem PR já existente**: se `PR_NUMBER` não estiver definido, Agente para
- **Submodules sempre antes do pai**, com push próprio antes da referência ser commitada no pai
- **Nunca mesclar com conflito**: checar `mergeable` antes de tentar
- **Nunca mesclar sem confirmação explícita (Y/N) do usuário**, mesmo sem conflito — o merge
  nunca é automático
- **Merge sempre por squash, com `--subject` igual ao título da PR** (`PR (#<PR_NUMBER>)
  <PR_NAME>`) — a branch de destino nunca recebe os commits individuais, apenas um commit final
  nomeado com o título da PR; o histórico detalhado fica preservado no PR do GitHub
- **Estatísticas do PR sempre recalculadas do `git log`/`git diff`** (passo 8), nunca só da
  memória de conversa
- **`status` em `$PR_DOC` sempre reflete o estado real** (`draft` → `open` → `merged`)
- **Stash é fallback, não padrão**: só é usado se o `checkout -b` direto da feature branch falhar
  por conflito real (passo 4)
- **Nunca executar `git pull`** em nenhum passo, incluindo a limpeza — sempre `fetch` +
  `merge --ff-only`
- **Parar e avisar**, nunca "seguir tentando", quando um pré-requisito falha

---

## 🧪 Exemplo — modo por-arquivo

`PR_NAME = "Retry Button Reutilizavel"`, sem `FEATURE_NAME` explícito →
`PR_SLUG = "retry-button-reutilizavel"`, `FEATURE_TEXT_SLUG = "retry-button-reutilizavel"` →
branch `feature/retry-button-reutilizavel` → `.backlog/features/` está vazio, então
`.backlog/features/feature-01-retry-button-reutilizavel.md` é criado (número `01`, primeira
feature do repo) → checkout direto a partir de `origin/develop` (sem precisar de stash) →
`.backlog/pull-request/retry-button-reutilizavel.md` criado com `extends:
feature-01-retry-button-reutilizavel` → PR draft `#57`, título "Retry Button Reutilizavel" →
changeset de 3 arquivos (ilustrando o modo por-arquivo):

```
feat(frontend-src-app-shared-retry): add retry-button.component.ts     (Refs: #57)
feat(backend-src-presentation-guards): add index.ts                    (Refs: #57)
docs(backlog): add feature-01-retry-button-reutilizavel.md             (Refs: #57)
```

Corpo final do PR segue exatamente o template do passo 9, com a lista de commits acima e suas
datas reais extraídas de `git log`. Ao confirmar o merge (Y), o passo 10 roda:

```bash
gh pr merge 57 --squash --delete-branch \
  --subject "PR (#57) Retry Button Reutilizavel" --body ""
```

Resultado em `develop`: um único commit, `PR (#57) Retry Button Reutilizavel`, no lugar dos 3
commits (+ o `chore: iniciar feature` vazio) que existiam na feature branch. Limpeza feita via
`git fetch origin develop && git merge --ff-only origin/develop`, nunca `git pull`.

## 🧪 Exemplo — modo agrupado (changeset grande, segunda feature do repo)

18 arquivos, sendo 8 em `src/domain/session/*`, 6 em `src/domain/auth/*`, 3 em `test/*` e 1
`README.md`. 18 > 8 → **modo agrupado**. `PR_NAME = "Sessao Unica Ativa Por Navegador"` →
`.backlog/features/` já tem `feature-01-retry-button-reutilizavel.md`, então o próximo número é
`02` → `.backlog/features/feature-02-sessao-unica-ativa-por-navegador.md` criado → branch
`feature/sessao-unica-ativa-por-navegador` → PR draft `#58` na `develop` → grupos analisados
(`domain-session`, `domain-auth`, `tests`, `docs`) → commits:

```
feat(domain-session): adicionar 8 arquivo(s)   (Refs: #58)
fix(domain-auth): atualizar 6 arquivo(s)       (Refs: #58)
test(tests): adicionar 3 arquivo(s)            (Refs: #58)
docs(root): atualizar 1 arquivo(s)             (Refs: #58)
```

Seguido de: push, recontagem determinística (passo 8), atualização do PR `#58` com estatísticas
no template do passo 9 (`MODO_TEXTO = "agrupados por contexto"`), `gh pr ready`, pergunta Y/N de
confirmação — se `Y`:

```bash
gh pr merge 58 --squash --delete-branch \
  --subject "PR (#58) Sessao Unica Ativa Por Navegador" --body ""
```

e `$PR_DOC` atualizado para `status: merged`; se `N`, o fluxo termina com o PR aberto e pronto,
sem mesclar.

---

## ⚠️ Limitações

- A escolha de tipo/escopo é heurística por padrões de texto; casos ambíguos podem exigir ajuste
  manual do Agente no momento
- O esqueleto de `$FEATURE_DOC`, quando criado automaticamente, é um rascunho — objetivo e
  critérios de aceite devem ser revisados por um humano, a skill não os inventa a partir do diff
- Depende de `gh` autenticado com permissão de escrita de PRs no repositório
- O merge é sempre executado por squash ao final, exceto com conflito — ver nota de design no
  passo 10; não há opção de `--merge`/`--rebase` nesta skill
- O commit vazio inicial (`chore: iniciar feature ...`) e todos os commits atômicos deixam de
  existir na branch de destino após o squash — permanecem visíveis apenas no PR fechado do
  GitHub, não em `git log` de `$TARGET_BRANCH`
- No modo agrupado, o limiar de 8 arquivos é um padrão ajustável, não uma regra rígida
- A numeração `<NN>` das features é sequencial e global ao diretório `.backlog/features/`; não
  há suporte a numeração por categoria/prefixo diferente de `feature-`
- O fallback de stash (passo 4) só é acionado em conflito real; se isso acontecer com frequência,
  pode indicar que o destino está avançando rápido demais em paralelo ao trabalho local

## 🔮 Evoluções futuras

- Detecção de breaking changes para sinalizar `BREAKING CHANGE:` no corpo do commit
- Integração com CI para só sugerir merge depois dos checks passarem
- Permitir uma PR com `extends:` apontando para **mais de uma** feature (many-to-one hoje só
  suporta feature → várias PRs, não o inverso)
- Permitir configurar a largura da numeração das features (hoje fixa em 2 dígitos) via
  `FEATURE_NUM_WIDTH`