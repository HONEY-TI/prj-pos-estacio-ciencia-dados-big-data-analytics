from sklearn.datasets import load_iris
from sklearn.preprocessing import MinMaxScaler
import pandas as pd


def carregar_base_iris() -> pd.DataFrame:
    """
    Carrega a base de dados Iris.

    Returns:
        pd.DataFrame: DataFrame contendo os atributos da base Iris
        e a coluna de classes codificadas.
    """
    dados = load_iris()

    df = pd.DataFrame(
        dados.data,
        columns=dados.feature_names
    )

    df["encoded_target"] = dados.target

    return df


def inserir_dados_corrompidos(df: pd.DataFrame) -> pd.DataFrame:
    """
    Insere valores nulos e um valor inválido no DataFrame para
    simular problemas de qualidade dos dados.

    Args:
        df (pd.DataFrame): DataFrame original.

    Returns:
        pd.DataFrame: DataFrame com dados corrompidos.
    """
    df = df.copy()

    df.iloc[0, 0] = None
    df.iloc[0, 1] = None
    df.iloc[0, 2] = None
    df.iloc[1, 0] = None
    df.iloc[4, 3] = None
    df.iloc[149, 2] = None

    # Valor extremo apenas para simulação
    df.iloc[3, 3] = -9999999999999999999999999999

    return df


def obter_linhas_com_nulos(df: pd.DataFrame) -> pd.DataFrame:
    """
    Retorna as linhas que possuem pelo menos um valor nulo.

    Args:
        df (pd.DataFrame): DataFrame analisado.

    Returns:
        pd.DataFrame: Linhas com valores nulos.
    """
    return df[df.isna().any(axis=1)]


def remover_nulos(df: pd.DataFrame) -> pd.DataFrame:
    """
    Remove todas as linhas que possuem valores nulos.

    Args:
        df (pd.DataFrame): DataFrame original.

    Returns:
        pd.DataFrame: DataFrame sem valores nulos.
    """
    return df.dropna()


def substituir_nulos_pela_media(df: pd.DataFrame) -> pd.DataFrame:
    """
    Substitui valores nulos pela média da coluna.

    Args:
        df (pd.DataFrame): DataFrame original.

    Returns:
        pd.DataFrame: DataFrame com os valores preenchidos pela média.
    """
    return df.fillna(df.mean(numeric_only=True))


def substituir_nulos_por_zero(df: pd.DataFrame) -> pd.DataFrame:
    """
    Substitui valores nulos por zero.

    Args:
        df (pd.DataFrame): DataFrame original.

    Returns:
        pd.DataFrame: DataFrame sem valores nulos.
    """
    return df.fillna(0)


def substituir_nulos_por_valor_impossivel(
    df: pd.DataFrame,
    valor: int = -999
) -> pd.DataFrame:
    """
    Substitui valores nulos por um valor impossível.

    Args:
        df (pd.DataFrame): DataFrame original.
        valor (int): Valor utilizado na substituição.

    Returns:
        pd.DataFrame: DataFrame com os valores substituídos.
    """
    return df.fillna(valor)


def normalizar_dados(df: pd.DataFrame) -> pd.DataFrame:
    """
    Normaliza os dados utilizando MinMaxScaler.

    Args:
        df (pd.DataFrame): DataFrame original.

    Returns:
        pd.DataFrame: DataFrame normalizado.
    """
    scaler = MinMaxScaler()

    dados_normalizados = scaler.fit_transform(df)

    return pd.DataFrame(
        dados_normalizados,
        columns=df.columns
    ).round(2)


def main():
    """
    Executa todas as etapas de carregamento, tratamento
    e normalização da base de dados Iris.
    """

    # Carrega a base
    iris_df = carregar_base_iris()

    # Insere problemas nos dados
    iris_df = inserir_dados_corrompidos(iris_df)

    print("\nDataFrame com dados corrompidos:")
    print(iris_df)

    print("\nValores nulos:")
    print(iris_df.isna())

    print("\nLinhas com valores nulos:")
    print(obter_linhas_com_nulos(iris_df))

    # Tratamentos
    iris_sem_nulos = remover_nulos(iris_df)
    iris_media = substituir_nulos_pela_media(iris_df)
    iris_zero = substituir_nulos_por_zero(iris_df)
    iris_impossivel = substituir_nulos_por_valor_impossivel(iris_df)

    print("\nDataFrame sem valores nulos:")
    print(iris_sem_nulos)

    print("\nNulos substituídos pela média:")
    print(iris_media)

    print("\nNulos substituídos por zero:")
    print(iris_zero)

    print("\nNulos substituídos por valor impossível:")
    print(iris_impossivel)

    # Normalização (utilizando a base original)
    iris_original = carregar_base_iris()
    iris_normalizado = normalizar_dados(iris_original)

    print("\nDados normalizados:")
    print(iris_normalizado)


if __name__ == "__main__":
    main()