#!/bin/bash

TEST_COMMIT_SHA="test"
KUBERNETES_VERSION="${KUBERNETES_VERSION:-"1.21"}"
HELM_CHART_PATH="${HELM_CHART_PATH:-"${1:-""}"}"
HELM_VALUES="${HELM_VALUES:-"global.image.tag=${TEST_COMMIT_SHA},image.tag=${TEST_COMMIT_SHA},app.imageTag=${TEST_COMMIT_SHA}"}"
HELM_VALUES_FILES="${HELM_VALUES_FILES:-""}"
_KUBEVAL_PARAMS="${KUBEVAL_PARAMS:-"--ignore-missing-schemas"}"
IFS="," read -r -a KUBEVAL_PARAMS <<< "${_KUBEVAL_PARAMS}"
_KUBESCORE_PARAMS="${KUBESCORE_PARAMS:-"--ignore-container-cpu-limit,--ignore-container-memory-limit,--ignore-test=container-security-context-user-group-id,--ignore-test=container-security-context-privileged,--ignore-test=container-security-context-readonlyrootfilesystem,--ignore-test=pod-networkpolicy,--ignore-test=networkpolicy-targets-pod,--ignore-test=container-image-pull-policy,--ignore-test=cronjob-has-deadline"}"
IFS="," read -r -a KUBESCORE_PARAMS <<< "${_KUBESCORE_PARAMS}"

declare -a HELM_VALUES_FILES_GROUPS

if [[ -z "$HELM_CHART_PATH" ]]; then
	echo "ERROR: Missing \"HELM_CHART_PATH\" setting" >&2
	exit 1
fi

###############################################################################
# GOOGLE_APPLICATION_CREDENTIALS

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

if [[ -n "$HELM_VALUES_FILES" ]]; then
	echo "ℹ️  HELM_VALUES_FILES was specified by user"
	echo "  📂 (from config): ${HELM_VALUES_FILES}"
	HELM_VALUES_FILES_GROUPS=("$HELM_VALUES_FILES")
else
	echo "🔮 HELM_VALUES_FILES is empty -> autodetecting environments and value files"
	HELM_VALUES_FILES_BASE="$(find "$HELM_CHART_PATH" -type f \! \( -path "*templates*" -or -path "*testing*" -or -path "*staging*" -or -path "*production*" \) -and \( -name "values.yaml" -or -name "values.yml" -or -name "secrets.yaml" -or -name "secrets.yml" -or -name "config.yaml" -or -name "config.yml" \) -print | sort -r | tr "\n" ",")"

	for env in testing staging production; do
		HELM_VALUES_FILES_ENV="$(find "$HELM_CHART_PATH" -type f -path "*${env}*" \! -path "templates" \( -name "*values*.yaml" -or -name "*values*.yml" -or -name "*secrets*.yaml" -or -name "*secrets*.yml" \) -print | sort -r | tr "\n" "," | sed 's/,$//')"

		if [[ -n "$HELM_VALUES_FILES_ENV" ]]; then
			echo "  📂 ${env}: ${HELM_VALUES_FILES_BASE}${HELM_VALUES_FILES_ENV}"
			HELM_VALUES_FILES_GROUPS+=("${HELM_VALUES_FILES_BASE}${HELM_VALUES_FILES_ENV}")
		fi
	done

	if [[ ${#HELM_VALUES_FILES_GROUPS[@]} -eq 0 ]]; then
		if [[ -n "$HELM_VALUES_FILES_BASE" ]]; then
			# shellcheck disable=SC2001
			HELM_VALUES_FILES_BASE="$(echo "$HELM_VALUES_FILES_BASE" | sed 's/,$//')"
			echo "  📂 (no env): ${HELM_VALUES_FILES_BASE}"
			HELM_VALUES_FILES_GROUPS=("$HELM_VALUES_FILES_BASE")
		else
			echo "⚠️  No helm value files were found!"
		fi
	fi
fi

function helm_template_params() {
	local -a helm_values_files="$1"  # comma-separated
	local -a values_files
	local -a params

	IFS="," read -r -a values_files <<< "${helm_values_files}"

	if [[ -n "$HELM_VALUES" ]]; then
        for i in "${HELM_VALUES[@]}"; do
	        params+=("--set-string")
	        params+=("$(echo "$i" | sed 's/[[:space:]]//g')") # empty any space
        done
	fi

	for i in "${values_files[@]}"; do
		params+=("--values")
		params+=("$i")
	done

	echo "${params[*]}"
}

# Required for helm secrets template to print yamls only
export HELM_SECRETS_QUIET="true"

# Re-install helm secrets plugin (lives in the base image). For some reason GA can't find it, even though it exists 100% on local docker run.
helm plugin install https://github.com/jkroepke/helm-secrets --version v4.1.1

for files in "${HELM_VALUES_FILES_GROUPS[@]}"; do
	echo
	echo "📂👇 Checking ${HELM_CHART_PATH} with values from: ${files}"
	rm -f /tmp/helm.out

	helm_params="$(helm_template_params "$files")"
	echo "  🧩 helm secrets template ${HELM_CHART_PATH} ${helm_params}"

	# shellcheck disable=SC2086
	if ! helm secrets template "${HELM_CHART_PATH}" ${helm_params} > /tmp/helm.out 2> /tmp/helm.err; then
		cat /tmp/helm.out 
		cat /tmp/helm.err >&2
		echo "‼️  \"helm secrets template\" failed!"
		exit 61
	fi

	echo "  🔦 kubeval --quiet --force-color --kubernetes-version ${KUBERNETES_VERSION}.0 ${KUBEVAL_PARAMS[*]}"
	kubeval --quiet --force-color --kubernetes-version "${KUBERNETES_VERSION}.0" "${KUBEVAL_PARAMS[@]}" /tmp/helm.out || exit 62
	cat /tmp/helm.out

	echo "  💎 kube-score score --kubernetes-version v${KUBERNETES_VERSION} ${KUBESCORE_PARAMS[*]}"
	kube-score score --kubernetes-version "v${KUBERNETES_VERSION}" "${KUBESCORE_PARAMS[@]}" /tmp/helm.out || exit 63
done

echo "👆"
echo "--"
