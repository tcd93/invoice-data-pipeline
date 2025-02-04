#!/bin/bash

set -e

kubectl create namespace everest &> /dev/null || true
kubectl config set-context --current --namespace=everest

kubectl apply -f ./deployment.yaml -f ./service.yaml --wait