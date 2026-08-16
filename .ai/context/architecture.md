---
name: architecture
description: Arquitetura da estrutura .ai como fonte central de conhecimento e integração dos agentes.
---

# Architecture

## 🎯 Objetivo

Este arquivo descreve a arquitetura da estrutura `.ai`, responsável por centralizar conhecimento, configurações e recursos utilizados pelos agentes integrados ao projeto.

A estrutura foi criada para manter uma única fonte de verdade, permitindo que diferentes agentes compartilhem o mesmo contexto sem duplicação de informações.

## 🏗️ Estrutura Principal

A organização base do projeto:

```
.ai/
├── system.md
├── memory.json
├── config/
├── context/
├── prompts/
├── tasks/
├── agents/
├── skills/
├── tools/
├── runs/
└── logs/
```

## 📚 Componentes

### 🧠 system

Arquivo responsável pelas instruções gerais compartilhadas entre os agentes.

Define:

- comportamento esperado;
- princípios;
- regras gerais de atuação.

---

### 📖 context

Local destinado às informações permanentes do projeto.

Contém conhecimentos que devem permanecer disponíveis para os agentes:

- arquitetura;
- domínio;
- projeto;
- regras.

---

### 💬 prompts

Local destinado aos modelos reutilizáveis de interação.

Centraliza padrões de comunicação e instruções específicas.

---

### 📋 tasks

Local destinado aos procedimentos executáveis e fluxos padronizados.

Representa processos que podem ser repetidos pelos agentes.

---

### 🧰 skills

Local destinado às capacidades reutilizáveis.

Uma skill pode conter:

- documentação;
- exemplos;
- templates;
- instruções específicas.

---

### 🤖 agents

Local destinado às definições dos agentes especializados.

Cada agente pode possuir responsabilidades e comportamentos específicos.

---

### ⚙️ config

Local destinado às configurações específicas das integrações e ferramentas.

---

### 💾 memory

Arquivo responsável pelo armazenamento persistente de informações utilizadas pelo ambiente.

---

### ▶️ runs

Local destinado aos registros de execuções.

---

### 📜 logs

Local destinado aos registros operacionais e históricos.

---

## 🔗 Integração dos Agentes

Os agentes externos podem possuir estruturas próprias de integração:

- `.blackbox/`
- `.codex/`
- `.claude/`

Essas estruturas não representam fontes independentes.

O conteúdo principal permanece centralizado em:

```
.ai/
```

## 🛡️ Princípios Arquiteturais

- Uma única fonte de verdade.
- Conhecimento centralizado.
- Evitar duplicação entre agentes.
- Estrutura simples e previsível.
- Evolução incremental.
- Compatibilidade entre integrações.

## 🔄 Evolução

Novos agentes ou capacidades devem ser adicionados utilizando a estrutura existente.

A expansão deve ocorrer por extensão dos componentes atuais, evitando novas estruturas paralelas.