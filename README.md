# Cortex Deployment Scripts
This repository has scripts for deploying Google Cloud Cortex Framework - Data Foundation for SAP.

Scripts contain commands that are specific to Argolis environments.

## Prerequisites
- Argolis environment in Google Cloud (domain: @$USER.altostrat.com)
- Argolis account with project creation permissions
- Argolis Organization Policy permissions

Following steps are strict pre-requisites in Argolis environment before running this script
- In your Argolis environment, grant yourself security admin role: Go to Cloud IAM and through the UI, grant yourself security admin role. 
- Grant yourself Organization Policy Administrator at an Organization level.  This is needed to set project level policies.  In the UI, set context to organization level (instead of project).  Go to Cloud IAM and through the UI, grant yourself Organization Policy Administrator at an Organization level.
- Log-in to Argolis as user with project creation permission and create a new project.  Note project ID. We will need this for the rest of this script

## Instructions to deploy to new argolis project
1. Login to Cloud Shell --> Open Editor --> Open New Terminal
2. Clone this repo.  Change working directory to this repo's root.
```shell
git clone https://github.com/ssdramesh/cortex-deployer-scripts
```
```shell
cd cortex-deployer-scripts
```
4. Run required script in Terminal
```shell
sh deployCortexFoundation.sh
```
Total Deployment Time: 120 min.

## What will happen?
1. All required APIs will be enabled
2. A VPC for the demo will be created, with a subnet in US
3. A User Managed Service Account (UMSA) will be created for Cortex deployment.  Required permissions will be given
4. Cloud Build Service Account (CBSA) will be given BQ permissions required during data foundation build
5. SA Impersonation for the logged in Argolis account will be granted
6. Composer environment will be created
7. Foundation BigQuery datasets required for cortex deployment will be created in US
8. Mando Checker will be run  <--Can be removed
9. Cortex Deployment will be run with test harness and CDC DAG creation
10. DAGs will be copied to composer Composer buckets <--Separate script
