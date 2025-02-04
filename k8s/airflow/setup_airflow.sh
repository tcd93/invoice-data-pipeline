#!/bin/bash

set -e

pip install --quiet pyyaml pyjwt

source ../common.sh
source ../defaults.sh

secret_file=".values.yaml"
rm -f $secret_file
touch $secret_file

airflow_password=$(get_secret postgres password)
if [[ -z $airflow_password ]]; then
    create_secret postgres password $postgres_default_airflow_admin_password
    airflow_password=$postgres_default_airflow_admin_password
fi
update_config $secret_file "['webserver', 'defaultUser', 'username']" "airflow_admin"
update_config $secret_file "['webserver', 'defaultUser', 'password']" $airflow_password

if [[ -z $(get_secret airflow webserver-secret-key) ]]; then
    value=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    create_secret airflow webserver-secret-key $value
fi

if [[ -z $(get_secret airflow fernet-key) ]]; then
    value=$(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")
    create_secret airflow fernet-key $value
fi

if [[ -z $(get_secret airflow connection) ]]; then
    create_secret airflow connection "postgresql+psycopg2://airflow_admin:$airflow_password@postgres:5432/airflow_db"
fi

if [[ -z $(get_secret airflow-connections AIRFLOW_CONN_AWS_DEFAULT) ]]; then
    minio_password=$(get_secret minio-secret password)
    if [[ -z $minio_password ]]; then
        create_secret minio-secret password $default_minio_password
        minio_password=$default_minio_password
    fi
    create_secret airflow-connections AIRFLOW_CONN_AWS_DEFAULT "{\
        \"conn_type\": \"aws\",\
        \"login\": \"admin\",\
        \"password\": \"$minio_password\",\
        \"extra\": { \"endpoint_url\": \"http://minio:9000\" }\
    }"
fi

if ! docker image inspect flickering &> /dev/null; then
    response="y"
else
    echo "Do you want to rebuild the Docker image 'flickering' from Dockerfile.airflow? (n)" 
    read -r response
fi

if [[ "$response" =~ ^[Yy]$ ]]; then
    echo "Expect slow build time due to large image size (pre-download Huggingface Donut model)"
    docker build -t flickering -f Dockerfile.airflow .
fi

helm upgrade -f cluster-nex-etl-airflow.yaml -f $secret_file airflow apache-airflow/airflow --install --hide-notes --create-namespace

rm -f $secret_file

./copy_dag.sh