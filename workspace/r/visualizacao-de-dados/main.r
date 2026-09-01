install.packages("plotly")
install.packages("gapminder")
library(dplyr)
library(plotly)
library(datasets)

# ---------------------------
# IRIS (equivalente ao sklearn + CSV)
# ---------------------------
get_merge_iris_df <- function() {

  df <- iris %>%
    rename(
      sepal_length = Sepal.Length,
      sepal_width  = Sepal.Width,
      petal_length = Petal.Length,
      petal_width  = Petal.Width,
      species      = Species
    ) %>%
    mutate(
      encoded_target = as.numeric(as.factor(species)) - 1
    )

  return(df)
}

# ---------------------------
# GAPMINDER (dataset base R)
# ---------------------------
data(gapminder, package = "gapminder")

# ---------------------------
# GRÁFICOS
# ---------------------------

show_grafico_plotly <- function() {

  df <- gapminder %>% filter(year == 2007)

  p <-plot_ly(
    df,
    x = ~gdpPercap,
    y = ~lifeExp,
    type = "scatter",
    mode = "markers",
    color = ~continent,
    text = ~country
  )
  print(p)
}

show_histograma_iris <- function(iris_df) {

  p <- plot_ly(
    iris_df,
    x = ~petal_length,
    type = "histogram"
  )
  print(p)
}

show_grafico_dispersao <- function(iris_df) {

  p <- plot_ly(
    iris_df,
    x = ~petal_length,
    y = ~petal_width,
    color = ~species,
    type = "scatter",
    mode = "markers"
  )
  print(p)
}

show_bar_categorias_medalhas <- function() {

  df <- data.frame(
    nation = c("USA", "China", "Russia"),
    count = c(10, 8, 6),
    medal = c("gold", "silver", "bronze")
  )

  p <- plot_ly(
    df,
    x = ~nation,
    y = ~count,
    color = ~medal,
    type = "bar"
  )
  print(p)
}

show_pie_gorjetas <- function() {

  df <- data.frame(
    day = c("Thur", "Fri", "Sat", "Sun"),
    tip = c(20, 10, 30, 40)
  )

  p <- plot_ly(
    df,
    labels = ~day,
    values = ~tip,
    type = "pie"
  )
  print(p)
}

show_line_expectativa_vida <- function() {

  south_america <- c(
    "Argentina", "Bolivia", "Brazil", "Chile", "Colombia",
    "Ecuador", "Paraguay", "Peru", "Uruguay", "Venezuela"
  )

  df <- gapminder %>%
    filter(country %in% south_america)

  p <- plot_ly(
    df,
    x = ~year,
    y = ~lifeExp,
    color = ~country,
    type = "scatter",
    mode = "lines"
  )
  print(p)
}

show_boxplot_iris <- function(iris_df) {

  p <- plot_ly(
    iris_df,
    x = ~species,
    y = ~petal_length,
    color = ~species,
    type = "box"
  )

  print(p)
}
# ---------------------------
# MAIN (equivalente ao Python)
# ---------------------------

main <- function() {

  iris_df <- get_merge_iris_df()

  show_grafico_plotly()
  show_histograma_iris(iris_df)
  show_grafico_dispersao(iris_df)
  show_bar_categorias_medalhas()
  show_pie_gorjetas()
  show_line_expectativa_vida()
  show_boxplot_iris(iris_df)
}

main()