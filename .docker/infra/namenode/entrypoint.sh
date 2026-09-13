#!/bin/bash
set -e

NAME_DIR="/data/name"

if [ ! -d "${NAME_DIR}/current" ]; then
    echo ">> NameNode ainda não formatado. Formatando..."
    hdfs namenode -format -force -nonInteractive
else
    echo ">> NameNode já formatado, pulando format."
fi

echo ">> Iniciando NameNode..."
exec hdfs namenode