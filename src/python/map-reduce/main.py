from mrjob.job import MRJob
import re
import os
import sys
import time


class ArquivoEntrada:
    """Responsável por localizar e validar o arquivo de entrada."""

    ARQUIVO_PADRAO = "texto_exemplo.txt"

    @classmethod
    def obter(cls, argumentos):
        arquivo = (
            argumentos[1]
            if len(argumentos) > 1
            else cls.ARQUIVO_PADRAO
        )

        if not cls.existe(arquivo):
            raise FileNotFoundError(
                f"Arquivo '{arquivo}' não encontrado."
            )

        return arquivo

    @staticmethod
    def existe(arquivo):
        return os.path.isfile(arquivo)


class ContadorPalavras(MRJob):
    """Job MapReduce responsável pela contagem de palavras."""

    palavra_regex = re.compile(r"[\w']+")

    def mapper(self, _, linha):
        """
        Executa a fase Map.
        Cada palavra encontrada gera uma chave com valor 1.
        """

        palavras = self.palavra_regex.findall(linha)

        for palavra in palavras:
            yield palavra.lower(), 1

    def reducer(self, palavra, quantidade):
        """
        Executa a fase Reduce.
        Soma todas as ocorrências da palavra.
        """

        yield palavra, sum(quantidade)


class EstatisticaExecucao:
    """Controla métricas de execução."""

    def __init__(self):
        self.inicio = None
        self.fim = None

    def iniciar(self):
        self.inicio = time.perf_counter()

    def finalizar(self):
        self.fim = time.perf_counter()

    def tempo_total(self):
        return self.fim - self.inicio

    def exibir(self):
        print("\n📊========== Estatísticas ==========")
        print(
            f"⏱️  Tempo total: "
            f"{self.tempo_total():.4f} segundos"
        )
        print("🚀 Status: Execução finalizada")
        print("==================================\n")


class Aplicacao:
    """Classe principal responsável pela execução."""

    @staticmethod
    def executar():

        estatistica = EstatisticaExecucao()
        estatistica.iniciar()

        try:
            print("🔄 Iniciando processamento MapReduce...")

            arquivo = ArquivoEntrada.obter(sys.argv)

            print(f"📄 Arquivo utilizado: {arquivo}\n")

            # Entrega apenas o arquivo para o MRJob
            sys.argv = [
                sys.argv[0],
                arquivo
            ]

            ContadorPalavras.run()

            print("\n✅ Processamento concluído!")

        except FileNotFoundError as erro:
            print(f"\n❌ Erro: {erro}")
            sys.exit(1)

        except Exception as erro:
            print(f"\n💥 Erro inesperado: {erro}")
            sys.exit(1)

        finally:
            estatistica.finalizar()
            estatistica.exibir()


if __name__ == "__main__":
    Aplicacao.executar()