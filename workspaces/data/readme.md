---
name: data
description: Pasta utilizada para armazenamento e integração de dados em ambientes de Data Science, RStudio, Jupyter e Python.
---

# 📂 Data

A pasta `data` é utilizada para organizar e disponibilizar dados consumidos pelos projetos executados.

## 🎯 Objetivo

Centralizar o acesso aos dados utilizados em análises, estudos, pipelines e modelos de Machine Learning, garantindo persistência e organização do ambiente.

## 🌐 Fontes de dados

Os dados podem vir de diferentes origens, como:

### 📄 Arquivos locais

- CSV
- Excel
- JSON
- TXT

### 🗄️ Bancos de dados

- Cassandra
- MySQL
- PostgreSQL
- SQL Server
- Oracle
- MongoDB
- CosmosDB
- DynamoDB

### ☁️ Serviços externos

- APIs REST
- Data Lakes
- Data Warehouses
- Storage em nuvem (S3, Azure Blob, Google Cloud Storage, etc)

## 🐳 Utilização dentro dos containers

A pasta pode ser montada como volume Docker para acesso por:

- RStudio
- Jupyter Notebook / JupyterLab
- Scripts Python
- Scripts R
- Pipelines ETL/ELT
- Processos de IA e Machine Learning

## 🗂️ Estrutura sugerida da pasta `data`

````markdown id="s2nv7k"
## 🗂️ Estrutura sugerida da pasta `data`

A organização abaixo ajuda a manter os dados separados por finalidade, facilitando manutenção, rastreabilidade e reutilização dos projetos.

```text
data/
├── 📥 raw/              # Dados brutos originais sem tratamento
├── 🧹 processed/        # Dados tratados e transformados
├── 🌐 external/         # Dados importados de APIs, terceiros ou parceiros
├── 🧠 models/           # Modelos treinados e artefatos de Machine Learning
├── 📊 analytics/        # Resultados de análises, relatórios e dashboards
├── 🔄 staging/          # Área temporária para ETL/ELT e integração
├── 🧪 sandbox/          # Experimentos e testes exploratórios
├── ⚡ temp/             # Arquivos temporários e cache
└── 📚 metadata/         # Dicionários de dados, schemas e documentação
````

## 📌 Significado das principais pastas

| Pasta          | Objetivo                                               |
| -------------- | ------------------------------------------------------ |
| 📥 `raw`       | Armazena dados originais recebidos das fontes          |
| 🧹 `processed` | Contém dados limpos e preparados para análise          |
| 🌐 `external`  | Dados externos obtidos via APIs, fornecedores ou cloud |
| 🧠 `models`    | Modelos treinados, serializados e versionados          |
| 📊 `analytics` | Outputs analíticos, gráficos e relatórios              |
| 🔄 `staging`   | Área intermediária de integração e transformação       |
| 🧪 `sandbox`   | Espaço livre para estudos e experimentações            |
| ⚡ `temp`       | Arquivos temporários gerados durante execuções         |
| 📚 `metadata`  | Informações estruturais sobre os dados                 |

## ✅ Boas práticas e benefícios da organização 

* Melhor separação entre dados brutos e processados
* Facilita pipelines ETL/ELT
* Ajuda na governança e rastreabilidade
* Simplifica integração com Docker e notebooks
* Facilita colaboração entre times de dados
* Reduz riscos de sobrescrita acidental
* Utilizar nomes padronizados