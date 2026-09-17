FROM alexfariakof/rstudio-dev-base:latest
USER root 
    
RUN apt-get update && apt-get install -y \
    openssh-client \
    zsh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

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


# ── Zsh personalizado ───────────────────────────────────────────────────────
RUN cat > /home/rstudio/.zshrc <<'EOF'
export PATH="/bin:/usr/local/bin:/home/rstudio/.local/bin:/home/rstudio/.npm-global/bin:$PATH"
export HISTFILE="$HOME/shell_history/.zsh_history"
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

function ls() {
    command eza -la --group --group-directories-first "$@"
}

alias ll='eza -lh --group --icons'
alias la='eza -lah --group'
alias lt='eza --tree --level=2 --group'

function parse_git_branch() {
    local branch
    branch=$(git branch --show-current 2>/dev/null)

    [[ -n "$branch" ]] && printf " (%s)" "$branch"
}
setopt PROMPT_SUBST

PROMPT=$'\e[1;34m┌── \e[0m(\e[1;31m%n\e[0m㉿\e[1;36m%m\e[0m)-\e[1;34m[\e[1;32m%~\e[1;33m$(parse_git_branch)\e[0m\e[1;34m]\e[0m\n\e[1;34m└─\e[0m%# '
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