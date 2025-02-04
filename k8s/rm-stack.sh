#!/bin/bash
kubectl config set-context --current --namespace=everest

helm uninstall trino --wait
kubectl delete deployment hive-metastore
kubectl delete service hive-metastore 
helm uninstall minio --wait
helm uninstall postgres --wait
helm uninstall airflow --wait

if [[ $? -eq 0 ]]; then
    read -p "Do you want to remove all persistent volumes? (n)" response
    if [[ $response =~ ^[Yy]$ ]]; then
        kubectl delete pvc --all --wait
        kubectl delete pv --all --wait
    fi
fi