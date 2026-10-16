# 🚀 Ambiente RStudio + JupyterLab com Docker

Ambiente de desenvolvimento utilizando:

- 🐳 Docker
- 📊 RStudio Server
- 📓 JupyterLab
- 🐍 Python
- 📈 R
- 🔬 Data Science Stack

---

# 🌐 Serviços Disponíveis

| Serviço | URL |
|---|---|
| 📊 RStudio Server | `http://localhost:8787` |
| 📓 JupyterLab | `http://localhost:8888` |

---

# 📊 Acesso ao RStudio Server

## 🔗 URL

```txt
http://localhost:8787
```

---

## 👤 Usuário

```txt
rdtudio
```

---

## 🔑 Senha

Definida no `docker-compose.yml`:

```yaml
environment:
  PASSWORD: toor
```

---

## ✅ Login Completo

| Campo | Valor |
|---|---|
| 👤 Usuário | `rstudio` |
| 🔑 Senha | `toor` |

---

# 📓 Acesso ao JupyterLab

## 🔗 URL

```txt
http://localhost:8888
```

---

# 🔐 Como Obter o Token do JupyterLab

O JupyterLab gera um token automaticamente por segurança.

---

## 📜 Método 1 — Via Logs do Container

Execute:

```bash
docker logs estacio-dev-container
```

Procure por algo semelhante:

```txt
http://127.0.0.1:8888/lab?token=abc123456
```

ou:

```txt
http://0.0.0.0:8888/lab?token=abc123456
```

---

## 🐳 Método 2 — Dentro do Container

Entrar no container:

```bash
docker exec -it estacio-dev-container bash
```

Listar servidores Jupyter ativos:

```bash
jupyter server list
```

ou:

```bash
jupyter lab list
```

Saída esperada:

```txt
http://localhost:8888/?token=abc123456
```

---
## 🚪 Método 3 de como Acessar o JupyterLab

### Gerar URL Completa do JupyterLab com Token

* 🔍 Comando

```bash
docker logs estacio-dev-container 2>&1 | grep -o 'http://127.0.0.1:8888/lab?token=[^ ]*'
```

Saída Esperada

```txt
http://127.0.0.1:8888/lab?token=abc123456789
```

---

# 🔓 Remover Token do Jupyter (Somente Ambiente Local)

> ⚠️ Recomendado apenas para ambiente local/desenvolvimento.

No `docker-compose.yml`:

```yaml
command: >
  bash -c "
    jupyter lab \
      --ip=0.0.0.0 \
      --port=8888 \
      --no-browser \
      --allow-root \
      --ServerApp.token='' \
      --ServerApp.password='' &
    exec /init
  "
```

---

## 🔄 Rebuild do Container

```bash
docker compose down
docker compose up -d --build
```

---

## ✅ Acesso Sem Token

```txt
http://localhost:8888
```

---

# 🩺 Verificar Serviços em Execução

## 📊 Verificar RStudio Server

```bash
docker exec -it estacio-dev-container bash -c "ps aux | grep rserver"


---

## 📓 Verificar JupyterLab

```bash
docker exec -it estacio-dev-container bash -c "ps aux | grep jupyter"
```

---

# 🌐 Verificar Portas Publicadas

```bash
docker ps
```

Saída esperada:

```txt
0.0.0.0:8787->8787/tcp
0.0.0.0:8888->8888/tcp
```

---

# 🔨 Rebuild Completo do Ambiente

Após alterações no Dockerfile ou docker-compose:

```bash
docker compose down -v
docker compose build --no-cache
docker compose up -d
```

---

# 📁 Estrutura Recomendada

```txt
project/
│
├── .devcontainer/
│   ├── devcontainer.json
│   ├── docker-compose.yml
│   └── Dockerfile
│
├── workspace/
│
└── README.md
```

---

# 🛠️ Stack Utilizada

## 🐍 Python

- JupyterLab
- Pandas
- NumPy
- Matplotlib
- Scikit-Learn
- Polars
- PyArrow

---

## 📈 R

- tidyverse
- IRKernel
- languageserver

---

# 🐳 Comandos Úteis

## ▶️ Subir Ambiente

```bash
docker compose up -d --build
```

---

## ⏹️ Parar Ambiente

```bash
docker compose down
```

---

## 🐚 Entrar no Container

```bash
docker exec -it estacio-dev-container bash
```

---

## 📜 Ver Logs

```bash
docker logs -f estacio-dev-container
```

---

# ✅ Ambiente Pronto

Agora o ambiente possui:

- 📊 RStudio Server
- 📓 JupyterLab
- 🐍 Python
- 📈 R
- 🐳 Docker
- 💻 VSCode DevContainer
- 🔬 Ambiente integrado para Data Science