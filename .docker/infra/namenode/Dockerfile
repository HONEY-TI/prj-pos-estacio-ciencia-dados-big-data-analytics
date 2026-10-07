FROM eclipse-temurin:17-jdk

ENV HADOOP_VERSION=3.4.3
ENV HADOOP_HOME=/opt/hadoop
ENV PATH=$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH
ENV JAVA_HOME=/opt/java/openjdk

RUN apt-get update \
    && apt-get install -y curl procps \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz \
       -o /tmp/hadoop.tar.gz \
       || curl -fsSL https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz \
       -o /tmp/hadoop.tar.gz \
    && tar -xzf /tmp/hadoop.tar.gz -C /opt \
    && ln -s /opt/hadoop-${HADOOP_VERSION} $HADOOP_HOME \
    && rm /tmp/hadoop.tar.gz

RUN mkdir -p /data/name

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 9870 9000

ENTRYPOINT ["/entrypoint.sh"]