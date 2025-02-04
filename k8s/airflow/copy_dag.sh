#!/bin/bash

copy_dag() {
    pod=$1
    container=$2
    kubectl exec $pod -c $container -- sh -c "mkdir -p /opt/airflow/dags/process_image"
    kubectl cp ../../pipe/dags/process_image/process_image.py $pod:/opt/airflow/dags/process_image/process_image.py -c $container
    if [[ $? -ne 0 ]]; then
        echo "Failed to copy certificate to $pod"
        exit 1
    fi
}

scheduler_pods=$(kubectl get pods -l app=airflow,component=scheduler -o jsonpath={.items[*].metadata.name})
if [[ -z $scheduler_pods ]]; then
    echo "No airflow scheduler pod found, exit copying config"
    exit 1
fi
for pod in $scheduler_pods; do
    copy_dag $pod scheduler
done
