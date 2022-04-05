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

## Instructions for end-to-end deployment to new project (fro example, in Argolis environment)
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
sh deployCortexFoundationE2E.sh
```
Total Deployment Time: ~120-140 min.

### What will happen in end-to-end deployment?
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

## Instructions for end-to-end undeployment of cortex foundation
1. Run required script in Terminal
```shell
sh unDeployCortexFoundationE2E.sh
```

### What will happen in end-to-end deployment?

## Instructions for step-by-step deployment (Workshop / Labs mode)
### Exercise 1: Deploy Cloud Composer instance
### Exercise 2: Deploy BigQuery Datasets
### Exercise 3: Deploy Cortex Foundation
### Exercise 5: Deploy Cortex Solution
