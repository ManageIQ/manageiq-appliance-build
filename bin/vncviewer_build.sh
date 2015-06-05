export VMID=`sudo virsh list | grep running | awk '{print $1}'`
if [ -z "${VMID}" ]; then
  echo "Build VM not started yet ..."
  exit 1
fi
echo "Build VM ID: $VMID"
export VNCID=`sudo virsh domdisplay $VMID | cut -f3 -d:`
echo "VNC ID :${VNCID}"
echo "Bringing up VncViewer for :${VNCID}   Note: Menu Key is F5 ..."
nohup vncviewer -MenuKey F5 :$VNCID > vncviewer.out 2>&1 &
