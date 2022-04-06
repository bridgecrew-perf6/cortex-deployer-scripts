# Cortex Deployment Scripts
This repository has scripts for deploying Google Cloud Cortex Framework - Data Foundation for SAP and preparatory steps to deploy Cortex Application Layer sample application via Google Cloud Marketplace.

## Prerequisites
- Google Cloud account with Project Creation permissions (role: Project Creator)
- Google Cloud account with Organization Policy permissions (role: Organization Policy Admin)

Following steps are pre-requisites in your Google Cloud project environment before running the scripts in this repo:
- In a separate browser window (e.g. Incognito or separate Chrome browser user profile), login as account with Project Creator role, grant yourself ```Security Admin``` role: Go to [Cloud Console](https://console.cloud.google.com) --> ```IAM```, grant yourself ```Security Admin``` role. 
- In a separate browser window (e.g. Incognito or separate Chrome browser user profile), login as account with ```Organization Policy Admin``` role, grant the Project Creator account from the previous step the ```Organization Policy Admin``` role at an Organization level.  This is needed to set project level policies.  Go to [Cloud Console](https://console.cloud.google.com), set context to organization level (instead of project).  Then go to ```IAM``` and grant ```Project Creator``` account (from previous step) the ```Organization Policy Admin``` role at an Organization level and ```Save```.  Close this Browser tab / window.
- Navigate back to the browser window in which you logged in as Project Creator.  Create a new project using the [Cloud Console](https://console.cloud.google.com).  Note project ID. We will need this for the rest of this script

## Instructions for end-to-end deployment to new project (for example, in Argolis environment)
1. Check Billing Account for the new project is set.  If not proceeed to set it. Login with user credentials that has the required role: ```Billing Account Creator```. Open Cloud Console --> From Org view --> Switch to Home Page of new Proejct --> (Click Hamburger Menu - Top Left) Select ```Billing``` --> ```Link Billing Account```.  On the pop-up that follows (Title: Select the billing account for your project ```<<Your New Project Name>>```) --> select an existing billing account from the drop-down and click ```Set Account```.  Do NOT forget to switch back to a Argolis user account, before you continue with the next steps.
2. Login to Cloud Shell --> Open Editor --> Open New Terminal
3. Clone this repo.  Change working directory to this repo's root.
```shell
git clone https://github.com/ssdramesh/cortex-deployer-scripts
```
```shell
cd cortex-deployer-scripts
```
4. Run required script in Terminal
```shell
sh deployCortexE2E.sh
```
Total Deployment Time: ~120-140 min.

### What will happen in end-to-end deployment?
1. All required APIs will be enabled
2. A VPC for the will be created with the name ```demo```, with a subnet in ```us-central1``` named ```us-central1```
3. A User Managed Service Account (UMSA) will be created for Cortex deployment.  Required permissions for Cloud Composer and BigQuery tasks will be granted
4. Cloud Build Service Account (CBSA) will be given BQ permissions required during data foundation build
5. SA Impersonation for the logged in account will be granted
6. Composer environment will be created
7. Foundation BigQuery datasets required for cortex deployment will be created in US
8. Cortex Data Foundation deployment preflight checker will be run
9. Cortex Deployment will be run with test harness and CDC DAG creation
10. DAGs will be copied to composer Composer buckets
11. Pub/Sub will be configured in preparaton of Cortex App Layer deployment from market place
12. Container cluster will be created in preparaton of Cortex App Layer deployment from market place
13. Workload Identity will be configured for the deployer service account in preparaton of Cortex App Layer deployment from market place

## Instructions for step-by-step deployment (Workshop / Labs mode)
The scripts named as ```exercise*.sh``` can be used as tech workshop (fast track option)

### Exercise 1: Deploy Cloud Composer instance
Contains all the steps required to create a Cloud Composer instance for CDC DAGs functionality of Cortex Data Foundation

### Exercise 2: Deploy BigQuery Datasets
Prepares a new project environment for the deployment of Cortex data Foundation.  Runs a "checker-build" to check the readiness of the Google Cloud project for the deployment of Cortex Data Foundation

### Exercise 3: Deploy Cortex Foundation
Submits the cloud build that triggers the actual deployment of all the artifacts of the Cortex Data Foundation

### Exercise 5: Configure project for Cortex Application Layer - sample application deployment
Runs all the steps required to configure the Google Cloud project to prepare for Cortex Application Layer - sample application deployment (via Google Cloud Marketplace) 

## Instructions for end-to-end "un"deployment of cortex
A helper script to rest your Googel Cloud project to initial state (CAUTION: Work-In-Progress, you might still need to execute some manual clean-up)
1. Run required script in Terminal
```shell
sh unDeployCortexE2E.sh
```