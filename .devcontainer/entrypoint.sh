#!/bin/bash

set -e

if [ "$1" = "" ] || [ "$1" = "/init" ]; then

    su - rstudio -c "
        jupyter lab \
            --ip='${JUPYTER_IP:-0.0.0.0}' \
            --port='${JUPYTER_PORT:-8888}' \
            --no-browser \
            --notebook-dir='${JUPYTER_NOTEBOOK_DIR:-/home/rstudio/workspace}' \
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