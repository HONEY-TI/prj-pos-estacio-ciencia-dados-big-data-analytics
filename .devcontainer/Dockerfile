FROM alexfariakof/rstudio-dev-base:latest
USER root 
    
RUN apt-get update && apt-get install -y \
    openssh-client \
    zsh \
    git-lfs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN git lfs install --system

RUN R -q -e "install.packages(c('sampling', 'survey'), repos='https://cloud.r-project.org', dependencies=TRUE)"

ARG USERNAME=rstudio

COPY requirements.txt /tmp/requirements.txt
RUN /opt/venv/bin/pip install --upgrade pip \
    && /opt/venv/bin/pip install -r /tmp/requirements.txt

COPY entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh \
    && chown root:root /usr/local/bin/docker-entrypoint.sh \
    && chmod 700 /usr/local/bin/docker-entrypoint.sh

COPY setup-codex.sh /usr/local/bin/setup-codex.sh
RUN chmod +x /usr/local/bin/setup-codex.sh \
    && chown root:root /usr/local/bin/setup-codex.sh \
    && chmod 700 /usr/local/bin/setup-codex.sh
  
RUN echo "rstudio ALL=(root) NOPASSWD: /usr/local/bin/setup-codex.sh, /usr/local/bin/docker-entrypoint.sh" \
    > /etc/sudoers.d/${USERNAME}-dev \
    && chmod 0440 /etc/sudoers.d/${USERNAME}-dev \
    && visudo -cf /etc/sudoers.d/${USERNAME}-dev

RUN mkdir -p /home/${USERNAME}/.ssh \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.ssh \
    && chmod 700 /home/${USERNAME}/.ssh

RUN touch /home/${USERNAME}/.bash_history /home/${USERNAME}/.zsh_history \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.bash_history /home/${USERNAME}/.zsh_history \
    && chmod 664 /home/${USERNAME}/.bash_history /home/${USERNAME}/.zsh_history


# =============================================================================
# Shell do usuário rstudio
# =============================================================================
RUN cat > /home/${USERNAME}/.bashrc <<'EOF'
export VIRTUAL_ENV="/opt/venv"
export SPARK_HOME="/opt/spark"
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"

export PYSPARK_PYTHON="${VIRTUAL_ENV}/bin/python"
export PYSPARK_DRIVER_PYTHON="${VIRTUAL_ENV}/bin/python"

export PATH="${VIRTUAL_ENV}/bin:${SPARK_HOME}/bin:${SPARK_HOME}/sbin:${HOME}/.npm-global/bin:/usr/local/bin:${PATH}"

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
        --color=always \
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
        --color=always \
        "$dir"
}
# ==========================================
# VENV + GIT BRANCH NO PROMPT
# ==========================================

parse_git_branch() {
    local branch
    branch=$(git branch --show-current 2>/dev/null)

    [ -n "$branch" ] && printf " (%s)" "$branch"
}

set_venv_prompt() {

    local venv_prompt=""

    if [ -n "${VIRTUAL_ENV:-}" ]; then
        venv_prompt='\[\e[1;31m\](venv)\[\e[0m\] '
    fi

    PS1='\[\e[1;32m\]┌──\[\e[0m\] '"${venv_prompt}"\
'\[\e[0;37m\](\[\e[1;34m\]\u\[\e[0;37m\]㉿\[\e[1;32m\]\h\[\e[0;37m\])\[\e[0m\]-'\
'\[\e[0;37m\][\w\[\e[1;33m\]$(parse_git_branch)\[\e[0;37m\]]\[\e[0m\]'\
'\n'\
'\[\e[1;32m\]└─\[\e[0m\]\$ '
}

activate_venv() {
    local venv="${1:-/home/jail/opt/venv}"

    if [ ! -f "$venv/bin/activate" ]; then
        echo "Erro: virtualenv não encontrado em: $venv"
        return 1
    fi

    export VIRTUAL_ENV_DISABLE_PROMPT=1
    source "$venv/bin/activate"
    set_venv_prompt
}

set_venv_prompt
EOF

RUN cat > /home/${USERNAME}/.bash_profile <<'EOF'
[ -f "${HOME}/.bashrc" ] && source "${HOME}/.bashrc"
EOF

# ── Zsh personalizado ───────────────────────────────────────────────────────
RUN cat > /home/rstudio/.zshrc <<'EOF'

export HISTFILE="$HOME/shell_history/.zsh_history"
export VIRTUAL_ENV="/opt/venv"
export PYSPARK_PYTHON="${VIRTUAL_ENV}/bin/python"
export PYSPARK_DRIVER_PYTHON="${VIRTUAL_ENV}/bin/python"
export PATH="${VIRTUAL_ENV}/bin:${SPARK_HOME}/bin:${SPARK_HOME}/sbin:/bin:/usr/local/bin:/home/rstudio/.local/bin:/home/rstudio/.npm-global/bin:$PATH"

HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=20000

setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
alias cls='clear'
alias py='python3'

function ls() {
    command eza -la --group --group-directories-first "$@"
}
alias py='python3'
alias ll='eza -lh --group --icons'
alias la='eza -lah --group'
alias lt='eza --tree --level=2 --group'

# ==========================================
# VENV + GIT BRANCH NO PROMPT
# ==========================================

# Caminho do venv
MY_VENV="/opt/venv"

function activate() {
    if [[ -f "$MY_VENV/bin/activate" ]]; then
        source "$MY_VENV/bin/activate"
        set_prompt
    else
        echo "Erro: virtualenv não encontrado em $MY_VENV"
        return 1
    fi
}

function desactive() {
    if [[ -n "$VIRTUAL_ENV" ]] && type deactivate >/dev/null 2>&1; then
        deactivate
        set_prompt
    else
        echo "Nenhum virtualenv ativo."
    fi
}

function set_prompt() {
    local git_branch=""
    git_branch=$(git branch --show-current 2>/dev/null)

    PROMPT=""
    PROMPT+="%F{%(#.blue.green)}┌── "

    # VENV — somente lê $VIRTUAL_ENV
    if [[ -n "$VIRTUAL_ENV" ]]; then
        PROMPT+="%F{red}%B($(basename "$VIRTUAL_ENV"))%b%f "
    fi

    # Usuário e máquina
    PROMPT+="(%B%F{%(#.red.blue)}%n㉿%m%b%F{%(#.blue.green)})"

    # Diretório
    PROMPT+="-[%B%F{reset}%~%b%F{%(#.blue.green)}"

    # Git branch
    if [[ -n "$git_branch" ]]; then
        PROMPT+=" %F{yellow}%B(${git_branch})%b%F{%(#.blue.green)}"
    fi

    PROMPT+="]"
    PROMPT+=$'\n'
    PROMPT+="└─%B%(#.%F{red}#.%F{blue}\$)%b%F{reset} "
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd set_prompt

setopt PROMPT_SUBST
EOF

RUN chown ${USERNAME}:${USERNAME} /home/${USERNAME}/.zshrc

RUN chsh -s /usr/bin/zsh ${USERNAME}    

ARG GITHUB_TOKEN
RUN if [ -n "$GITHUB_TOKEN" ]; then \
      printf '%s\n' "$GITHUB_TOKEN" | gh auth login --with-token || echo "gh auth falhou, seguindo sem autenticar"; \
    else \
      echo "GITHUB_TOKEN não fornecido, pulando gh auth login"; \
    fi

RUN git config --global user.name "Alex Ribeiro de Faria" \
    && git config --global user.email "135660435+alexribeirofaria@github.com"


# =============================================================================
# 🔄 AUTO SWITCH — ROOT ➜ RSTUDIO
# =============================================================================
# 📌 false = DESATIVADO | true = ATIVADO
# =============================================================================

ARG ENABLE_SWITCH_USER=true

RUN if [ "$ENABLE_SWITCH_USER" = "true" ]; then \
        echo "🔄 Configurando auto switch: root ➜ rstudio"; \
        printf '%s\n' \
            'if [ "${AUTO_SWITCHED}" != "1" ]; then' \
            '    export AUTO_SWITCHED=1' \
            '    exec su - rstudio' \
            'fi' \
            > /root/.switch_user; \
        echo "source /root/.switch_user" >> /root/.bashrc; \
        echo "source /root/.switch_user" >> /root/.bash_profile; \
        echo ". /root/.switch_user" >> /root/.profile; \
    else \
        echo "⏭️  Auto switch root ➜ rstudio: DESATIVADO"; \
    fi

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]