"""
Exemplo 3
Não supervisionado ‒ agrupamento
O objetivo de um algoritmo de agrupamento é reunir objetos de uma coleção que mantenham algum grau de afinidade. É utilizada uma função para maximizar a similaridade de objetos do mesmo grupo e minimizar entre elementos de outros grupos.

Exemplos de algoritmo de agrupamento são k-means e Mean-Shift.

No próximo exemplo, vamos utilizar o algoritmo k-means para gerar grupos a partir do dataset de flor de íris.
"""

import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
from sklearn.cluster import KMeans
from sklearn.datasets import load_iris

##################      Pré-processamento     ###################

# Coleta e Integração
iris = load_iris()

caracteristicas = iris.data

###################       Mineração        #####################

grupos = KMeans(n_clusters=3)
grupos.fit(X=caracteristicas)

labels = grupos.labels_    # indice do grupo ao qual cada amostra pertence

################      Pós-processamento     ####################

# ============================================================
# GRÁFICO A - Grupos encontrados pelo K-Means
# ============================================================

fig = plt.figure(1)

ax = fig.add_subplot(111, projection='3d')

ax.set_xlabel('Comprimento Sépala')
ax.set_ylabel('Largura Sépala')
ax.set_zlabel('Comprimento Pétala')

ax.scatter(
    caracteristicas[:, 0],
    caracteristicas[:, 1],
    caracteristicas[:, 2],
    c=grupos.labels_,
    edgecolor='k'
)

# Salva o gráfico A como imagem
fig.savefig('agrupamento.png', dpi=300, bbox_inches='tight')

# Fecha a figura depois de salvá-la
plt.close(fig)


# ============================================================
# GRÁFICO B - Classes reais do dataset
# ============================================================

target = iris.target

fig = plt.figure(2)

ax = fig.add_subplot(111, projection='3d')

ax.set_xlabel('Comprimento Sépala')
ax.set_ylabel('Largura Sépala')
ax.set_zlabel('Comprimento Pétala')

ax.scatter(
    caracteristicas[:, 0],
    caracteristicas[:, 1],
    caracteristicas[:, 2],
    c=target,
    edgecolor='k'
)

# Salva o gráfico B como imagem
fig.savefig('.agrupamento.png', dpi=300, bbox_inches='tight')

# Fecha a figura depois de salvá-la
plt.close(fig)

# plt.show()