import pandas as pd
from sklearn.datasets import load_iris


def iris_df():
    """
    Carrega o conjunto de dados Iris a partir do arquivo CSV e do
    dataset do sklearn, padronizando os nomes das colunas e retornando
    um DataFrame único juntamente com os nomes das classes.
    """

    df_csv = pd.read_csv("Iris.csv")

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

    return df, target_names


def display_dataframe(df):
    """
    Exibe o DataFrame informado.
    """
    print(df)


def display_dataset_summary(df):
    """
    Exibe informações gerais e estatísticas descritivas
    do conjunto de dados.
    """
    df.info()
    df.describe()


def demonstrate_dataframe_selection(df):
    """
    Demonstra diferentes formas de projeção e seleção
    de linhas e colunas utilizando loc e iloc.
    """
    df.loc[0]
    df.describe().loc["mean"]
    df.iloc[1]
    df.iloc[1, 2]


def remove_rows_by_condition():
    """
    Remove registros que atendem a uma condição utilizando query().
    """
    df, _ = iris_df()

    df = df.drop(
        df.query("`sepal_length` >= 4.5").index
    )

    return df


def demonstrate_series_concatenation():
    """
    Demonstra concatenação de Series nas direções
    vertical e horizontal.
    """
    s1 = pd.Series(["a", "b"])
    s2 = pd.Series(["c", "d"])

    pd.concat([s1, s2], axis=0)

    s1 = pd.Series(["a", "b"])
    s2 = pd.Series(["c", "d"])

    pd.concat([s1, s2], axis=1)


def demonstrate_dataframe_merge():
    """
    Demonstra a utilização do método merge()
    entre dois DataFrames.
    """
    df1 = pd.DataFrame({
        "lkey": ["foo", "bar", "baz", "foo"],
        "value": [1, 2, 3, 5]
    })

    df2 = pd.DataFrame({
        "rkey": ["foo", "bar", "baz", "foo"],
        "value": [5, 6, 7, 8]
    })

    print(
        df1.merge(
            df2,
            left_on="lkey",
            right_on="rkey",
            suffixes=("_left", "_right")
        )
    )


def demonstrate_dataframe_join():
    """
    Demonstra o uso do método join()
    entre dois DataFrames.
    """
    df = pd.DataFrame({
        "key": ["K0", "K1", "K2", "K3", "K4", "K5"],
        "A": ["A0", "A1", "A2", "A3", "A4", "A5"]
    })

    other = pd.DataFrame({
        "key": ["K0", "K1", "K2"],
        "B": ["B0", "B1", "B2"]
    })

    resultado = df.join(
        other,
        lsuffix="_caller",
        rsuffix="_other"
    )

    return resultado


def demonstrate_dataframe_join():
    """
    Demonstra a realização de um RIGHT JOIN
    utilizando o método merge().
    """
    df = pd.DataFrame({
        "key": ["K0", "K1", "K2", "K3", "K4", "K5"],
        "A": ["A0", "A1", "A2", "A3", "A4", "A5"]
    })

    other = pd.DataFrame({
        "key": ["K0", "K1", "K2"],
        "B": ["B0", "B1", "B2"]
    })

    resultado = df.merge(
        other,
        on="key",
        how="right"
    )

    return resultado


def demonstrate_groupby_aggregations():
    """
    Demonstra operações de agregação utilizando groupby.
    """
    df, _ = iris_df()

    df.groupby(by=["encoded_target"]).count()
    df.groupby(by=["encoded_target"]).min()


def demonstrate_dataframe_apply():
    """
    Demonstra a manipulação do DataFrame.
    O uso de apply não é necessário, pois o tratamento
    da coluna species já ocorre na função iris_df().
    """
    df, _ = iris_df()

    df = df * 2

    return df


def main():
    """
    Função principal responsável por executar todas
    as demonstrações do exemplo.
    """
    df, _ = iris_df()

    display_dataframe(df)

    display_dataset_summary(df)

    demonstrate_dataframe_selection(df)

    remove_rows_by_condition()

    demonstrate_series_concatenation()

    demonstrate_dataframe_merge()

    demonstrate_dataframe_join()

    demonstrate_dataframe_join()

    demonstrate_groupby_aggregations()

    demonstrate_dataframe_apply()


if __name__ == "__main__":
    main()