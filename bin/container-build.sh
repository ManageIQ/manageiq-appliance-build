#!/bin/bash

set -ex

if [[ $# != 1 ]]; then
  echo "Wrong number of arguments: $#. Usage example: container-build.sh <branch or tag>"
  exit 1
fi

BRANCH=${1%%-*}
PODS_SOURCE_DIR="/build/manageiq-pods-${BRANCH}"
MANAGEIQ_SOURCE_DIR="/build/manageiq-${BRANCH}"

if [ "${1}" = "master" ]; then
  tag="latest"
elif [ "${1}" != "${BRANCH}" ]; then # tag build
  tag="${1}"
else # branch build
  tag="latest-${BRANCH}"
fi

rm -rf ${PODS_SOURCE_DIR}
git clone -b ${1} https://github.com/ManageIQ/manageiq-pods ${PODS_SOURCE_DIR}

pushd ${PODS_SOURCE_DIR}
  env BUILD_REF=${1} bin/build -n -p -d images -r manageiq -t ${tag}
  bin/remove_images -r manageiq -t ${tag}
popd

rm -rf ${MANAGEIQ_SOURCE_DIR}
git clone -b ${1} --depth 1 https://github.com/ManageIQ/manageiq ${MANAGEIQ_SOURCE_DIR}

pushd ${MANAGEIQ_SOURCE_DIR}
  docker build --no-cache -t manageiq/manageiq:${tag} --build-arg IMAGE_REF=${tag} .
  docker push manageiq/manageiq:${tag}
  docker rmi manageiq/manageiq:${tag}
popd
