#!/bin/bash
set -e

# Our trino instance will be using TLS and JWT authentication method
# This script will generate a self-signed certificate for Trino server
# and save JWT token as an Airflow variable in $secret_file

kubectl create namespace everest &> /dev/null || true
kubectl config set-context --current --namespace=everest

source ../common.sh
source ../defaults.sh

secret_file=".values.yaml"
rm -f $secret_file
touch $secret_file

generate_jwt_token() {
    # 'sub' must be the login name, we'll use 'trino' username for this entire project
    local payload='{"iss": "localhost", "aud": "k8s", "sub": "trino"}'
    local secret_base64="$1"
    # for some reason python's base64.b64decode works correctly and bash's base64 -d does not
    token=$(python3 -c "import jwt; import base64; secret_key = base64.b64decode('$secret_base64'); print(jwt.encode($payload, secret_key, algorithm='HS256'))")
    echo "$token"
}

trino_secret=$(kubectl get secret trino --ignore-not-found)

if [[ -n $trino_secret ]]; then
    echo "Found existing keys and certs, do you want to clean up them? (n)"
    read -r response
    if [[ $response =~ ^[Yy]$ ]]; then
        echo "Cleaning up existing keys and certs..."
        kubectl delete secret trino
        trino_secret=""
    fi
fi

# Generate self-signed certificate and JWT auth
if [[ -z $trino_secret ]]; then
    key_file="../airflow/config/trino/private.key"
    cert_file="../airflow/config/trino/certificate.crt"
    pem_file="../airflow/config/trino/certificate.pem"
    days=3650 # Validity period (10 years)
    
    # Should match service name
    common_name="trino"
    # Generate private key
    openssl genrsa -out "$key_file" 2048

    subject_cn="/CN=$common_name"
    # add leading slash to escape if current platform is windows (mingw/msys)
    # see issue https://stackoverflow.com/questions/31506158/running-openssl-from-a-bash-script-on-windows-subject-does-not-start-with
    [[ $OSTYPE == cygwin || $OSTYPE == msys ]] && subject_cn="/$subject_cn"
    openssl req -x509 -new -nodes -key "$key_file" \
    -days $days -out "$cert_file" -subj $subject_cn -addext "subjectAltName = DNS:localhost,IP:127.0.0.1,DNS:trino" || rm -f $key_file

    # Verify the certificate
    openssl x509 -in "$cert_file" -text -noout

    # Read more about Trino PEM files: https://trino.io/docs/current/security/inspect-pem.html#inspect-pem-file
    cat $key_file $cert_file > $pem_file
    kubectl create secret generic trino --from-file=certificate="$pem_file" || rm -f $key_file $pem_file

    rm -f $key_file $pem_file

    jwt_hmac=$(openssl rand -hex 32)
    jwt_token=$(generate_jwt_token $jwt_hmac)
    create_secret trino jwt_hmac "$jwt_hmac"
    create_secret trino jwt_token "$jwt_token"
fi

# Create default catalog to connect to object store
minio_password=$(get_secret minio-secret password)
if [[ -n $minio_password ]]; then
    catalog_config=$(cat <<EOF
    connector.name=hive
    hive.metastore=thrift
    hive.metastore.uri=thrift://hive-metastore:9083
    hive.metastore.username=trino
    fs.native-s3.enabled=true
    s3.endpoint=http://minio:9000
    s3.region=default
    s3.aws-access-key=admin
    s3.aws-secret-key=$minio_password
    s3.path-style-access=true
EOF
    )
    update_config $secret_file "['catalogs', 'minio']" "$(echo "$catalog_config" | xargs | sed 's/ /\\n/g')"
else
    echo "Warning: minio password is not set, catalog Trino is not created"
fi
helm repo add trino https://trinodb.github.io/charts &> /dev/null || true
helm upgrade -f cluster-nex-etl-trino.yaml -f $secret_file trino trino/trino --install --hide-notes --create-namespace --wait
echo

if [[ -n "$jwt_token" ]]; then
    echo "----------TRINO ACCESS TOKEN----------"
    echo "$jwt_token"
    echo "----------TRINO ACCESS TOKEN----------"
fi

rm -f $secret_file

# ./import_cert.sh