# ============================================================
# Teste de integração RStudio + PostgreSQL
#
# Objetivo:
# - Validar comunicação RStudio -> PostgreSQL.
# - Instalar dependências R caso não existam.
# - Validar conexão com banco PostgreSQL.
# - Criar tabela de teste.
# - Inserir dados.
# - Consultar resultado.
# - Encerrar conexão.
#
# PostgreSQL Docker:
#   Host: postgres-db
#   Porta: 5432
#   Banco: analytics
#   Usuário: admin
#
# IMPORTANTE:
# Este script deve ser executado dentro da rede Docker.
# O host "postgres-db" é o nome do serviço no docker-compose.
# ============================================================


# ============================================================
# Verifica e instala pacotes R necessários
#
# Caso o pacote já exista, não reinstala.
# ============================================================

pacotes <- c(
  "DBI",
  "RPostgres"
)

instalar <- pacotes[
  !(pacotes %in% installed.packages()[, "Package"])
]


if(length(instalar) > 0) {

  install.packages(instalar)

}


# ============================================================
# Carrega bibliotecas
# ============================================================

library(DBI)
library(RPostgres)



# ============================================================
# Conexão PostgreSQL
#
# Dentro do Docker:
#
#   CORRETO:
#       host = "postgres-db"
#
#   INCORRETO:
#       host = "localhost"
#
# Porque localhost aponta para o container RStudio,
# e não para o container PostgreSQL.
# ============================================================

con <- dbConnect(
  RPostgres::Postgres(),
  host = "postgres-db",
  port = 5432,
  dbname = "analytics",
  user = "admin",
  password = "admin"
)



# ============================================================
# Validação da conexão
#
# TRUE  = conexão ativa
# FALSE = conexão inválida
# ============================================================

cat("Conexão PostgreSQL:",
    dbIsValid(con),
    "\n"
)



# ============================================================
# Lista tabelas existentes
#
# Resultado inicial esperado:
#
# character(0)
#
# Significa:
# - conexão OK;
# - banco acessível;
# - nenhuma tabela criada.
# ============================================================

print(dbListTables(con))



# ============================================================
# Criar tabela de teste
#
# IMPORTANTE:
# RPostgres não permite múltiplos comandos SQL
# dentro do mesmo dbExecute() preparado.
#
# Por isso DROP e CREATE são executados separadamente.
#
# A tabela é recriada para permitir executar o teste
# várias vezes sem conflito.
# ============================================================


dbExecute(
  con,
  "DROP TABLE IF EXISTS alunos;"
)


dbExecute(
  con,
  "
  CREATE TABLE alunos (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(100),
    curso VARCHAR(100)
  );
  "
)



# ============================================================
# Inserir dados de teste
# ============================================================

dbExecute(
  con,
  "
  INSERT INTO alunos(nome, curso)
  VALUES
  ('Alex', 'Big Data');
  "
)



# ============================================================
# Consultar resultado
# ============================================================

resultado <- dbGetQuery(
  con,
  "SELECT * FROM alunos;"
)


print(resultado)



# ============================================================
# Resultado esperado:
#
#   id   nome   curso
#    1   Alex   Big Data
#
# ============================================================



# ============================================================
# Limpeza
#
# Fecha a conexão com PostgreSQL.
# ============================================================

dbDisconnect(con)


cat("Teste finalizado com sucesso.\n")