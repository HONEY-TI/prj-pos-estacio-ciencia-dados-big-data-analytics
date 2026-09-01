import sys
from pathlib import Path
import pandas as pd
from sklearn.datasets import load_iris
import plotly.express as px 
import plotly.io as pio
import plotly.graph_objects as go

# Garante que o pacote `libs` seja encontrado
PYTHON_ROOT = Path(__file__).resolve().parent.parent
if str(PYTHON_ROOT) not in sys.path:
    sys.path.insert(0, str(PYTHON_ROOT))

from libs import get_merge_iris_df

def show_grafico_3d_sepal_iris(iris_df):
    fig = px.scatter_3d(
        iris_df,
        x="sepal_length",
        y="sepal_width",
        z="petal_length", 
        color="species",
        title="Gráfico de Dispersão 3D - Iris",
        labels={
            "sepal_length": "Comprimento da Sépala",
            "sepal_width": "Largura da Sépala",
            "petal_length": "Comprimento da Pétala"
        }
    )
    fig.show(renderer="browser")

def show_grafico_3d_iris(iris_df):
    fig = px.scatter_3d(
        iris_df,
        x="sepal_length",
        y="sepal_width",
        z="petal_width",
        color="petal_length",
        size="petal_length",
        size_max=18,
        symbol="species",
        opacity=0.7,
        title="Gráfico de Dispersão 3D - Iris"
    )

    # Ajusta as margens do gráfico
    fig.update_layout(
        margin=dict(l=0, r=0, b=0, t=40)
    )
    fig.show(renderer="browser")
    

def show_grafico_ploty():
    df = px.data.gapminder()
    fig = px.scatter(df.query("year==2007"), x="gdpPercap", 
    y="lifeExp", size="pop", color="continent",
    hover_name="country", log_x=True, size_max=60)
    fig.show(renderer="browser")

def show_histograma_iris(iris_df):    
    fig = px.histogram(iris_df, x="petal_length", title="Dados Numéricos - Histograma")
    fig.show(renderer="browser")

def show_grafico_dispersao(iris_df):
    fig = px.scatter(iris_df, 
    x="petal_length", 
    y="petal_width",
    color="species",
    title="Dados Numéricos - Gráfico de Dispersão")
    fig.show(renderer="browser")

def show_bar_categoriacao_medalhas():
    df = px.data.medals_long()
    fig = px.bar(df, 
    x="nation", 
    y="count",
    color="medal",
    title="Dados Categóricos - Gráfico de Barras")
    fig.show(renderer="browser")

def show_pie_categorizacao_gorjetas():
    df = px.data.tips()
    fig = px.pie(df, 
    values="tip", 
    names="day",
    title="Dados Categóricos - Gráfico de Pizza/Torta")
    fig.show(renderer="browser")

def show_line_expectativa_de_vida():
    df = px.data.gapminder()
    south_america = [
        "Argentina", "Bolivia", "Brazil", "Chile", "Colombia",
        "Ecuador", "Paraguay", "Peru", "Uruguay", "Venezuela"
    ]

    df = df[df["country"].isin(south_america)]
    fig = px.line(df, 
    x="year", 
    y="lifeExp",
    color="country",
    title="Dados Temporais - Gráfico de Linha")
    fig.show(renderer="browser")
    
def show_boxplot_iris(iris_df):
    fig = px.box(
        iris_df,
        x="species",
        y="petal_length",
        color="species",
        title="Dados Numéricos - Boxplot (Petal Length por Species)"
    )
    fig.show(renderer="browser")

def show_line_com_anotacoes():
    # Dados simulados
    meses = ["Oct", "Nov", "Dec", "Jan", "Feb", "Mar", "Apr", "May", "Jun"]
    vendas = [35, 62, 30, 33, 45, 12, 25, 55, 78]

    fig = go.Figure()

    # Linha principal
    fig.add_trace(go.Scatter(
        x=meses,
        y=vendas,
        mode="lines+markers",
        line=dict(color="black", width=3),
        marker=dict(size=10, color="black")
    ))

    # Anotação 1 (pico)
    fig.add_annotation(
        x="Nov",
        y=62,
        text="Pico de vendas",
        showarrow=True,
        arrowhead=2,
        arrowcolor="black",
        ax=0,
        ay=-40
    )

    # Anotação 2 (queda)
    fig.add_annotation(
        x="Mar",
        y=12,
        text="Queda",
        showarrow=True,
        arrowhead=2,
        arrowcolor="black",
        ax=0,
        ay=40
    )

    # Layout estilo dashboard
    fig.update_layout(
        title="Produce Sales (in thousands USD)",
        xaxis_title="Month",
        yaxis_title="Sales",
        template="simple_white"
    )

    fig.show(renderer="browser")

def main():
    pio.renderers.default = "browser"
    iris_df = get_merge_iris_df()
    print(iris_df.head())
    print(iris_df.columns)
    figs = [        
        lambda: show_grafico_3d_iris(iris_df),
        lambda: show_grafico_3d_sepal_iris(iris_df),
        lambda: show_histograma_iris(iris_df),
        lambda: show_grafico_dispersao(iris_df),
        show_bar_categoriacao_medalhas,
        show_pie_categorizacao_gorjetas,
        show_line_expectativa_de_vida,
        lambda: show_boxplot_iris(iris_df),        
        show_line_com_anotacoes,
        show_grafico_ploty,
    ]

    for f in figs:
        f()
if __name__ == "__main__":
    main()
