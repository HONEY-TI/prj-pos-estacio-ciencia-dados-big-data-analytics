FROM alexfariakof/rstudio-dev-base:latest

ENV USERNAME=rstudio

# ==========================================
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

alias activate='source /opt/venv/bin/activate'
alias deactivate='deactivate'
alias cpu='cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'

function ls() { command eza -la --group --group-directories-first "$@"; }

#=========================
# Colorized Path with Branch
# =========================

function parse_git_branch() {
    local branch
    branch=$(git branch --show-current 2>/dev/null)
    [ -n "$branch" ] && echo " ($branch)"
}

PS1='\[\e[0;32m\][\[\e[1;34m\]\u\[\e[0m\]:\[\e[1;36m\]\w\[\e[0m\]\[\e[1;33m\]$(parse_git_branch)\[\e[0m\]\[\e[0;32m\]]\[\e[0m\]\$'
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

# Locale
RUN apt-get update && apt-get install -y locales \
    && locale-gen pt_BR.UTF-8 \
    && update-locale LANG=pt_BR.UTF-8

ENV LANG=pt_BR.UTF-8
ENV LANGUAGE=pt_BR:pt
ENV LC_ALL=pt_BR.UTF-8

WORKDIR /workspaces
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]