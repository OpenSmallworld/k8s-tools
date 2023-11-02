#!/usr/bin/env bash

if [[ ! -z $1 ]]; then
        ns=$1
else
        ns=''
fi

if [[ ! $(which jq) ]]; then
    echo "*** Error: jq not installed"
    exit 2
fi

kubectl get secret -A --no-headers | awk "/^$ns/ { print \$1\":\"\$2 }" | while read details;do
        ns=$(echo $details | awk -F : '{ print $1 }')
        secret=$(echo $details | awk -F : '{ print $2 }')
        echo '-------------------------------'
        echo -e "Namespace: $ns\nSecret: $secret"
        data=$(kubectl get secret -n $ns $secret -o jsonpath='{.data}')
        echo "${data}" | jq -r '.|to_entries[]|(.key+"="+(.value|@base64d))'
done