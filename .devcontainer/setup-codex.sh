#!/usr/bin/env bash
#
# Prepara o Codex dentro do container:
#   1. valida o ambiente
#   2. garante autenticação (device auth, com ponte para a extensão VS Code)
#   3. marca o workspace como trusted
#   4. valida os arquivos TOML
#   5. executa o comando recebido (exec "$@")
#
set -Eeuo pipefail

# ==========================================================
# Constantes
# ==========================================================

readonly LOG_PREFIX="[codex]"
readonly EXPECTED_USER="${1:-${EXPECTED_USER:-rstudio}}"
readonly WORKSPACE="/workspace"
readonly CODEX_HOME="$HOME/.codex"
readonly CODEX_CONFIG="$CODEX_HOME/config.toml"
readonly PROJECT_CONFIG="$WORKSPACE/.codex/config.toml"

readonly BRIDGE_DIR="$WORKSPACE/.codex"
readonly DEVICE_AUTH_FILE="$BRIDGE_DIR/device-auth.json"

readonly DEVICE_URL="https://auth.openai.com/codex/device"
readonly DEVICE_CODE_REGEX='\b[A-Z0-9]{4,6}-[A-Z0-9]{4,6}\b'
readonly DEVICE_CODE_TIMEOUT_SECONDS=120

# ==========================================================
# Estado (usado pelo cleanup)
# ==========================================================

LOGIN_OUTPUT=""
LOGIN_PID=""
TAIL_PID=""

# ==========================================================
# Log
# ==========================================================

log()   { echo "$LOG_PREFIX $*"; }
error() { echo "$LOG_PREFIX ERRO: $*" >&2; }

die() {
    local exit_code="$1"
    shift
    error "$*"
    exit "$exit_code"
}

on_error() {
    local exit_code="$1" line="$2" command="$3"
    echo "$LOG_PREFIX ERRO linha $line: $command (exit $exit_code)" >&2
}

# ==========================================================
# Cleanup
# ==========================================================

stop_process() {
    local pid="$1"
    [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
}

cleanup_login() {
    stop_process "$TAIL_PID"
    stop_process "$LOGIN_PID"
    rm -f "$LOGIN_OUTPUT" "$DEVICE_AUTH_FILE" "$DEVICE_AUTH_FILE.tmp"
    TAIL_PID=""
    LOGIN_PID=""
    LOGIN_OUTPUT=""
}

# ==========================================================
# Ambiente
# ==========================================================

require_user() {
    [[ "$(id -un)" == "$EXPECTED_USER" ]] \
        || die 1 "este script precisa ser executado como $EXPECTED_USER"
}

require_command() {
    local name="$1" message="$2"
    command -v "$name" >/dev/null 2>&1 || die 127 "$message"
}

log_environment() {
    log "setup iniciado"
    log "user: $(id -un)"
    log "HOME: $HOME"
    log "PATH: $PATH"
}

prepare_environment() {
    require_user
    require_command codex   "codex não encontrado"
    require_command python3 "python3 não está instalado no container"

    cd "$WORKSPACE"
    mkdir -p "$CODEX_HOME" "$BRIDGE_DIR"
    touch "$CODEX_CONFIG"
    #rm -f "$DEVICE_AUTH_FILE"
}

# ==========================================================
# Autenticação
# ==========================================================

is_authenticated() {
    codex login status >/dev/null 2>&1
}

start_login() {
    LOGIN_OUTPUT="$(mktemp)"
    codex login --device-auth > "$LOGIN_OUTPUT" 2>&1 &
    LOGIN_PID=$!

    # Espelha a saída do login no terminal.
    tail -f "$LOGIN_OUTPUT" &
    TAIL_PID=$!
}

login_is_running() {
    kill -0 "$LOGIN_PID" 2>/dev/null
}

extract_device_codev1() {
    sed 's/\x1b\[[0-9;]*m//g' "$LOGIN_OUTPUT" \
        | grep -Eo '[A-Z0-9]{4,6}-[A-Z0-9]{4,6}' \
        | tail -n 1 \
        || true
}

extract_device_code() {
    sed 's/\x1b\[[0-9;]*m//g' "$LOGIN_OUTPUT" \
        | grep -E '^[[:space:]]*[A-Z0-9]{4,6}-[A-Z0-9]{4,6}[[:space:]]*$' \
        | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
        | head -n 1 \
        || true
}

wait_for_device_code() {
    local attempt
    local code

    for ((attempt = 0; attempt < DEVICE_CODE_TIMEOUT_SECONDS; attempt++)); do
        code="$(extract_device_code)"

        if [[ -n "$code" ]]; then
            printf '%s\n' "$code"
            return 0
        fi

        if ! login_is_running; then
            error "o processo de login terminou antes de gerar o código"
            return 1
        fi

        sleep 1
    done

    error "tempo esgotado esperando o device code"
    return 1
}

open_browser() {
    local url="$1" helper sock

    helper="${BROWSER:-}"
    if [[ ! -x "$helper" || "$helper" != *browser.sh ]]; then
        helper="$(/bin/ls -t "$HOME"/.vscode-server/bin/*/bin/helpers/browser.sh 2>/dev/null | head -n 1 || true)"
    fi
    [[ -n "$helper" ]] || return 1

    if [[ -n "${VSCODE_IPC_HOOK_CLI:-}" && -S "$VSCODE_IPC_HOOK_CLI" ]]; then
        VSCODE_IPC_HOOK_CLI="$VSCODE_IPC_HOOK_CLI" timeout 10 "$helper" "$url" >/dev/null 2>&1 </dev/null && return 0
    fi

    while IFS= read -r sock; do
        VSCODE_IPC_HOOK_CLI="$sock" timeout 10 "$helper" "$url" >/dev/null 2>&1 </dev/null && return 0
    done < <(/bin/ls -t /tmp/vscode-ipc-*.sock 2>/dev/null || true)

    return 1
}

publish_device_auth() {
    local code="$1"
    local tmp_file="$DEVICE_AUTH_FILE.tmp"

    log "publicando device code: [$code]"

    cat >"$tmp_file" <<EOF
{
    "url": "$DEVICE_URL",
    "code": "$code"
}
EOF

    chmod 600 "$tmp_file"
    mv -f "$tmp_file" "$DEVICE_AUTH_FILE"

    log "device-auth publicado em: $DEVICE_AUTH_FILE"

    if ! copy_to_clipboard "$code"; then
        log "clipboard indisponível. Código: [$code]"
    fi

    # ------------------------------------------------------
    # Abre o navegador
    # ------------------------------------------------------
    log "abrindo navegador..."
    if open_browser "$DEVICE_URL"; then
        log "navegador aberto no host"
    else
        log "não foi possível abrir o navegador automaticamente"
    fi
    log "abra: $DEVICE_URL"
    env -u VSCODE_IPC_HOOK_CLI -u BROWSER bash -c 'H=$(/bin/ls -t ~/.vscode-server/bin/*/bin/helpers/browser.sh | head -n 1); for S in $(/bin/ls -t /tmp/vscode-ipc-*.sock); do echo "tentando $S"; VSCODE_IPC_HOOK_CLI="$S" timeout 10 "$H" "https://auth.openai.com/codex/device"; echo "exit=$?"; done'
}

# ------------------------------------------------------
# Clipboard
# ------------------------------------------------------
copy_to_clipboard() {
    local text="$1"
    echo "###########"
    echo "DISPLAY: ${DISPLAY:-}"
    echo "###########"
    if [[ -z "${DISPLAY:-}" ]]; then
        return 1
    fi

    if command -v xclip >/dev/null 2>&1 \
        && printf '%s' "$text" | xclip -selection clipboard >/dev/null 2>&1; then
        log "device code copiado para o clipboard (xclip)"
        return 0
    fi

    if command -v xsel >/dev/null 2>&1 \
        && printf '%s' "$text" | xsel --clipboard --input >/dev/null 2>&1; then
        log "device code copiado para o clipboard (xsel)"
        return 0
    fi

    return 1
}


authenticate_with_device_code() {
    local device_code

    log "autenticação necessária"
    log "iniciando device authentication..."
    start_login

    log "aguardando device code..."
    device_code="$(wait_for_device_code)" || exit 1
    log "device code detectado: [$device_code]"

    publish_device_auth "$device_code"
    log "solicitação enviada para VS Code"
    log "navegador será aberto no host"    
    log "código será copiado para o clipboard"
    log "aguardando autenticação..."

    wait "$LOGIN_PID" || die 1 "autenticação falhou"
    log "autenticação concluída"

    cleanup_login
}

ensure_authenticated() {
    log "verificando autenticação..."

    if is_authenticated; then
        log "autenticação OK"
    else
        authenticate_with_device_code
    fi
}


# ==========================================================
# Trust
# ==========================================================

is_workspace_trusted() {
    grep -Fq "[projects.\"$WORKSPACE\"]" "$CODEX_CONFIG"
}

trust_workspace() {
    cat >>"$CODEX_CONFIG" <<EOF

[projects."$WORKSPACE"]
trust_level = "trusted"
EOF
}

ensure_workspace_trusted() {
    log "configurando trust..."

    if is_workspace_trusted; then
        log "trust já configurado"
    else
        trust_workspace
        log "$WORKSPACE marcado como trusted"
    fi
}

# ==========================================================
# Configuração
# ==========================================================

require_project_config() {
    [[ -f "$PROJECT_CONFIG" ]] || die 1 "$PROJECT_CONFIG não existe"
    log "configuração do projeto encontrada"
}

validate_toml_files() {
    log "validando TOML..."

    python3 - "$@" <<'PY'
import sys
import tomllib

for path in sys.argv[1:]:
    with open(path, "rb") as f:
        tomllib.load(f)
    print(f"[codex] TOML válido: {path}")
PY
}

# ==========================================================
# Main
# ==========================================================

main() {
    trap 'on_error $? $LINENO "$BASH_COMMAND"' ERR
    trap cleanup_login EXIT
    log "🗑️  limpando estado anterior do codex..."
    rm -rf "$CODEX_HOME"
    log "✅ .codex removido"
    log_environment
    prepare_environment
    ensure_authenticated
    ensure_workspace_trusted
    require_project_config
    validate_toml_files "$PROJECT_CONFIG" "$CODEX_CONFIG"

    log "configuração concluída"
    log "setup finalizado"

    # exec substitui o processo e o trap EXIT não dispara,
    # então limpamos explicitamente antes.
    cleanup_login
    trap - EXIT
    exec "$@"
}

main "$@"
