#!/bin/bash
set -e

source '/build/bin/shared_functions.sh'
stop_on_existing_build

if [[ $# != 1 ]]; then
  echo "Wrong number of arguments: $#. Usage example: release-build.sh capablanca-1-alpha1"
  exit 1
fi

log_file="/build/logs/${1}.log"
nohup time ruby /build/scripts/vmbuild.rb --type release --upload --reference $1 > $log_file 2>&1 &
echo "${1} release build kicked off, see log @ $log_file ..."
