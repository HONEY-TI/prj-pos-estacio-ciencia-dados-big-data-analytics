# =============================================================================
# Node.js 24 + npm + OpenAI Codex
# =============================================================================
FROM node:24-bookworm-slim AS node

RUN npm install -g npm@12.0.2 \
    && npm install -g @openai/codex

# =============================================================================
# Stage final
# =============================================================================
FROM alexfariakof/rstudio-base:latest AS final
ENV USERNAME=rstudio

# ==========================================
# Dependências do sistema (root — correto no build)
# ==========================================
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    git \
    gh \
    curl \
    build-essential \
    nano \
    eza \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Node.js + npm + Codex
# =============================================================================
COPY --from=node /usr/local /usr/local
ENV PATH="/usr/local/bin:${PATH}"

# =============================================================================
# npm global do usuário rstudio
# =============================================================================
RUN mkdir -p /home/${USERNAME}/.npm-global \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.npm-global \
    && su - ${USERNAME} -c 'npm config set prefix /home/${USERNAME}/.npm-global'

ENV PATH="/home/${USERNAME}/.npm-global/bin:${PATH}"

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

# Virtualenv
if [ -f "${VIRTUAL_ENV}/bin/activate" ]; then
    source "${VIRTUAL_ENV}/bin/activate"
fi

# Aliases
alias cls='clear'
alias py='python3'
alias ll='eza -l -h --group '
alias la='eza -la -h --group '
alias lt='eza --tree --level=2 --group'

ls() {
    command eza -la --group-directories-first "$@"
}

# Git
parse_git_branch() {
    local branch
    branch=$(git branch --show-current 2>/dev/null)
    [ -n "$branch" ] && printf " (%s)" "$branch"
}

# Prompt
set_venv_prompt() {
    local venv_name=""

    if [ -n "${VIRTUAL_ENV:-}" ]; then
        venv_name="(venv) "
    fi

    PS1='\[\e[1;34m\]┌── \[\e[1;32m\]'"${venv_name}"'\[\e[0m\](\[\e[1;31m\]\u\[\e[0m\]㉿\[\e[1;36m\]\h\[\e[0m\])-\[\e[1;34m\][\[\e[1;32m\]\w\[\e[0m\]\[\e[1;33m\]$(parse_git_branch)\[\e[0m\]\[\e[1;34m\]]\[\e[0m\]\n\[\e[1;34m\]└─\[\e[0m\]\$ '
}

activate() {
    local venv="${1:-$VIRTUAL_ENV}"

    if [ ! -f "$venv/bin/activate" ]; then
        echo "Erro: virtualenv não encontrado em: $venv"
        return 1
    fi

    source "$venv/bin/activate"
    set_venv_prompt
}

deactivate_venv() {
    if type deactivate &>/dev/null; then
        deactivate
    fi

    set_venv_prompt
}

set_venv_prompt
EOF

RUN cat > /home/${USERNAME}/.bash_profile <<'EOF'
[ -f "${HOME}/.bashrc" ] && source "${HOME}/.bashrc"
EOF

RUN chown ${USERNAME}:${USERNAME} \
    /home/${USERNAME}/.bashrc \
    /home/${USERNAME}/.bash_profile


    RUN cat > /root/.switch_user <<'SWITCHEOF'
if [ "${AUTO_SWITCHED}" != "1" ]; then
    export AUTO_SWITCHED=1
    exec su - rstudio
fi
SWITCHEOF

RUN echo 'source /root/.switch_user' >> /root/.bashrc     && \
    echo 'source /root/.switch_user' >> /root/.bash_profile && \
    echo '. /root/.switch_user'      >> /root/.profile