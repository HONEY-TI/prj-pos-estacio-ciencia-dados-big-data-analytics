FROM rocker/rstudio:latest

ENV DEBIAN_FRONTEND=noninteractive
ENV USERNAME=rstudio
ENV PATH="/opt/venv/bin:$PATH"

# ==========================================
# Dependências do sistema (root — correto no build)
# ==========================================
RUN apt-get update && apt-get install -y \
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
        plotly

# ==========================================
# Pacotes R (root)
# ==========================================
RUN R -e "install.packages(c( \
    'tidyverse', \
    'languageserver', \
    'IRkernel' \
    ), repos='https://cloud.r-project.org/')"

# ==========================================
# Kernel IRkernel global
# ==========================================
RUN R -e "IRkernel::installspec(user = FALSE)"

# ==========================================
# Permissões
# ==========================================
RUN mkdir -p /usr/local/share/jupyter/kernels \
    && chown -R ${USERNAME}:${USERNAME} /usr/local/share/jupyter \
    && mkdir -p /home/${USERNAME}/workspace \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

# ==========================================
# Shell do usuário rstudio:
#   - venv sempre ativo ao abrir qualquer terminal
#   - aliases e prompt colorido mostrando (venv)
#
# .bashrc      → shell interativo (docker exec -it container bash)
# .bash_profile → shell de login  (VS Code Dev Containers usa bash -l)
# ==========================================
RUN cat > /home/${USERNAME}/.bashrc <<'RSTUDIOEOF'
# Ativa o venv automaticamente
source /opt/venv/bin/activate

export PATH="/opt/venv/bin:$PATH"

# Aliases
alias cls='clear'
alias py='python3'
alias ll='eza -l -h --group --icons'
alias la='eza -la -hs --group'
alias lt='eza --tree --level=2 --group'

ls() {
    command eza -la --group --group-directories-first "$@"
}

# Prompt: (venv) rstudio:/caminho$
PS1='\[\e[0;32m\](venv)\[\e[0m\] \[\e[1;34m\]\u\[\e[0m\]:\[\e[1;36m\]\w\[\e[0m\]\$ '
RSTUDIOEOF

# .bash_profile carrega .bashrc — cobre shell de login do VS Code
RUN cat > /home/${USERNAME}/.bash_profile <<'PROFILEEOF'
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi
PROFILEEOF

RUN chown ${USERNAME}:${USERNAME} \
    /home/${USERNAME}/.bashrc \
    /home/${USERNAME}/.bash_profile

# ==========================================
# Auto-switch root → rstudio em qualquer tipo de shell root
#
# VS Code Dev Containers: abre bash -l → lê .bash_profile → .profile
# docker exec -it bash  : abre shell interativo → lê .bashrc
# Ambos redirecionam para o mesmo script /root/.switch_user
#
# PARA ENTRAR COMO ROOT (manutenção):
#   docker exec -it container bash --norc --noprofile
# ==========================================
RUN cat > /root/.switch_user <<'SWITCHEOF'
if [ "${AUTO_SWITCHED}" != "1" ]; then
    export AUTO_SWITCHED=1
    exec su - rstudio
fi
SWITCHEOF

RUN echo 'source /root/.switch_user' >> /root/.bashrc     && \
    echo 'source /root/.switch_user' >> /root/.bash_profile && \
    echo '. /root/.switch_user'      >> /root/.profile

# ==========================================
# Serviço Jupyter via s6-overlay
# s6 inicia como root → s6-setuidgid troca para rstudio antes do exec
# ==========================================
RUN mkdir -p /etc/services.d/jupyter && \
    cat > /etc/services.d/jupyter/run <<'S6EOF'
#!/bin/bash
exec s6-setuidgid rstudio /opt/venv/bin/jupyter lab \
    --ip=0.0.0.0 \
    --port=8888 \
    --no-browser \
    --notebook-dir=/home/rstudio/workspace \
    --ServerApp.token='' \
    --ServerApp.password='' \
    --ServerApp.allow_root=False
S6EOF

RUN chmod +x /etc/services.d/jupyter/run && \
    printf '#!/bin/bash\nexit 0\n' > /etc/services.d/jupyter/finish && \
    chmod +x /etc/services.d/jupyter/finish

EXPOSE 8787 8888

WORKDIR /home/${USERNAME}/workspace