#!/bin/bash
# helper script to deploy robot, proxy and token secrets in all namespaces.

if [ $# -ne 1 ]; then
    echo "Usage: deploy-cluster-secrets.sh  <path_to_secrets>"
    exit 1
fi

namespaces="auth default crab das dbs dmwm http tzero wma dqm rucio ruciocm"

certificates=$1

robot_key=$certificates/robotkey.pem
robot_crt=$certificates/robotcert.pem

robot_key_crab=$certificates/robotkey-crab.pem
robot_crt_crab=$certificates/robotcert-crab.pem

robot_key_wmcore=$certificates/robotkey-wmcore.pem
robot_crt_wmore=$certificates/robotcert-wmcore.pem

client_id=$certificates/client_id
client_secret=$certificates/client_secret

proxy=/tmp/$USER/proxy
token=/tmp/$USER/token

#create proxies with VOMS extensions
#for generic namesace
voms-proxy-init -voms cms -rfc \
        --key $robot_key --cert $robot_crt --out $proxy
#for wmcore
voms-proxy-init -voms cms -rfc \
        --key $robot_key_wmcore --cert $robot_crt_wmcore --out $proxy_wmcore
#for crab
voms-proxy-init -voms cms -rfc \
        --key $robot_key_crab --cert $robot_crt_crab --out $proxy_crab
    for ns in $namespaces; do
        echo "---"
        echo "Create certificates secrets in namespace: $ns"
	keys=$certificates/$ns-keys.txt
	echo $keys
        if [ -f $keys ]; then
            kubectl create secret generic $ns-keys-secrets \
                --from-file=$keys --dry-run=client -o yaml | \
                kubectl apply --namespace=$ns -f -
        fi

	if [ $ns == "crab" ]
        then
        #create robot secret
            kubectl create secret generic robot-secrets \
            --from-file=$robot_key_crab --from-file=$robot_crt_crab \
            --dry-run=client -o yaml | \
            kubectl apply --namespace=$ns -f -

        # create proxy secret
        if [ -f $proxy_crab ]
        then
            kubectl create secret generic proxy-secrets \
            --from-file=$proxy_crab --dry-run=client -o yaml | \
            kubectl apply --namespace=$ns -f -

        elif [$ns== "dmwm" ]
        then
        #create robot secret
            kubectl create secret generic robot-secrets \
            --from-file=$robot_key_wmcore --from-file=$robot_crt_wmcore \
            --dry-run=client -o yaml | \
            kubectl apply --namespace=$ns -f -

        # create proxy secret
        if [ -f $proxy_wmcore ]; then
            kubectl create secret generic proxy-secrets \
                --from-file=$proxy_wmcore --dry-run=client -o yaml | \
                kubectl apply --namespace=$ns -f -

        else
        # create robot secrets
        kubectl create secret generic robot-secrets \
            --from-file=$robot_key --from-file=$robot_crt \
            --dry-run=client -o yaml | \
            kubectl apply --namespace=$ns -f -

        # create proxy secret
        if [ -f $proxy ]; then
            kubectl create secret generic proxy-secrets \
                --from-file=$proxy --dry-run=client -o yaml | \
                kubectl apply --namespace=$ns -f -
        fi
        fi
        # create client secret
        if [ -f $client_id ] && [ -f $client_secret ]; then
            kubectl create secret generic client-secrets \
                --from-file=$client_id --from-file=$client_secret --dry-run=client -o yaml | \
                kubectl apply --namespace=$ns -f -
        fi
        # create token secrets
	curl -s -d grant_type=client_credentials -d scope="profile" -u ${client_id}:${client_secret} https://cms-auth.web.cern.ch/token | jq -r '.access_token' > $token
        now=$(date +'%Y%m%d %H:%M')
        if [ -f $token ]; then
            kubectl create secret generic token-secrets \
               --from-file=$token --dry-run=client -o yaml | \
               kubectl apply --namespace=$ns -f -
            echo "$now Token created."
        else
            echo "$now Failed to create token secrets"
        fi
   done

#### proxy for ms-unmerged service

   voms-proxy-init -rfc \
        -key $robot_key \
        -cert $robot_crt \
        --voms cms:/cms/Role=production --valid 192:00 \
        -out $proxy

    out=$?
    if [ $out -eq 0 ]; then
     kubectl create secret generic proxy-secrets-ms-unmerged \
                --from-file=$proxy --dry-run=client -o yaml | \
                kubectl apply --namespace=dmwm -f -
     fi
