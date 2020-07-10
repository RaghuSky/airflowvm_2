# Deployment Manager for the Airflow VM

# Pre-requisite

This deployment uses a start-up script to customize the VM. You'll need to save the start-up script to this bucket prior to creating your deployment.

# How tos

## Configure your deployment

A configuration file lists the resources, and their respective properties, that from part of your deployment. These resources include a VM and associated firewall rules. This project has three such configuration files, one for each project:

* **```dev.yaml```**: customise the ```zone```, ```machineType```, ```startupScriptBucket``` and ```repo``` parameters. The start-up script will checkout the master branch.
* **```test.yaml```**: in addition to the above, set the git branch name to checkout into your TEST project. The branch name is required in TEST.
* **```prod.yaml```**: set the git tag name, rather than the branch name. The tag is required in PROD.

## Create a deployment using gcloud

Create a deployment in DEV named ```etl-dev``` with the gcloud command-line tool, as follows:

```
gcloud deployment-manager deployments create etl-dev \
  --config deployment-manager/dev.yaml \
  --labels billing_team=decis,data_classification=internal-confidential,environment=dev,terraform=false
```

Create a deployment in the TEST project from the command line, as follows:

```
gcloud deployment-manager deployments create etl-test \
  --config deployment-manager/test.yaml \
  --labels billing_team=decis,data_classification=internal-confidential,environment=test,terraform=false
```

Create a deployment in the PROD project from the command line, as follows:

```
gcloud deployment-manager deployments create etl-prod \
  --config deployment-manager/prod.yaml \
  --labels billing_team=decis,data_classification=internal-confidential,environment=prod,terraform=false
```

If your deployment is successful, you can get a description of the deployment, as follows:

```
gcloud deployment-manager deployments describe etl-dev
```

### Labels

A label is a key-value pair that helps you organize your Google Cloud Platform deployments. You can attach a label to each resource, then filter the resources based on their labels. Information about labels is made available to the billing system, so you can break down your billing charges by label.

## Delete a deployment

When you delete a deployment, all resources that are part of the deployment are also deleted.

If you want to delete specific resources from your deployment and keep the rest, delete those resources from your configuration file, and update the deployment instead.

```
gcloud deployment-manager deployments delete etl-dev \
  --delete-policy=DELETE
```

### Delete policy

The delete policy you use determines how the resources in the deployment are handled. You can use one of these policies:

* **```DELETE```** *[Default]*: Deletes the underlying resource. This is permanent and cannot be undone.
* **```ABANDON```**: This deletes the deployment, but does not delete the underlying resources. For example, if you have a VM instance in the deployment, it will still be available for you to use after the deployment is deleted.

If you need to re-create a deployment that you deleted, you can use the original configuration file. However, the deployment is considered a new deployment, with new resources.

# GCP Documentation

* **Quick-start guide:** https://cloud.google.com/deployment-manager/docs/quickstart
* **Step-by-step walkthrough:** https://cloud.google.com/deployment-manager/docs/step-by-step-guide/installation-and-setup
* **Deployment manager samples:** https://github.com/GoogleCloudPlatform/deploymentmanager-samples/tree/master/examples/