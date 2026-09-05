import random

palavras = [
    "teste",
    "hadoop",
    "mapreduce",
    "mrjob",
    "palavra",
    "palavras",
    "python",
    "repetidas",
    "tem",
    "texto",
    "spark",
    "dados",
    "cluster",
    "docker",
    "linux",
    "bigdata"
]

with open("texto_exemplo.txt", "w", encoding="utf-8") as arquivo:
    for _ in range(100000):
        quantidade = random.randint(5, 20)
        linha = " ".join(random.choices(palavras, k=quantidade))
        arquivo.write(linha + "\n")

print("Arquivo texto_exemplo.txt criado com 300 linhas")