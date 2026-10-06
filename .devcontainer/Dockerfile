FROM alexfariakof/rstudio-base:latest AS base
ARG USERNAME="rstudio" 
RUN USERNAME=${USERNAME} 
EXPOSE 9864
# ==========================================
# Dependências do sistema
# ==========================================
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        sudo \ 
        iptables \
        ipset \
        iproute2 \
        iputils-ping \
        dnsutils \
        git \
        git-lfs \
        gh \
        openssh-client \
        jq \
        xdg-utils \
        xauth \
        xclip \
        xsel \
        x11-apps \
        x11-utils \
        gnupg \    
        build-essential \
        nano \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN git lfs install --system
RUN npm install -g npm@12.0.2 \
    && npm install -g @openai/codex@latest --include=optional \
    && codex --version

RUN sed -i 's|^SHELL=.*|SHELL=/usr/bin/zsh|' /etc/default/useradd \
    && sed -i 's|^DSHELL=.*|DSHELL=/usr/bin/zsh|' /etc/adduser.conf \
    && awk -F: '$7 == "/bin/bash" || $7 == "/usr/bin/bash" || $7 == "/bin/sh" {print $1}' /etc/passwd \
       | xargs -r -I{} usermod -s /usr/bin/zsh {}

COPY .devcontainer/requirements.txt /usr/local/share/requirements.txt

COPY .devcontainer/post-start.sh /usr/local/sbin/post-start.sh
COPY .devcontainer/docker-entrypoint.sh /usr/local/sbin/docker-entrypoint.sh
COPY ./.ai/setup-codex-any-user.sh /usr/local/sbin/setup-codex.sh
RUN chmod 755 /usr/local/sbin/post-start.sh \
                /usr/local/sbin/docker-entrypoint.sh \
                /usr/local/sbin/setup-codex.sh
        
# 🔐 Sudo sem senha
RUN echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME}-dev \
    && chmod 0440 /etc/sudoers.d/${USERNAME}-dev

# 🧾 Configuração do Git'''
RUN mkdir -p /home/${USERNAME} && \
    printf '[user]\n    name = Alex Ribeiro de Faria\n    email = 135660435+alexribeirofaria@github.com\n[safe]\n    directory = /workspace\n' \
    > /home/${USERNAME}/.gitconfig && \
    chown ${USERNAME}:${USERNAME} /home/${USERNAME}/.gitconfig

# =============================================================================
# GITHUB SET 
# ============================================================================
ARG GITHUB_TOKEN
RUN if [ -n "$GITHUB_TOKEN" ]; then \
      echo "${GITHUB_TOKEN}" | gh auth login --with-token || echo "gh auth falhou, seguindo sem autenticar"; \
    else \
      echo "GITHUB_TOKEN não fornecido, pulando gh auth login"; \
    fi

# =============================================================================
# 🪐 Jupyter Lab como serviço s6
# =============================================================================
ARG JUPYTER_NOTEBOOK_DIR=""
ARG PROJECT_WORKSPACE=""
ARG JUPYTER_IP="0.0.0.0"
ARG JUPYTER_PORT="8888"
ARG JUPYTER_TOKEN=""
ARG JUPYTER_PASSWORD_REQUIRED="False"
ARG JUPYTER_ALLOW_ORIGIN="*"

ENV JUPYTER_NOTEBOOK_DIR="${JUPYTER_NOTEBOOK_DIR}"
ENV PROJECT_WORKSPACE="${PROJECT_WORKSPACE}"
ENV JUPYTER_IP="${JUPYTER_IP}"
ENV JUPYTER_PORT="${JUPYTER_PORT}"
ENV JUPYTER_TOKEN="${JUPYTER_TOKEN}" \
    JUPYTER_PASSWORD_REQUIRED="${JUPYTER_PASSWORD_REQUIRED}" \
    JUPYTER_ALLOW_ORIGIN="${JUPYTER_ALLOW_ORIGIN}"

RUN mkdir -p /etc/services.d/jupyter \
    && cat > /etc/services.d/jupyter/run <<'EOF'
#!/usr/bin/with-contenv bash

unset JUPYTER_TOKEN JUPYTER_PASSWORD

APP_USER="${USERNAME:-rstudio}"
export HOME="/home/${APP_USER}"

NOTEBOOK_DIR="${JUPYTER_NOTEBOOK_DIR:-${PROJECT_WORKSPACE:-${HOME}}}"
[ -d "${NOTEBOOK_DIR}" ] || NOTEBOOK_DIR="${HOME}"
cd "${NOTEBOOK_DIR}"

exec s6-setuidgid "${APP_USER}" /opt/venv/bin/jupyter lab \
    --ip="${JUPYTER_IP:-0.0.0.0}" \
    --port="${JUPYTER_PORT:-8888}" \
    --no-browser \
    --notebook-dir="${NOTEBOOK_DIR}" \
    --IdentityProvider.token="${JUPYTER_TOKEN}" \
    --ServerApp.password="" \
    --ServerApp.password_required="${JUPYTER_PASSWORD_REQUIRED}" \
    --ServerApp.allow_origin="${JUPYTER_ALLOW_ORIGIN}"

EOF

RUN chmod 755 /etc/services.d/jupyter/run


# =============================================================================
# Shell global: bash (/etc/bash.bashrc)
# =============================================================================
RUN cat >> /etc/bash.bashrc <<'EOF'

export HISTFILE="$HOME/shell_history/.zsh_history"
export VIRTUAL_ENV="/opt/venv"
export PYSPARK_PYTHON="${VIRTUAL_ENV}/bin/python"
export PYSPARK_DRIVER_PYTHON="${VIRTUAL_ENV}/bin/python"
export PATH="/bin:/usr/local/bin:/usr/local/sbin:${VIRTUAL_ENV}/bin:${SPARK_HOME}/bin:${SPARK_HOME}/sbin:$HOME/.local/bin:$PATH"

# =========================================================
# ALIASES
# =========================================================
alias cls='clear'
alias py='python3'
alias ll='eza -l -h --group --group-directories-first'
alias la='eza -la -hs --group --group-directories-first'
alias lt='eza --tree --level=2 --group --group-directories-first'

function ls() {
    command eza \
        -la \
        -h \
        --group \
        --group-directories-first \
        --color=auto \
        "$@"
}

function lsh() {
    local dir="${1:-.}"

    command eza \
        -la \
        -h \
        --group \
        --group-directories-first \
        --sort=size \
        --color=auto \
        "$dir"
}


# ==========================================
# VENV + GIT BRANCH NO PROMPT
# ==========================================
MY_VENV="/opt/venv"

parse_git_branch() {
    local branch
    branch=$(git branch --show-current 2>/dev/null)

    [ -n "$branch" ] && printf " (%s)" "$branch"
}

set_venv_prompt() {
    local venv_prompt=""

    if [[ -n "${VIRTUAL_ENV:-}" ]]; then
        venv_prompt='\[\e[1;31m\](venv)\[\e[0m\] '
    fi

    PS1='\[\e[1;32m\]┌──\[\e[0m\] '"$venv_prompt"\
'\[\e[0;37m\](\[\e[1;34m\]\u\[\e[0;37m\]㉿\[\e[1;32m\]\h\[\e[0;37m\])\[\e[0m\]-'\
'\[\e[0;37m\][\w\[\e[1;33m\]$(parse_git_branch)\[\e[0;37m\]]\[\e[0m\]'\
'\n'\
'\[\e[1;32m\]└─\[\e[0m\]\$ '
}


function activate() {
    if [ -f "$MY_VENV/bin/activate" ]; then
        source "$MY_VENV/bin/activate"
        set_venv_prompt
    else
        echo "Erro: virtualenv não encontrado em $MY_VENV"
        return 1
    fi
}

function desactive() {
    if [[ -n "$VIRTUAL_ENV" ]] && type deactivate >/dev/null 2>&1; then
        deactivate
        set_venv_prompt
    else
        echo "Nenhum virtualenv ativo."
    fi
}

set_venv_prompt
EOF

# =============================================================================
# Shell global: zsh (/etc/zsh/zshrc)
# =============================================================================
RUN cat >> /etc/zsh/zshrc <<'EOF'
export HISTFILE="$HOME/shell_history/.zsh_history"
export VIRTUAL_ENV="/opt/venv"
export PYSPARK_PYTHON="${VIRTUAL_ENV}/bin/python"
export PYSPARK_DRIVER_PYTHON="${VIRTUAL_ENV}/bin/python"
export PATH="/bin:/usr/local/bin:/usr/local/sbin:${VIRTUAL_ENV}/bin:${SPARK_HOME}/bin:${SPARK_HOME}/sbin:$HOME/.local/bin:$PATH"

HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=20000

setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt PROMPT_SUBST

alias cls='clear'
alias py='python3'
alias ll='eza -lh --group --group-directories-first'
alias la='eza -lah --group --group-directories-first'
alias lt='eza --tree --level=2 --group'


function ls() {
    command eza \
        -la \
        -h \
        --group \
        --group-directories-first \
        --color=auto \
        "$@"
}

function lsh() {
    local dir="${1:-.}"

    command eza \
        -la \
        -h \
        --group \
        --group-directories-first \
        --sort=size \
        --color=auto \
        "$dir"
}

MY_VENV="/opt/venv"

activate() {
    if [[ -f "$MY_VENV/bin/activate" ]]; then
        source "$MY_VENV/bin/activate"
    else
        echo "Erro: virtualenv não encontrado em $MY_VENV"
        return 1
    fi
}

desactive() {
    if [[ -n "$VIRTUAL_ENV" ]] && type deactivate >/dev/null 2>&1; then
        deactivate
    else
        echo "Nenhum virtualenv ativo."
    fi
}

set_prompt() {
    local git_branch
    git_branch=$(git branch --show-current 2>/dev/null)

    PROMPT=""
    PROMPT+="%F{%(#.blue.green)}┌── "

    if [[ -n "$VIRTUAL_ENV" ]]; then
        PROMPT+="%F{red}%B($(basename "$VIRTUAL_ENV"))%b%f "
    fi

    PROMPT+="(%B%F{%(#.red.blue)}%n㉿%m%b%F{%(#.blue.green)})"
    PROMPT+="-[%B%F{reset}%~%b%F{%(#.blue.green)}"

    if [[ -n "$git_branch" ]]; then
        PROMPT+=" %F{yellow}%B(${git_branch})%b%F{%(#.blue.green)}"
    fi

    PROMPT+="]"
    PROMPT+=$'\n'
    PROMPT+="└─%B%(#.%F{red}#.%F{blue}\$)%b%F{reset} "
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd set_prompt
EOF

RUN echo '[ -f /usr/local/sbin/auto-switch-user.sh ] && . /usr/local/sbin/auto-switch-user.sh' \
    >> /etc/zsh/zshrc

# =============================================================================
# 🔄 AUTO SWITCH
# =============================================================================
# 🎯 Destino fixo: rstudio
# -----------------------------------------------------------------------------
# 👑 root    ➜ rstudio
# 👤 rstudio ➜ rstudio (permanece)
# 👥 outros  ➜ rstudio
# -----------------------------------------------------------------------------
# 🖥️  Atua somente em shell interativo (bash e zsh)
# 📄 Script gerado: /usr/local/sbin/auto-switch-user.sh
# =============================================================================
RUN printf '%s\n' \
        '# 🔄 Auto switch: todos os usuários trocam para o usuário de destino.' \
        '' \
        '# 🖥️  Somente shell interativo.' \
        'case $- in' \
        '    *i*) ;;' \
        '    *) return 0 2>/dev/null || exit 0 ;;' \
        'esac' \
        '' \
        '# 🎯 Usuário de destino (fixo).' \
        'TARGET="rstudio"' \
        'CURRENT="$(id -un 2>/dev/null || echo unknown)"' \
        '' \
        '# ✅ Já é o usuário de destino ou ele não existe: nada a fazer.' \
        'if [ "${CURRENT}" = "${TARGET}" ] || ! id "${TARGET}" >/dev/null 2>&1; then' \
        '    return 0 2>/dev/null || exit 0' \
        'fi' \
        '' \
        'export AUTO_SWITCHED=1' \
        '' \
        '# 👑 root troca com su | 🔑 demais usam sudo | ⚠️ sem permissão: permanece' \
        'if [ "$(id -u)" = "0" ]; then' \
        '    echo "🔄 auto-switch: ${CURRENT} ➜ ${TARGET}"' \
        '    exec su - "${TARGET}"' \
        'elif command -v sudo >/dev/null 2>&1 && sudo -n -u "${TARGET}" true 2>/dev/null; then' \
        '    echo "🔄 auto-switch: ${CURRENT} ➜ ${TARGET} (sudo)"' \
        '    exec sudo -n -u "${TARGET}" -i' \
        'else' \
        '    echo "⚠️  auto-switch: sem permissão para virar ${TARGET}, permanecendo como ${CURRENT}."' \
        'fi' \
        > /usr/local/sbin/auto-switch-user.sh \
    && chmod 755 /usr/local/sbin/auto-switch-user.sh \
    && echo '[ -f /usr/local/sbin/auto-switch-user.sh ] && . /usr/local/sbin/auto-switch-user.sh' >> /etc/bash.bashrc \
    && mkdir -p /etc/zsh \
    && echo '[ -f /usr/local/sbin/auto-switch-user.sh ] && . /usr/local/sbin/auto-switch-user.sh' >> /etc/zsh/zshrc

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["/init"]

