#!/bin/bash
set -ex

while getopts "t:r:h" opt; do
  case $opt in
    t) BUILD_TYPE=$OPTARG ;;
    r) REF=$OPTARG ;;
    h) echo "Usage: $0 -t BUILD_TYPE -r REF [-h]"; exit 1
  esac
done

if [ "$BUILD_TYPE" != "nightly" ] && [ "$BUILD_TYPE" != "release" ]; then
  echo "Build type (-t) is required, must be either 'nightly' or 'release'"
  exit 1
fi

if [ -z "$REF" ]; then
  echo "ref (-r) is required"
  exit 1
fi

BRANCH=${REF%%-*}
PODS_SOURCE_DIR="/build/manageiq-pods-${BRANCH}"
MANAGEIQ_SOURCE_DIR="/build/manageiq-${BRANCH}"

if [ "${REF}" = "master" ]; then
  tag="latest"
elif [ "${REF}" != "${BRANCH}" ]; then # tag build
  tag="${REF}"
else # branch build
  tag="latest-${BRANCH}"
fi

rm -rf ${PODS_SOURCE_DIR}
git clone -b ${REF} --depth 1 https://github.com/ManageIQ/manageiq-pods ${PODS_SOURCE_DIR}

pushd ${PODS_SOURCE_DIR}
  build_args="-n -p -d . -r docker.io/manageiq -t ${tag}"
  if [ "$BUILD_TYPE" == "release" ]; then
    build_args+=" -s"
  fi
  env BUILD_REF=${REF} bin/build ${build_args}
  bin/remove_images -r manageiq -t ${tag}
popd

rm -rf ${MANAGEIQ_SOURCE_DIR}
git clone -b ${REF} --depth 1 https://github.com/ManageIQ/manageiq ${MANAGEIQ_SOURCE_DIR}

pushd ${MANAGEIQ_SOURCE_DIR}
  docker build --no-cache -t docker.io/manageiq/manageiq:${tag} --build-arg IMAGE_REF=${tag} .
  docker push docker.io/manageiq/manageiq:${tag}
  docker rmi docker.io/manageiq/manageiq:${tag}
popd
