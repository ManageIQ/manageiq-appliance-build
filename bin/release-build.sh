#!/bin/bash
set -e

BUILD_DIR="$(dirname "$(readlink -f "$0")")/.."

source "${BUILD_DIR}/bin/shared_functions.sh"
stop_on_existing_build

if [[ $# != 1 ]]; then
  echo "Wrong number of arguments: $#. Usage example: release-build.sh capablanca-1-alpha1"
  exit 1
fi

log_file="/build/logs/${1}.log"
copy_dir="${1%%-*}"

nohup sh -c \
        "echo time ruby ${BUILD_DIR}/scripts/vmbuild.rb --type release --upload --reference $1 --copy-dir $copy_dir \
         && time ruby ${BUILD_DIR}/scripts/vmpublish.rb --copy-dir $copy_dir" \
        > $log_file 2>&1 &
echo "${1} release build kicked off, see log @ $log_file ..."
