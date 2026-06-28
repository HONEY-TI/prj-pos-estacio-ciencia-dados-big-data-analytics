import sys
from pathlib import Path

# Garante que o pacote `libs` seja encontrado
PYTHON_ROOT = Path(__file__).resolve().parent.parent
if str(PYTHON_ROOT) not in sys.path:
    sys.path.insert(0, str(PYTHON_ROOT))

import pandas as pd
from sklearn.datasets import load_iris
from libs import get_merge_iris_df


def main():
    """
    Função principal do programa.
    """

    # Carrega o DataFrame da base Iris
    iris_df = get_merge_iris_df()

    # Exibe o DataFrame
    print("DataFrame Iris:")
    print(iris_df)


if __name__ == "__main__":
    main()
