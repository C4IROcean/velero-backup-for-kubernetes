#!/bin/bash

# This script assumes that the `az login` part is already configured outside the script,
#   so `az` cli can talk to correct azure subscription.

CONFIG_FILE_FOR_VELERO_INSTALLATION=$1

if [ ! -r "${CONFIG_FILE_FOR_VELERO_INSTALLATION}" ]; then
  echo "Please provide full path for configuration file to help with velero installation."
  echo "You must have already configured az cli to be able to talk to azure cloud."
  echo
  echo "The config file needs to have the following items: (the values are example values)"
  echo ""
  echo AZURE_SUBSCRIPTION_NAME=ODP
  echo KUBECTL_CLUSTER_CONTEXT_NAME=arck-dev-odp
  echo AZURE_RESOURCE_GROUP_FOR_K8S_CLUSTER=MC_rg-dev-kubernetes_arck-dev-odp_westeurope
  echo VELERO_CREDENTIALS_FILE=~/credentials-velero-k8s-arck-dev-odp
  echo AZURE_BACKUP_RESOURCE_GROUP=kubernetes-backups
  echo AZURE_STORAGE_ACCOUNT_ID=stkubernetesbackups
  echo AZURE_BLOB_CONTAINER=backups-k8s-arck-dev-odp
  echo AZURE_SERVICE_PRINCIPAL_NAME=velero-k8s-backup-helper
  echo AZURE_SERVICE_PRINCIPAL_SECRET=password-obtained-earlier-during-ad-rbac-account-creation
  echo
  echo "Exiting ..."
  exit 1
else
  echo "Reading config file - ${CONFIG_FILE_FOR_VELERO_INSTALLATION} ..."
  source ${CONFIG_FILE_FOR_VELERO_INSTALLATION}
fi

echo
echo "Found AZURE_SUBSCRIPTION_NAME=${AZURE_SUBSCRIPTION_NAME}"
echo "Found KUBECTL_CLUSTER_CONTEXT_NAME=${KUBECTL_CLUSTER_CONTEXT_NAME}"
echo "Found AZURE_RESOURCE_GROUP_FOR_K8S_CLUSTER=${AZURE_RESOURCE_GROUP_FOR_K8S_CLUSTER}"
echo "Found VELERO_CREDENTIALS_FILE=${VELERO_CREDENTIALS_FILE}"
echo "Found AZURE_BACKUP_RESOURCE_GROUP=${AZURE_BACKUP_RESOURCE_GROUP}"
echo "Found AZURE_STORAGE_ACCOUNT_ID=${AZURE_STORAGE_ACCOUNT_ID}"
echo "Found AZURE_BLOB_CONTAINER=${AZURE_BLOB_CONTAINER}"
echo "Found AZURE_SERVICE_PRINCIPAL_NAME=${AZURE_SERVICE_PRINCIPAL_NAME}"
echo "AZURE_SERVICE_PRINCIPAL_SECRET=NOT_SHOWN_HERE"
echo

# The following are read from the installation config file.
# AZURE_SUBSCRIPTION_NAME=ODP
# VELERO_CREDENTIALS_FILE=~/credentials-velero-arck-dev-odp
# AZURE_BACKUP_RESOURCE_GROUP=kubernetes-backups
# AZURE_STORAGE_ACCOUNT_ID=stkubernetesbackups
# AZURE_BLOB_CONTAINER=backups-k8s-arck-dev-odp
# AZURE_RESOURCE_GROUP_FOR_K8S_CLUSTER=MC_rg-dev-kubernetes_arck-dev-odp_westeurope
# KUBECTL_CLUSTER_CONTEXT_NAME=arck-dev-odp
# AZURE_SERVICE_PRINCIPAL_NAME=velero-k8s-backup-helper
# AZURE_SERVICE_PRINCIPAL_SECRET=password-obtained-earlier-during-ad-rbac-account-creation



echo "Switching kubectl context to the one provided - ${KUBECTL_CLUSTER_CONTEXT_NAME} ..."
kubectl config use-context ${KUBECTL_CLUSTER_CONTEXT_NAME}

if [ $? -ne 0 ] ; then
  echo "The cluster context does not exist. There is no use of proceeding ..."
  echo "Exiting ..."
  exit 1
fi

echo

AZURE_SUBSCRIPTION_ID=$(az account list --query '[?isDefault].id' -o tsv)

AZURE_TENANT_ID=$(az account list --query '[?isDefault].tenantId' -o tsv)


# Create service principal OUTSIDE this script. Otherwise,
#   each time you run this command, a new password will be generated,
#   which is undesired.

#   This service principal will act as a client 
#   when talking to Blob containers inside Azure StorageAccount.

# AZURE_SERVICE_PRINCIPAL_SECRET=$(az ad sp create-for-rbac \
#  --name "velero-k8s-backup-helper" \
#  --role "Contributor" \
#  --query 'password' \
#  -o tsv \
#  --scopes  /subscriptions/${AZURE_SUBSCRIPTION_ID})

AZURE_CLIENT_SECRET=${AZURE_SERVICE_PRINCIPAL_SECRET}
  

# This is actually AZURE_CLIENT_ID  
AZURE_SERVICE_PRINCIPAL_ID=$(az ad sp list \
  --display-name "${AZURE_SERVICE_PRINCIPAL_NAME}" \
  --query '[0].appId' \
  -o tsv)

AZURE_CLIENT_ID=${AZURE_SERVICE_PRINCIPAL_ID}  
 
AZURE_RESOURCE_GROUP=${AZURE_RESOURCE_GROUP_FOR_K8S_CLUSTER}

# Essentially the main Subsctiption ID and the Backup Subscription ID are same.
AZURE_BACKUP_SUBSCRIPTION_NAME=${AZURE_SUBSCRIPTION_NAME}

AZURE_BACKUP_SUBSCRIPTION_ID=$(az account list \
  --query="[?name=='${AZURE_BACKUP_SUBSCRIPTION_NAME}'].id | [0]" \
  -o tsv)


# Create velero credentials file:

echo "VELERO_CREDENTIALS_FILE - ${VELERO_CREDENTIALS_FILE} "


cat << EOF  > ${VELERO_CREDENTIALS_FILE}
# This top section of this file is consumed by the "--secret-file" option
#   of the "velero install" command.

AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}
AZURE_TENANT_ID=${AZURE_TENANT_ID}
AZURE_CLIENT_ID=${AZURE_SERVICE_PRINCIPAL_ID}
AZURE_CLIENT_SECRET=${AZURE_SERVICE_PRINCIPAL_SECRET}

# This will change for each cluster you want to perform backup and restore on.
AZURE_RESOURCE_GROUP=${AZURE_RESOURCE_GROUP_FOR_K8S_CLUSTER}
AZURE_CLOUD_NAME=AzurePublicCloud

# This bottom section contains extra variables for safe keeping.
# These variables are used in the 'velero install' command directly.
# These variables are defined in the CONFIG_FILE_FOR_VELERO_INSTALLATION anyway.

AZURE_BACKUP_SUBSCRIPTION_ID=${AZURE_BACKUP_SUBSCRIPTION_ID}
AZURE_BACKUP_RESOURCE_GROUP=${AZURE_BACKUP_RESOURCE_GROUP}
AZURE_STORAGE_ACCOUNT_ID=${AZURE_STORAGE_ACCOUNT_ID}
AZURE_BLOB_CONTAINER=${AZURE_BLOB_CONTAINER}

EOF


echo "Displaying the generated VELERO_CREDENTIALS_FILE - ${VELERO_CREDENTIALS_FILE} ..."
echo
echo "---------------------------------------------------------------------------------"
cat ${VELERO_CREDENTIALS_FILE}
echo "---------------------------------------------------------------------------------"
echo



echo "Now running the velero install command ..."

echo The following command will be executed  - \
  velero install \
    --use-restic \
    --provider azure \
    --plugins velero/velero-plugin-for-microsoft-azure:v1.4.0 \
    --bucket ${AZURE_BLOB_CONTAINER} \
    --secret-file ${VELERO_CREDENTIALS_FILE} \
    --backup-location-config resourceGroup=${AZURE_BACKUP_RESOURCE_GROUP},storageAccount=${AZURE_STORAGE_ACCOUNT_ID},subscriptionId=${AZURE_BACKUP_SUBSCRIPTION_ID} \
    --snapshot-location-config apiTimeout=5m,resourceGroup=${AZURE_BACKUP_RESOURCE_GROUP},subscriptionId=${AZURE_BACKUP_SUBSCRIPTION_ID}

echo
read -p "Proceed? Enter to continue, OR, ctrl + c to abort. "
echo

velero install \
    --use-restic \
    --provider azure \
    --plugins velero/velero-plugin-for-microsoft-azure:v1.4.0 \
    --bucket ${AZURE_BLOB_CONTAINER} \
    --secret-file ${VELERO_CREDENTIALS_FILE} \
    --backup-location-config resourceGroup=${AZURE_BACKUP_RESOURCE_GROUP},storageAccount=${AZURE_STORAGE_ACCOUNT_ID},subscriptionId=${AZURE_BACKUP_SUBSCRIPTION_ID} \
    --snapshot-location-config apiTimeout=5m,resourceGroup=${AZURE_BACKUP_RESOURCE_GROUP},subscriptionId=${AZURE_BACKUP_SUBSCRIPTION_ID}
    
    
echo
    
