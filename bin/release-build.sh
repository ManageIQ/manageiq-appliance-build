#!/bin/bash
set -e

BUILD_DIR="$(dirname "$(readlink -f "$0")")/.."

source "${BUILD_DIR}/bin/shared_functions.sh"
stop_on_existing_build

if [[ $# -lt 1 ]]; then
  echo "Wrong number of arguments: $#. Usage example: release-build.sh capablanca-1-alpha1 [build options]"
  exit 1
fi

build_ref=${1}
shift

rpm_log_file="/build/logs/${1}_rpm.log"
log_file="/build/logs/${1}.log"
container_log_file="/build/logs/${1}_container.log"

( nohup time ${BUILD_DIR}/bin/rpm-build.sh -t release -r $build_ref > $rpm_log_file 2>&1;
  nohup time ruby ${BUILD_DIR}/scripts/vmbuild.rb --type release --upload --reference $build_ref --copy-dir ${build_ref%%-*} $@ > $log_file 2>&1 &
  nohup time ${BUILD_DIR}/bin/container-build.sh -t release -r $build_ref > $container_log_file 2>&1 ) &

echo "$build_ref release build kicked off, see logs @ /build/logs/${build_ref}*.log ..."
