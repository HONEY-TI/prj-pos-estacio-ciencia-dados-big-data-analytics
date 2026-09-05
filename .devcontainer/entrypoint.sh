#!/bin/bash

set -e
readonly USER=rstudio

# ── Realinhar UID/GID do node com o dono do /workspaces (bind mount do host) ─
# Assim não depende de saber o UID/GID do host antecipadamente nem de rebuild.
HOST_UID=$(stat -c '%u' /workspace)
HOST_GID=$(stat -c '%g' /workspace)
CURRENT_UID=$(id -u "$USER")
CURRENT_GID=$(id -g "$USER")

#echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

sudo echo "[entrypoint] /workspace pertence a UID:GID ${HOST_UID}:${HOST_GID}"
sudo echo "[entrypoint] usuário '$USER' atualmente é UID:GID ${CURRENT_UID}:${CURRENT_GID}"

# -o (non-unique) evita falha caso o UID/GID alvo já esteja em uso por outro
# usuário/grupo do sistema dentro da imagem (ex: colidir com root, UID 0).
if [ "$HOST_GID" != "$CURRENT_GID" ]; then
    sudo echo "[entrypoint] ajustando GID de '$USER' para $HOST_GID"
    sudo groupmod -o -g "$HOST_GID" "$USER"
fi

if [ "$HOST_UID" != "$CURRENT_UID" ]; then
    sudo echo "[entrypoint] ajustando UID de '$USER' para $HOST_UID"
    sudo usermod -o -u "$HOST_UID" "$USER"
fi

# /home/node e o volume nomeado do vscode-server são gerenciados pelo Docker
# (não são arquivos reais do host), então chown -R aqui é seguro.
sudo chown -R "$USER:$USER" /home/$USER  2>/dev/null || true
sudo chown -R "$USER:$USER" /home/$USER/.ssh 2>/dev/null || true
# /workspace é bind mount do host: depois do realinhamento acima o dono já
# deve bater. Evitamos chown -R recursivo nele (mexeria nos arquivos reais
# do projeto no host e pode ser lento em diretórios grandes); só corrigimos
# o ponto de montagem em si, como fallback.
if [ "$(stat -c '%u:%g' /workspace)" != "$HOST_UID:$HOST_GID" ]; then
sudo chown -R "$USER:$USER" /workspace 2>/dev/null || true
fi

if [ "$1" = "" ] || [ "$1" = "/init" ]; then

    su - rstudio -c "
        jupyter lab \
            --ip='${JUPYTER_IP:-0.0.0.0}' \
            --port='${JUPYTER_PORT:-8888}' \
            --no-browser \
            --notebook-dir='${JUPYTER_NOTEBOOK_DIR:-/workspace/src}' \
            --ServerApp.token='${JUPYTER_TOKEN:-}' \
            --ServerApp.password='${JUPYTER_PASSWORD:-}' \
            --ServerApp.allow_root='${JUPYTER_ALLOW_ROOT:-False}'
    " &

    exec /init
fi


# Shell interativo root com TTY — redirecionar para rstudio
if [ -t 1 ] && [ "$(whoami)" = "root" ] && [ "${AUTO_SWITCHED}" != "1" ]; then
    export AUTO_SWITCHED=1
    exec su - rstudio
fi

# Qualquer outro comando passado diretamente — executar como está
exec "$@"
