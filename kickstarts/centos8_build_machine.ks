#version=RHEL8

### See CHANGEME lines and adjust as needed ###

ignoredisk --only-use=sda
zerombr
clearpart --all --initlabel --drives=sda
partition /boot --ondisk=sda --asprimary --size=1024 --fstype=xfs
partition pv.1 --ondisk=sda --asprimary --size=10240 --grow
volgroup kegerator8 pv.1
logvol swap --vgname=kegerator8 --name=swap --size=8192
logvol / --vgname=kegerator8 --name=root --size=20480 --fstype=xfs
logvol /build --vgname=kegerator8 --name=build --size=20480 --fstype=xfs --grow

bootloader --append="rhgb quiet net.ifnames=0 biosdevname=0 crashkernel=auto" --driveorder="sda" --boot-drive=sda

# Reboot after installation
reboot

# Use graphical install
graphical

# Use network installation
url --url="http://mirror.centos.org/centos/8/BaseOS/x86_64/os/"
repo --name="AppStream" --baseurl=http://mirror.centos.org/centos/8/AppStream/x86_64/os/
repo --name="PowerTools" --baseurl=http://mirror.centos.org/centos/8/PowerTools/x86_64/os/
repo --name="extras" --baseurl=http://mirror.centos.org/centos/8/extras/x86_64/os/
repo --name="epel" --baseurl=https://mirror.atl.genesisadaptive.com/epel//8/Everything/x86_64/
repo --name="ManageIQ-Build" --baseurl=https://copr-be.cloud.fedoraproject.org/results/manageiq/ManageIQ-Build/epel-8-x86_64/

keyboard --vckeymap=us --xlayouts='us'

lang en_US.UTF-8

# Installation logging level
logging --level=debug

# Network information
network --bootproto=dhcp --device=eth1 --onboot=off --noipv6 --no-activate # CHANGEME or remove based on your hardware
network --bootproto=static --device=eth0 --gateway=192.0.2.1 --ip=192.0.2.2 --nameserver=192.0.2.1 --netmask=255.255.252.0 --noipv6 --activate # CHANGEME
network --hostname=kegerator8.example.com # CHANGEME

# Root password: smartvm
rootpw --iscrypted $1$DZprqvCu$mhqFBjfLTH/PVvZIompVP/

# SELinux configuration
selinux --enforcing

# X Window System configuration information
xconfig  --startxonboot
firstboot --disable
systemctl set-default graphical
sed -i 's/^#WaylandEnable.*/WaylandEnable=False/' /etc/gdm/custom.conf

# System services
services --enabled="chronyd"

# System timezone
timezone America/New_York --isUtc --ntpservers=time.nist.gov # CHANGEME if needed

%post --logfile=/root/anaconda-post.log

mkdir -p /build/fileshare /build/images /build/isos /build/logs /build/storage

pushd /build
  git clone https://www.github.com/ManageIQ/manageiq-appliance-build.git
  ln -s manageiq-appliance-build/bin bin
  git clone https://www.github.com/redhat-imaging/imagefactory.git
popd

pip3 install oauth2 cherrypy boto monotonic

pushd /build/imagefactory/scripts
  sed -i 's/python2\.7/python3\.6/' imagefactory_dev_setup.sh
  ./imagefactory_dev_setup.sh
popd

pushd /build/manageiq-appliance-build/scripts
  gem install bundler
  export PATH="/usr/local/bin:${PATH}"
  bundle install
popd

echo "export LIBGUESTFS_BACKEND=direct" >> /root/.bash_profile

# needed to test this kickstart file in Fusion
sed -i 's/^#options kvm_intel.*/options kvm_intel nested=1/' /etc/modprobe.d/kvm.conf
kversion=$(rpm -q kernel --qf '%{version}-%{release}.%{arch}\n')
ramfsfile="/boot/initramfs-$kversion.img"
dracut --force --add-drivers "vmw_pvscsi mptspi" $ramfsfile $kversion

# Resulting build storage
mkdir /mnt/builds
#echo "nfs-host.example.com:/builds/manageiq /mnt/builds nfs rw,timeo=600,tcp,nfsvers=3,soft,nosharecache,context=system_u:object_r:public_content_rw_t:s0  0 0" >> /etc/fstab # CHANGEME if desired

chvt 1

%end

%packages
@development
@graphical-server-environment
@virtualization-client
@virtualization-hypervisor
epel-release
kexec-tools
libguestfs-tools
oz
python3-httplib2
python3-libguestfs
python3-libs
python3-libxml2
python3-m2crypto
python3-pycurl
python3-zope-interface
ruby
ruby-devel
tigervnc
tigervnc-server
tigervnc-server-module

%end

%addon com_redhat_kdump --enable --reserve-mb='auto'

%end
