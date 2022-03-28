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

# Check and set configured project (default = current)
read -p "Enter project id [default:current project]: " PROJECT_ID
PROJECT_ID=${PROJECT_ID:-$(gcloud config get-value project)}

gcloud config set project ${PROJECT_ID}

# Variables
PROJECT_NUMBER=$(gcloud projects list --filter="${PROJECT_ID}" --format="value(PROJECT_NUMBER)")

read -e -i "us-central1" -p "Enter google cloud region [default: us-central1]: " REGION
read -e -i "cortex-deployer-sa" -p "Enter service account identifier for deployment [default: cortex-deployer-sa]" UMSA

UMSA_FQN=$UMSA@${PROJECT_ID}.iam.gserviceaccount.com
CBSA_FQN=${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com
ADMIN_FQ_UPN=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")

# Grant IAM Permissions to UMSA for BigQuery Tasks
gcloud projects add-iam-policy-binding -q ${PROJECT_ID} \
    --member=serviceAccount:${UMSA_FQN} \
    --role="roles/bigquery.admin"

gcloud projects add-iam-policy-binding -q ${PROJECT_ID} \
    --member=serviceAccount:${UMSA_FQN} \
    --role="roles/bigquery.dataEditor"

# Grant IAM Permissions to CBSA for BigQuery Tasks
gcloud projects add-iam-policy-binding -q ${PROJECT_ID} \
    --member=serviceAccount:${CBSA_FQN} \
    --role="roles/bigquery.dataEditor"

gcloud projects add-iam-policy-binding -q ${PROJECT_ID} \
    --member="serviceAccount:${CBSA_FQN}" \
    --role="roles/bigquery.jobUser"

# Grant IAM permisiions to CBSA for Storage Tasks
gcloud projects add-iam-policy-binding -q ${PROJECT_ID} \
    --member=serviceAccount:${CBSA_FQN} \
    --role="roles/storage.objectAdmin"

# Grant permissions to service account to run cloud build
gcloud projects add-iam-policy-binding -q ${PROJECT_ID} \
    --member="serviceAccount:${UMSA_FQN}" \
    --role="roles/cloudbuild.builds.editor"  

read -e -i "RAW_LANDING" -p "Enter name of the BQ dataset for landing raw data [default: RAW_LANDING]: " DS_RAW
bq --location=${REGION} mk -d ${DS_RAW}

read -e -i "CDC_PROCESSED" -p "Enter name of the BQ dataset for changed data processing [default: CDC_PROCESSED]: " DS_CDC
bq --location=${REGION} mk -d ${DS_CDC}

read -e -i "MODELS" -p "Enter name of the BQ dataset for ML models [default: MODELS]: " DS_MODELS
bq --location=${REGION} mk -d ${DS_MODELS}

read -e -i "REPORTING" -p "Enter name of the BQ dataset for reporting views [default: REPORTING]: " DS_REPORTING
bq --location=${REGION} mk -d ${DS_REPORTING}

# Create a storage bucket for Airflow DAGs
# Create a storage bucket for Airflow DAGs
read -e -i ${PROJECT_ID}-dags -p "Enter name of the GCS Bucket for Airflow DAGs [default: ${PROJECT_ID}-dags]: " DAGS_BUCKET
echo 'Creating GCS bucket for Airflow DAGs...'${DAGS_BUCKET}
gsutil mb -l ${REGION} gs://${DAGS_BUCKET}

# Create a storage bucket for logs
read -e -i ${PROJECT_ID}-logs -p "Enter name of the GCS Bucket for Cortex deployment logs [default: ${PROJECT_ID}-logs]: " LOGS_BUCKET
echo 'Creating GCS bucket for cortex data foundation deployment logs...\n'
gsutil mb -l ${REGION} gs://${LOGS_BUCKET}

HOME=$(pwd)

# Enable required APIs
gcloud services enable \
    bigquery.googleapis.com \

if [[ $? -ne 0 ]] ; then
    echo "Required APIs could NOT be enabled"
    exit 1
else
    echo "Required APIs enabled successfully"
fi

# Clone and run deployment checker
git clone  https://github.com/fawix/mando-checker

# Change to mando-checker folder
cd mando-checker

# Run the deployment checker
gcloud builds submit \
   --project ${PROJECT_ID} \
   --substitutions _DEPLOY_PROJECT_ID=${PROJECT_ID},_DEPLOY_BUCKET_NAME=${DAGS_BUCKET},_LOG_BUCKET_NAME=${LOGS_BUCKET} .

# Change back to parent / root folder
cd ${HOME}

# Cleanup clones repo folders
rm -rf mando-checker