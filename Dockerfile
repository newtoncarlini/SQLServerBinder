# Utiliza a imagem do Jupyter Notebook como base
FROM jupyter/datascience-notebook

# Define a versão do Debian
ENV DEBIAN_VERSION=buster

# Instala o SQL Server
USER root
RUN apt-get update && \
    apt-get install -y curl gnupg2 lsb-release apt-utils && \
    curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/debian/${DEBIAN_VERSION}/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y msodbcsql17 mssql-tools unixodbc-dev && \
    apt-get clean && \
    echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> /etc/profile.d/mssql-tools.sh && \
    echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc && \
    . /etc/profile.d/mssql-tools.sh

# Instala as dependências do Python
RUN apt-get install -y python3-dev python3-pip libpq-dev gcc && \
    pip3 install psycopg2 pyodbc sqlalchemy && \
    pip3 install -r requirements.txt

# Configura o SQL Server
USER mssql
RUN /opt/mssql/bin/mssql-conf set sqlagent.enabled true && \
    /opt/mssql/bin/mssql-conf set telemetry.customerfeedback false && \
    /opt/mssql/bin/mssql-conf set sqlagent.startup_type manual && \
    /opt/mssql/bin/mssql-conf set hadr.hadrenabled 0

# Configura o usuário
USER root
RUN echo "jovyan:redspot" | chpasswd && \
    adduser jovyan sudo && \
    echo "jovyan ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/jovyan

# Configura o banco de dados
USER mssql
RUN /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P '' -Q "CREATE DATABASE dbfito"

# Instala as bibliotecas necessárias
USER root
COPY requirements.txt /tmp/
RUN pip3 install -r /tmp/requirements.txt

# Copia os arquivos
USER jovyan
COPY *.ipynb ./
COPY *.sql ./

# Define o comando de entrada
USER root
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh
USER jovyan
ENTRYPOINT ["/entrypoint.sh"]
