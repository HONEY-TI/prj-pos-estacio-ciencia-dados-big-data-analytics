FROM rocker/rstudio:latest

ENV DEBIAN_FRONTEND=noninteractive
ENV USERNAME=rstudio
ENV PATH="/opt/venv/bin:$PATH"

# ==========================================
# Dependências do sistema (root — correto no build)
# ==========================================
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    git \
    curl \
    wget \
    build-essential \
    libssl-dev \
    libcurl4-openssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    nano \
    eza \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ==========================================
# Venv Python: criado como root, dono = rstudio
# ==========================================
RUN python3 -m venv /opt/venv \
    && chown -R ${USERNAME}:${USERNAME} /opt/venv

# ==========================================
# Libs Python instaladas no venv
# ==========================================
RUN /opt/venv/bin/pip install --upgrade pip && \
    /opt/venv/bin/pip install \
    jupyterlab \
    notebook \
    pandas \
    numpy \
    matplotlib \
    seaborn \
    scikit-learn \
    polars \
    pyarrow \
    jupyterlab-git \
    plotly \
    pyspark

# ==========================================
# Pacotes R (root)— tidyverse é o mais pesado (~15 min sem cache)
# -----------------------------------------------------------------------------
RUN R -e "install.packages( \
        c('tidyverse', 'languageserver', 'IRkernel'), \
        repos = 'https://cloud.r-project.org/', \
        quiet = TRUE \
    )" \
    && R -e "IRkernel::installspec(user = FALSE)"


# ==========================================
# Permissões
# ==========================================
RUN mkdir -p /usr/local/share/jupyter/kernels \
    && chown -R ${USERNAME}:${USERNAME} /usr/local/share/jupyter \
    && mkdir -p /home/${USERNAME}/workspace \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}


# -----------------------------------------------------------------------------
# 5. Shell do usuário rstudio
#    .bashrc      → shell interativo  (docker exec -it bash)
#    .bash_profile → shell de login   (VS Code abre bash -l)
# -----------------------------------------------------------------------------
RUN cat > /home/${USERNAME}/.bashrc <<'EOF'
export PATH="/opt/venv/bin:$PATH"
 
alias cls='clear'
alias py='python3'
alias ll='eza -l -h --group --icons'
alias la='eza -la -hs --group'
alias lt='eza --tree --level=2 --group'

alias activate='source /opt/venv/bin/activate'
alias deactivate='deactivate'

ls() { command eza -la --group --group-directories-first "$@"; }

PS1='\[\e[0;32m\][\[\e[1;34m\]\u\[\e[0m\]:\[\e[1;36m\]\w\[\e[0m\]\[\e[1;33m\]$\[\e[0m\]\[\e[0;32m\]]\[\e[0m\]\$ '

source /opt/venv/bin/activate
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

WORKDIR /home/${USERNAME}/workspace

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]