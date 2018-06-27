#!/bin/bash

set -e

export COMPOSER_BIN PHP_BIN
COMPOSER_BIN="${COMPOSER_BIN:-composer}"
PHP_BIN="${PHP_BIN:-php}"
APT_BIN="${APT_BIN:-apt-get}"
TAR_BIN="${TAR_BIN:tar}"
CURL_BIN="${CURL_BIN:tar}"
BINARY_EXTENSION="${BINARY_EXTENSION:-tar.gz}"

# ---- BUILD PHASE ----
function build() {
	downloadComposerIfMissing
	"${COMPOSER_BIN}" install
	local artifactLocation
	local artifactName
	artifactName="$(retrieveAppName)-${PIPELINE_VERSION}.${BINARY_EXTENSION}"
	artifactLocation="$(outputFolder)/${artifactName}"
	"${TAR_BIN}" -czvf "${artifactLocation}"
	"${CURL_BIN}" -u "${M2_SETTINGS_REPO_USERNAME}:${M2_SETTINGS_REPO_PASSWORD}" -X POST "${REPO_WITH_BINARIES_FOR_UPLOAD}"/"${artifactName}" --data "${artifactLocation}"
}

function downloadAppBinary() {
	local repoWithBinaries="${1}"
	local groupId="${2}"
	local artifactId="${3}"
	local version="${4}"
	local destination
	local changedGroupId
	local pathToArtifact
	destination="$(pwd)/$(outputFolder)/${artifactId}-${version}.${BINARY_EXTENSION}"
	changedGroupId="$(echo "${groupId}" | tr . /)"
	pathToArtifact="${repoWithBinaries}/${changedGroupId}/${artifactId}/${version}/${artifactId}-${version}.${BINARY_EXTENSION}"
	mkdir -p "$(outputFolder)"
	echo "Current folder is [$(pwd)]; Downloading binary to [${destination}]"
	local success="false"
	curl -u "${M2_SETTINGS_REPO_USERNAME}:${M2_SETTINGS_REPO_PASSWORD}" "${pathToArtifact}" -o "${destination}" --fail && success="true"
	mkdir -p "$(outputFolder)/sources"
	if [[ "${success}" == "true" ]]; then
		echo "File downloaded successfully!"
		"${TAR_BIN}" -cvf "${destination}" "$(outputFolder)/sources"
		echo "File unpacked successfully"
		return 0
	else
		echo "Failed to download file!"
		return 1
	fi
}

function pathToPushToCf() {
	echo "$(outputFolder)/sources"
}

# TODO: Describe that we're overriding the pipeline-cf function
export -f pathToPushToCf

function apiCompatibilityCheck() {
	"${COMPOSER_BIN}" test-apicompatibility
}

# TODO: Add to list of required functions
function retrieveGroupId() {
	echo "com.example"
}

# TODO: Add to list of required functions
function retrieveAppName() {
	local tmpDir
	tmpDir="$( mktemp -d )"
	trap "{ rm -rf \$tmpDir; }" EXIT
	("${COMPOSER_BIN}" app-name) > "${tmpDir}/command" && cat "${tmpDir}/command" | tail -1
}

# ---- TEST PHASE ----

function runSmokeTests() {
	"${COMPOSER_BIN}" test-smoke
}

# ---- STAGE PHASE ----

function runE2eTests() {
	"${COMPOSER_BIN}" test-e2e
}

# ---- COMMON ----

function projectType() {
	echo "COMPOSER"
}

function outputFolder() {
	echo "vendor"
}

function testResultsAntPattern() {
	echo ""
}

# ---- PHP SPECIFIC ----

function downloadComposerIfMissing() {
	installPhpIfMissing
	local composerInstalled
	"${COMPOSER_BIN}" --version && composerInstalled="true" || composerInstalled="false"
	if [[ "${composerInstalled}" == "false" ]]; then
		mkdir -p "$( outputFolder )"
		pushd "$( outputFolder )"
			"${PHP_BIN}" -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
			"${PHP_BIN}" -r "if (hash_file('SHA384', 'composer-setup.php') === '544e09ee996cdf60ece3804abc52599c22b1f40f4323403c44d44fdfdd586475ca9813a858088ffbc1f233e9b180f061') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
			"${PHP_BIN}" composer-setup.php
			"${PHP_BIN}" -r "unlink('composer-setup.php');"
			COMPOSER_BIN="${__DIR}/composer"
			echo "Installed composer at [${COMPOSER_BIN}]"
		popd
	fi
}

function installPhpIfMissing() {
	local phpInstalled
	"${PHP_BIN}" --version && phpInstalled="true" || phpInstalled="false"
	if [[ "${phpInstalled}" == "false" ]]; then
		# LAME
		"${APT_BIN}" update && "${APT_BIN}" install -y php7
	fi
}
