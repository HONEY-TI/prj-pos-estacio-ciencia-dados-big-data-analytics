import matplotlib.pyplot as plt
import pandas as pd
from sklearn.linear_model import LinearRegression
from sklearn.metrics import r2_score
from sklearn.model_selection import train_test_split

df = pd.read_csv("../../datasets/data_reg_linear.csv")
print(df.sample(5))
print(df.dtypes)
print(df.shape)
print(df.describe())

fig, ax = plt.subplots(figsize=(12, 8))
plt.scatter(df["Height"].astype(float), df["Weight"].astype(float))

plt.xlabel("Height")
plt.ylabel("Weight")
plt.show()

x_weight = df["Weight"]
y_height = df["Height"]


x_train, x_test, y_train, y_test = train_test_split(
    x_weight, y_height, test_size=0.4)
print(x_train.sample())

# Treino do modelo
lienar_model = LinearRegression().fit(x_train.values.reshape(-1, 1), y_train)

# Saída
print("Modelo Linear Simples: Intercept= {:.5}"
      .format(lienar_model.intercept_))
print("Modelo Linear Simples: Coeficiente= {:.5}"
      .format(lienar_model.coef_[0]))
print(
    "Modelo Linear Simples: Weight= {:.5} + {:.5}(Height)".format(
        lienar_model.intercept_, lienar_model.coef_[0]
    )
)

print("Test score:", lienar_model.score(x_test.values.reshape(-1, 1), y_test))


y_pred = lienar_model.predict(x_test.values.reshape(-1, 1))
print("Testing Score:", r2_score(y_test, y_pred))


fig, ax = plt.subplots(figsize=(12, 8))
plt.scatter(x_test.values.reshape(-1, 1), y_test)
plt.plot(x_test.values.reshape(-1, 1), y_pred, color="red")
plt.xlabel("Height")
plt.ylabel("Weight")
plt.show()


x_train, x_test, y_train, y_test = train_test_split(
    x_weight, y_height, test_size=0.2)
print(x_train.sample())

# Treino do modelo
lienar_model = LinearRegression().fit(x_train.values.reshape(-1, 1), y_train)

# Saída
print("Modelo Linear Simples: Intercept= {:.5}"
      .format(lienar_model.intercept_))
print("Modelo Linear Simples: Coeficiente= {:.5}"
      .format(lienar_model.coef_[0]))
print(
    "Modelo Linear Simples: Weight= {:.5} + {:.5}(Height)".format(
        lienar_model.intercept_, lienar_model.coef_[0]
    )
)

print("Test score:", lienar_model.score(x_test.values.reshape(-1, 1), y_test))


y_pred = lienar_model.predict(x_test.values.reshape(-1, 1))
print("Testing Score:", r2_score(y_test, y_pred))


fig, ax = plt.subplots(figsize=(12, 8))
plt.scatter(x_test.values.reshape(-1, 1), y_test)
plt.plot(x_test.values.reshape(-1, 1), y_pred, color="red")
plt.xlabel("Height")
plt.ylabel("Weight")
plt.show()
