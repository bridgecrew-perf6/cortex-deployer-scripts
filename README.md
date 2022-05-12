# Cortex Deployment Scripts
This repository has the scripts for the exercises of Google Cloud Cortex Framework Tech Workshop (Tech Workshop).  The Tech Workshop familiarises participants with the following:
- Deployment of a Cloud Composer environment used by the Cortex Data Foundation
- Checking the prerequisites for deployment of Cortex Data Foundation
- Deploying the Cortex Data Foundation cloned from the open sourse Github location
- Executing preparatory steps for the deployment of Cortex Application Layer sample application

The scripts in this repository are useful for fast tracking the exercise of the Tech Workshop

Please ensure that you follow the exercise flow, in the order instructed in the workshop slide deck.  Subsequent exercises have dependencies on previous ones like granted permissions, activated API / services etc.  Skipping exercises will cause errors in later exercises.

## Prerequisites
You will need a Google Cloud DevRel dasher account user credentials to execute the exercise scripts in this repository.

At the beginning of the Tech Workshop you will receive a ticket with your user credentialsas shown below:

![user credentials](img/ticket.png "User Credentials")

## Preparation Steps
Ensure that the following steps are completed in your Google Cloud project environment before running the actual exercise scripts.

### New Incognito Chrome Browser Window
Open a new Chrome Browser Window in Incognito mode.

### Login
Login to [Cloud Console] using the credentials in the [Prerequisites](#Prerequistes) section

Accept terms and conditions and click ```AGREE AND CONTINUE```
![terms and conditions](img/terms.png "Accept Terms")

### Project Selection
Select the project (default created for you)

![project selection](img/project_selection.png "Select Project")

![selected project](img/selected_project.png "Selected Project")

### Know your ```ProjectID```
Make a note of your project ID, that will be required in many subsequent steps and exercises.  

In case you do not have it handy, always use the dashboard of your project in the [Cloud Console] to copy ```Project ID``` value

![project id](img/project_id.png "Project ID")

### Cloud Shell
Open Cloud Shell.

Do this by clicking ![Cloud Shell Icon](img/cloud_shell_icon.png "Cloud Shell Icon") in the top bar of the [Cloud Console]

![Cloud Shell](img/cloud_shell.png "Cloud Shell")

### Open Editor
Open Editor by clicking the ![Open Editor](img/open_editor.png) button in the Cloud Shell bar
![Editor](img/editor.png "Editor")

As you are using incognito mode, Cloud Shell editor will not open as 3rd party cookies are disabled in Incognito mode.

![No Cookies](img/no_cookies.png "No Cookies")

To enable it, follow the instructions below to enable third-party cookies for this site. Otherwise you can continue with the step of opening a new terminal.

Click ```Open in New Window```, Select the closed eye button in address bar

![Closed Eye](img/closed_eye.png "Closed Eye")

Select the ```Site not working?``` link

![Site Not Working](img/site_not_working.png "Site Not Working")

Select Allow Cookies and reload the page

![Allow Cookies](img/allow_cookies.png "Allow Cookies")

Open a new Terminal by Terminal → New Terminal

![New Terminal](img/new_terminal.png "New Terminal")

### Authorization
Run

```shell
gcloud auth list
```

![Auth List](img/auth_list.png "Auth List")

Run

```shell 
gcloud auth login --no-launch-browser
```

Open the link displayed in a separate browser tab (for example using ```Cmd+Click```)

![Auth Link](img/auth_link.png "Auth Link")

Select the account displayed (This will be the only account as you are logged in Incognito)

![Choose Account](img/choose_account.png "Choose Account")

Click ```Allow```

![Auth Allow](img/auth_allow.png "Auth Allow")

An Authorization Code will be displayed

![Auth Code Display](img/auth_code_display.png "Auth Code Display")

Click on the ![Copy](img/copy.png "Copy") (Copy) button

Back in the Cloud Shell Editor → Terminal window, paste the verification code that you copied (Ctrl + V / Cmd + V)

![Auth Code Paste](img/auth_code_paste.png "Auth Code Paste")

Press ```Enter```

You should be able to see output similar to the one shown at the right

![Auth Done](img/auth_done.png "Auth Done")

### Set Project
Ensure that you are in the right google Cloud Project by checking the Cloud Shell bash prompt

![Project Display](img/project_display.png "Project Display")

If you do not see your Project ID in the command prompt, or if you are in wrong project, use the following command to set the correct project with the following command (replace ```<PROJECT_ID>``` with the Project ID that you noted from [Know Your Project ID](#Know-your-```ProjectID```) section

```shell
gcloud config set project <PROJECT_ID>
```

3. Clone this repo into your Cloud Shell home folder

```shell
git clone https://github.com/ssdramesh/cortex-deployer-scripts
```

Change into the cloned repository folder
```shell
cd cortex-deployer-scripts
```

## Exercise 1: Create a Cloud Composer environment
Run the script:

```shell
sh exercise1.sh
```

Follow the instructions on the terminal. Keep pressing entering to input default values as proposed.

This script will do the following:
- Enable all required APIs
- Create a VPC network for installing Cloud Composer
- Create a custom subnet
- Create a couple of basic firewall rules to make the new network accessible
- Create a User Managed Service Account (UMSA) for cortexx deployment (applicable for all exercises)
- Grant permisssions for:
    - User Managed Service Account (UMSA) to run Cloud Composer environment creation
    - User to operate as User Managed Service Account (UMSA)
- Create a Cloud Composer environment

The script triggers the creation of a Cloud Composer environment and will be run asynchronously in the background.  Creation will take about 15-20 min.

You can check the status of instance creation after ~20 min. in the [Cloud Console].

Open Cloud Console and scroll down to Composer in the hamburger menu at the top left.

![Nav Composer](img/composer_nav.png "Nav Composer")

If the composer environment creation is complete, you should be able to see an instance similar to one shown on the right

![Composer Display](img/composer_display.png "Composer Display")

You will anyway do this at the end of exercise 3, when you need to copy the DAGHs created to the Cloud Composer DAGs bucket.

Additional Info: [Creating Environments | Cloud Composer | Google Cloud][Create Environments]

## Exercise 2: 
Run the script for exercise 2

sh exercise2.sh

Follow the instructions on the terminal. Keep pressing entering to input default values as proposed

This script will do the following:
- Enable all required APIs for this exercise (BigQuery API)
- Grant BigQuery roles to the User Managed Service Account (UMSA) required for the deployment of Cortex Data Foundation
- Grant BigQuery roles to the Cloud Build Service Account (CBSA) required by Cloud Build to run the automated deployment of Cortex Data Foundation
- Create the datasets in your BigQuery Dataset required for deployment of Cortex Data Foundation
- Create Google Cloud Storage (GCS) buckets required for storing Airflow DAGs and logs during the deployment of Cortex Data Foundation
- Check all the prerequisites for the deployment of Cortex data Foundation

## End-to-End Deployment
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

[Cloud Console]: https://console.cloud.googlee.com
[Create Environments]: https://cloud.google.com/composer/docs/how-to/managing/creating?hl=en