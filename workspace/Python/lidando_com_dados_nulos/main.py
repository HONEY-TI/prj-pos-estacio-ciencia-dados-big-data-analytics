from sklearn.datasets import load_iris
import pandas as pd
import random

def iris_df():
    data_iris = load_iris()

    iris_df = pd.DataFrame(
        data_iris.data,
        columns=data_iris.feature_names
    )

    iris_df["encoded_target"] = data_iris.target

    return iris_df

def identificar_object(df):
    colunas_object = df.select_dtypes(include=['object']).columns.tolist()

    if colunas_object:
        print("Colunas do tipo 'object':")
        for coluna in colunas_object:
            print(f"- {coluna}")
    else:
        print("Não há colunas do tipo 'object'.")

def show(df):
  print(df)

df=iris_df()

# lidando com dados nulos, substituição
df_mean = df.fillna(df.mean) ## subistituir pela média da coluna 
df_zero = df.fillna(0) # Subistituir por zero 
df_valores_impossiveis = df.fillna(-999) ## subistituir por valores impossiveis 

show(df)
show(df_mean)
show(df_zero)
show(df_valores_impossiveis)

df.loc[0, 'sepal_length'] = 'erro'
identificar_object(df)


df = iris_df()
linha = random.randint(0, len(df) - 1)
coluna = random.choice(df.select_dtypes(include="number").columns)
df[coluna] = df[coluna].astype(object)
df.loc[linha, coluna] = "erro dado corrompido"
identificar_object(df)