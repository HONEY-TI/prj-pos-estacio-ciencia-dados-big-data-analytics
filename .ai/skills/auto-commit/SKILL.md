---
name: auto-commit
file: auto-commit.sh
description: Executar Commit por Arquivo com Mensagem Inteligente automatizada, incluindo suporte a submodules com script de execução dedicado.
---

## 🎯 Objetivo

- Criar commits **granulares e semânticos** por arquivo
* Cada arquivo modificado ou criado gera **um commit individual**
* Cada commit possui uma **mensagem específica baseada na alteração**
* Sempre criar descrições para mensagem utilizando língua portuguesa
* Cire sempre mensagens com descrições no formato markdown siginificativas sobre as alterações realizadas
* O processo é **automatizado via Git + análise de diff**
* **Nunca gerar um script (`.sh`) para executar depois.** comando diretamente deve ser executado dinamicamente por auto-commit.sh, um

---

## ⚙️ Pré-requisitos

- Git >= 2.x instalado e configurado (`user.name`, `user.email`)
- Repositório inicializado com remote `origin`
- Submodules inicializados: `git submodule update --init --recursive`

---

## 🛡️ Regras Obrigatórias

1. **Usar `git add .`** — adicionar arquivo por arquivo para commits atômicos
2. **Submodules sempre primeiro** — commitar dentro do submodule antes do repositório pai
3. **Nunca commitar arquivos binários sem verificação** — detectar e tratar separadamente
4. **Mensagens sempre em Conventional Commits** — `type(scope): description`
5. **Mensagem do commit** — usar pt-BR sempre com mensagem sucinta e clara 
6. **Descrições** — Usar sempre linguagem pt-BR detalhando o que foi realizado no formato markdown

---

## 📐 Detecção de Tipo por Status Git

| Status Git | Tipo Conventional | Ação     |
|------------|-------------------|----------|
| `A`        | `feat`            | `add`    |
| `M`        | Depende do diff   | `update` |
| `D`        | `chore`           | `remove` |
| `R`        | `refactor`        | `rename` |
| `??`       | `feat`            | `add`    |

---

## 🧠 Refinamento Semântico pelo Conteúdo do Diff

| Padrão no diff                                     | Tipo preferencial |
|----------------------------------------------------|-------------------|
| `+.*test\|spec\|describe\|it(\|expect(`           | `test`            |
| `+.*interface \|type \|enum \|abstract class`     | `refactor`        |
| `+.*@Injectable\|@Controller\|@Module`            | `feat`            |
| `+.*function \|async \|=>\|class `               | `feat`            |
| `+.*fix\|bug\|erro\|error\|correct`               | `fix`             |
| `+.*password\|secret\|token\|apiKey`              | `security`        |
| `+.*console\.\|logger\.\|log(`                   | `chore`           |
| Apenas remoções (`^-`)                            | `refactor`        |

---

## 🔍 Detecção de Escopo pelo Caminho

| Padrão no caminho         | Escopo       |
|---------------------------|--------------|
| `src/domain/`             | `domain`     |
| `src/application/`        | `app`        |
| `src/infrastructure/`     | `infra`      |
| `src/presentation/`       | `presentation` |
| `test/` ou `*.spec.*`     | `tests`      |
| `*.md`                    | `docs`       |
| `*.json\|yaml\|yml\|env`  | `config`     |
| `Dockerfile\|docker-*`    | `docker`     |
| `.github/`                | `ci`         |

---

## 🔗 Fluxo para Submodules

Submodules precisam ser commitados **de dentro para fora**:

```
1. Entrar no submodule
2. Commitar arquivos modificados dentro dele
3. Fazer push do submodule
4. Voltar ao repositório pai
5. Commitar a referência atualizada do submodule
```

### Detecção de submodule modificado

```bash
# Listar submodules com modificações
git submodule foreach --quiet 'git status --porcelain -uall | grep -q . && echo $displaypath'
```

### Commit dentro do submodule

```bash
SUBMODULE_PATH="caminho/do/submodule"

(
  cd "$SUBMODULE_PATH"
  # Executar o mesmo loop de commit por arquivo aqui dentro
  git push origin HEAD
)

# Voltar ao pai e commitar a referência atualizada
git add "$SUBMODULE_PATH"
git commit -m "chore(deps): update submodule $SUBMODULE_PATH" \
           -m "Atualiza referência do submodule após commits internos."
```

---

## 🚀 Fluxo Completo da Skill

### Etapa 1 — Verificar branch e status

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "📍 Branch: $BRANCH"
git status --porcelain=v1 -uall
```

### Etapa 2 — Processar submodules primeiro

```bash
git submodule foreach --quiet \
  'git status --porcelain -uall | grep -q . && echo $displaypath' \
| while read submodule; do
    echo "🔗 Processando submodule: $submodule"
    # executar loop de commit dentro do submodule
    (cd "$submodule" && bash auto-commit.sh --no-push)
    git add "$submodule"
    git commit \
      -m "chore(deps): update submodule $(basename $submodule)" \
      -m "Atualiza referência do submodule \`$submodule\` após commits internos realizados automaticamente."
  done
```

### Etapa 3 — Processar arquivos do repositório pai

```bash
git diff --name-only | while read file; do

  diff=$(git diff "$file")

  case "$status" in
    A|"??") TYPE="feat";     ACTION="add"    ;;
    M)      TYPE="fix";      ACTION="update" ;;
    D)      TYPE="chore";    ACTION="remove" ;;
    R*)     TYPE="refactor"; ACTION="rename" ;;
    *)      TYPE="chore";    ACTION="update" ;;
  esac

  if [[ "$status" == "A" ]]; then
    type="feat"
    action="add"
  elif [[ "$status" == "M" ]]; then
    type="fix"
    action="update"
  elif [[ "$status" == "D" ]]; then
    type="chore"
    action="remove"
  else
    type="chore"
    action="update"
  fi

  
  message="$type: $action changes"
  description="descrição detalhada das modificações no formato markdown"

  git add "$file"
  git commit -m "$message" - m "$description"
  echo "✅ $file - $message"
  done
```

### Etapa 4 — Push

```bash
git push origin "$BRANCH"
```

---

## ✅ Resultado Esperado

| Etapa                        | Status |
|------------------------------|--------|
| Submodules commitados        | ✔      |
| Referências pai atualizadas  | ✔      |
| Commits atômicos por arquivo | ✔      |
| Mensagens Conventional       | ✔      |
| Descrições em português      | ✔      |
| Push automático              | ✔      |