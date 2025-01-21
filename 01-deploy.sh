#!/bin/bash
export VAULT_KNS="vault"
export TKNS="tektoncd"
TF_USERNAME="$2"
TF_ORG="$1"

if [ -f "$HOME/.terraform.d/credentials.tfrc.json" ];then
    export TOKEN="$(cat $HOME/.terraform.d/credentials.tfrc.json | awk -F': ' '/token/ {print $NF}' | tr -d "\"")"
else
    echo -e "\nTerraform credentials not found. Consider doing \"terraform login\" next time...\n"
    read -s -p "Insert your Terraform Cloud user API Token: " TOKEN
fi

if ! which jq > /dev/null;then
    echo -e "\nThis script needs \"jq\" to parse JSON outputs. Please, install \"jq\"..."
    exit 1
fi

if [ -z "$1" ] || [ -z "$2" ];then
    echo -e "\nPlease type your Terraform Cloud Org and Terraform Cloud user as parameters: \n"
    echo -e "\t $0 <YOUR_TFC_ORG> <YOUR_TFC_USERNAME> \n"
    exit 1
fi

tfc_params() {
    local organization=$1
    local user=$2

    echo -e "\nTerraform Cloud Organization: $organization"
    echo -e "\nTerraform Cloud User: $user"

    export TEAMID="$(curl \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/vnd.api+json" \
    https://app.terraform.io/api/v2/organizations/$organization/teams \
    | jq -r '.data[] | select(.attributes.name == "owners") | .id')"

    export TFUSERID="$(curl \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/vnd.api+json" \
    "https://app.terraform.io/api/v2/teams/$TEAMID?include=users" \
    | jq -r  ".included[] | select(.attributes.username == \"$user\") | .id")"

    echo -e "\nTerraform Cloud Team ID for Owners at organization $1: $TEAMID"
    echo -e "\nTerraform Cloud User ID for user $2: $TFUSERID\n"
}


vault_config() {


    export VAULT_SA_NAME="$(kubectl get sa vault-auth -n default \
        --output go-template='{{ range .secrets }}{{ .name }}{{ end }}')"

    export SA_JWT_TOKEN="$(kubectl get secret $VAULT_SA_NAME -n default \
        --output 'go-template={{ .data.token }}' | base64 --decode)"

    export SA_CA_CRT=$(kubectl get secret $VAULT_SA_NAME \
        -o go-template='{{ index .data "ca.crt" }}' | base64 -d; echo)

    export K8S_HOST="$(kubectl exec -ti vault-0 -n vault -- printenv KUBERNETES_SERVICE_HOST | tr -d '\r')"
    export K8S_PORT=$(kubectl exec -ti vault-0 -n vault -- printenv KUBERNETES_SERVICE_PORT | tr -d '\r')

    kubectl exec -i vault-0 -n $VAULT_KNS -- vault policy write tektonpol - <<EOF
path "secret/data/cicd/*" {
    capabilities = ["read","update","list"]
}
path "terraform/creds/*" {
    capabilities = ["read","list"]
}
EOF

    kubectl exec vault-0 -n $VAULT_KNS -- vault auth enable kubernetes

    kubectl exec vault-0 -n $VAULT_KNS -- vault write auth/kubernetes/config \
            token_reviewer_jwt="$SA_JWT_TOKEN" \
            kubernetes_host="https://$K8S_HOST:$K8S_PORT" \
            kubernetes_ca_cert="$SA_CA_CRT" \
            issuer="https://kubernetes.default.svc.cluster.local"

    kubectl exec vault-0 -n $VAULT_KNS -- vault write auth/kubernetes/role/tekton \
        bound_service_account_names="tekton-sa","vault-auth","default"\
        bound_service_account_namespaces="tekton-pipelines","default" \
        policies="tektonpol" \
        token_no_default_policy=false \
        token_ttl="1m"


    kubectl exec vault-0 -n $VAULT_KNS -- vault secrets enable terraform

    kubectl exec vault-0 -n $VAULT_KNS -- vault write terraform/config token="$TOKEN"
    kubectl exec vault-0 -n $VAULT_KNS -- vault write terraform/role/tekton user_id=$TFUSERID ttl=10m
}



# FUN STARTS HERE
# Deploy Vault SA for JWT Token Review, Tekton pipelines service account and Vault Agent ConfigMap
kubectl apply -f ./config

# Set TFC params
tfc_params $TF_ORG $TF_USERNAME

# Configuring Vault
vault_config








