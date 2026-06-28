library(dplyr)

#-------------------------------------------------------
# Carrega o conjunto de dados Iris
#-------------------------------------------------------
iris_df <- function() {

  # Lê o arquivo CSV
  df_csv <- read.csv("../../datasets/Iris.csv", stringsAsFactors = FALSE)

  # Renomeia as colunas
  names(df_csv)[names(df_csv) == "SepalLengthCm"] <- "sepal_length"
  names(df_csv)[names(df_csv) == "SepalWidthCm"]  <- "sepal_width"
  names(df_csv)[names(df_csv) == "PetalLengthCm"] <- "petal_length"
  names(df_csv)[names(df_csv) == "PetalWidthCm"]  <- "petal_width"

  # Remove a coluna Id
  df_csv <- df_csv %>%
    select(-Id)

  # Codifica a espécie
  df_csv$encoded_target <- c(
    "Iris-setosa" = 0,
    "Iris-versicolor" = 1,
    "Iris-virginica" = 2
  )[df_csv$Species]

  # Dataset iris do R
  df_sk <- iris

  names(df_sk) <- c(
    "sepal_length",
    "sepal_width",
    "petal_length",
    "petal_width",
    "Species"
  )

  df_sk$encoded_target <- as.numeric(df_sk$Species) - 1

  # Adiciona coluna apenas para demonstração
  df_csv$encoded_target_sk <- df_sk$encoded_target

  target_names <- c(
    "setosa",
    "versicolor",
    "virginica"
  )

  df_csv$species <- target_names[df_csv$encoded_target + 1]

  df <- df_csv %>%
    select(
      sepal_length,
      sepal_width,
      petal_length,
      petal_width,
      species,
      encoded_target
    )

  return(list(
    df = df,
    target_names = target_names
  ))
}

#-------------------------------------------------------
# Exibe DataFrame
#-------------------------------------------------------
display_dataframe <- function(df){
  print(df)
}

#-------------------------------------------------------
# Resumo do dataset
#-------------------------------------------------------
display_dataset_summary <- function(df){

  str(df)

  summary(df)

}

#-------------------------------------------------------
# Seleção de linhas e colunas
#-------------------------------------------------------
demonstrate_dataframe_selection <- function(df){

  # primeira linha
  print(df[1, ])

  # médias
  print(colMeans(df[sapply(df,is.numeric)]))

  # segunda linha
  print(df[2, ])

  # segunda linha, terceira coluna
  print(df[2,3])

}

#-------------------------------------------------------
# Remove linhas por condição
#-------------------------------------------------------
remove_rows_by_condition <- function(){

  dados <- iris_df()
  df <- dados$df

  df <- df %>%
    filter(sepal_length < 4.5)

  return(df)

}

#-------------------------------------------------------
# Concatenação de vetores
#-------------------------------------------------------
demonstrate_series_concatenation <- function(){

  s1 <- c("a","b")
  s2 <- c("c","d")

  # Vertical
  print(c(s1,s2))

  # Horizontal
  print(data.frame(s1,s2))

}

#-------------------------------------------------------
# Merge
#-------------------------------------------------------
demonstrate_dataframe_merge <- function(){

  df1 <- data.frame(
    lkey=c("foo","bar","baz","foo"),
    value=c(1,2,3,5)
  )

  df2 <- data.frame(
    rkey=c("foo","bar","baz","foo"),
    value=c(5,6,7,8)
  )

  resultado <- merge(
    df1,
    df2,
    by.x="lkey",
    by.y="rkey",
    suffixes=c("_left","_right")
  )

  print(resultado)

}

#-------------------------------------------------------
# RIGHT JOIN
#-------------------------------------------------------
demonstrate_dataframe_join <- function(){

  df <- data.frame(
    key=c("K0","K1","K2","K3","K4","K5"),
    A=c("A0","A1","A2","A3","A4","A5")
  )

  other <- data.frame(
    key=c("K0","K1","K2"),
    B=c("B0","B1","B2")
  )

  resultado <- merge(
    df,
    other,
    by="key",
    all.y=TRUE
  )

  return(resultado)

}

#-------------------------------------------------------
# Group By
#-------------------------------------------------------
demonstrate_groupby_aggregations <- function(){

  dados <- iris_df()
  df <- dados$df

  print(
    df %>%
      group_by(encoded_target) %>%
      summarise(total=n())
  )

  print(
    df %>%
      group_by(encoded_target) %>%
      summarise(across(where(is.numeric), min))
  )

}

#-------------------------------------------------------
# Manipulação do DataFrame
#-------------------------------------------------------
demonstrate_dataframe_apply <- function(){

  dados <- iris_df()
  df <- dados$df

  df <- df %>%
    mutate(across(where(is.numeric), ~ . * 2))

  return(df)

}

#-------------------------------------------------------
# Função principal
#-------------------------------------------------------
main <- function(){

  dados <- iris_df()

  df <- dados$df

  display_dataframe(df)

  display_dataset_summary(df)

  demonstrate_dataframe_selection(df)

  remove_rows_by_condition()

  demonstrate_series_concatenation()

  demonstrate_dataframe_merge()

  print(demonstrate_dataframe_join())

  demonstrate_groupby_aggregations()

  print(demonstrate_dataframe_apply())

}

main()