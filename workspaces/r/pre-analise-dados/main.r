#-------------------------------------------------------
# Carrega a base Iris
#-------------------------------------------------------
carregar_base_iris <- function() {

  df <- iris

  names(df) <- c(
    "sepal_length",
    "sepal_width",
    "petal_length",
    "petal_width",
    "species"
  )

  df$encoded_target <- as.numeric(df$species) - 1

  return(df)
}

#-------------------------------------------------------
# Insere dados corrompidos
#-------------------------------------------------------
inserir_dados_corrompidos <- function(df){

  df[1,1] <- NA
  df[1,2] <- NA
  df[1,3] <- NA
  df[2,1] <- NA
  df[5,4] <- NA
  df[150,3] <- NA

  # Valor extremo
  df[4,4] <- -999999999999999999

  return(df)

}

#-------------------------------------------------------
# Linhas contendo valores nulos
#-------------------------------------------------------
obter_linhas_com_nulos <- function(df){

  return(df[!complete.cases(df), ])

}

#-------------------------------------------------------
# Remove linhas com valores nulos
#-------------------------------------------------------
remover_nulos <- function(df){

  return(na.omit(df))

}

#-------------------------------------------------------
# Substitui NA pela média
#-------------------------------------------------------
substituir_nulos_pela_media <- function(df){

  for(col in names(df)){

    if(is.numeric(df[[col]])){

      media <- mean(df[[col]], na.rm = TRUE)

      df[[col]][is.na(df[[col]])] <- media

    }

  }

  return(df)

}

#-------------------------------------------------------
# Substitui NA por zero
#-------------------------------------------------------
substituir_nulos_por_zero <- function(df){

  df[is.na(df)] <- 0

  return(df)

}

#-------------------------------------------------------
# Substitui NA por valor impossível
#-------------------------------------------------------
substituir_nulos_por_valor_impossivel <- function(df, valor=-999){

  df[is.na(df)] <- valor

  return(df)

}

#-------------------------------------------------------
# Normalização Min-Max
#-------------------------------------------------------
normalizar_dados <- function(df){

  df_normalizado <- df

  colunas <- sapply(df_normalizado, is.numeric)

  df_normalizado[colunas] <- lapply(
    df_normalizado[colunas],
    function(x){

      (x - min(x))/(max(x)-min(x))

    }
  )

  df_normalizado[colunas] <- round(
    df_normalizado[colunas],
    2
  )

  return(df_normalizado)

}

#-------------------------------------------------------
# Programa principal
#-------------------------------------------------------
main <- function(){

  iris_df <- carregar_base_iris()

  iris_df <- inserir_dados_corrompidos(iris_df)

  cat("\nDataFrame com dados corrompidos\n")
  print(iris_df)

  cat("\nValores nulos\n")
  print(is.na(iris_df))

  cat("\nLinhas com valores nulos\n")
  print(obter_linhas_com_nulos(iris_df))

  iris_sem_nulos <- remover_nulos(iris_df)

  iris_media <- substituir_nulos_pela_media(iris_df)

  iris_zero <- substituir_nulos_por_zero(iris_df)

  iris_impossivel <- substituir_nulos_por_valor_impossivel(iris_df)

  cat("\nDataFrame sem valores nulos\n")
  print(iris_sem_nulos)

  cat("\nNulos substituídos pela média\n")
  print(iris_media)

  cat("\nNulos substituídos por zero\n")
  print(iris_zero)

  cat("\nNulos substituídos por valor impossível\n")
  print(iris_impossivel)

  iris_original <- carregar_base_iris()

  iris_normalizado <- normalizar_dados(iris_original)

  cat("\nDados normalizados\n")
  print(iris_normalizado)

}

main()