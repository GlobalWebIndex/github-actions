# Helm deploy GA plugin

## What it does
It deploys your Helm chart on a GKE cluster

## Usage

Just use the following environmental variables as inputs
 > Either `GKE_REGION` or `GKE_ZONE` are needed

```sh
# Required
GCP_CREDENTIALS: The service account in GCP to be used
GKE_PROJECT: The name of your GKE project
GKE_CLUSTER_NAME: The name of your cluster
GKE_REGION: the region of your cluster
GKE_ZONE: the zone of your cluster
HELM_CHART_PATH: The path of your Helm chart

# Optional
HELM_TIMEOUT: how many seconds until Helm times out, default: 600s
HELM_HISTORY_MAX: The max value of Helm\'s history, default: 30
HELM_RELEASE_NAMESPACE: The namespace where your application will be deployed, default: "default"
HELM_RELEASE_NAME: The name of your release, default: the foldername of the helm chart
HELM_VALUES: Comma separated Values passed to Hlem through the --set-string attribute, default: ""
HELM_VALUES_FILES: Comma separated value files for your Helm charts, default: ""
```

## Usage example
```sh
jobs:
  helm_deploy:
    runs-on: [ <tags for your self hosted runners> ]
    container:
      image: ghcr.io/catthehacker/ubuntu:act-latest
    steps:
    - uses: actions/checkout@v3
      with:
        repo-token: ${{ secrets.GITHUB_TOKEN }}
    - name: helm-deploy
      uses: GlobalWebIndex/github-actions/helm-deploy
      env:
        HELM_CHART_PATH: <path to your helm charts>
        GCP_CREDENTIALS: ${{ secrets.SA_NAME}}
        GKE_PROJECT: <your project in GKE>
        GKE_CLUSTER_NAME: <the name of your cluster on GKE>
        GKE_ZONE: europe-west1-b
        HELM_VALUES: image.tag=demo,image.repository=demo-repo
        HELM_VALUES_FILES: <values-file.yaml>, <values-file-2.yaml>
```

## Test it locally

In your local repo, create `./.github/workflows/main.yml` and add the code from the example above, making sure you fill all the required info. Then run the following command in order to test this with [act](https://github.com/nektos/act)

```sh
act --container-architecture linux/amd64 -s GITHUB_TOKEN -s SA_NAME --workflows ./.github/workflows/main.yml
```
