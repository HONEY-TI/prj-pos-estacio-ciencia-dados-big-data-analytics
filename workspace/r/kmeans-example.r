rm(list = ls())
set.seed(10)

num_clientes <- 100;
consumo_laticinios <- abs(rnorm(num_clientes, mean=50, sd=30))
consumo_carne <- abs(rnorm(num_clientes, mean=70, sd=40)) 
consumo_padaria <- abs(rnorm(num_clientes, mean=30, sd=10))
dados <-data.frame(laticinios=consumo_laticinios,
                   carne=consumo_carne,
                   padaria=consumo_padaria)

head(dados)

dados.padronizados <- scale(dados,center=TRUE,scale=TRUE)

install.packages("NbClust")
library(NbClust)

num_grupos <- NbClust(dados.padronizados, distance = "euclidean", 
                      min.nc = 3, max.nc = 10, 
                      method = "complete", index ="all")

install.packages("factoextra")
library(factoextra)

fviz_nbclust(num_grupos) + theme_minimal()

install.packages("cluster")
library(cluster)	

kmeans.resultado <- eclust(dados.padronizados, "kmeans", k = 4,
                           nstart = 20, graph = FALSE)

kmeans.resultado$cluster

fviz_cluster(kmeans.resultado, 
             geom = "point", 
             frame.type = "norm")

silhueta <- silhouette(kmeans.resultado$ cluster,dist(dados.padronizados))

head(silhueta[, 1:3], 10)
plot(silhueta, main=" Silhoeta - Kmeans" )


fviz_silhouette(silhueta)


si.sum <- summary(silhueta)
si.sum$clus.sizes
