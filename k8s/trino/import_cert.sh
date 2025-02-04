#!/bin/bash

if [[ -z $JAVA_HOME ]]; then
    echo "JAVA_HOME is not set"
    exit 0
fi

# Import Trino cert to truststore, to be used by SQL clients such as Trino CLI

keytool -delete -keystore "$JAVA_HOME/lib/security/cacerts" -alias trino_docker

keytool -importcert -trustcacerts -file ../airflow/config/trino/certificate.crt -keystore "$JAVA_HOME/lib/security/cacerts" -alias trino_docker -noprompt
exit $?