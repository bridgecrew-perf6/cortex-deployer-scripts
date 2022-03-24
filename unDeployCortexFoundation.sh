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

DS_CDC=CDC_PROCESSED
DS_MODELS=MODELS
DS_REPORTING=REPORTING

HOME=$(pwd)

# Remove BigQuery Datasets
read -p "Enter name of the BQ dataset for landing raw data [default: RAW_LANDING]: " DS_RAW
DS_RAW=${DS_RAW:-'RAW_LANDING'}
bq rm -r -f -d ${PROJECT_ID}:${DS_RAW}

read -p "Enter name of the BQ dataset for changed data processing [default: CDC_PROCESSED]: " DS_CDC
DS_CDC=${DS_CDC:-'CDC_PROCESSED'}
bq rm -r -f -d ${PROJECT_ID}:${DS_CDC}

read -p "Enter name of the BQ dataset for ML models [default: MODELS]: " DS_MODELS
DS_MODELS=${DS_MODELS:-'MODELS'}
bq rm -r -f -d ${PROJECT_ID}:${DS_MODELS}

read -p "Enter name of the BQ dataset for reporting views [default: REPORTING]: " DS_REPORTING
DS_MODELS=${DS_REPORTING:-'REPORTING'}
bq rm -r -f -d ${PROJECT_ID}:${DS_REPORTING}

read -p "Enter google cloud region used for cortex-deployment[default: us-central1]: " REGION
REGION=${REGION:-us-central1}

# Prepare to delete cloud composer instance
read -p "Enter Cloud Composer Environment Name [default: ${PROJECT_ID}-cortex]: " VPC_NM
COMPOSER_ENV_NM=${PROJECT_ID}-cortex

# Extract the bucket name generated during composer environment creation
COMPOSER_GEN_BUCKET_FQN=$(gcloud composer environments describe ${COMPOSER_ENV_NM} --location=${REGION} --format='value(config.dagGcsPrefix)')
COMPOSER_GEN_BUCKET_NAME=$(echo ${COMPOSER_GEN_BUCKET_FQN} | cut -d'/' -f 3)

# Remove Cloud Composer Instance
gcloud composer environments delete ${COMPOSER_ENV_NM} --location ${REGION} 

# Remove bucket created by the Cloud Composer Instance
gsutil rm -r gs://${COMPOSER_GEN_BUCKET_NAME}

# Remove all the persistent disks that were previously used by  the removed cloud composer instance


# Restore permissions relaxed for creation of Cloud Composer

# Remove Cloud Storage Buckets

# Remove VPC Network
read -p "Enter VPC network [default: demo]: " VPC_NM
VPC_NM="demo"
VPC_FQN=projects/${PROJECT_ID}/global/networks/$VPC_NM
SUBNET_NM=${VPC_NM}-subnet

# Remove IAM permissions for Cloud build service account (CBSA)

# Remove User Managed Service Account (UMSA)
read -p "Enter service account identifier for deployment [default: cortex-deployer-sa]" UMSA
UMSA=${UMSA:-cortex-deployer-sa}
UMSA_FQN=$UMSA@${PROJECT_ID}.iam.gserviceaccount.com

# Remove cloned repo folder 