#!/bin/bash
set -ex

BUILD_DIR="$(dirname "$(readlink -f "$0")")/.."

CONFIG_OPTION=${CONFIG_OPTION:-$BUILD_DIR/OPTIONS}
COPR_TOKEN=${COPR_TOKEN:-~/.config/copr}
RPM_BUILD_IMAGE=${RPM_BUILD_IMAGE:-"manageiq/rpm_build"}

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

if [ "$REF" = "master" ]; then
  tag="latest"
else
  tag="latest-${REF%%-*}"
fi
RPM_BUILD_IMAGE=$RPM_BUILD_IMAGE:$tag

cmd="build --build-type $BUILD_TYPE --git-ref $REF"
docker pull $RPM_BUILD_IMAGE
docker run --rm -v $COPR_TOKEN:/root/.config/copr -v $CONFIG_OPTION:/root/OPTIONS $RPM_BUILD_IMAGE $cmd
