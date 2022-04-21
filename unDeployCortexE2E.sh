#!/bin/bash

# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Set Project
# Check and set configured project (default = current)
read -p "Enter project id [default:current project]: " PROJECT_ID
PROJECT_ID=${PROJECT_ID:-$(gcloud config get-value project)}

gcloud config set project ${PROJECT_ID}

# Derive parameters
PROJECT_NUMBER=$(gcloud projects list --filter="${PROJECT_ID}" --format="value(PROJECT_NUMBER)")
CBSA_FQN=${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com
ADMIN_FQ_UPN=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")

HOME=$(pwd)

# Remove BigQuery Datasets
read -e -i "RAW_LANDING" -p "Enter name of the BQ dataset for landing raw data [default: RAW_LANDING]: " DS_RAW
bq rm -r -f -d ${PROJECT_ID}:${DS_RAW}

read -e -i "CDC_PROCESSED" -p "Enter name of the BQ dataset for changed data processing [default: CDC_PROCESSED]: " DS_CDC
bq rm -r -f -d ${PROJECT_ID}:${DS_CDC}

read -e -i "MODELS" -p "Enter name of the BQ dataset for ML models [default: MODELS]: " DS_MODELS
bq rm -r -f -d ${PROJECT_ID}:${DS_MODELS}

read -e -i "REPORTING" -p "Enter name of the BQ dataset for reporting views [default: REPORTING]: " DS_REPORTING
bq rm -r -f -d ${PROJECT_ID}:${DS_REPORTING}

read -e -i "us-central1" -p "Enter google cloud region used for cortex-deployment[default: us-central1]: " REGION

# Prepare to delete cloud composer instance
read -e -i ${PROJECT_ID}-cortex -p "Enter Cloud Composer environment name [default: ${PROJECT_ID}-cortex]: " COMPOSER_ENV_NM

# Extract the bucket name generated during composer environment creation BEFORE deleting it!
COMPOSER_GEN_BUCKET_FQN=$(gcloud composer environments describe ${COMPOSER_ENV_NM} --location=${REGION} --format='value(config.dagGcsPrefix)')
COMPOSER_GEN_BUCKET_NAME=$(echo ${COMPOSER_GEN_BUCKET_FQN} | cut -d'/' -f 3)
if [[ -z ${COMPOSER_GEN_BUCKET_NAME} ]] ; then
    echo 'Could not extract Cloud Composer bucket location for environment: '${COMPOSER_ENV_NM} 
    echo 'Please check Cloud Composer environment creation logs'
    exit 1
fi

# Remove Cloud Composer Instance
echo 'Removing Cloud Composer installation: '${COMPOSER_ENV_NM}
gcloud composer environments delete -q ${COMPOSER_ENV_NM} --location ${REGION} 

# Remove bucket created by the Cloud Composer Instance
echo 'Removing bucket created by Cloud Composer installation: '${COMPOSER_GEN_BUCKET_NAME}
gsutil rm -r gs://${COMPOSER_GEN_BUCKET_NAME}

# Remove all the persistent disks that were previously used by  the removed cloud composer instance
for ZONE_LONG in $(gcloud compute disks list --format='value(ZONE)' | sort | uniq)
do
    ZONE=$(echo ${ZONE_LONG} | cut -d'/' -f 9)
    gcloud config set compute/zone ${ZONE}
    echo 'Removing disks left by Cloud Composer installation: '${COMPOSER_ENV_NM}
    gcloud compute disks delete -q $(gcloud compute disks list --filter="zone=${ZONE} AND -users:*" --format "value(name)")
done

# Reset OS login requirement
gcloud org-policies reset constraints/compute.requireOsLogin --project=${PROJECT_ID}

# Reset disable serial port logging 
gcloud org-policies reset constraints/compute.disableSerialPortLogging --project=${PROJECT_ID}

# Reset shielded VM requirement
gcloud org-policies reset constraints/compute.requireShieldedVm --project=${PROJECT_ID}

# Reset VM can IP forward
gcloud org-policies reset constraints/compute.vmCanIpForward --project=${PROJECT_ID}

# Reset VM external access
gcloud org-policies reset constraints/compute.vmExternalIpAccess --project=${PROJECT_ID}

# Rest restrict VPC peering
gcloud org-policies reset constraints/compute.restrictVpcPeering --project=${PROJECT_ID}

# Remove other Cloud Storage Buckets created by cloud builds and cortex deployment
read -e -i ${PROJECT_ID}-dags -p "Enter name of the GCS Bucket for Airflow DAGs [default: ${PROJECT_ID}-dags]: " DAGS_BUCKET
echo 'Deleting GCS bucket for cortex data foundation DAGs...'
gsutil rm -r gs://${DAGS_BUCKET}

read -e -i ${PROJECT_ID}-logs -p "Enter name of the GCS Bucket for Cortex deployment logs [default: ${PROJECT_ID}-logs]: " LOGS_BUCKET
echo 'Deleting GCS bucket for cortex data foundation deployment logs...'
gsutil rm -r gs://${LOGS_BUCKET}

read -e -i ${PROJECT_ID}-cortex-app -p "Enter GCS Bucket identifier for deployment [default: ${PROJECT_ID}-cortex-app]: " APP_BUCKET
gsutil rm -r gs://${APP_BUCKET}

echo 'Deleting GCS bucket for all cloud build logs...'
gsutil rm -r gs://${PROJECT_ID}_cloudbuild

# # Remove firewalls
# echo 'Deleting firewall: allow-all-intra-vpc'
# gcloud compute firewall-rules delete allow-all-intra-vpc

# echo 'Deleting firewall: allow-ssh'
# gcloud compute firewall-rules delete allow-ssh
# FW_RULES=$(gcloud compute firewall-rules list --format="value(name)")
for rule in $(gcloud compute firewall-rules list --format="value(name)") ; do
    gcloud compute firewall-rules delete $rule
done

# Remove subnet
read -e -i "demo" -p "Enter VPC network [default: demo]: " VPC_NM
read -e -i ${VPC_NM}-subnet -p "Enter subnet [default: ${VPC_NM}-subnet]: " ${VPC_NM}-subnet
gcloud compute networks subnets delete ${VPC_NM}-subnet --region=${REGION}

# Remove VPC Network
gcloud compute networks delete ${VPC_NM}

# Remove roles for cloud build
for role in 'roles/bigquery.dataEditor' 'roles/bigquery.jobUser' 'roles/storage.objectAdmin' ; do
    gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
        --member=serviceAccount:${CBSA_FQN} \
        --role="$role"
done

# Grant logged in user permission to remove service accounts
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=${ADMIN_FQ_UPN}
    --role:"roles/iam.serviceAccountKeyAdmin"

# Remove User Managed Service Account (UMSA)
read -e -i "cortex-fdn-deployer" -p "Enter service account identifier for deployment [default: cortex-fdn-deployer]: " UMSA
read -e -i "cortex-app-deployer" -p "Enter service account identifier for deployment [default: cortex-app-deployer]: " UMSAD
read -e -i "cortex-app-runner" -p "Enter service account identifier for running app [default: cortex-app-runner]: " UMSAR

UMSA_FQN=$UMSA@${PROJECT_ID}.iam.gserviceaccount.com
UMSAD_FQN=$UMSAD@${PROJECT_ID}.iam.gserviceaccount.com
UMSAR_FQN=$UMSAR@${PROJECT_ID}.iam.gserviceaccount.com

gcloud auth revoke ${UMSA_FQN}
gcloud iam service-accounts delete -q ${UMSA_FQN}

gcloud auth revoke ${UMSAD_FQN}
gcloud iam service-accounts delete -q ${UMSAD_FQN}

gcloud auth revoke ${UMSAD_FQN}
gcloud iam service-accounts delete -q ${UMSAD_FQN}

# Disbale APIs
gcloud services disable --force \
    cloudbuild.googleapis.com \
    composer.googleapis.com \
    storage-component.googleapis.com \
    cloudresourcemanager.googleapis.com \
    orgpolicy.googleapis.com \
    monitoring.googleapis.com \
    cloudtrace.googleapis.com \
    clouddebugger.googleapis.com \
    cloudscheduler.googleapis.com \
    pubsub.googleapis.com

if [[ $? -ne 0 ]] ; then
    echo "Required APIs could NOT be disabled"
    exit 1
else
    echo "Required APIs disabled successfully"
fi