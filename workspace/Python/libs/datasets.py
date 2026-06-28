from sklearn.datasets import load_iris
import pandas as pd
from pathlib import Path
import sys

PATH = Path(__file__).resolve().parent

def get_iris_df():
    data_iris = load_iris()

    iris_df = pd.DataFrame(
        data_iris.data,
        columns=data_iris.feature_names
    )

    iris_df["encoded_target"] = data_iris.target

    return iris_df


def get_merge_iris_df():
    """
    Carrega o conjunto de dados Iris a partir do arquivo CSV e do
    dataset do sklearn, padronizando os nomes das colunas e retornando
    um DataFrame único juntamente com os nomes das classes.
    """

    df_csv = pd.read_csv(f"{PATH}/Iris.csv")

    df_csv = df_csv.rename(columns={
        "SepalLengthCm": "sepal_length",
        "SepalWidthCm": "sepal_width",
        "PetalLengthCm": "petal_length",
        "PetalWidthCm": "petal_width",
    })

    df_csv = df_csv.drop(columns=["Id"])

    df_csv["encoded_target"] = df_csv["Species"].map({
        "Iris-setosa": 0,
        "Iris-versicolor": 1,
        "Iris-virginica": 2,
    })

    iris = load_iris()

    df_sk = pd.DataFrame(
        iris.data,
        columns=[
            "sepal_length",
            "sepal_width",
            "petal_length",
            "petal_width"
        ]
    )

    df_sk["encoded_target"] = iris.target

    df = df_csv.copy()
    df["encoded_target_sk"] = df_sk["encoded_target"]

    target_names = ["setosa", "versicolor", "virginica"]

    df["species"] = df["encoded_target"].map(
        lambda x: target_names[int(x)]
    )

    df = df[[
        "sepal_length",
        "sepal_width",
        "petal_length",
        "petal_width",
        "species",
        "encoded_target"
    ]]

    return df