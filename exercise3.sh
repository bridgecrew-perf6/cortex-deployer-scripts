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

read -e -i "RAW_LANDING" -p "Enter name of the BQ dataset for landing raw data [default: RAW_LANDING]: " DS_RAW
read -e -i "CDC_PROCESSED" -p "Enter name of the BQ dataset for changed data processing [default: CDC_PROCESSED]: " DS_CDC
read -e -i "MODELS" -p "Enter name of the BQ dataset for ML models [default: MODELS]: " DS_MODELS
read -e -i "REPORTING" -p "Enter name of the BQ dataset for reporting views [default: REPORTING]: " DS_REPORTING
read -e -i ${PROJECT_ID}-dags -p "Enter name of the GCS Bucket for Airflow DAGs [default: ${PROJECT_ID}-dags]: " DAGS_BUCKET
read -e -i ${PROJECT_ID}-logs -p "Enter name of the GCS Bucket for Cortex deployment logs [default: ${PROJECT_ID}-logs]: " LOGS_BUCKET

read -e -i "us-central1" -p "Enter google cloud region [default: us-central1]: " REGION
read -e -i "cortex-deployer-sa" -p "Enter service account identifier for deployment [default: cortex-deployer-sa]: " UMSA
read -e -i ${PROJECT_ID}-cortex -p "Enter the name of the cloud composer environment for Airflow DAGs deployment: [default: ${PROJECT_ID}-cortex]: " COMPOSER_ENV_NM

UMSA_FQN=$UMSA@${PROJECT_ID}.iam.gserviceaccount.com
#  Check if the following are used?
CBSA_FQN=${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com
ADMIN_FQ_UPN=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")

# Change to user root for cloning new repos
HOME=$(dirname $(pwd))

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

# Extract the bucket name generated during composer environment creation
COMPOSER_GEN_BUCKET_FQN=$(gcloud composer environments describe ${COMPOSER_ENV_NM} --location=${REGION} --format='value(config.dagGcsPrefix)')
COMPOSER_GEN_BUCKET_NAME=$(echo ${COMPOSER_GEN_BUCKET_FQN} | cut -d'/' -f 3)
echo ${COMPOSER_GEN_BUCKET_NAME}
if [ -z ${COMPOSER_GEN_BUCKET_NAME} ] ; then
    echo "Cannot find DAGs bucket for the new composer environment. Please cehck environment creation logs"
    exit 1
fi

# Copy files from generation storage bucket to Cloud Composer DAGs bucket folders
SRC_DAGS_BUCKET=$(echo gs://${PROJECT_ID}-dags/dags)
TGT_DAGS_BUCKET=$(echo gs://${COMPOSER_GEN_BUCKET_NAME})
gsutil -m cp -r  ${SRC_DAGS_BUCKET} ${TGT_DAGS_BUCKET}

SRC_DATA_BUCKET=$(echo gs://${PROJECT_ID}-dags/data)
TGT_DATA_BUCKET=$(echo gs://${COMPOSER_GEN_BUCKET_NAME})
gsutil -m cp -r  ${SRC_DATA_BUCKET} ${TGT_DATA_BUCKET} 

SRC_HIER_BUCKET=$(echo gs://${PROJECT_ID}-dags/hierarchies)
TGT_HIER_BUCKET=$(echo gs://${COMPOSER_GEN_BUCKET_NAME}/dags)
gsutil -m cp -r  ${SRC_HIER_BUCKET} ${TGT_HIER_BUCKET} 

# Change back to parent / root folder
cd ${HOME}

# Cleanup clones repo folders
rm -rf cortex-data-foundation

# Delete holding bucket
gsutil rm -r gs://${PROJECT_ID}-dags