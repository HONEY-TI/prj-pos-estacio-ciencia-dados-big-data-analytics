from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .master("spark://spark-master:7077") \
    .appName("teste_spark") \
    .getOrCreate()

spark.range(10).show()