FROM alexfariakof/rstudio-dev-base:latest
USER root 
    
RUN apt-get update && apt-get install -y \
    openssh-client \
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

ARG GITHUB_TOKEN
RUN if [ -n "$GITHUB_TOKEN" ]; then \
      printf '%s\n' "$GITHUB_TOKEN" | gh auth login --with-token || echo "gh auth falhou, seguindo sem autenticar"; \
    else \
      echo "GITHUB_TOKEN não fornecido, pulando gh auth login"; \
    fi

RUN git config --global user.name "Alex Ribeiro de Faria" \
    && git config --global user.email "135660435+alexribeirofaria@github.com"


# =============================================================================
# 🔄 AUTO SWITCH — ROOT ➜ NODE
# =============================================================================
# 📌 false = DESATIVADO | true = ATIVADO
# =============================================================================

ARG ENABLE_SWITCH_USER=true

RUN if [ "$ENABLE_SWITCH_USER" = "true" ]; then \
        echo "🔄 Configurando auto switch: root ➜ node"; \
        printf '%s\n' \
            'if [ "${AUTO_SWITCHED}" != "1" ]; then' \
            '    export AUTO_SWITCHED=1' \
            '    exec su - node' \
            'fi' \
            > /root/.switch_user; \
        echo "source /root/.switch_user" >> /root/.bashrc; \
        echo "source /root/.switch_user" >> /root/.bash_profile; \
        echo ". /root/.switch_user" >> /root/.profile; \
    else \
        echo "⏭️  Auto switch root ➜ node: DESATIVADO"; \
    fi

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]