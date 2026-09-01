#!/usr/bin/env bash
# Bootstrap .ai/ (master) + symlinks por agente + validacao — Linux.
# Idempotente. Nunca sai da raiz do projeto.
#
#   1. Os arquivos do master .ai/ nascem com conteudo real (nao vazios).
#   2. Cria os symlinks de .blackbox/, .codex/, .github/copilot/, .claude/.
#   3. Ao final, VALIDA todo link: se o alvo nao existir, cria o arquivo real
#      antes, e so entao confirma que o link resolve. Imprime um relatorio.
#
# Reutilizavel: para adicionar um agente novo, edite APENAS o array
# AGENT_LINKS abaixo. A criacao e a validacao usam a mesma tabela,
# entao nao tem como esquecer de "registrar" o link em dois lugares.

set -uo pipefail

WARNINGS=0

# ---------------------------------------------------------------------------
# Descobre a raiz do projeto — funciona mesmo se .ai/ ainda nao existir
# (roda de dentro de .ai/ OU da raiz do projeto, indiferente do estado atual)
# ---------------------------------------------------------------------------

if [[ "$(basename "$PWD")" == ".ai" ]]; then
  ROOT="$(dirname "$PWD")"
else
  ROOT="$PWD"
fi

# Resolve o caminho físico real uma única vez
ROOT="$(cd "$ROOT" && pwd -P)"

# CRÍTICO: todo o resto do script usa caminhos relativos (".ai/system.md",
# ".blackbox/skills" etc). Sem isso, se você rodar de dentro de .ai/, esses
# caminhos relativos são resolvidos a partir do PWD atual (.ai/) em vez da
# raiz do projeto, e você acaba com uma pasta .ai/.ai/ aninhada. Forçando o
# cd aqui, o resto do script funciona igual não importa de onde foi chamado.
cd "$ROOT" || { echo "❌ Não consegui entrar em $ROOT" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Seguranca
# ---------------------------------------------------------------------------

assert_safe_path() {
  local target="$1"
  local resolved

  resolved="$(realpath -m -- "$target")"

  case "$resolved" in
    "$ROOT"|"$ROOT"/*)
      return 0
      ;;
    *)
      echo "❌ Acesso proibido fora da raiz do projeto:"
      echo "   ROOT    : $ROOT"
      echo "   TARGET  : $target"
      echo "   RESOLVE : $resolved"
      exit 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Helpers de criacao idempotente
# ---------------------------------------------------------------------------

ensure_dir() {
  local dir="$1"

  assert_safe_path "$dir"

  mkdir -p "$dir"

  if getent group users >/dev/null 2>&1; then
    chgrp users "$dir" 2>/dev/null || true
  fi

  chmod 2775 "$dir" 2>/dev/null || true
}


ensure_file() {
  local file="$1"
  local content="$2"

  assert_safe_path "$file"

  ensure_dir "$(dirname "$file")"

  if [[ -L "$file" ]]; then
    rm -f "$file"
  fi

  if [[ ! -f "$file" ]]; then
    printf '%s\n' "$content" > "$file"
    echo "+ criado: $file"
  else
    echo "= já existe: $file"
  fi

  if getent group users >/dev/null 2>&1; then
    chgrp users "$file" 2>/dev/null || true
  fi

  chmod 664 "$file" 2>/dev/null || true
}


link_path() {
  local link="$ROOT/$1"
  local target="$ROOT/$2"

  assert_safe_path "$link"
  assert_safe_path "$target"

  ensure_dir "$(dirname "$link")"

  # remove link quebrado ou incorreto
  if [[ -L "$link" ]]; then
    local current
    current="$(readlink -f "$link" 2>/dev/null || true)"

    if [[ "$current" != "$(realpath -m "$target")" ]]; then
      echo "⚠ removendo symlink incorreto: $link"
      rm -f "$link"
    else
      echo "= link ok: $1 -> $2"
      return
    fi
  fi

  # remove arquivo/pasta real que impede criação
  if [[ -e "$link" ]]; then
    echo "⚠ removendo arquivo conflitante: $link"
    rm -rf "$link"
  fi

  local relative_target

  relative_target="$(realpath --relative-to="$(dirname "$link")" "$target")"

  ln -s -- "$relative_target" "$link"
  echo "+ link criado: $1 -> $relative_target"

  if getent group users >/dev/null 2>&1; then
    chgrp -h users "$link" 2>/dev/null || true
  fi
}

# ensure_file <caminho> <conteudo>  -- so escreve se o arquivo nao existir
ensure_file() {
  local file="$1" content="$2"
  assert_safe_path "$file"
  ensure_dir "$(dirname "$file")"

  if [[ -e "$file" && ! -L "$file" ]]; then
    echo "= já existe: $file"
  else
    printf '%s\n' "$content" > "$file"
    echo "+ criado: $file"
  fi
}

# link_path <link relativo> <alvo relativo>
# cria o symlink com ln -s se nao existir; se ja existir e apontar certo, ok;
# se apontar errado ou for arquivo real, avisa e nao mexe.
link_path() {
  local link="$ROOT/$1" target="$ROOT/$2"
  assert_safe_path "$link"
  assert_safe_path "$target"
  ensure_dir "$(dirname "$link")"

  if [[ -L "$link" ]]; then
    local current wanted
    current="$(readlink -f -- "$link" 2>/dev/null || true)"
    wanted="$(realpath -m -- "$target")"
    if [[ "$current" == "$wanted" ]]; then
      echo "= link ok: $1 -> $2"
    else
      echo "⚠ symlink existente aponta pra outro lugar, mantendo: $1"
      WARNINGS=$((WARNINGS+1))
    fi
    return
  fi

  if [[ -e "$link" ]]; then
    echo "⚠ arquivo/pasta real já existe, não sobrescrevendo: $1"
    WARNINGS=$((WARNINGS+1))
    return
  fi

  ln -s "$target" "$link"
  echo "+ link criado: $1 -> $2"
}

echo "== 1/3 — Criando estrutura master .ai/ (com conteúdo real) em: $ROOT =="

ensure_file ".ai/system.md" "# System

Instrução/persona canônica compartilhada por todos os agentes.
Edite este arquivo — as mudanças refletem em .blackbox, .codex,
.github/copilot e .claude automaticamente (são symlinks)."

ensure_file ".ai/memory.json" '{
  "version": 1,
  "cache": {
    "enabled": true,
    "ttl": 86400,
    "maxEntries": 200
  },
  "sessions": {
    "persist": true,
    "maxHistoryTokens": 8000,
    "summarizeAfterTokens": 4000
  },
  "performance": {
    "lazyRestore": true,
    "preload": false
  }
}'

ensure_file ".ai/config/blackbox.json" '{
  "name": "blackbox",
  "version": "1.0.0",
  "description": "Config nativa do Blackbox — referencia o master .ai/",
  "autoload": true,
  "lazyLoad": true,
  "cache": true,
  "parallelLoad": true,
  "maxConcurrent": 8,
  "watch": false,
  "debug": false,
  "skills": []
}'

ensure_file ".ai/config/codex.json" '{
  "name": "codex",
  "version": "1.0.0",
  "description": "Config nativa do Codex — referencia o master .ai/",
  "runs": true,
  "logs": true,
  "skills": []
}'

ensure_file ".ai/config/copilot.md" "# Copilot Instructions

Instruções leves para o GitHub Copilot. Sem memória persistente,
sem execução de tasks — foco em guideline direto e exemplos."

ensure_file ".ai/config/cluade.yaml" 'name: cluade
version: "1.0.0"
description: "Config nativa do OpenClaude — referencia o master .ai/"
agents_dir: agents
prompts_dir: prompts
skills_dir: skills'

ensure_file ".ai/context/domain.md" "# Domínio

Descreva aqui o domínio do projeto (o que ele faz, pra quem)."
ensure_file ".ai/context/architecture.md" "# Arquitetura

Descreva aqui a arquitetura técnica do projeto."
ensure_file ".ai/context/rules.md" "# Regras

Regras e convenções gerais que todos os agentes devem seguir."
ensure_file ".ai/context/project.md" "# Projeto

Contexto geral do projeto (stack, objetivos, restrições)."

ensure_file ".ai/prompts/system.md" "# Prompt de sistema

Prompt de sistema canônico usado pelos agentes."
ensure_file ".ai/prompts/assistant.md" "# Prompt do assistente

Comportamento padrão esperado do assistente."
ensure_file ".ai/prompts/default.md" "# Prompt padrão

Prompt default para tarefas gerais."
ensure_file ".ai/prompts/user.md" "# Prompt do usuário

Template de prompt do usuário."

ensure_file ".ai/tasks/commit.md" "# Task: commit

Descreva o passo a passo para gerar commits."

ensure_file ".ai/agents/default.yaml" 'name: default
role: "Agente padrão"'
ensure_file ".ai/agents/reviewer.yaml" 'name: reviewer
role: "Revisor de código"'

ensure_file ".ai/tools/commands.yaml" 'commands: []'

ensure_dir ".ai/runs"
ensure_dir ".ai/logs"

ensure_file ".ai/skills/commit/skill.md" "# Skill: commit

Define o comportamento principal da skill de commit."
ensure_file ".ai/skills/commit/metadata.json" '{
  "name": "commit",
  "version": "1.0.0",
  "description": "Gera mensagens de commit seguindo o padrão do projeto"
}'
ensure_file ".ai/skills/commit/example.md" "# Exemplo

Exemplo de uso da skill de commit."
ensure_file ".ai/skills/commit/examples/basic.md" "# Exemplo básico"
ensure_file ".ai/skills/commit/examples/advanced.md" "# Exemplo avançado"
ensure_file ".ai/skills/commit/examples/multi-file.md" "# Exemplo multi-arquivo"
ensure_file ".ai/skills/commit/prompts/system.md" "# Prompt de sistema da skill commit"
ensure_file ".ai/skills/commit/prompts/user.md" "# Prompt de usuário da skill commit"
ensure_file ".ai/skills/commit/context/rules.md" "# Regras específicas da skill commit"
ensure_file ".ai/skills/commit/templates/commit-format.md" "# Formato de commit

<tipo>(<escopo>): <descrição curta>"
ensure_file ".ai/skills/commit/tests/cases.md" "# Casos de teste da skill commit"

# ---------------------------------------------------------------------------
# Tabela única de links por agente — CRIAÇÃO e VALIDAÇÃO leem daqui.
# Formato de cada entrada: "link relativo|alvo relativo dentro de .ai"
#
# Para adicionar um agente novo: acrescente linhas aqui. Não precisa mexer
# em mais nenhum lugar do script.
# ---------------------------------------------------------------------------

AGENT_LINKS=(
  ".blackbox/config.json|.ai/config/blackbox.json"
  ".blackbox/system.md|.ai/system.md"
  ".blackbox/memory.json|.ai/memory.json"
  ".blackbox/context|.ai/context"
  ".blackbox/prompts|.ai/prompts"
  ".blackbox/skills|.ai/skills"

  ".codex/config.json|.ai/config/codex.json"
  ".codex/instructions.md|.ai/system.md"
  ".codex/context|.ai/context"
  ".codex/tasks|.ai/tasks"
  ".codex/skills|.ai/skills"
  ".codex/runs|.ai/runs"
  ".codex/logs|.ai/logs"

  ".claude/config.yaml|.ai/config/cluade.yaml"
  ".claude/agents|.ai/agents"
  ".claude/prompts|.ai/prompts"
  ".claude/memory/history.json|.ai/memory.json"
  ".claude/skills|.ai/skills"
  ".claude/tools|.ai/tools"

  ".openclaude/config.yaml|.ai/config/cluade.yaml"
  ".openclaude/agents|.ai/agents"
  ".openclaude/prompts|.ai/prompts"
  ".openclaude/memory/history.json|.ai/memory.json"
  ".openclaude/skills|.ai/skills"
  ".openclaude/tools|.ai/tools"


  # -- exemplo de como registrar um agente novo (deixe comentado):
  # ".novoagente/config.json|.ai/config/novoagente.json"
  # ".novoagente/skills|.ai/skills"
)

echo ""
echo "== 2/3 — Criando symlinks por agente (${#AGENT_LINKS[@]} links registrados) =="

ensure_dir ".ai/memory"   # pai de memory/history.json precisa existir antes

for entry in "${AGENT_LINKS[@]}"; do
  link="${entry%%|*}"
  target="${entry#*|}"
  link_path "$link" "$target"
done


# ---------------------------------------------------------------------------
# 3. Validação final — usa a MESMA tabela AGENT_LINKS, nada duplicado.
# ---------------------------------------------------------------------------

echo ""
echo "== 3/3 — Validando todos os links =="

OK=0
FIXED=0
BROKEN=0

printf "%-42s %-8s %s\n" "LINK" "STATUS" "ALVO REAL"
printf '%.0s-' {1..90}; echo

for entry in "${AGENT_LINKS[@]}"; do
  link="${entry%%|*}"
  full="$ROOT/$link"

  if [[ ! -L "$full" ]]; then
    printf "%-42s %-8s %s\n" "$link" "SEM LINK" "-"
    BROKEN=$((BROKEN+1))
    continue
  fi

  resolved="$(readlink -f -- "$full" 2>/dev/null || true)"

  if [[ -n "$resolved" && -e "$resolved" ]]; then
    printf "%-42s %-8s %s\n" "$link" "OK" "${resolved#$ROOT/}"
    OK=$((OK+1))
  else
    # alvo apontado nao existe de verdade ainda -> cria como documento real
    target_raw="$(readlink -- "$full")"
    target_abs="$(realpath -m -- "$target_raw" 2>/dev/null || true)"
    if [[ -z "$target_abs" ]]; then
      target_abs="$(realpath -m -- "$ROOT/$target_raw")"
    fi

    if [[ "$(basename "$target_abs")" == *.* ]]; then
      ensure_dir "$(dirname "$target_abs")"
      printf '%s\n' "# Documento gerado automaticamente na validação" > "$target_abs"
    else
      ensure_dir "$target_abs"
    fi

    if [[ -e "$target_abs" ]]; then
      printf "%-42s %-8s %s\n" "$link" "CRIADO" "${target_abs#$ROOT/}"
      FIXED=$((FIXED+1))
    else
      printf "%-42s %-8s %s\n" "$link" "QUEBRADO" "não foi possível criar alvo"
      BROKEN=$((BROKEN+1))
    fi
  fi
done

echo ""
echo "Resumo: $OK ok | $FIXED corrigidos (documento criado agora) | $BROKEN quebrados | $WARNINGS avisos"

if [[ $BROKEN -gt 0 ]]; then
  echo "⚠ Existem links quebrados que não puderam ser corrigidos automaticamente."
  exit 1
fi

echo "✅ .ai/ é a fonte de verdade; todos os links foram criados e validados."
