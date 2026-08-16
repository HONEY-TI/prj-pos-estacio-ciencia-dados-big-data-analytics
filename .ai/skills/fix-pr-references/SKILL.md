---
name: fix-pr-references
file: fix-pr-references.sh
description: Corrigir retroativamente commits já existentes (locais e/ou remotos, incluindo submodules) que não referenciam o Pull Request ao qual pertencem. Usa `git notes` — nunca reescreve hashes de commit, nunca faz force-push, nunca altera histórico existente. Submodules são sempre processados antes do repositório pai. Trigger quando o usuário pedir para "linkar commits antigos ao PR", "corrigir referência de PR nos commits", "adicionar #PR nos commits que já existem" ou similar.
---

# 🔗 Skill: Corrigir Referência de PR em Commits Existentes

---

## 🎯 Objetivo

Ligar commits **já feitos e já mesclados/pushados** ao número do Pull Request correspondente — **sem**:

- reescrever hashes de commit (`rebase`, `filter-branch`, `commit --amend` em commit já pushado)
- fazer `push --force` em qualquer branch
- perder ou reordenar histórico existente

A técnica usada é **`git notes`**: um objeto Git separado, anexado a um commit existente por referência (não altera o hash do commit), versionável e sincronizável via `refs/notes/*`. É o mecanismo correto para "anotar" histórico sem reescrevê-lo.

> ⚠️ Isso é diferente da skill `auto-pr-commit`, que resolve o problema **na hora de criar** o PR (via commit vazio de referência, para commits que ainda vão ser pushados). Esta skill é para o **passivo já existente**: commits antigos, de PRs já abertos/mesclados, sem nenhuma referência cruzada.

Todo o fluxo é executado **ao vivo** por Claude via ferramenta de bash, comando a comando — cada decisão (qual commit pertence a qual PR) depende de inspecionar o estado real do repositório e da API do GitHub. Um script de apoio (`fix-pr-references.sh`) existe como **referência da lógica e para uso manual opcional pelo usuário** (ex.: rodar via cron/CI para manter as notas em dia), mas Claude não depende dele para executar a skill ao vivo — continua rodando comando a comando, mostrando a prévia e pedindo autorização antes de escrever.

> 📌 **Submodules sempre primeiro.** Assim como na skill `auto-pr-commit`, qualquer submodule com PRs próprios (repositório Git independente, com seu próprio `origin` e seus próprios PRs no GitHub) é processado **antes** do repositório pai — prévia, autorização e escrita completas no submodule primeiro, depois no pai. Isso evita referenciar um SHA de submodule que ainda pode mudar, e mantém a ordem lógica: "primeiro a peça menor, depois quem a contém".

---

## ⚙️ Pré-requisitos

Claude verifica ao vivo, na ordem, parando se algo falhar:

```bash
command -v git
command -v gh
gh auth status
git rev-parse --is-inside-work-tree
git remote get-url origin
gh repo view
```

Também confirma que não há operação Git pendente (`rebase-merge`, `MERGE_HEAD`, etc. dentro de `.git`) antes de tocar em qualquer coisa.

**Regra dura: confirmação nunca é pedida "no escuro".** Claude sempre executa primeiro os passos 1–3 (somente leitura — nenhuma nota é escrita, nenhum push acontece) para levantar números reais, e só then pede autorização mostrando esses números. Pedir "posso prosseguir?" sem ter rodado a prévia é uma falha da skill, não uma opção válida.

---

## 🚀 Fluxo da Skill

### 0. Detectar submodules e definir ordem de processamento

```bash
git submodule status --recursive
```

Para cada submodule listado, Claude verifica se ele tem `origin` próprio e é gerenciado via GitHub (`git -C <submodule> remote get-url origin` + `gh repo view` dentro dele). Se sim, ele entra na fila de repositórios a processar **antes** do repositório pai.

A skill roda o fluxo completo (Fase A + Fase B, com sua própria prévia e autorização) **uma vez por repositório**, nesta ordem:

```
1º) cada submodule (na ordem em que aparece em .gitmodules)
2º) o repositório pai, por último
```

Isso é importante porque o repositório pai referencia commits do submodule por SHA fixo (o "ponteiro" do submodule) — processar o submodule primeiro garante que, se o usuário quiser, o ponteiro do pai já reflita um estado com notas aplicadas, sem qualquer necessidade de recriar commits em nenhum dos dois lados.

> Cada repositório (submodule ou pai) tem sua **própria** ref `refs/notes/pr-refs` e seu **próprio** remoto — nada é compartilhado ou misturado entre eles.

### Fase A — Prévia (somente leitura, sem autorização ainda)

### 1. Buscar notas já existentes (evitar sobrescrever trabalho de outra pessoa)

```bash
git fetch origin 'refs/notes/*:refs/notes/*'
git notes --ref=pr-refs list
```

Se a ref remota já existir, Claude sincroniza antes de adicionar qualquer coisa nova — nunca sobrescreve notas de terceiros.

### 2. Levantar todos os PRs (abertos, mesclados e fechados) do repositório

```bash
gh pr list --state all --limit 1000 \
  --json number,title,mergeCommit,commits,baseRefName,headRefName,state
```

Para cada PR, o campo `commits` já traz a lista de OIDs de commit pertencentes àquele PR (via API do GitHub), incluindo os que foram *squashed* (nesse caso, o PR pode ter só o commit final — Claude trata isso separadamente, ver passo 5).

### 3. Para cada PR, para cada commit, verificar se já tem nota (só contagem, nada é escrito ainda)

```bash
git notes --ref=pr-refs show <sha> 2>/dev/null
```

Nesta fase, Claude apenas **classifica e conta** cada commit, sem tocar em nada:
- já tem nota referenciando esse PR → conta como "já anotado" (será pulado)
- já tem nota de **outro** PR → conta como "vai receber append" (nota será acrescentada, não sobrescrita)
- sem nota → conta como "a anotar"
- pertence a um PR squashed cuja branch já foi deletada e cujo SHA não é mais alcançável → conta como "squash sem rastro" (ver passo 6)

### 3.5. Apresentar a prévia e pedir autorização

Antes de escrever qualquer nota ou fazer qualquer push, Claude mostra um resumo numérico e só then pergunta se pode prosseguir:

```
📊 Prévia — repositório: <nome-do-submodule-ou-pai> (nada foi escrito ainda)

PRs encontrados:                 42
Commits a anotar:                175
Commits já anotados (pulados):   12
Commits com nota de outro PR
  (vai receber append):          3
PRs squashed sem commits
  rastreáveis (só o commit de
  squash será anotado):          3

⏱️  Estimativa: pode levar alguns minutos dependendo do tamanho do histórico
  e do rate limit da API do GitHub.
```

Junto com a prévia, Claude reafirma o escopo e as ressalvas, e pergunta explicitamente pela autorização — incluindo uma opção de rodar em um subconjunto primeiro:

```
Conforme a skill, o que vou fazer:
1. Buscar notas remotas existentes (refs/notes/*) antes de escrever
2. Anotar cada commit com `git notes --ref=pr-refs`, referenciando seu PR
3. Publicar apenas a ref `refs/notes/pr-refs` no remoto

O que NÃO vai acontecer:
❌ Nenhum hash de commit é reescrito
❌ Nenhum push --force
❌ refs/notes/commits não é tocada
❌ Nenhuma branch de código é alterada

Observações importantes:
- As notas não aparecem no GitHub nem no `git log` padrão — só visíveis via
  `git log --notes=pr-refs` ou `git notes --ref=pr-refs show <sha>`
- Se houver notas conflitantes de outra pessoa no remoto, eu paro e te mostro
  o conflito antes de decidir qualquer coisa — nunca resolvo sozinho
- Isso é reversível: dá para apagar a ref (`git push origin :refs/notes/pr-refs`)
  a qualquer momento sem afetar nenhum outro histórico

Autoriza seguir com todos os 42 PRs deste repositório, ou prefere testar
primeiro com um subconjunto (ex.: só os últimos N PRs mesclados, ou uma
branch específica)?
```

Claude só avança para a Fase B (deste repositório) depois de uma resposta afirmativa explícita. Se o usuário pedir um subconjunto, Claude filtra a lista de PRs da Fase A por esse critério e recalcula a prévia antes de agir. **Depois que um submodule termina sua Fase B (incluindo o push da ref), Claude avisa que vai passar ao próximo repositório da fila (outro submodule ou o pai) e repete a Fase A+3.5 para ele** — a autorização de um repositório não vale para os demais.

---

### Fase B — Escrita (somente após autorização explícita)

### 4. Adicionar a nota

```bash
git notes --ref=pr-refs add -m "Refs: #${PR_NUMBER} (${PR_TITLE})
Base: ${BASE_BRANCH} <- Head: ${HEAD_BRANCH}
Status: ${PR_STATE}" "$SHA"
```

Isso **não altera o SHA do commit** — a nota é um objeto Git separado, apenas associado por referência. `git log` mostra a nota automaticamente quando `git config notes.displayRef` inclui `refs/notes/pr-refs`, sem precisar reescrever nada.

### 5. Tratar PRs com squash/rebase (o commit individual "sumiu")

Quando o PR foi mesclado com `--squash`, os commits atômicos originais podem não existir mais na branch de destino (viraram um único commit de squash). Nesse caso:

- Claude tenta localizar os commits atômicos originais **na feature branch ainda existente localmente ou remotamente** (`git log origin/<head-branch>`, se a branch não foi deletada)
- Se a feature branch já foi deletada e os commits não existem em nenhum lugar alcançável (`git rev-parse --verify`), Claude **não inventa** hash nem tenta recriar — apenas anota o **commit de squash resultante** (presente na branch de destino) com a referência ao PR, e informa isso claramente ao usuário
- Nunca usa `git reflog` de outra máquina/clone que Claude não tem acesso — só o que está alcançável no repositório atual

### 6. Publicar as notas no remoto

```bash
git push origin refs/notes/pr-refs
```

Isso é **aditivo**: cria ou atualiza a ref `refs/notes/pr-refs` no remoto. Não é um `--force`, não sobrescreve `main`/`develop`/nenhuma branch de código. Se o push for rejeitado por não-fast-forward (outra pessoa também anotou), Claude faz:

```bash
git fetch origin refs/notes/pr-refs:refs/notes/pr-refs-remote
git notes --ref=pr-refs merge -s cat_sort_uniq refs/notes/pr-refs-remote
git push origin refs/notes/pr-refs
```

(estratégia `cat_sort_uniq` combina notas duplicadas sem perder nenhuma)

### 7. Tornar as notas visíveis por padrão (opcional, com consentimento)

Por padrão, `git log` não mostra notas de refs customizadas. Se o usuário quiser ver `Refs: #123` automaticamente no `git log` de todo mundo no time, Claude pode sugerir (não aplica sozinho, pois é uma mudança de configuração do repositório):

```bash
git config notes.displayRef refs/notes/pr-refs
```

Isso é local por padrão — para valer para o time todo, precisa ser documentado no README ou aplicado via `.gitconfig` compartilhado. Claude explica essa distinção em vez de assumir.

### 8. Relatório final (por repositório, e consolidado ao terminar tudo)

Claude apresenta um resumo ao final de **cada** repositório (submodule ou pai), nunca silencioso:

```
📊 Relatório de referências adicionadas — repositório: <nome>

PRs processados:      42
Commits anotados:     187
Commits já com nota:  12 (pulados)
PRs com squash sem
  commits rastreáveis: 3 (apenas commit de squash anotado)
Ref publicada:        refs/notes/pr-refs → origin ✅
```

E, ao final de todos os repositórios da fila (submodules + pai), um resumo consolidado:

```
🎉 FLUXO CONCLUÍDO — todos os repositórios processados

1) submodule-a       → 18 commits anotados, ref publicada ✅
2) submodule-b       → 42 commits anotados, ref publicada ✅
3) repositório pai   → 187 commits anotados, ref publicada ✅

Nenhum hash de commit foi alterado em nenhum dos repositórios.
Nenhum push --force foi executado.
```

---

## 🔒 Boas práticas / limites rígidos

- **Nunca** usar `git commit --amend`, `git rebase`, `git filter-branch`/`git filter-repo`, ou qualquer comando que altere um SHA de commit já existente
- **Nunca** usar `--force` ou `--force-with-lease` em nenhum push
- **Nunca** deletar ou sobrescrever `refs/notes/commits` (ref genérica que outras ferramentas podem usar) — sempre usar a ref dedicada `refs/notes/pr-refs`
- **Sempre** buscar (`fetch`) notas remotas existentes antes de escrever, para não perder anotações de outra pessoa
- Se o merge de notas (`git notes merge`) gerar conflito que a estratégia automática não resolve, Claude **para e mostra o conflito ao usuário** — nunca resolve arbitrariamente
- Idempotente: rodar a skill de novo não duplica referências já existentes
- **Nunca pedir autorização sem antes ter rodado a prévia com números reais** (Fase A completa) — "vou fazer X, posso prosseguir?" sem contagem é uma pergunta incompleta e não deve ser feita
- Se o usuário pedir um subconjunto (ex.: só últimos N PRs, ou uma branch), Claude refiltra e mostra uma nova prévia antes de escrever — não assume o subconjunto sem confirmar os novos números
- **Submodules são sempre processados antes do repositório pai**, cada um com sua própria prévia, autorização e ref de notes — nunca em lote sem distinção, mesmo que o usuário peça "faz tudo de uma vez" (Claude processa em sequência e reporta cada etapa)

---

## ⚠️ Limitações

- Depende da API do GitHub (`gh pr list --json commits`) retornar corretamente os commits de cada PR — em repositórios muito grandes (>1000 PRs) pode ser necessário paginar manualmente
- Notas não aparecem por padrão em `git log` nem na maioria das UIs de terceiros (GitHub web não renderiza `git notes` na timeline do commit) — é uma solução para quem consulta via CLI/tooling interno, não substitui a referência nativa do GitHub (que só existe quando o PR já linka os commits pela branch, o que o GitHub já faz sozinho na maioria dos casos)
- Para commits de PRs squashed cuja feature branch já foi deletada e cujo SHA não é mais alcançável em lugar nenhum do repositório, não há como recuperar a referência individual — apenas o commit de squash final pode ser anotado

## 🔥 Evoluções futuras

- Gerar também um `CHANGELOG.md` a partir das notas agregadas por PR
- Expor um `git alias` (`git pr-log`) que já roda com `--notes=pr-refs` por padrão
- Verificação periódica (ex. via CI) que falha se um novo commit em `main`/`develop` não tiver nota associada a um PR

---

## ✅ Conclusão

Essa skill fecha a lacuna de rastreabilidade em repositórios com histórico já existente, sem o custo/risco de reescrever commits: usa `git notes` como mecanismo aditivo, respeita o trabalho de outras pessoas (fetch + merge antes de push), nunca faz `--force`, e deixa claro para o usuário exatamente qual ref está sendo criada/publicada antes de agir.