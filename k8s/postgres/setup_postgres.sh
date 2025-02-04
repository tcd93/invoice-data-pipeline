#!/bin/bash

set -e

kubectl create namespace everest &> /dev/null || true
kubectl config set-context --current --namespace=everest

source ../common.sh
source ../defaults.sh

secret_file=".values.yaml"
rm -f $secret_file
touch $secret_file

root_password=$(get_secret postgres postgres-password)
if [[ -n $root_password ]]; then
    # a work-around to execute initdb script with root access
    update_config $secret_file "['primary', 'initdb', 'password']" $root_password
else
    create_secret postgres postgres-password $postgres_default_root_password
    update_config $secret_file "['primary', 'initdb', 'password']" $postgres_default_root_password
fi

airflow_password=$(get_secret postgres airflow-password)
if [[ -z $airflow_password ]]; then
    create_secret postgres airflow-password $postgres_default_airflow_admin_password
    airflow_password=$postgres_default_airflow_admin_password
    # create the init script (must have .sh or .sql extension) to execute upon first mount
    create_secret postgres-initdb setup_airflow.sql \
        "select 'Running init script as ' || current_user as message; \
        create user airflow_admin with password '$postgres_default_airflow_admin_password'; \
        create database airflow_db with owner airflow_admin;"
fi

hive_password=$(get_secret postgres metastore-password)
if [[ -z $hive_password ]]; then
    create_secret postgres metastore-password $postgres_default_hive_password

    # create the init script (must have .sh or .sql extension) to execute upon first mount
    create_secret postgres-initdb setup_metastore.sql \
        "select 'Running init script as ' || current_user as message; \
        create user hive with password '$postgres_default_hive_password'; \
        create database hive_metastore with owner hive;"
fi

superset_password=$(get_secret postgres superset-password)
if [[ -z $superset_password ]]; then
    create_secret postgres superset-password $superset_default_password

    create_secret postgres-initdb setup_superset.sql \
        "select 'Running init script as ' || current_user as message; \
        create user superset with password '$superset_default_password'; \
        create database superset with owner superset;"
fi

helm upgrade -f cluster-nex-etl-postgres.yaml -f $secret_file postgres oci://registry-1.docker.io/bitnamicharts/postgresql --install --hide-notes --create-namespace --wait
echo
rm -f $secret_file