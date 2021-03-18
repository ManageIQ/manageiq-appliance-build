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
CONTAINER_LOG_FILE="${LOG_DIR}/${BRANCH}_${DATE_STAMP}_container.log"
RPM_LOG_FILE="${LOG_DIR}/${BRANCH}_${DATE_STAMP}_rpm.log"
BUILD_OPTIONS="--type nightly --upload --reference ${BRANCH} --copy-dir ${BRANCH}"

if [ "${!#}" = "--fg" ]
then
  echo "Nightly RPM build kicked off, Log being saved in ${RPM_LOG_FILE} ..."
  ${BUILD_DIR}/bin/rpm-build.sh -t nightly -r $BRANCH 2>&1 |tee ${RPM_LOG_FILE}
  [ ${PIPESTATUS[0]} -ne 0 ] && exit 1

  echo "Nightly Build kicked off, Log being saved in ${LOG_FILE} ..."
  time ruby ${BUILD_DIR}/scripts/vmbuild.rb $BUILD_OPTIONS ${@:1:$#-1} 2>&1 | tee ${LOG_FILE}
  time ${BUILD_DIR}/bin/container-build.sh -t nightly -r ${BRANCH} 2>&1 | tee ${CONTAINER_LOG_FILE}
else
  ( nohup time ${BUILD_DIR}/bin/rpm-build.sh -t nightly -r $BRANCH > ${RPM_LOG_FILE} 2>&1 &&
    ( nohup time ruby ${BUILD_DIR}/scripts/vmbuild.rb $BUILD_OPTIONS $@ >${LOG_FILE} 2>&1 &
      nohup time ${BUILD_DIR}/bin/container-build.sh -t nightly -r ${BRANCH} >${CONTAINER_LOG_FILE} 2>&1 ) ) &

  echo "Nightly Build kicked off, Logs @ ${LOG_DIR}/${BRANCH}_${DATE_STAMP}*.log..."
fi
