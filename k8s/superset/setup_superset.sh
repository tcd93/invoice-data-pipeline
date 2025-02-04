#!/bin/bash

set -e

kubectl create namespace everest &> /dev/null || true
kubectl config set-context --current --namespace=everest

source ../common.sh
source ../defaults.sh

superset_secret=$(get_secret superset secret-key)
if [[ -z $superset_secret ]]; then
    superset_secret=$(openssl rand -base64 42)
    create_secret superset secret-key $superset_secret
fi

helm repo add superset https://apache.github.io/superset &> /dev/null || true
helm upgrade -f cluster-nex-etl-superset.yaml superset superset/superset --install --hide-notes --create-namespace --
