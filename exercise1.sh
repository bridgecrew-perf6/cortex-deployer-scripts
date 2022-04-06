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
read -e -i "cortex-deployer-sa" -p "Enter service account identifier for deployment [default: cortex-deployer-sa]: " UMSA
read -e -i "demo" -p "Enter VPC name for deployment [default: demo]: " VPC_NM
read -e -i ${PROJECT_ID}-cortex -p "Enter Cloud Composer environment name [default: ${PROJECT_ID}-cortex]" COMPOSER_ENV_NM

UMSA_FQN=$UMSA@${PROJECT_ID}.iam.gserviceaccount.com
CBSA_FQN=${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com
ADMIN_FQ_UPN=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
VPC_FQN=projects/${PROJECT_ID}/global/networks/$VPC_NM
SUBNET_NM=${VPC_NM}-subnet

# Change to user root for cloning new repos
HOME=$(dirname $(pwd))

# Enable required APIs
gcloud services enable \
    composer.googleapis.com \
    storage-component.googleapis.com \
    cloudresourcemanager.googleapis.com \
    orgpolicy.googleapis.com \
    compute.googleapis.com \
    monitoring.googleapis.com \
    cloudtrace.googleapis.com \
    clouddebugger.googleapis.com

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
if [ $? -ne 0 ]; then
    echo "Error -- Failed to create network ${VPC_NM} in project ${PROJECT_ID}"
    exit 1
else

# Create custom subnet
gcloud compute networks subnets create -q ${SUBNET_NM} \
    --project=${PROJECT_ID} \
    --network=${VPC_NM} \
    --range=10.0.0.0/24 \
    --region=${REGION}
if [ $? -ne 0 ]; then
    echo "Error -- Failed to create subnet ${SUBNET_NM} for network ${VPC_NM} in project ${PROJECT_ID}"
    exit 1
else

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

# Argolis specific: Relax require OS Login
rm os_login.yaml

cat > os_login.yaml << ENDOFFILE
name: projects/${PROJECT_ID}/policies/compute.requireOsLogin
spec:
  rules:
  - enforce: false
ENDOFFILE

gcloud org-policies set-policy os_login.yaml 

rm os_login.yaml

# Argolis specific: Disable Serial Port Logging
rm disableSerialPortLogging.yaml

cat > disableSerialPortLogging.yaml << ENDOFFILE
name: projects/${PROJECT_ID}/policies/compute.disableSerialPortLogging
spec:
  rules:
  - enforce: false
ENDOFFILE

gcloud org-policies set-policy disableSerialPortLogging.yaml 

rm disableSerialPortLogging.yaml

# Argolis Specific: Disable Shielded VM requirement
rm shieldedVm.yaml 

cat > shieldedVm.yaml << ENDOFFILE
name: projects/${PROJECT_ID}/policies/compute.requireShieldedVm
spec:
  rules:
  - enforce: false
ENDOFFILE

gcloud org-policies set-policy shieldedVm.yaml 

rm shieldedVm.yaml 

# Argolis Specific: Disable VM can IP forward requirement
rm vmCanIpForward.yaml

cat > vmCanIpForward.yaml << ENDOFFILE
name: projects/${PROJECT_ID}/policies/compute.vmCanIpForward
spec:
  rules:
  - allowAll: true
ENDOFFILE

gcloud org-policies set-policy vmCanIpForward.yaml

rm vmCanIpForward.yaml

# Argolis Specific: Enable VM external access
rm vmExternalIpAccess.yaml

cat > vmExternalIpAccess.yaml << ENDOFFILE
name: projects/${PROJECT_ID}/policies/compute.vmExternalIpAccess
spec:
  rules:
  - allowAll: true
ENDOFFILE

gcloud org-policies set-policy vmExternalIpAccess.yaml

rm vmExternalIpAccess.yaml

# Argolis Specific: Enable restrict VPC peering
rm restrictVpcPeering.yaml

cat > restrictVpcPeering.yaml << ENDOFFILE
name: projects/${PROJECT_ID}/policies/compute.restrictVpcPeering
spec:
  rules:
  - allowAll: true
ENDOFFILE

gcloud org-policies set-policy restrictVpcPeering.yaml

rm restrictVpcPeering.yaml

# Create a user managed service account
gcloud iam service-accounts create -q ${UMSA} \
    --description="User Managed Service Account for Cortex Deployment" \
    --display-name=$UMSA 

# Grant roles to user managed service account
for role in 'roles/composer.admin' \
            'roles/iam.serviceAccountTokenCreator' \
            'roles/composer.worker' \
            'roles/storage.objectViewer' \
            'roles/iam.serviceAccountUser' ; do
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:${UMSA_FQN}" \
        --role="$role"
done

# Grant roles for user to operate as service account
for role in 'roles/iam.serviceAccountUser' \
            'roles/iam.serviceAccountTokenCreator' \
            'roles/iam.serviceAccountUser' ; do
    gcloud iam service-accounts add-iam-policy-binding -q ${UMSA_FQN} \
        --member="user:${ADMIN_FQ_UPN}" \
        --role="$role"
done

# Grant roles for user account too
for role in 'roles/composer.admin' \
            'roles/composer.worker' \
            'roles/storage.objectViewer' \
            'roles/composer.environmentAndStorageObjectViewer' ; do
    gcloud projects add-iam-policy-binding -q ${PROJECT_ID} \
        --member=user:${ADMIN_FQ_UPN} \
        --role="$role"
done

# Create a composer environment
gcloud composer environments create ${COMPOSER_ENV_NM} \
    --location ${REGION} \
    --labels env=dev,purpose=cortex-data-foundation \
    --network ${VPC_NM} \
    --subnetwork ${SUBNET_NM} \
    --service-account ${UMSA_FQN}

exit 0
