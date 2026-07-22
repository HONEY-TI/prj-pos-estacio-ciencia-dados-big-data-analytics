library(dplyr)

# Carregar o conjunto de dados Iris
iris_df <- function() {
  df <- iris

  # Criar coluna de alvo codificado
  df$encoded_target <- as.numeric(df$Species) - 1

  return(df)
}

# Identificar colunas do tipo character
identificar_object <- function(df) {
  colunas_character <- names(df)[sapply(df, is.character)]

  if (length(colunas_character) > 0) {
    cat("Colunas do tipo 'character':\n")
    for (coluna in colunas_character) {
      cat("-", coluna, "\n")
    }
  } else {
    cat("Não há colunas do tipo 'character'.\n")
  }
}

# Mostrar dataframe
show_df <- function(df) {
  print(df)
}

df <- iris_df()

# Inserindo alguns valores NA para demonstrar o tratamento
df[1, "Sepal.Length"] <- NA
df[5, "Petal.Width"] <- NA

# Substituir NA pela média da coluna
df_mean <- df

colunas_numericas <- sapply(df_mean, is.numeric)

for (coluna in names(df_mean)[colunas_numericas]) {
  media <- mean(df_mean[[coluna]], na.rm = TRUE)
  df_mean[[coluna]][is.na(df_mean[[coluna]])] <- media
}

# Substituir NA por zero
df_zero <- df
df_zero[is.na(df_zero)] <- 0

# Substituir NA por um valor impossível
df_valores_impossiveis <- df
df_valores_impossiveis[is.na(df_valores_impossiveis)] <- -999

show_df(df)
show_df(df_mean)
show_df(df_zero)
show_df(df_valores_impossiveis)

# Inserindo um erro em uma coluna numérica
df$Sepal.Length <- as.character(df$Sepal.Length)
df[1, "Sepal.Length"] <- "erro"

identificar_object(df)

# Novo dataframe
df <- iris_df()

# Escolher linha e coluna numérica aleatórias
set.seed(Sys.time())

linha <- sample(1:nrow(df), 1)

colunas_numericas <- names(df)[sapply(df, is.numeric)]
coluna <- sample(colunas_numericas, 1)

# Converter a coluna para character e inserir erro
df[[coluna]] <- as.character(df[[coluna]])
df[linha, coluna] <- "erro dado corrompido"

identificar_object(df)