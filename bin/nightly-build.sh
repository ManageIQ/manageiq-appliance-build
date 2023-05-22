#
# Kick off a nightly upstream build
#
# repo:      ManageIQ/manageiq.git
# branch:    master
#

BUILD_DIR="$(dirname "$(readlink -f "$0")")/.."

source "${BUILD_DIR}/bin/shared_functions.sh"
stop_on_existing_build

LOG_DIR=/build/logs
mkdir -p ${LOG_DIR}

BRANCH=master
DATE_STAMP=`date +"%Y%m%d_%T"`
LOG_FILE="${LOG_DIR}/${BRANCH}_${DATE_STAMP}.log"
BUILD_OPTIONS="--type nightly --upload --reference ${BRANCH} --copy-dir ${BRANCH}"

if [ "${!#}" = "--fg" ]
then
  echo "Nightly Build kicked off, Log being saved in ${LOG_FILE} ..."
  time ruby ${BUILD_DIR}/scripts/vmbuild.rb $BUILD_OPTIONS ${@:1:$#-1} 2>&1 | tee ${LOG_FILE}
else
  nohup time ruby ${BUILD_DIR}/scripts/vmbuild.rb $BUILD_OPTIONS $@ >${LOG_FILE} 2>&1 &
  echo "Nightly Build kicked off, Logs @ ${LOG_DIR}/${BRANCH}_${DATE_STAMP}*.log..."
fi
