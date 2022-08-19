# Helm check GA plugin

## What it does

GA plugin that validates your Helm charts against kubeval and kube-score. It uses `helm secrets template` to generate the Helm templates, so it is possible to integrate with GCP in case KMS is being used for your secrets.

## Usage

Just use the following two environmental variables as inputs

```sh
HELM_CHART_PATH:  <path of your Helm chart>
GCP_CREDENTIALS: <SA to use for Helms secrets> # This is not needed if you don't have secrets.yaml in your Helm files
KUBERNETES_VERSION: Kubernetes version to check against, default: 1.21
HELM_VALUES: Comma separated Values passed to Hlem through the --set-string attribute, default: ""
HELM_VALUES_FILES: Comma separated value files for your Helm charts, default: ""
KUBESCORE_PARAMS: Parameters to add to kubescore
```

## Usage example

```sh
name: default
on:
  push: {}

jobs:
  helm_check:
    runs-on: [ <tages for your self hosted runners> ]
    container:
      image: ghcr.io/catthehacker/ubuntu:act-latest
    steps:
    - uses: actions/checkout@v3 # Checkout your code
      with:
        repo-token: ${{ secrets.GITHUB_TOKEN }}
    - name: helm-check # Run this plugin
      uses: GlobalWebIndex/github-actions/helm-check
      env:
        HELM_CHART_PATH: <path to your helm charts>
        GCP_CREDENTIALS: ${{ secrets.SA_NAME}}
```

## Test it locally

In your local repo, create `./.github/workflows/main.yml` and add the code from the example above, making sure you fill all the required info. Then run the following command in order to test this with [act](https://github.com/nektos/act)

```sh
act --container-architecture linux/amd64 -s GITHUB_TOKEN -s SA_NAME --workflows ./.github/workflows/main.yml
```
