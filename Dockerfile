# Utiliza a imagem do Ubuntu 20.04 como base
FROM ubuntu:20.04

# Atualiza o cache do APT e instala as dependências do SQL Server
USER root
RUN apt-get update && \
    apt-get install -y curl gnupg2 lsb-release && \
    curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/debian/$(lsb_release -rs)/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
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

# Remove as dependências obsoletas
RUN dpkg -l | grep '^rc' | awk '{print $2}' | xargs dpkg --purge && \
    dpkg -l | grep '^iU' | awk '{print $2}' | xargs dpkg --purge && \
    apt-get clean && \
    apt-get autoclean && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

# Configura o SQL Server
USER mssql
RUN /opt/mssql/bin/mssql-conf set sqlagent.enabled true && \
    /opt/mssql/bin/mssql-conf set telemetry.customerfeedback false && \
    /opt/mssql/bin/mssql-conf set sqlagent.startup_type manual && \
    /opt/mssql/bin/mssql-conf set hadr.hadrenabled 0

# Configura o usuário
USER root
RUN echo "adminbanco:fito@2023" | chpasswd && \
    adduser adminbanco sudo && \
    echo "adminbanco ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/adminbanco

# Configura o banco de dados
USER mssql
RUN /opt/mssql-tools/bin/sqlcmd -S localhost -U adminbanco -P '' -Q "CREATE DATABASE dbfito"

# Instala as bibliotecas necessárias
USER root
COPY requirements.txt /tmp/
RUN pip3 install -r /tmp/requirements.txt

# Copia os arquivos
USER adminbanco
COPY *.ipynb ./
COPY *.sql ./

# Define o comando de entrada
USER root
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh
USER adminbanco 
ENTRYPOINT ["/entrypoint.sh"]


