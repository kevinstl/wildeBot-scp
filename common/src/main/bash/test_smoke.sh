#!/bin/bash

set -o errexit

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export ENVIRONMENT=TEST

# shellcheck source=/dev/null
[[ -f "${__DIR}/pipeline.sh" ]] && source "${__DIR}/pipeline.sh" ||  \
 echo "No pipeline.sh found"

#prepareForSmokeTests
cd ${WORKSPACE}/scripts
./markserv-install.sh skipInitMinikube

cd ${WORKSPACE}

runSmokeTests
