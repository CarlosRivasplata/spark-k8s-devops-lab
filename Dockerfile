# Dockerfile CORREGIDO - DataStream Corp
# Spark Worker Image v2.0 - Optimizado para Kubernetes

FROM eclipse-temurin:17-jre-jammy

# Metadata
LABEL maintainer="devops@datastream.corp"
LABEL version="2.0"

# Variables de entorno
ENV SPARK_VERSION=3.5.1 \
    HADOOP_VERSION=3.4.0 \
    SPARK_HOME=/opt/spark \
    PYTHONUNBUFFERED=1

# Instalación de dependencias y limpieza de caché
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    python3=3.10* \
    python3-pip \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Descarga de Spark
RUN curl -L "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz" \
    | tar -xz -C /opt \
    && mv /opt/spark-${SPARK_VERSION}-bin-hadoop3 ${SPARK_HOME}

# Instalación de librerías Python
RUN pip3 install --no-cache-dir \
    pyspark==3.5.1 \
    pandas==2.2.0 \
    numpy==1.26.0

# Configuración de usuario y permisos (SOLUCIÓN AL ACCESSO DENEGADO)
RUN useradd -r -u 1001 -g root sparkuser && \
    mkdir -p /opt/spark/work && \
    chown -R 1001:root /opt/spark/work

USER 1001

WORKDIR /app
COPY --chown=1001:root . .

# Salud del contenedor
HEALTHCHECK --interval=30s --timeout=10s CMD curl -f http://localhost:4040 || exit 1

EXPOSE 4040 7077 8080

CMD ["spark-class", "org.apache.spark.deploy.worker.Worker"]