---
name: sem2-ciclo-de-vida-e-linguagem-r
pr: 31
title: "PR(#31)-sem2-ciclo-de-vida-e-linguagem-r"
branch: feature/sem2-ciclo-de-vida-e-linguagem-r
base: main
extends: feature-12-sem2-ciclo-de-vida-e-linguagem-r
status: merged
---

## Descrição

Atualiza o material da disciplina **Sem2 — Ciclo de Vida e Linguagem R**, com conteúdo introdutório sobre amostras aleatórias, estatísticas amostrais e estimadores.

Também inclui ajustes no ambiente do monorepositório e a atualização do submódulo da disciplina.

## Escopo

- Adicionar os textos dos módulos 1 e 2 do Tema 2.
- Adicionar as imagens utilizadas nos materiais didáticos.
- Atualizar a configuração do ambiente e dos submódulos.
- Integrar a alteração do submódulo por meio da PR externa #3.

## Repositórios e PRs

| Repositório | Branch | PR | Estado |
| --- | --- | --- | --- |
| Repositório pai | `main` | [#31](https://github.com/HONEY-TI/prj-pos-estacio-ciencia-dados-big-data-analytics/pull/31) | Mesclada por squash |
| Submódulo Sem2 | `main` | [#3](https://github.com/HONEY-TI/sem2-ciclo-de-vida-e-linguagem-r/pull/3) | Mesclada por squash |

## Estatísticas do submódulo

| Métrica | Valor |
| --- | ---: |
| Commits de conteúdo | 1 |
| Arquivos alterados | 9 |
| Linhas adicionadas | 375 |
| Linhas removidas | 0 |

## Estatísticas da PR principal

| Métrica | Valor |
| --- | ---: |
| Commits | 2 |
| Arquivos alterados | 6 |
| Linhas adicionadas | 180 |
| Linhas removidas | 47 |

## Checklist

- [x] Conteúdo organizado em módulos.
- [x] Imagens PNG verificadas.
- [x] PR externa criada.
- [x] PR externa mesclada por squash.
- [x] Ponteiro do submódulo atualizado no repositório pai.
- [ ] Revisão funcional.
- [ ] Validação em ambiente Linux/jail.

## Commits de conteúdo

- `feat(amostragem): adicionar conteúdo do tema 2`
  - Adiciona os textos e os recursos visuais do Tema 2.
  - Referências: `#31` e `#3`.

- `feat(integracao): integrar conteúdo da disciplina Sem2`
  - Atualiza o gitlink do submódulo, o ambiente e esta documentação.
  - Referência: `#31`.
