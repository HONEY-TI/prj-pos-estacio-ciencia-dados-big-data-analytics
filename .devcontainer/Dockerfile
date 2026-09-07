FROM alexfariakof/rstudio-dev-base:latest

RUN apt-get update && apt-get install -y \
    git \
    gh \
    openssh-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV USERNAME=rstudio
#==========
# Permissões
# ==========================================
RUN mkdir -p /usr/local/share/jupyter/kernels \
    && chown -R ${USERNAME}:${USERNAME} /usr/local/share/jupyter \
    && mkdir -p /home/${USERNAME}/workspaces \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

# -----------------------------------------------------------------------------
# Shell do usuário rstudio
#    .bashrc      → shell interativo  (docker exec -it bash)
#    .bash_profile → shell de login   (VS Code abre bash -l)
# -----------------------------------------------------------------------------
RUN cat > /home/${USERNAME}/.bashrc <<'EOF'
export PATH="/opt/venv/bin:$PATH"
export SPARK_HOME=/opt/spark
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$SPARK_HOME/bin:$SPARK_HOME/sbin:$PATH"
export PATH=$SPARK_HOME/bin:$PATH
export PYSPARK_PYTHON=/opt/venv/bin/python
export PYSPARK_DRIVER_PYTHON=/opt/venv/bin/python

alias cls='clear'
alias py='python3'
alias ll='eza -l -h --group --icons'
alias la='eza -la -hs --group'
alias lt='eza --tree --level=2 --group'

export VIRTUAL_ENV=/opt/venv
export PATH="$VIRTUAL_ENV/bin:$PATH"

if [ -f "$VIRTUAL_ENV/bin/activate" ]; then
    source "$VIRTUAL_ENV/bin/activate"
fi

function ls() { command eza -la --group --group-directories-first "$@"; }

# ==========================================
# VENV + GIT BRANCH NO PROMPT (estilo Kali)
# ==========================================
export MY_VENV=/home/jail/opt/venv

function parse_git_branch() {
    local branch
    branch=$(git branch --show-current 2>/dev/null)
    [ -n "$branch" ] && printf " (%s)" "$branch"
}

function set_venv_prompt() {
    if [ -n "$VIRTUAL_ENV" ]; then
        PS1='\[\e[1;34m\]┌── \[\e[1;32m\](venv) \[\e[0m\](\[\e[1;31m\]\u\[\e[0m\]㉿\[\e[1;36m\]\h\[\e[0m\])-\[\e[1;34m\][\[\e[1;32m\]\w\[\e[0m\]\[\e[1;33m\]$(parse_git_branch)\[\e[0m\]\[\e[1;34m\]]\[\e[0m\]\n\[\e[1;34m\]└─\[\e[0m\]\$ '
    else
        PS1='\[\e[1;34m\]┌── \[\e[0m\](\[\e[1;31m\]\u\[\e[0m\]㉿\[\e[1;36m\]\h\[\e[0m\])-\[\e[1;34m\][\[\e[1;32m\]\w\[\e[0m\]\[\e[1;33m\]$(parse_git_branch)\[\e[0m\]\[\e[1;34m\]]\[\e[0m\]\n\[\e[1;34m\]└─\[\e[0m\]\$ '
    fi
}

function activate() {
    local venv="${1:-$MY_VENV}"

    if [ -z "$venv" ]; then
        echo "Uso: activate /caminho/do/venv"
        return 1
    fi

    if [ ! -f "$venv/bin/activate" ]; then
        echo "Erro: virtualenv não encontrado em: $venv"
        return 1
    fi

    source "$venv/bin/activate"
    set_venv_prompt
}

function desactivate() {
    if type deactivate &>/dev/null; then
        deactivate
    fi

    set_venv_prompt
}

set_venv_prompt
EOF

RUN cat > /home/${USERNAME}/.bash_profile <<'EOF'
[ -f ~/.bashrc ] && source ~/.bashrc
EOF

RUN chown ${USERNAME}:${USERNAME} \
    /home/${USERNAME}/.bashrc \
    /home/${USERNAME}/.bash_profile

COPY entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh \
    && chown root:root /usr/local/bin/docker-entrypoint.sh

RUN mkdir -p /home/${USERNAME}/.ssh \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.ssh \
    && chmod 700 /home/${USERNAME}/.ssh


ARG GITHUB_TOKEN
RUN if [ -n "$GITHUB_TOKEN" ]; then \
      echo "${GITHUB_TOKEN}" | gh auth login --with-token || echo "gh auth falhou, seguindo sem autenticar"; \
    else \
      echo "GITHUB_TOKEN não fornecido, pulando gh auth login"; \
    fi

RUN git config --global user.name "Alex Ribeiro de Faria" \
    && git config --global user.email "135660435+alexribeirofaria@github.com"

RUN cat > /root/.switch_user <<'SWITCHEOF'
if [ "${AUTO_SWITCHED}" != "1" ]; then
    export AUTO_SWITCHED=1
    exec su - rstudio
fi
SWITCHEOF

RUN echo 'source /root/.switch_user' >> /root/.bashrc     && \
    echo 'source /root/.switch_user' >> /root/.bash_profile && \
    echo '. /root/.switch_user'      >> /root/.profile
 
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
