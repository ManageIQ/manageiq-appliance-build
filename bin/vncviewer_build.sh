#!/bin/bash

SLEEP=5
WAIT=0
if [ "$1" = "--wait" ]
then
  WAIT=1
  shift
fi

while :
do
  VMSYS="`sudo virsh list | grep running`"
  if [ -z "$VMSYS" -o -n "`echo $VMSYS | grep guestfs`" ]
  then
    echo "Build VM not started yet ..."
    if [ "$WAIT" = 0 ]; then exit 1; fi
    sleep $SLEEP
    continue
  fi

  export VMID=`echo $VMSYS | awk '{print $1}'`
  if [ -z "${VMID}" ]; then
    echo "Build VM not started yet ..."
    if [ "$WAIT" = 0 ]; then exit 1; fi
    sleep $SLEEP
    continue
  fi

  echo "Build VM ID: $VMID"
  export VNCID=`sudo virsh domdisplay $VMID | cut -f3 -d:`

  echo "VNC ID :${VNCID}"
  echo "Bringing up VncViewer for :${VNCID}   Note: Menu Key is F5 ..."
  nohup vncviewer -MenuKey F5 :$VNCID >> /build/logs/vncviewer.out 2>&1 &
  exit 0
done
