#!/bin/bash

create_secret() {
    local secret=$1
    local key=$2
    local value=$3
    if kubectl get secret $1 &> /dev/null; then
        kubectl patch secret $1 -p '{"stringData": {"'"$key"'": "'"$value"'"}}'
    else 
        kubectl create secret generic $1 --from-literal=$key="$value"
    fi
}

get_secret() {
    local secret=$1
    local key=$2
    kubectl get secret $secret --ignore-not-found -o jsonpath="{.data.$key}" | base64 -d
}

# Update a nested value in a YAML configuration file
#
# Args:
# config_file: The YAML file to update
# config_path: An array of strings representing the path to the value to update. 
#   example: ['webserver', 'defaultUser', 'username']
# value: The new value to set
update_config() {
    local config_file=$1
    local config_path=$2
    local value=$3
    python <<EOF
import yaml
data = yaml.safe_load(open('$config_file')) or {}
config = data
paths = $config_path
for path in paths:
    if path not in config:
        config[path] = {}
    # if last path, set value
    if path == paths[-1]:
        config[path] = '$value'
    else:
        config = config[path]
yaml.dump(data, open('$config_file', 'w'))
EOF
}
