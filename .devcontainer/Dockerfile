FROM alexfariakof/rstudio-base:latest AS base     
ARG USERNAME=rstudio
ENV USERNAME=${USERNAME}
ARG WORKSPACE=/workspace
ENV WORKSPACE=${WORKSPACE}

# ==========================================
# Dependências do sistema
# ==========================================
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        xterm \
        iptables \
        ipset \
        iproute2 \
        iputils-ping \
        dnsutils \
        aggregate \
        gh \
        git \
        git-lfs \
        openssh-client \
        jq \
        procps \
        xdg-utils \
        xauth \
        xclip \
        xsel \
        bubblewrap \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN git lfs install --system

# =============================================================================
# Instalação/atualização das dependências Python
# =============================================================================
COPY .devcontainer/requirements.in /usr/local/share/requirements.in
RUN set -e; \
    PIP="/opt/venv/bin/python -m pip"; \
    OUT="$($PIP install --dry-run --no-cache-dir -r /usr/local/share/requirements.in 2>&1)"; \
    case "$OUT" in \
        *"Would install"*) \
            echo "Pacotes ausentes ou desatualizados:"; \
            echo "$OUT" | grep "Would install"; \
            $PIP install --no-cache-dir -r /usr/local/share/requirements.in; \
            chown -R ${USERNAME}:${USERNAME} /opt/venv ;; \
        *) echo "Requirements já satisfeitos, nada a instalar." ;; \
    esac; \
    rm -f /usr/local/share/requirements.in
    
# =============================================================================
# Instalação codex cli
# =============================================================================
RUN npm install -g @openai/codex@latest --include=optional \
    && codex --version

# =============================================================================
# SSH
# =============================================================================
RUN mkdir -p /home/${USERNAME}/.ssh \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.ssh \
    && chmod 700 /home/${USERNAME}/.ssh

# =============================================================================
# Shell history global: 
# =============================================================================
RUN mkdir -p /home/${USERNAME}/shell_history \
    && touch /home/${USERNAME}/shell_history/.bash_history \
             /home/${USERNAME}/shell_history/.zsh_history \
    && rm -rf /home/${USERNAME}/.bash_history \
               /home/${USERNAME}/.zsh_history \
    && ln -s /home/${USERNAME}/shell_history/.bash_history \
             /home/${USERNAME}/.bash_history \
    && ln -s /home/${USERNAME}/shell_history/.zsh_history \
             /home/${USERNAME}/.zsh_history \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/shell_history \
    && chmod 664 /home/${USERNAME}/.bash_history \
                 /home/${USERNAME}/.zsh_history \
    && chmod 664 /home/${USERNAME}/shell_history/.bash_history \
                 /home/${USERNAME}/shell_history/.zsh_history

RUN mkdir -p /home/${USERNAME}/.vscode-server  \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.vscode-server  \
    && chmod 770 /home/${USERNAME}/.vscode-server 

COPY .ai/tools/rstudio-entrypoint.sh /usr/local/sbin/docker-entrypoint.sh
RUN chmod 700 /usr/local/sbin/docker-entrypoint.sh
RUN chmod +x /usr/local/sbin/docker-entrypoint.sh

COPY .ai/setup-codex-any-user.sh /usr/local/sbin/setup-codex.sh
COPY .ai/tools/post-start.sh /usr/local/sbin/post-start.sh
COPY .ai/tools/open-user-shell.sh /usr/local/sbin/open-user-shell.sh

RUN chmod 755 /usr/local/sbin/post-start.sh \
            /usr/local/sbin/setup-codex.sh \
            /usr/local/sbin/open-user-shell.sh

RUN chmod +x /usr/local/sbin/post-start.sh \
            /usr/local/sbin/setup-codex.sh \
            /usr/local/sbin/open-user-shell.sh

RUN echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
RUN echo "${USERNAME} ALL=(root) NOPASSWD: \
        /usr/local/sbin/setup-codex.sh, \
        /usr/local/sbin/open-user-shell.sh" \        
        > /etc/sudoers.d/${USERNAME}-dev \
    && chmod 0440 /etc/sudoers.d/${USERNAME}-dev \
    && visudo -cf /etc/sudoers.d/${USERNAME}-dev


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

RUN chsh -s /bin/zsh 2>/dev/null || true;

USER root
WORKDIR ${WORKSPACE}
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["/init"]

