#!/bin/bash

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
  letters=({a..z})
  letter=${product_version_name::1}
  for (( i=0; ; i++ ))
  do
    if [[ ${letters[$i]} == $letter ]]; then
      product_version_number=$(($i + 1))
      break
    fi
  done
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
virt-install -n $vm_name --memory 4096 --vcpus 2 --cpu host --disk $disk_image --disk $db_disk --network default --graphics spice --osinfo centos-stream9 --import --noautoconsole

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
sshpass -p $newpassword ssh -tt root@$ip_address "hostnamectl hostname ${ip_address}.xip.io"
sshpass -p $newpassword ssh -tt root@$ip_address "echo '${ip_address} ${ip_address}.xip.io 192' >> /etc/hosts"
/usr/bin/expect <<EOF;
spawn sshpass -p $newpassword ssh -tt root@$ip_address appliance_console
match_max 100000
expect "Press any key to continue.\r"
send -- " "
expect -exact "\[H\[2J\[3JAdvanced Setting\r
\r
1) Create Database Backup\r
2) Create Database Dump\r
3) Restore Database From Backup\r
4) Configure Application\r
5) Configure Database Replication\r
6) Logfile Configuration\r
7) Control Application Database Failover Monitor\r
8) Configure External Authentication (httpd)\r
9) Update External Authentication Options\r
10) Generate Custom Encryption Key\r
11) Stop EVM Server Processes\r
12) Start EVM Server Processes\r
13) Restart Appliance\r
14) Shut Down Appliance\r
15) Summary Information\r
16) Quit\r
\r
Choose the advanced setting: "
send -- "4\r"
expect -exact "4\r
\[H\[2J\[3JConfigure Application\r
\r
No encryption key found.\r
For migrations, copy encryption key from a hardened appliance.\r
For worker and multi-region setups, copy key from another appliance.\r
If this is your first appliance, just generate one now.\r
\r
Encryption Key\r
\r
1) Create key\r
2) Fetch key from remote machine\r
(1) \r
Choose the encryption key: |1| "
send -- "1\r"
expect -exact "1\r
\r
Encryption key now configured.\r
\r
Database Operation\r
\r
1) Create Internal Database\r
2) Create Region in External Database\r
3) Join Region in External Database\r
4) Reset Configured Database\r
5) Make No Database Changes\r
\r
Choose the database operation: "
send -- "1\r"
expect -exact "1\r
\[H\[2J\[3JConfigure Messaging\r
\r
1) Configure this appliance as a messaging server\r
2) Connect to an external messaging system\r
3) Make No messaging changes\r
\r
Choose the configure messaging: "
send -- "1\r"
expect -exact "1\r
\[H\[2J\[3J\r
Stopping ManageIQ Server...\r
database disk\r
\r
1) /dev/vdb: 2048 MB\r
2) Don't partition the disk\r
(1) \r
Choose the database disk: |1| "
send -- "1\r"
expect -exact "1\r
\[H\[2J\[3J\r
Should this appliance run as a standalone database server?\r
\r
NOTE:\r
* The ManageIQ application will not be running.\r
* This is required when using highly available database deployments.\r
* CAUTION: This is not reversible.\r
\r
? (Y/N): |N| "
send -- "n\r"
expect -exact "n\r
\[H\[2J\[3JEach database region number must be unique.\r
Enter the database region number: \[?2004h"
send -- "55\r"
expect "Enter the database password on localhost: "
send -- "smartvm\r"
expect "Enter the database password again: "
send -- "smartvm\r"
expect -exact "\r
\[H\[2J\[3JActivating the configuration using the following settings...\r
Host:     localhost\r
Username: root\r
Database: vmdb_production\r
Region:   55\r
\r
Initialize postgresql disk starting\r
Initialize postgresql disk complete\r
Initialize postgresql starting\r
Initialize postgresql complete\r
Checking for connections to the database...\r
\r
Create region starting\r
Create region complete\r
\r
Configuration activated successfully.\r
Configure Application\r
\r
Installed file /opt/kafka/config/server.properties found.\r
\r
Already configured on this Appliance, Un-Configure first? (Y/N): "
send -- "y\r"
expect -exact "y\r
Remove Installed Files\r
Unconfigure Firewall\r
Deactivate Services\r
\r
Proceed with Configuration? (Y/N): "
send -- "y\r"
expect "Enter the Message Server Hostname or IP address: "
send -- "\r"
expect -exact "\[?2004l\rEnter the Message Keystore Username: |admin| \[?2004h"
send -- "\r"
expect -exact "\[?2004l\rEnter the Message Keystore Password: "
send -- "smartvm\r"
expect -exact "\r
Configure a new persistent disk volume? (Y/N): "
send -- "n\r"
expect "Proceed? (Y/N): "
send -- "y\r"
expect "Press any key to continue.\r
"
send -- " "
expect "Press any key to continue.\r
"
send -- " "
expect -exact "\[H\[2J\[3JAdvanced Setting\r
\r
1) Create Database Backup\r
2) Create Database Dump\r
3) Restore Database From Backup\r
4) Configure Application\r
5) Configure Database Replication\r
6) Logfile Configuration\r
7) Control Application Database Failover Monitor\r
8) Configure External Authentication (httpd)\r
9) Update External Authentication Options\r
10) Generate Custom Encryption Key\r
11) Stop EVM Server Processes\r
12) Start EVM Server Processes\r
13) Restart Appliance\r
14) Shut Down Appliance\r
15) Summary Information\r
16) Quit\r
\r
Choose the advanced setting: "
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
