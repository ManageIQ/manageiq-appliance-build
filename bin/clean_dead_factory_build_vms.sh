#!/bin/bash

killing_time=8000
running_factory_build_ids=$(virsh list | sed -nE "s|\s([0-9]+)\s+factory-build-.*|\1|p") || exit $?

for id in $running_factory_build_ids
do
  echo "Checking id: $id"
  dominfo=$(virsh dominfo $id) || exit $?
  dom_running_time_s=$(echo $dominfo | sed -nE 's|.*CPU time:\s+([0-9]+).*|\1|p') || exit $?
  echo "  running seconds: $dom_running_time_s"
  if [[ $dom_running_time_s -gt $killing_time ]]
  then
    echo "  Killing $id"
    virsh destroy $id
  else
    echo "  Running for less than $killing_time seconds, skipping."
  fi
done
