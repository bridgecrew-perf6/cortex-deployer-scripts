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
read -e -i "us" -p "Enter google cloud region for BQ datasets [default: us]: " BQ_REGION
read -e -i "cortex-deployer-sa" -p "Enter service account identifier for deployment [default: cortex-deployer-sa]: " UMSA

UMSA_FQN=$UMSA@${PROJECT_ID}.iam.gserviceaccount.com
CBSA_FQN=${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com
ADMIN_FQ_UPN=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")

VPC_NM="demo"
VPC_FQN=projects/${PROJECT_ID}/global/networks/$VPC_NM
SUBNET_NM=${VPC_NM}-subnet
COMPOSER_ENV_NM=${PROJECT_ID}-cortex

HOME=$(dirname $(pwd))

# Enable required APIs
gcloud services enable \
    bigquery.googleapis.com \
    cloudbuild.googleapis.com \
    composer.googleapis.com \
    storage-component.googleapis.com \
    cloudresourcemanager.googleapis.com \
    orgpolicy.googleapis.com \
    compute.googleapis.com \
    monitoring.googleapis.com \
    cloudtrace.googleapis.com \
    clouddebugger.googleapis.com \
    cloudscheduler.googleapis.com \
    pubsub.googleapis.com


if [[ $? -ne 0 ]] ; then
    echo "Required APIs could NOT be enabled"
    exit 1
else
    echo "Required APIs enabled successfully"
fi

# Create VPC
gcloud compute networks create -q ${VPC_NM} \
    --project=${PROJECT_ID} \
    --subnet-mode=custom \
    --mtu=1460 \
    --bgp-routing-mode=regional

# Create custom subnet
gcloud compute networks subnets create -q ${SUBNET_NM} \
    --project=${PROJECT_ID} \
    --network=${VPC_NM} \
    --range=10.0.0.0/24 \
    --region=${REGION}

# Create firewall: Intra-VPC allow all communication
gcloud compute firewall-rules create -q allow-all-intra-vpc \
    --project=${PROJECT_ID} \
    --network=${VPC_FQN} \
    --description="Allows\ connection\ from\ any\ source\ to\ any\ instance\ on\ the\ network\ using\ custom\ protocols." \
    --direction=INGRESS \
    --priority=65534 \
    --source-ranges=10.0.0.0/20 \
    --action=ALLOW \
    --rules=all

# Create firewall: Allow SSH
gcloud compute firewall-rules create -q allow-all-ssh \
    --project=$PROJECT_ID \
    --network=$VPC_FQN \
    --description="Allows\ TCP\ connections\ from\ any\ source\ to\ any\ instance\ on\ the\ network\ using\ port\ 22." \
    --direction=INGRESS \
    --priority=65534 \
    --source-ranges=0.0.0.0/0 \
    --action=ALLOW \
    --rules=tcp:22

# 1##########################################################################
# Relax require OS Login
rm os_login.yaml

cat > os_login.yaml << ENDOFFILE
name: projects/${PROJECT_ID}/policies/compute.requireOsLogin
spec:
  rules:
  - enforce: false
ENDOFFILE

gcloud org-policies set-policy os_login.yaml 

rm os_login.yaml
# 2##########################################################################
# Disable Serial Port Logging
rm disableSerialPortLogging.yaml

cat > disableSerialPortLogging.yaml << ENDOFFILE
name: projects/${PROJECT_ID}/policies/compute.disableSerialPortLogging
spec:
  rules:
  - enforce: false
ENDOFFILE

gcloud org-policies set-policy disableSerialPortLogging.yaml 

rm disableSerialPortLogging.yaml

# 3##########################################################################
# Disable Shielded VM requirement
rm shieldedVm.yaml 

cat > shieldedVm.yaml << ENDOFFILE
name: projects/${PROJECT_ID}/policies/compute.requireShieldedVm
spec:
  rules:
  - enforce: false
ENDOFFILE

gcloud org-policies set-policy shieldedVm.yaml 

rm shieldedVm.yaml 

# 4##########################################################################
# Disable VM can IP forward requirement
rm vmCanIpForward.yaml

cat > vmCanIpForward.yaml << ENDOFFILE
name: projects/${PROJECT_ID}/policies/compute.vmCanIpForward
spec:
  rules:
  - allowAll: true
ENDOFFILE

gcloud org-policies set-policy vmCanIpForward.yaml

rm vmCanIpForward.yaml

# 5##########################################################################
# Enable VM external access
rm vmExternalIpAccess.yaml

cat > vmExternalIpAccess.yaml << ENDOFFILE
name: projects/${PROJECT_ID}/policies/compute.vmExternalIpAccess
spec:
  rules:
  - allowAll: true
ENDOFFILE

gcloud org-policies set-policy vmExternalIpAccess.yaml

rm vmExternalIpAccess.yaml

# 6##########################################################################
# Enable restrict VPC peering
rm restrictVpcPeering.yaml

cat > restrictVpcPeering.yaml << ENDOFFILE
name: projects/${PROJECT_ID}/policies/compute.restrictVpcPeering
spec:
  rules:
  - allowAll: true
ENDOFFILE

gcloud org-policies set-policy restrictVpcPeering.yaml

rm restrictVpcPeering.yaml

# Grant roles to user managed service account for Cloud Composer and BigQuery tasks
for role in 'roles/composer.admin' \
            'roles/composer.worker' \
            'roles/iam.serviceAccountUser' \
            'roles/iam.serviceAccountTokenCreator' \
            'roles/storage.objectViewer' \
            'roles/bigquery.admin' \
            'roles/bigquery.dataEditor' \
            'roles/cloudbuild.builds.editor' ; do \
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:${UMSA_FQN}" \
        --role="$role"
done

# Grant roles for user to operate as service account
for role in 'roles/iam.serviceAccountUser' \
            'roles/iam.serviceAccountTokenCreator' \
            'roles/composer.worker' \
            'roles/storage.objectViewer' ; do \
    gcloud iam service-accounts add-iam-policy-binding -q ${UMSA_FQN} \
        --member="user:${ADMIN_FQ_UPN}" \
        --role="$role"
done

# Grant roles for user account too
for role in 'roles/composer.admin' \
            'roles/composer.environmentAndStorageObjectViewer' ; do \
    gcloud projects add-iam-policy-binding -q ${PROJECT_ID} \
        --member=user:${ADMIN_FQ_UPN} \
        --role="$role"
done

# Grant roles to cloud build service account fot BigQuery Tasks
for role in 'roles/bigquery.dataEditor' 'roles/bigquery.jobUser' 'roles/storage.objectAdmin' ; do
    gcloud projects add-iam-policy-binding -q ${PROJECT_ID} \
        --member=serviceAccount:${CBSA_FQN} \
        --role="$role"
done

# Create a composer environment
gcloud composer environments create ${COMPOSER_ENV_NM} \
    --location ${REGION} \
    --labels env=dev,purpose=cortex-data-foundation \
    --network ${VPC_NM} \
    --subnetwork ${SUBNET_NM} \
    --service-account ${UMSA_FQN} \

# Extract the bucket name generated during composer environment creation
COMPOSER_GEN_BUCKET_FQN=$(gcloud composer environments describe ${COMPOSER_ENV_NM} --location=${REGION} --format='value(config.dagGcsPrefix)')
COMPOSER_GEN_BUCKET_NAME=$(echo ${COMPOSER_GEN_BUCKET_FQN} | cut -d'/' -f 3)
echo ${COMPOSER_GEN_BUCKET_NAME}
if [[ ${COMPOSER_GEN_BUCKET_NAME} -eq '' ]] ; then
    echo "\nCannot find DAGs bucket for the new composer environment. Please cehck environment creation logs \n"
    exit 1
fi

read -e -i "RAW_LANDING" -p "Enter name of the BQ dataset for landing raw data [default: RAW_LANDING]: " DS_RAW
bq --location=${BQ_REGION} mk -d ${DS_RAW}

read -e -i "CDC_PROCESSED" -p "Enter name of the BQ dataset for changed data processing [default: CDC_PROCESSED]: " DS_CDC
bq --location=${BQ_REGION} mk -d ${DS_CDC}

read -e -i "MODELS" -p "Enter name of the BQ dataset for ML models [default: MODELS]: " DS_MODELS
bq --location=${BQ_REGION} mk -d ${DS_MODELS}

read -e -i "REPORTING" -p "Enter name of the BQ dataset for reporting views [default: REPORTING]: " DS_REPORTING
bq --location=${BQ_REGION} mk -d ${DS_REPORTING}

# Create a storage bucket for Airflow DAGs
read -e -i ${PROJECT_ID}-dags -p "Enter name of the GCS Bucket for Airflow DAGs [default: ${PROJECT_ID}-dags]: " DAGS_BUCKET
echo 'Creating GCS bucket for Airflow DAGs...'${DAGS_BUCKET}
gsutil mb -l ${REGION} gs://${DAGS_BUCKET}

# Create a storage bucket for logs
read -e -i ${PROJECT_ID}-logs -p "Enter name of the GCS Bucket for Cortex deployment logs [default: ${PROJECT_ID}-logs]: " LOGS_BUCKET
echo 'Creating GCS bucket for cortex data foundation deployment logs...\n'
gsutil mb -l ${REGION} gs://${LOGS_BUCKET}

# Change to parent / root folder
cd ${HOME}

# Clone and run deployment checker
git clone  https://github.com/fawix/mando-checker

# Change to mando-checker folder
cd mando-checker

# Run the deployment checker
gcloud builds submit \
   --project ${PROJECT_ID} \
   --substitutions _DEPLOY_PROJECT_ID=${PROJECT_ID},_DEPLOY_BUCKET_NAME=${PROJECT_ID}-dags,_LOG_BUCKET_NAME=${PROJECT_ID}-logs .

# Change back to parent / root folder
cd ${HOME}

# Clone the Open Source Git Repo from Github
git clone --recurse-submodules https://github.com/GoogleCloudPlatform/cortex-data-foundation

# Change to cloned repo folder
cd cortex-data-foundation

# Run cloud build
gcloud builds submit --project ${PROJECT_ID} \
    --substitutions \
        _PJID_SRC=${PROJECT_ID},_PJID_TGT=${PROJECT_ID},_DS_CDC=${DS_CDC},_DS_RAW=${DS_RAW},_DS_REPORTING=${DS_REPORTING},_DS_MODELS=${DS_MODELS},_GCS_BUCKET=${LOGS_BUCKET},_TGT_BUCKET=${DAGS_BUCKET},_TEST_DATA=true,_DEPLOY_CDC=true

OPEN_BUILDS= $(gcloud builds list --filter 'status=WORKING')
while [ ! -z ${OPEN_BUILDS} ]
do 
    echo "waiting for cortex-data-foundation build to complete..."
    sleep 5m
    ${OPEN_BUILDS}=$(gcloud builds list --filter 'status=WORKING')
done

# Copy files from generation storage bucket to Cloud Composer DAGs bucket folders
SRC_DAGS_BUCKET=$(echo gs://${PROJECT_ID}-dags/dags)
TGT_DAGS_BUCKET=$(echo gs://${COMPOSER_GEN_BUCKET_NAME}/dags)
gsutil -m cp -r  ${SRC_DAGS_BUCKET} ${TGT_DAGS_BUCKET}

SRC_DATA_BUCKET=$(echo gs://${PROJECT_ID}-dags/data)
TGT_DATA_BUCKET=$(echo gs://${COMPOSER_GEN_BUCKET_NAME}/data)
gsutil -m cp -r  ${SRC_DATA_BUCKET} ${TGT_DATA_BUCKET} 

SRC_HIER_BUCKET=$(echo gs://${PROJECT_ID}-dags/hierarchies)
TGT_HIER_BUCKET=$(echo gs://${COMPOSER_GEN_BUCKET_NAME}/dags/hierarchies/)
gsutil -m cp -r  ${SRC_HIER_BUCKET} ${TGT_HIER_BUCKET} 

# Delete holding bucket
gsutil rm -r gs://${PROJECT_ID}-dags


# Argolis/Google Internal-specific: Share your datasets with googlecloud.looker.com
read -e -i "N" -p "Do you want to connect your datasets to Google-internal looker demo instance [Y/N] " IS_ARGOLIS
if [[ ${IS_ARGOLIS} =~ ^([yY][eE][sS] | [yY])$ ]]
then
    gcloud projects add-iam-policy-binding -q ${PROJECT_ID} \
        --member=serviceAccount:googlecloud@sandbox-trials.iam.gserviceaccount.com \
        --role="roles/bigquery.dataViewer"    
    gcloud projects add-iam-policy-binding -q ${PROJECT_ID} \
        --member=serviceAccount:googlecloud@sandbox-trials.iam.gserviceaccount.com \
        --role="roles/viewer"
fi

# Change back to parent / root folder
cd ${HOME}

# Cleanup clones repo folders
rm -rf mando-checker
rm -rf cortex-data-foundation

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

# Application Layer
# Configure Pub / Sub
gcloud projects add-iam-policy-binding {PROJECT_ID} \
     --member=serviceAccount:service-${PSSA_FQN} \
     --role=roles/iam.serviceAccountTokenCreator

# Create Cluster
# this creates a very bare-minimum cluster with all defaults
gcloud container clusters create cortex \
    --workload-pool=$PROJECT_ID.svc.id.goog

# Configure Workload Identity for your target namespace for the deployer service account. The Kubernetes SA name is `cortex-apployer-bot`.
# This step is only after the creation of a cluster
gcloud iam service-accounts add-iam-policy-binding ${UMSAD_FQN} \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:${WISA}"