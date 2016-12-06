#
# Kick off a nightly upstream build
#
# repo:      ManageIQ/manageiq.git
# branch:    darga
# fileshare: true
#

BUILD_DIR="$(dirname "$(readlink -f "$0")")/.."

source "${BUILD_DIR}/bin/shared_functions.sh"
stop_on_existing_build

LOG_DIR=/build/logs
mkdir -p ${LOG_DIR}

DATE_STAMP=`date +"%Y%m%d_%T"`
LOG_FILE="${LOG_DIR}/darga_${DATE_STAMP}.log"
BUILD_OPTIONS="--type nightly --reference darga --copy-dir darga --upload"

if [ "${1}" = "--fileshare" -o "${1}" = "--no-fileshare" -o "${1}" = "--local" ]
then
  BUILD_OPTIONS="$BUILD_OPTIONS ${1}"
  shift
fi

if [ "${1}" = "--fg" ]
then
  echo "Nightly Build kicked off, Log being saved in ${LOG_FILE} ..."

  time ruby ${BUILD_DIR}/scripts/vmbuild.rb $BUILD_OPTIONS 2>&1 | tee ${LOG_FILE}
else
  #nohup time ruby ${BUILD_DIR}/scripts/vmbuild.rb $BUILD_OPTIONS >${LOG_FILE} 2>&1 &
  nohup ruby ${BUILD_DIR}/scripts/vmbuild.rb $BUILD_OPTIONS >${LOG_FILE} 2>&1 &

  echo "Nightly Build kicked off, Log @ ${LOG_FILE} ..."
fi
