# <img src="./emds_logo.png" width="30" height="30"/> Invoice Data Platform
**A sample data pipeline for transforming invoice images and CSV files into BI Service Dashboards**

## Summary
TL;DR  
![Data flow](flow.png)  

Raw data (images and CSV) from repo's [/k8s/object_store](./k8s/object_store) will be transformed into 
beautiful numbers displayed in Apache Superset.

> * Invoice images are sampled from CORDv2 dataset  
> * CSV file is from [Kaggle](https://www.kaggle.com/code/mahabubsheikh/cafe-sales-dirty-data-for-cleaning)

> This is a simplified data pipeline, meant to be run on a single machine (e.g. your laptop). In a production environment, the Airflow would only act as a scheduler to trigger jobs on a separate Spark Cluster. Trino is probably not needed in this case, and can be replaced with SparkSQL.

## Requirement
- **[Docker for Desktop](https://www.docker.com/products/docker-desktop/)** (Enable Kubernetes and WSL2) or **minikube**
- [Helm](https://helm.sh/docs/intro/install/)
- Python 3.12 ([Microsoft store](https://apps.microsoft.com/search?query=python+3.12))
- openssl: generate secrets for SuperSet and cert for Trino
    - For Windows users: just install [Git for Windows](https://gitforwindows.org/), it'll be included in Git Bash console
- \>16GB RAM. Preferably 32GB

## Quick Start
TL;DR
```bash
(cd ./k8s && ./deploy.sh)
```

Many services are of type NodePort, run `kubectl get svc -n everest` to get their exposed port numbers. Go to [defaults.sh](./k8s/defaults.sh) 
to see default login credentials.

Step-by-step [guide](./guide/README.md)
