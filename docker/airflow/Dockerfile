FROM apache/airflow:3.3.0-python3.11

USER root
RUN apt-get update     && apt-get install -y --no-install-recommends        openjdk-17-jre-headless curl tesseract-ocr tesseract-ocr-por fonts-dejavu-core     && rm -rf /var/lib/apt/lists/*     && ln -sfn "$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")" /opt/java
ENV JAVA_HOME=/opt/java
ENV PATH="${JAVA_HOME}/bin:${PATH}"

USER airflow
RUN pip install --no-cache-dir       apache-airflow-providers-apache-spark==6.2.0       pyspark==3.5.6       boto3==1.43.0       pypdf==5.1.0       Pillow==11.1.0       pytesseract==0.3.13

USER root
RUN mkdir -p /opt/spark/jars-extra     && curl -fsSL -o /opt/spark/jars-extra/iceberg-spark-runtime.jar        https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/1.10.0/iceberg-spark-runtime-3.5_2.12-1.10.0.jar     && curl -fsSL -o /opt/spark/jars-extra/iceberg-aws-bundle.jar        https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-aws-bundle/1.10.0/iceberg-aws-bundle-1.10.0.jar     && chown -R airflow:root /opt/spark
USER airflow
