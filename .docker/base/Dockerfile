FROM apache/spark:3.5.1 AS spark
FROM rocker/rstudio:latest
COPY --from=spark /opt/spark /opt/spark

ENV DEBIAN_FRONTEND=noninteractive
ENV USERNAME=rstudio
ENV PATH="/opt/venv/bin:$PATH"
ENV SPARK_HOME=/opt/spark
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="$SPARK_HOME/bin:$SPARK_HOME/sbin:/opt/venv/bin:$PATH"
ENV PYSPARK_PYTHON=/opt/venv/bin/python
ENV PYSPARK_DRIVER_PYTHON=/opt/venv/bin/python

# ==========================================
# Dependências do sistema (root — correto no build)
# ==========================================
RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    openjdk-17-jdk \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ==========================================
# Venv Python: criado como root, dono = rstudio
# ==========================================
RUN python3 -m venv /opt/venv \
    && chown -R ${USERNAME}:${USERNAME} /opt/venv

# ==========================================
# Libs Python essenciais
# ==========================================
RUN /opt/venv/bin/pip install --upgrade pip && \
    /opt/venv/bin/pip install \
    jupyterlab \
    ipykernel \
    pandas \
    numpy \
    matplotlib \
    pyarrow \
    pyspark==3.5.1

RUN R -e "install.packages( \
        c('tidyverse', 'languageserver', 'IRkernel', 'sparklyr'), \
        repos = 'https://cloud.r-project.org/', \
        quiet = TRUE \
    )" \
    && R -e "IRkernel::installspec(user = FALSE)"