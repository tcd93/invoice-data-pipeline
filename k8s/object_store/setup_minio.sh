#!/bin/bash
set -e

kubectl create namespace everest &> /dev/null || true
kubectl config set-context --current --namespace=everest

source ../common.sh
source ../defaults.sh

# can use secret key 'minio' here as it confict with helm chart internal usage
minio_password=$(get_secret minio-secret password)
if [[ -z $minio_password ]]; then
    create_secret minio-secret password $default_minio_password
    minio_password=$default_minio_password
fi

# Install MinIO community helm chart
helm repo add minio https://charts.min.io/ &> /dev/null || true
helm upgrade -f cluster-nex-etl-minio.yaml minio minio/minio --install --hide-notes --create-namespace --wait
pod=$(kubectl get pods -l app=minio -o jsonpath={.items[0].metadata.name})
# copy dirty_cafe_sales.csv into pod
# `kubectl cp` doesn't work because `tar` is not installed in pod
cat ./dirty_cafe_sales.csv | kubectl exec -i $pod -- sh -c "tee /tmp/dirty_cafe_sales.csv > /dev/null"
if [[ $? -ne 0 ]]; then
    echo "Failed to copy dirty_cafe_sales.csv to $pod"
    exit 1
else
    echo "Successfully copied dirty_cafe_sales.csv to $pod (/tmp/dirty_cafe_sales.csv)"
    # copy dirty_cafe_sales.csv to 'lake' bucket
    kubectl exec $pod -c minio -- sh -c "mc alias set myminio http://localhost:9000 admin $minio_password"
    kubectl exec $pod -c minio -- sh -c "mc cp /tmp/dirty_cafe_sales.csv myminio/lake"
fi
# copy ./invoices/* images into pod
for file in ./invoices/*; do
    base64 $file | kubectl exec -i $pod -- sh -c "base64 -d > /tmp/$(basename $file)"
done
if [[ $? -ne 0 ]]; then
    echo "Failed to copy dirty_cafe_sales.csv to $pod"
    exit 1
else
    echo "Successfully copied sample invoice images to $pod (/tmp/*.png)"
    for file in ./invoices/*; do
        kubectl exec $pod -c minio -- sh -c "mc cp /tmp/$(basename $file) myminio/lake/invoices/"
    done
fi