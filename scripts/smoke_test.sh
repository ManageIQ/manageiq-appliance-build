#!/bin/bash
# Dependencies: qemu-kvm libvirt virt-install expect

if [[ -z $1 ]]; then
  echo "Missing test image!"
  exit 1
fi

image_name=$(basename $1)
echo "=== Smoke testing ${image_name}"

[[ "$image_name" =~ ^(.+)-(libvirt|ovirt)-([0-9]*)([a-z]*)(.+)\.qc2$ ]]
product_name=${BASH_REMATCH[1]}              #manageiq
platform=${BASH_REMATCH[2]}                  #libvirt
product_version_number=${BASH_REMATCH[3]}    #18? (this is almost always blank, will fill in later)
product_version_name=${BASH_REMATCH[4]}      #quinteros?
product_version_remainder=${BASH_REMATCH[5]} #-1-20240403
# Fill in product version number if missing
if [[ -z "$product_version_number" ]]; then
  product_version_number=$(($(printf '%d' "'${product_version_name::1}") - 96))
fi

script_directory=$(dirname -- "$( readlink -f -- "$0"; )")

vm_name="smoketest-${product_version_number}${product_version_name}${product_version_remainder}"
newpassword=smartvm123

echo "=== Copying image..."
disk_image="/var/lib/libvirt/images/${vm_name}.qc2"
cp $1 $disk_image

echo "=== Creating database disk"
db_disk="/var/lib/libvirt/images/${vm_name}-db.qc2"
qemu-img create -f qcow2 $db_disk 2G

echo "=== Creating VM..."
virt-install -n $vm_name --memory 4096 --vcpus 2 --cpu host --boot hd --disk $disk_image --disk $db_disk --network default --graphics vnc --osinfo centos-stream9 --import --noautoconsole

echo "=== Waiting for VM to boot..."
sleep 30

echo "=== Finding IP Address..."
ip_address=$(virsh guestinfo $vm_name --interface | grep 192.168.122. | cut -f2 -d: | xargs)
echo "--- Found ${ip_address}"

echo "=== Waiting for SSH..."
while true; do
  ncat ${ip_address} 22 < /dev/null && break
  sleep 1
done
sleep 1

echo "=== Adding to known_hosts..."
cat ~/.ssh/known_hosts | grep -v $ip_address > ~/.ssh/known_hosts
ssh-keyscan $ip_address >> ~/.ssh/known_hosts

echo "=== Changing default password..."
/usr/bin/expect <<EOF;
spawn sshpass -p smartvm ssh -tt root@$ip_address true
match_max 100000
expect "New password: "
send -- "$newpassword\r"
expect "Retype new password: "
send -- "$newpassword\r"
expect eof
EOF


### Configure the appliance
echo "=== Configuring the appliance..."
sshpass -p $newpassword ssh -tt root@$ip_address "hostnamectl hostname ${ip_address}.local"
sshpass -p $newpassword ssh -tt root@$ip_address "echo '${ip_address} ${ip_address}.local 192' >> /etc/hosts"
/usr/bin/expect <<EOF;
spawn sshpass -p $newpassword ssh -tt root@$ip_address appliance_console
match_max 100000
expect "Press any key to continue.\r"
send -- " "
expect "Choose the advanced setting: "
send -- "4\r"
expect "Choose the encryption key: |1| "
send -- "1\r"
expect "Choose the database operation: "
send -- "1\r"
expect "Choose the configure messaging: "
send -- "1\r"
expect "Choose the database disk: |1| "
send -- "1\r"
expect "? (Y/N): |N| "
send -- "n\r"
expect "Enter the database region number: \[?2004h"
send -- "55\r"
expect "Enter the database password on localhost: "
send -- "smartvm\r"
expect "Enter the database password again: "
send -- "smartvm\r"
expect "Already configured on this Appliance, Un-Configure first? (Y/N): "
send -- "y\r"
expect "Proceed with Configuration? (Y/N): "
send -- "y\r"
expect "Enter the Message Server Hostname or IP address: "
send -- "\r"
expect "\[?2004l\rEnter the Message Keystore Username: |admin| \[?2004h"
send -- "\r"
expect "\[?2004l\rEnter the Message Keystore Password: "
send -- "smartvm\r"
expect "Configure a new persistent disk volume? (Y/N): "
send -- "n\r"
expect "Proceed? (Y/N): "
send -- "y\r"
expect "Press any key to continue.\r
"
send -- " "
expect "Press any key to continue.\r
"
send -- " "
expect "Choose the advanced setting: "
send -- "16\r"
expect eof
EOF
sleep 5


#### Basic Smoke tests
for testfile in "${script_directory}"/smoke_test/*; do
  source ${testfile}
done


### Cleanup
echo "=== Cleaning up"
virsh destroy $vm_name
virsh undefine $vm_name --remove-all-storage
rm -rfv $disk_image $db_disk

echo "=== Success!"
