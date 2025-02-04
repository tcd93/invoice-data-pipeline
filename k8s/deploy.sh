#!/bin/bash

set -e

# install neccessary packages to run this Bash script
pip install --quiet pyyaml pyjwt

kubectl create namespace everest &> /dev/null || true
kubectl config set-context --current --namespace=everest

(cd ./postgres && ./setup_postgres.sh)
(cd ./object_store && ./setup_minio.sh)
(cd ./hive && ./setup_hive.sh)
(cd ./trino && ./setup_trino.sh)
(cd ./superset && ./setup_superset.sh)
(cd ./airflow && ./setup_airflow.sh)

echo
echo "------------------------"
echo "- run \"kubectl get svc\" to get the list of services and their exposed node ports."
echo "      pods in Kubernetes can connect to other services by name."
echo "- run \"kubectl get pod\" to get the list of pods."
echo "- run \"kubectl describe pod [pod_name]\" to get logs."
echo "------------------------"
echo 
