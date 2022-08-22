#!/bin/bash

set -e

if [[ -n "$GCP_CREDENTIALS" ]]; then

	if [[ -f "$GCP_CREDENTIALS" ]]; then
		GOOGLE_APPLICATION_CREDENTIALS="$GCP_CREDENTIALS"
	else
		GOOGLE_APPLICATION_CREDENTIALS="/tmp/gac.$$.json"
		echo "${GCP_CREDENTIALS}" > "$GOOGLE_APPLICATION_CREDENTIALS"
	fi

	export GOOGLE_APPLICATION_CREDENTIALS
	echo "Activating service account: $(yq eval '.client_email' "$GOOGLE_APPLICATION_CREDENTIALS")"
	/google-cloud-sdk/bin/gcloud auth activate-service-account --key-file="$GOOGLE_APPLICATION_CREDENTIALS" || exit 2
	echo "--"
fi

###############################################################################
# GKE
GKE_PROJECT="${GKE_PROJECT:-${GCP_PROJECT:-""}}"

if [[ -z "$HELM_CHART_PATH" ]]; then
	echo "ERROR: Missing \"HELM_CHART_PATH\" setting" >&2
	exit 1
fi

if [[ -z "$GKE_CLUSTER_NAME" || -z "$GKE_PROJECT" ]]; then
	echo "ERROR: Missing \"GKE_CLUSTER_NAME\" and/or \"GKE_PROJECT\" settings" >&2
	exit 1
fi

if [[ -z "$GKE_REGION" && -z "$GKE_ZONE" ]]; then
	echo "ERROR: Missing \"GKE_REGION\" or \"GKE_ZONE\" setting" >&2
	exit 1
fi

# If both options are specified then we will try both
# this is a helper variable for tracking the result
cluster_setup=1337

if [[ -n "$GKE_ZONE" ]]; then
	set +e
	set -x
	/google-cloud-sdk/bin/gcloud container clusters get-credentials "$GKE_CLUSTER_NAME" --project="$GKE_PROJECT" --zone="$GKE_ZONE"
	cluster_setup=$?
	{ set +x; set -e; } 2>/dev/null
fi

if [[ -n "$GKE_REGION" && "$cluster_setup" -ne 0 ]]; then
	set +e
	set -x
	/google-cloud-sdk/bin/gcloud container clusters get-credentials "$GKE_CLUSTER_NAME" --project="$GKE_PROJECT" --region="$GKE_REGION"
	cluster_setup=$?
	{ set +x; set -e; } 2>/dev/null
fi

if [[ "$cluster_setup" -ne 0 ]]; then
	echo "ERROR: Failed to fetch credentials for a GKE cluster" >&2
	exit 3
fi

echo "--"
###############################################################################
# Helm2 and Helm commit parameters setup
HELM_TIMEOUT="${HELM_TIMEOUT:-600s}"
HELM_HISTORY_MAX="${HELM_HISTORY_MAX:-30}"
HELM_RELEASE_NAMESPACE="${HELM_RELEASE_NAMESPACE:-"default"}"
HELM_CHART_PATH="${HELM_CHART_PATH:-"${1:-""}"}"
HELM_RELEASE_NAME="${HELM_RELEASE_NAME:-""}"
declare -a HELM_PARAMS=(
	"--cleanup-on-fail"
	"--history-max" "$HELM_HISTORY_MAX"
)
HELM_VALUES="${HELM_VALUES:-""}"
IFS=$',' read -r -a HELM_VALUES_FILES <<< "$HELM_VALUES_FILES"

if [[ -z "$HELM_RELEASE_NAME" ]]; then
	HELM_CHART_DIR="$(cd "$HELM_CHART_PATH" || exit 64 ; pwd -P)"
	HELM_RELEASE_NAME="$(basename "$HELM_CHART_DIR")"
fi

for i in "${HELM_VALUES_FILES[@]}"; do
	HELM_PARAMS+=("--values")
	HELM_PARAMS+=("$(echo "$i" | sed 's/[[:space:]]//g')") # empty any space
done

if [[ -n "$HELM_VALUES" ]]; then
	HELM_PARAMS+=("--set-string")
	HELM_PARAMS+=("$HELM_VALUES")
fi

export HELM_SECRETS_QUIET="true"

####################################################
#run
echo "👇"
set -x

which helm
helm plugin install https://github.com/jkroepke/helm-secrets --version v4.1.1
helm plugin list

#helm3 update or new install
if ! /usr/local/bin/helm secrets upgrade --install "${HELM_PARAMS[@]}" --timeout "$HELM_TIMEOUT" --namespace "$HELM_RELEASE_NAMESPACE" "$HELM_RELEASE_NAME" "$HELM_CHART_PATH"; then
	{ set +x; } 2>/dev/null
	echo "‼️  ERROR: helm upgrade command has failed; \"${HELM_RELEASE_NAME}\" was not updated/installed." >&2
	exit 42
fi

{ set +x; } 2>/dev/null
echo "👆"
echo "--"
