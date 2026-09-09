---
name: feature-07-corrigir-sincronizacao-de-submodulos-no-vs-code
file: feature-07-corrigir-sincronizacao-de-submodulos-no-vs-code.md
description: >
  Corrigir a sincronização automática de submódulos executada pelo VS Code,
  evitando locks e falhas durante a atualização remota.
---

## Contexto / Problema

O comando de atualização automática dos submódulos pode falhar quando existem
arquivos de lock ou quando os repositórios ainda não fizeram fetch das referências remotas.

## Objetivo

Centralizar no VS Code um fluxo robusto para remover locks, sincronizar URLs,
buscar referências remotas e atualizar os submódulos.

## Critérios de aceite

Rascunho — revisar e complementar manualmente.
