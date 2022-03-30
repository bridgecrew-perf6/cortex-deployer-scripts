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
read -e -i "cortex-app-deployer-sa" -p "Enter service account identifier for deployment [default: cortex-app-deployer-sa]: " UMSAD
read -e -i "cortex-app-runner-sa" -p "Enter service account identifier for running app [default: cortex-app-runner-sa]: " UMSAR
read -e -i ${PROJECT_ID}-cortex-app -p "Enter GCS Bucket identifier for deployment [default: ${PROJECT_ID}-cortex-app]: " APP_BUCKET

UMSAD_FQN=$UMSAD@${PROJECT_ID}.iam.gserviceaccount.com
UMSAR_FQN=$UMSAR@${PROJECT_ID}.iam.gserviceaccount.com
PSSA_FQN=${PROJECT_NUMBER}@gcp-sa-pubsub.iam.gserviceaccount.com
WISA=${PROJECT_ID}.svc.id.goog[default/cortex-apployer-bot]

# Create a bucket for cortex sample application deployment:
gsutil mb -l ${REGION} gs://${APP_BUCKET}

# Create the User Managed Service Account for Deployment UMSAD
gcloud iam service-accounts create -q ${UMSAD} \
    --description="User Managed Service Account for Cortex Application Deployment" \
    --display-name=$UMSAD

# Grant IAM Permissions to deployer service account
# Cloud Run Administrator
gcloud projects add-iam-policy-binding -q ${PROJECT_ID} \
    --member=serviceAccount:${UMSAD_FQN} \
    --role="roles/run.admin"

# Cloud Scheduler Administrator
gcloud projects add-iam-policy-binding -q ${PROJECT_ID} \
    --member=serviceAccount:${UMSAD_FQN} \
    --role="roles/cloudscheduler.admin"

# Pub/Sub Administrator
gcloud projects add-iam-policy-binding -q ${PROJECT_ID} \
    --member=serviceAccount:${UMSAD_FQN} \
    --role="roles/pubsub.admin"


# Service Usage Administrator
gcloud projects add-iam-policy-binding -q ${PROJECT_ID} \
    --member=serviceAccount:${UMSAD_FQN} \
    --role="roles/serviceusage.serviceUsageAdmin"


# Source Repository Administrator
gcloud projects add-iam-policy-binding -q ${PROJECT_ID} \
    --member=serviceAccount:${UMSAD_FQN} \
    --role="roles/source.admin"

# Storage Object Admin
gcloud projects add-iam-policy-binding -q ${PROJECT_ID} \
    --member=serviceAccount:${UMSAD_FQN} \
    --role="roles/storage.admin"

# Create the User Managed Service Account for running Cortex sample application UMSAR
gcloud iam service-accounts create -q ${UMSAR} \
    --description="User Managed Service Account for running Cortex Application" \
    --display-name=$UMSAR

# Grant IAM Permissions to runner service account
# Cloud Run Invoker
gcloud projects add-iam-policy-binding -q ${PROJECT_ID} \
    --member=serviceAccount:${UMSAR_FQN} \
    --role="roles/run.invoker"

# BigQuery Data Viewer
gcloud projects add-iam-policy-binding -q ${PROJECT_ID} \
    --member=serviceAccount:${UMSAR_FQN} \
    --role="roles/bigquery.dataViewer"

# BigQuery Job User
gcloud projects add-iam-policy-binding -q ${PROJECT_ID} \
    --member=serviceAccount:${UMSAR_FQN} \
    --role="roles/bigquery.jobUser"

# Pub/Sub Publisher
gcloud projects add-iam-policy-binding -q ${PROJECT_ID} \
    --member=serviceAccount:${UMSAR_FQN} \
    --role="roles/pubsub.publisher)"

# Configure Pub / Sub
gcloud projects add-iam-policy-binding {PROJECT_ID} \
     --member=serviceAccount:service-${PSSA_FQN} \
     --role=roles/iam.serviceAccountTokenCreator

# Create Cluster

# Configure Workload Identity for your target namespace for the deployer service account. The Kubernetes SA name is `cortex-apployer-bot`.
# This step is only after the creation of a cluster
gcloud iam service-accounts add-iam-policy-binding ${UMSAD_FQN} \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:${WISA}"

# @TODO: (after published in GCP marketplace)
# Clone repo 

# @TODO: (after published in GCP marketplace)
# Cloud build