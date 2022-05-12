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
read -e -i $(gcloud config get-value project) -p "Enter project id: " PROJECT_ID
gcloud config set project ${PROJECT_ID}

# Variables
PROJECT_NUMBER=$(gcloud projects list --filter="${PROJECT_ID}" --format="value(PROJECT_NUMBER)")

read -e -i "us-central1" -p "Enter google cloud region [default: us-central1]: " REGION
#  @TODO: Currently only US works!
read -e -i "us" -p "Enter google cloud region for BQ datasets [default: us]: " LOCATION
read -e -i "demo" -p "Enter VPC name for deployment [default: demo]: " VPC_NM

read -e -i "cortex-app-deployer-sa" -p "Enter service account identifier for deployment [default: cortex-app-deployer-sa]: " UMSAD
read -e -i "cortex-app-runner-sa" -p "Enter service account identifier for running app [default: cortex-app-runner-sa]: " UMSAR
read -e -i ${PROJECT_ID}-cortex-app -p "Enter GCS Bucket identifier for deployment [default: ${PROJECT_ID}-cortex-app]: " APP_BUCKET

UMSAD_FQN=$UMSAD@${PROJECT_ID}.iam.gserviceaccount.com
UMSAR_FQN=$UMSAR@${PROJECT_ID}.iam.gserviceaccount.com
PSSA_FQN=${PROJECT_NUMBER}@gcp-sa-pubsub.iam.gserviceaccount.com
WISA=${PROJECT_ID}.svc.id.goog[default/cortex-apployer-bot]

#  Enable APIs
gcloud services enable \
    cloudscheduler.googleapis.com \    
    pubsub.googleapis.com

# Create a bucket for cortex sample application deployment:
gsutil mb -l ${REGION} gs://${APP_BUCKET}

# Create the User Managed Service Account for Deployment UMSAD
gcloud iam service-accounts create -q ${UMSAD} \
    --description="User Managed Service Account for Cortex Application Deployment" \
    --display-name=$UMSAD

# Grant IAM Permissions to deployer service account
for role in 'roles/run.admin' 'roles/cloudscheduler.admin' 'roles/pubsub.admin' 'roles/serviceusage.serviceUsageAdmin' 'roles/source.admin' 'roles/storage.objectAdmin' 'roles/iam.serviceAccountUser' ; do
    gcloud projects add-iam-policy-binding -q $PROJECT_ID \
        --member=serviceAccount:${UMSAD_FQN} \
        --role="$role"
done

# Create the User Managed Service Account for running Cortex sample application UMSAR
gcloud iam service-accounts create -q ${UMSAR} \
    --description="User Managed Service Account for running Cortex Application" \
    --display-name=$UMSAR

# Grant IAM Permissions to runner service account
for role in 'roles/run.invoker' 'roles/cloudscheduler.admin' 'roles/bigquery.dataViewer' 'roles/bigquery.jobUser' 'roles/pubsub.publisher' ; do
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:${UMSAR_FQN}" \
        --role="$role"
done

# Configure Pub / Sub
gcloud projects add-iam-policy-binding {PROJECT_ID} \
     --member=serviceAccount:service-${PSSA_FQN} \
     --role=roles/iam.serviceAccountTokenCreator

# Create Cluster
# this creates a very bare-minimum cluster with all defaults
gcloud container clusters create cortex \
    --region=${REGION} \
    --machine-type=e2-standard-4 \
    --network=${VPC_NM} \
    --subnetwork=${VPC_NM}-subnet \
    --workload-pool=$PROJECT_ID.svc.id.goog

# Configure Workload Identity for your target namespace for the deployer service account. The Kubernetes SA name is `cortex-apployer-bot`.
# This step is only after the creation of a cluster
gcloud iam service-accounts add-iam-policy-binding ${UMSAD_FQN} \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:${WISA}"
