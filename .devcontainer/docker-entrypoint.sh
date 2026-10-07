#!/bin/bash

set -e
readonly USER="${EXPECTED_USER:-rstudio}"
readonly PROJECT_WORKSPACE=/workspace

# ── Realinhar UID/GID do node com o dono do $PROJECT_WORKSPACE ───────────────
HOST_UID=$(stat -c '%u' $PROJECT_WORKSPACE)
HOST_GID=$(stat -c '%g' $PROJECT_WORKSPACE)
CURRENT_UID=$(id -u "$USER")
CURRENT_GID=$(id -g "$USER")

echo "[entrypoint] $PROJECT_WORKSPACE pertence a UID:GID ${HOST_UID}:${HOST_GID}"
echo "[entrypoint] usuário '$USER' atualmente é UID:GID ${CURRENT_UID}:${CURRENT_GID}"

if [ "$HOST_GID" != "$CURRENT_GID" ]; then
    echo "[entrypoint] ajustando GID de '$USER' para $HOST_GID"
    groupmod -o -g "$HOST_GID" "$USER"
fi

if [ "$HOST_UID" != "$CURRENT_UID" ]; then
    echo "[entrypoint] ajustando UID de '$USER' para $HOST_UID"
    usermod -o -u "$HOST_UID" "$USER"
fi

chown -R "$USER:$USER" /home/$USER 2>/dev/null || true
chown -R "$USER:$USER" /home/$USER/.ssh 2>/dev/null || true
chown -R "$USER:$USER" /home/$USER/.vscode-server 2>/dev/null || true

if [ "$(stat -c '%u:%g' $PROJECT_WORKSPACE)" != "$HOST_UID:$HOST_GID" ]; then
    chown "$USER:$USER" $PROJECT_WORKSPACE 2>/dev/null || true
fi

if [ "$1" = "" ] || [ "$1" = "/init" ]; then

    su - rstudio -c "
        jupyter lab \
            --ip='${JUPYTER_IP:-0.0.0.0}' \
            --port='${JUPYTER_PORT:-8888}' \
            --no-browser \
            --notebook-dir='${JUPYTER_NOTEBOOK_DIR:-/$PROJECT_WORKSPACE}' \
            --ServerApp.token='${JUPYTER_TOKEN:-}' \
            --ServerApp.password='${JUPYTER_PASSWORD:-}' \
            --ServerApp.allow_root='${JUPYTER_ALLOW_ROOT:-False}'
    " &

    exec /init
fi

# ── Processo original do container ──────────────────────────────────
cd $PROJECT_WORKSPACE
exec su - "$USER"
#exec "$@"