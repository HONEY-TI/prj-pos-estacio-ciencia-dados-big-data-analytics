#!/bin/bash
set -e

NAMENODE_HOST="${NAMENODE_HOST:-namenode}"
NAMENODE_PORT="${NAMENODE_PORT:-9000}"

echo ">> Aguardando NameNode em ${NAMENODE_HOST}:${NAMENODE_PORT}..."
until nc -z "${NAMENODE_HOST}" "${NAMENODE_PORT}"; do
    echo "   NameNode ainda não disponível, tentando novamente em 3s..."
    sleep 3
done

echo ">> NameNode disponível. Iniciando DataNode..."
exec hdfs datanode