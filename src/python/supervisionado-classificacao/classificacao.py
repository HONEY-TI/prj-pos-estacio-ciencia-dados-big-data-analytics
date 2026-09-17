"""
============================================================
EXEMPLO 2 — SUPERVISIONADO: CLASSIFICAÇÃO
============================================================

Os algoritmos de classificação são algoritmos supervisionados,
nos quais passamos um conjunto de características sobre um
determinado item de uma classe.

O algoritmo utiliza essas características para aprender a qual
classe pertence um determinado item que ainda não foi mapeado.
"""


"""
============================================================
DATASET IRIS
============================================================

Neste exemplo, vamos utilizar o Iris Dataset.

Esse conjunto de dados contém informações sobre flores de íris
e é muito utilizado em exemplos de Machine Learning.
"""


"""
============================================================
CLASSES DAS FLORES
============================================================

O dataset possui três diferentes classes de flores:

- Iris setosa
- Iris virginica
- Iris versicolor

Cada classe possui 50 amostras.
"""


"""
============================================================
CARACTERÍSTICAS
============================================================

Cada amostra possui quatro características:

- Comprimento da sépala
- Largura da sépala
- Comprimento da pétala
- Largura da pétala

As medidas são informadas em centímetros.
"""


"""
============================================================
SCIKIT-LEARN
============================================================

Como o Iris Dataset é pequeno e bastante utilizado,
a biblioteca scikit-learn já disponibiliza esse dataset
internamente.

Assim, podemos carregá-lo diretamente pela biblioteca.
"""


"""
============================================================
ALGORITMOS DE CLASSIFICAÇÃO
============================================================

Neste exemplo serão utilizados dois algoritmos:

1. Árvore de Decisão
2. Máquina de Vetores de Suporte (SVM)

Esses algoritmos serão treinados para classificar
as flores de íris.
"""


"""
============================================================
TREINAMENTO
============================================================

Durante o treinamento, os algoritmos recebem as características
das flores e suas respectivas classes.

Depois do treinamento, podemos fornecer as características
de uma nova flor para que o algoritmo tente identificar
a sua classe.
"""


"""
============================================================
OBSERVAÇÃO
============================================================

A implementação interna da Árvore de Decisão e da SVM
está fora do escopo deste conteúdo.

O objetivo é compreender como esses algoritmos podem ser
utilizados para realizar uma classificação.
"""

from sklearn.datasets import load_iris, fetch_kddcup99
from sklearn.metrics import accuracy_score
from sklearn.model_selection import train_test_split
from sklearn.tree import DecisionTreeClassifier, export_text, plot_tree
from sklearn.svm import SVC

##################      Pré-processamento     ###################
# Coleta e Integração
iris = load_iris()

caracteristicas = iris.data
rotulos = iris.target

print("Caracteristicas:\n", caracteristicas[:2])
print("Rótulos:\n", rotulos[:2])
print('########################################################')

# Partição dos dados
carac_treino, carac_teste, rot_treino, rot_teste = train_test_split(caracteristicas, rotulos)

###################       Mineração        #####################

############---------- Arvore de Decisão -----------############
arvore = DecisionTreeClassifier(max_depth=2)
arvore.fit(X=carac_treino, y=rot_treino)

rot_preditos = arvore.predict(carac_teste)
acuracia_arvore = accuracy_score(rot_teste, rot_preditos)
############-------- Máquina de Vetor Suporte ------############
clf = SVC()
clf.fit(X=carac_treino, y=rot_treino)

rot_preditos_svm = clf.predict(carac_teste)
acuracia_svm = accuracy_score(rot_teste, rot_preditos_svm)

################      Pós-processamento     ####################
print("Acurácia Árvore de Decisão:", round(acuracia_arvore, 5))
print("Acurácia SVM:", round(acuracia_svm, 5))
print('########################################################')

r = export_text(arvore, feature_names=iris['feature_names'])
print("Estrutura da árvore")
print(r)