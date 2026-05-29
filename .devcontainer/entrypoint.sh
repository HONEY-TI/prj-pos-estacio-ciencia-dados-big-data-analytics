#!/bin/bash
set -e

# ==========================================
# Entrypoint wrapper para rocker/rstudio
#
# Problema que resolve:
#   O s6-overlay (/init) precisa de root para iniciar os serviços.
#   Mas queremos que o usuário final (docker exec, shell interativo)
#   entre como 'rstudio', não como root.
#
# /root/.bashrc — executado quando root abre qualquer shell interativo
# ==========================================

if [ -t 1 ] && [ "${AUTO_SWITCHED}" != "1" ]; then
    export AUTO_SWITCHED=1
    exec su - rstudio      # substitui o processo root pelo rstudio
fi 