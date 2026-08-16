---
name: auto-pr-commit
file: auto-pr-commit.sh
description: >
  Executar commits (por arquivo OU agrupados por contexto, conforme o tamanho do changeset),
  criar feature branch, ABRIR O PULL REQUEST ANTES de qualquer commit de conteúdo (para que cada
  commit já referencie "Refs: #PR"), atualizar o PR com estatísticas agregadas, e mesclar —
  sempre com destino `develop` (fallback `main`, com override manual via MAIN_BRANCH). Todo o
  fluxo é executado ao vivo por Claude via ferramenta de bash, comando a comando, analisando cada
  diff — nunca gerando um script para rodar depois. A lógica de commit por arquivo (tipo, escopo,
  formato de mensagem, submodules) é a mesma da skill `auto-commit` — esta skill acrescenta
  gestão de branch/PR e a opção de agrupar commits por contexto.
---

# 🧠 Skill: Commit Inteligente + Feature Branch + Pull Request

> Esta skill **invoca** a skill `auto-commit` no modo por-arquivo (passo 6): Claude lê o arquivo
> [auto-commit](../auto-commit/skill.md)` naquele momento do fluxo e executa o que está descrito nele, em vez de aplicar
> de memória uma versão resumida. Por isso as tabelas de tipo/escopo e o formato de mensagem não
> são duplicados aqui — mudar [auto-commit](../auto-commit/skill.md)` já muda o comportamento desta skill também. O que
> é exclusivo deste arquivo: abrir o PR antes dos commits, `Refs: #PR`, a escolha entre modo
> por-arquivo/agrupado, e o modo agrupado em si (que não existe em `auto-commit`).

---

## 🎯 Objetivo

- Criar commits **semânticos e rastreáveis**, escolhendo automaticamente a granularidade certa:
  - **modo por-arquivo**: um commit por arquivo — delega inteiramente para o fluxo da skill
    [auto-commit](../auto-commit/skill.md), só acrescentando `Refs: #PR` a cada commit;
  - **modo agrupado**: um commit por grupo funcional/técnico (`domain`, `app`, `infra`, `tests`…)
    — exclusivo desta skill, ideal para changesets grandes, reduzindo ruído no histórico e custo
    de análise/tokens.
- Isolar o trabalho numa **feature branch** (nome gerado automaticamente ou informado manualmente)
- **O Pull Request é aberto ANTES de qualquer commit de conteúdo**, como `draft`. Isso é
  intencional: só assim cada commit pode citar `Refs: #<numero-do-pr>` diretamente na própria
  mensagem, em vez de precisar de um commit de referência criado depois (que exigiria reescrever
  ou complementar o histórico)
- **Qualquer Pull Request já existente para a branch é revisado antes de prosseguir** — ver
  passo 5.0
- **Branch de destino resolvida por prioridade**: `MAIN_BRANCH` (se definida) → `develop` local →
  `develop` remota → `main`
- **Nunca gerar um script (`.sh`) para executar depois.** Cada comando é executado dinamicamente
  via ferramenta de bash, um de cada vez, analisando a saída antes do próximo passo. Isso evita
  heurísticas "cegas" — cada decisão (tipo, escopo, mensagem, agrupamento) é tomada olhando o
  diff real, na hora.
- **Nunca usar o comando `sleep`**

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
- é proibido executar git pull origin develop
- A ferramenta de Bash deve receber **exclusivamente comandos Bash válidos**.
- Nunca enviar XML, HTML ou qualquer outro formato de marcação (além de markdown na comunicação
  com o usuário) para a ferramenta de Bash.
- Nunca envolver comandos em blocos de parâmetro/tag como se fossem parte do próprio comando.

---

## 🔀 Escolha do modo de commit

Antes de tocar em qualquer arquivo, Claude decide o modo com uma regra simples e transparente:

| Condição | Modo escolhido |
|---|---|
| Usuário pediu explicitamente "um commit por arquivo" | **por-arquivo** |
| Usuário pediu explicitamente "agrupar" / "commits agrupados" | **agrupado** |
| Nº de arquivos alterados ≤ 8 | **por-arquivo** (o detalhamento vale o custo) |
| Nº de arquivos alterados > 8 | **agrupado** (reduz ruído e tokens) |

Claude informa ao usuário, em uma linha, qual modo foi escolhido e por quê, antes de prosseguir.

---

## ⚙️ Pré-requisitos

Antes de qualquer commit, Claude verifica ao vivo (um comando por vez, parando se algo falhar):

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

Se qualquer um falhar, Claude **para e explica** o que precisa ser corrigido — nunca segue em
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

Se não houver nada modificado, Claude informa e encerra — não cria branch nem PR à toa.

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

Essa é a única fonte de verdade da branch alvo — usada em todo o resto do fluxo (checkout, pull,
PR `--base`, merge).

### 3. Definir nome da feature branch

- Se o usuário informar um nome explicitamente, Claude usa esse nome (normalizado: minúsculo,
  sem acento, `a-z0-9/-`).
- Caso contrário, Claude olha os arquivos alterados e o diff agregado — **enquanto o working
  tree ainda está sujo, sem nenhum commit ainda** — para montar um nome como
  `feature/adicionar-autenticacao`:
  - **Ação dominante**: mais adições → `adicionar`; mais remoções → `remover`; mais modificações
    → `atualizar`
  - **Módulo pelo conteúdo do diff**: `auth|login|token|jwt|session` → `autenticacao`; e por aí
    vai por palavra-chave (heurística não exaustiva — Claude usa bom senso quando nada bate)
  - Sem acentos, minúsculo, só `a-z0-9-`, máx. ~50 caracteres

### 4. Sincronizar destino e criar a feature branch (ainda sem commits de conteúdo)

```bash
git diff --quiet && git diff --cached --quiet || git stash push -u
git checkout "$TARGET_BRANCH"
git submodule update --init --recursive
git checkout -b "$FEATURE_NAME"
git stash pop 2>/dev/null || true
```

### 5.0 Revisar PR já existente para esta branch (antes de decidir criar um novo)

```bash
gh pr list --head "$FEATURE_NAME" --state open --json number,baseRefName,mergeable --jq '.[0]'
```

Se existir um PR aberto para `$FEATURE_NAME`, Claude **não cria um novo** — reaproveita o número,
mas antes verifica:
- **`baseRefName` bate com `$TARGET_BRANCH`?** Se não bater, avisa o usuário e para — mesclar
  numa base diferente da resolvida no passo 2 pode não ser o que se espera.
- **`mergeable` já é `CONFLICTING`?** Se sim, avisa antes de continuar — não faz sentido empilhar
  commits novos num PR que já está conflitante com o destino.
- Se ambos os pontos estiverem ok, segue para o passo 6 usando esse `PR_NUMBER`.

Se não existir PR aberto para a branch, segue para 5.1 (criação).

### 5.1 ⭐ Abrir o Pull Request (draft) — ANTES de qualquer commit de conteúdo

```bash
git commit --allow-empty -m "chore: iniciar feature ${FEATURE_NAME}" \
  -m "Commit inicial vazio para permitir abertura do PR antes dos commits de conteúdo."
git push -u origin "$FEATURE_NAME"

gh pr create --draft \
  --base "$TARGET_BRANCH" --head "$FEATURE_NAME" \
  --title "<título provisório a partir do nome da branch>" \
  --body "_PR aberto antes dos commits de conteúdo; corpo será atualizado com estatísticas._"

PR_NUMBER=$(gh pr view "$FEATURE_NAME" --json number --jq .number)
```

A partir daqui, `PR_NUMBER` é conhecido e usado em todos os commits seguintes. Draft é usado
propositalmente: o PR existe e é rastreável, mas não sinaliza "pronto para revisão" enquanto só
tem o commit vazio.

Labels/reviewers, se solicitados, são aplicados aqui, um por vez, avisando se algum falhar:

```bash
gh pr edit "$PR_NUMBER" --add-label "<label>"
gh pr edit "$PR_NUMBER" --add-reviewer "<usuario>"
```

> Se `PR_NUMBER` não estiver definido em nenhum momento a partir daqui, Claude **para e não
> commita nada** — commitar sem o PR já existir quebra a premissa do fluxo.

### 6. Processar submodules e arquivos do repositório pai

- **Modo por-arquivo**: Claude **invoca a skill `auto-commit`** neste ponto — não "aplica de
  cabeça" as mesmas regras, mas efetivamente lê [auto-commit](../auto-commit/skill.md)` e executa o fluxo dela passo a
  passo (pré-requisitos já foram checados no passo 0 desta skill, não precisa repetir):

  1. Ler/reler [auto-commit](../auto-commit/skill.md)` (via `view` ou equivalente) antes de começar a commitar, mesmo
     que já tenha sido lida antes na sessão — garante que a versão executada é a atual do
     arquivo, não uma lembrança da conversa.
  2. Executar o "Fluxo da Skill" de [auto-commit](../auto-commit/skill.md)` (submodules primeiro, depois arquivo por
     arquivo do repositório pai) exatamente como descrito lá — mesmas tabelas de tipo/escopo,
     mesmo formato de commit.
  3. Único acréscimo desta chamada: o `PR_NUMBER` resolvido no passo 5 desta skill é passado como
     contexto, então cada commit gerado por `auto-commit` inclui `Refs: #${PR_NUMBER}` (a própria
     seção "Uso dentro de outro fluxo" de [auto-commit](../auto-commit/skill.md)` cobre esse comportamento).
  4. Quando `auto-commit` sinalizar que terminou os commits, Claude retoma o fluxo desta skill no
     passo 7 (push) — `auto-commit` não dá push nem mexe em PR quando chamada com `PR_NUMBER` no
     contexto, isso fica por conta de quem chamou.

  Isso é uma chamada real, não um resumo: se [auto-commit](../auto-commit/skill.md)` mudar (nova regra de tipo, novo
  escopo), o comportamento aqui muda junto, automaticamente, porque o passo 1 relê o arquivo.

- **Modo agrupado**: exclusivo desta skill, não passa por `auto-commit` — ver seção 6B abaixo.
  Submodules continuam sempre primeiro, também usando o agrupamento quando fizer sentido dentro
  do submodule.

#### 6B. Modo agrupado (exclusivo desta skill)

1. **Agrupar**: cada arquivo de `git status --porcelain=v1 -uall` é associado a um escopo, usando
   a mesma tabela de escopo de [auto-commit](../auto-commit/skill.md)` (incluindo o refinamento de dois níveis, ex.:
   `domain-auth` vs. `domain-payment`).
2. **Analisar uma vez por grupo** (não por arquivo):

```bash
git diff -- <arquivos do grupo>
```

3. Determinar o tipo do grupo pela mesma tabela de tipos de [auto-commit](../auto-commit/skill.md)`, por predominância
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
> `domain-payment` caíram os dois em `domain` por não terem sido pré-refinados), Claude divide o
> commit em vez de forçar tudo junto — coerência da mudança tem prioridade sobre reduzir a
> contagem de commits.

### 7. Push da feature branch com os commits reais

```bash
git push origin "$FEATURE_NAME"
```

### 8. Recalcular estatísticas de forma determinística

Antes de escrever o corpo do PR, Claude roda estes comandos e usa a **saída deles**, não a soma
mental acumulada ao longo da conversa — isso evita erro de contagem em changesets grandes com
muitas chamadas de bash:

```bash
git rev-list --count "$TARGET_BRANCH".."$FEATURE_NAME"
git diff --name-only "$TARGET_BRANCH".."$FEATURE_NAME" | wc -l
git diff --shortstat "$TARGET_BRANCH".."$FEATURE_NAME"
git log "$TARGET_BRANCH".."$FEATURE_NAME" --no-merges --pretty=format:'%s' \
  | grep -v '^chore: iniciar feature'
```

A última saída (lista de subjects `type(scope): ...`) é a fonte para as tabelas de "commits por
tipo" e "commits por escopo" do passo 9 — contar direto dessa lista, não do que foi "lembrado"
durante os commits.

### 9. Atualizar o PR com título e estatísticas reais, e tirá-lo do draft

```bash
gh pr edit "$PR_NUMBER" --title "<título dinâmico>" --body "<corpo com estatísticas>"
gh pr ready "$PR_NUMBER"
```

- **Título dinâmico**: prefixado pelo tipo dominante entre os commits/grupos da feature (ex.:
  `feat: Adicionar Autenticacao`)
- **Corpo do PR inclui**: modo usado (por-arquivo ou agrupado) e por quê; estatísticas agregadas
  (passo 8); tabela de commits por tipo; tabela de commits por escopo; lista de commits em blocos
  `<details>` expansíveis (excluindo o commit vazio inicial); checklist de revisão.

### 10. Verificar conflitos e mesclar

```bash
gh pr view "$PR_NUMBER" --json mergeable --jq .mergeable
```

- Se `CONFLICTING` → Claude **avisa e não tenta mesclar**.
- Caso contrário → Claude **sempre executa** `gh pr merge "$PR_NUMBER" --merge --delete-branch`
  (estratégia configurável via `--merge` / `--squash` / `--rebase`, padrão `--merge`).

> **Decisão de design, não descuido**: esta skill mescla automaticamente sem pedir confirmação
> adicional quando não há conflito — o PR aqui serve como rastreabilidade e changelog, não como
> gate de revisão humana. Se o seu processo exige revisão antes do merge, não use este passo
> automaticamente — pare no passo 9 (`gh pr ready`) e mescle manualmente.

### 11. Limpeza

```bash
git checkout "$TARGET_BRANCH"
git pull origin "$TARGET_BRANCH"
git submodule update --init --recursive
git branch -d "$FEATURE_NAME" 2>/dev/null || git branch -D "$FEATURE_NAME"
```

Apenas a feature branch é removida (local + remota via `--delete-branch`). A branch de destino
nunca é tocada além de `checkout`/`pull`.

---

## 🔒 Regras obrigatórias

- **Nunca alterar o conteúdo dos arquivos** — a skill só detecta, agrupa/analisa, adiciona ao
  stage, commita, dá push e mescla.
- **O PR é sempre aberto ANTES dos commits de conteúdo**, como `draft` (a menos que um PR já
  exista para a branch — ver passo 5.0)
- **Todo commit de conteúdo (pai e submodules) cita `Refs: #<PR_NUMBER>`**
- **Nunca commitar em massa sem revisar**: `git add .` é proibido em ambos os modos
- **Nunca commitar sem PR já existente**: se `PR_NUMBER` não estiver definido, Claude para
- **Submodules sempre antes do pai**, com push próprio antes da referência ser commitada no pai
- **Nunca mesclar com conflito**: checar `mergeable` antes de tentar
- **Estatísticas do PR sempre recalculadas do `git log`/`git diff`** (passo 8), nunca só da
  memória de conversa
- **Parar e avisar**, nunca "seguir tentando", quando um pré-requisito falha

---

## 🧪 Exemplo — modo agrupado (changeset grande)

18 arquivos, sendo 8 em `src/domain/auth/*`, 6 em `src/domain/payment/*`, 3 em `test/*` e 1
`README.md`. 18 > 8 → **modo agrupado** → branch `feature/atualizar-autenticacao-pagamentos` →
commit vazio + push → PR draft `#57` na `develop` → grupos analisados
(`domain-auth`, `domain-payment`, `tests`, `docs`) → commits:

```
feat(domain-auth): adicionar 8 arquivo(s)      (Refs: #57)
fix(domain-payment): atualizar 6 arquivo(s)    (Refs: #57)
test(tests): adicionar 3 arquivo(s)            (Refs: #57)
docs(root): atualizar 1 arquivo(s)             (Refs: #57)
```

Seguido de: push, recontagem determinística (passo 8), atualização do PR `#57` com estatísticas,
`gh pr ready`, merge em `develop`.

## 🧪 Exemplo — modo por-arquivo (changeset pequeno)

`src/app/service.ts` (M), `src/app/new-feature.ts` (A), `README.md` (M) — 3 ≤ 8 →
**modo por-arquivo**, delegado à skill `auto-commit` com `Refs: #42` acrescentado:

```
feat(app): add new-feature.ts        (Refs: #42)
fix(app): update service.ts          (Refs: #42)
docs(root): update README.md         (Refs: #42)
```

---

## ⚠️ Limitações

- A escolha de tipo/escopo é heurística por padrões de texto; casos ambíguos podem exigir ajuste
  manual do Claude no momento
- Depende de `gh` autenticado com permissão de escrita de PRs no repositório
- O merge é sempre executado ao final, exceto com conflito — ver nota de design no passo 10
- O commit vazio inicial fica no histórico da feature branch (excluído do resumo do PR, mas
  visível em `git log`)
- No modo agrupado, o limiar de 8 arquivos é um padrão ajustável, não uma regra rígida

## 🔮 Evoluções futuras

- Squash inteligente de commits relacionados antes do PR
- Detecção de breaking changes para sinalizar `BREAKING CHANGE:` no corpo do commit
- Integração com CI para só sugerir merge depois dos checks passarem