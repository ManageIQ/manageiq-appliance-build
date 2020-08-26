#!/bin/bash
set -e

BUILD_DIR="$(dirname "$(readlink -f "$0")")/.."

source "${BUILD_DIR}/bin/shared_functions.sh"
stop_on_existing_build

if [[ $# != 1 ]]; then
  echo "Wrong number of arguments: $#. Usage example: release-build.sh capablanca-1-alpha1"
  exit 1
fi

rpm_log_file="/build/logs/${1}_rpm.log"
log_file="/build/logs/${1}.log"
container_log_file="/build/logs/${1}_container.log"

( nohup time ${BUILD_DIR}/bin/rpm-build.sh -t release -r ${1} > $rpm_log_file 2>&1;
  nohup time ruby ${BUILD_DIR}/scripts/vmbuild.rb --type release --upload --reference $1 --copy-dir ${1%%-*} > $log_file 2>&1 &
  nohup time ${BUILD_DIR}/bin/container-build.sh -t release -r ${1} > $container_log_file 2>&1 ) &

echo "${1} release build kicked off, see logs @ /build/logs/${1}*.log ..."
