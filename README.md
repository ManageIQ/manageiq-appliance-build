
# Installation

  **Note: All instructions are as root unless specified**

## Setup CentOS 7.1 in a new virtual machine

  * CentOS-7-x86_64-DVD-1503-01.iso (attached to vm)
  * Vm configuration:
    * 8GB Ram
    * 80GB HD - Minimum
    * NAT or Bridged
    * Enable Intel Hardware Virtualization VT-x/EPT
    * Time Sync with Host

  * Create a personal userid with admin privileges.
  * Enable Network in UI.
  * Default enable network upon boot.

  `/etc/sysconfig/network-scripts/ifcfg-eno* equiv eth0 file, ONBOOT=yes`

  * Add /root/.ssh/authorized_key with id_rsa.pub if desired to ssh to root without password.

## Add yum repositories

  * Add EPEL repo

    * Create: `/etc/yum.repos.d/epel.repo`

      ```
      [epel]
      name=CentOS-$releasever - Epel
      baseurl=http://dl.fedoraproject.org/pub/epel/$releasever/$basearch/
      enabled=1
      gpgcheck=0
      ```
  * Add repo to support building openstack images

    * Create: `/etc/yum.repos.d/openstack-kilo.repo`

      ```
      [openstack-kilo]
      name=CentOS-$releasever - openstack-kilo
      baseurl=http://centos.mirror.constant.com/7/cloud/x86_64/openstack-kilo/
      enabled=1
      gpgcheck=0
      ```

## Install yum packages and updates

  * Install Updates from UI
  * Reboot
  * `yum install git`
  * As personal user-id (NOT NEEEDED?  We use https to clone, pull)
    * Create ssh-keygen for Github (optional).
    * Add ssh-key to personal user-id on Github settings.

## Setup the /build directory

  * Create the directories:

    ```
    /build
      /fileshare
      /imagefactory
      /images
      /isos
      /kickstarts
      /logs
      /references
      /storage
    ```

  * Clone the build scripts and setup symlinks

    ```
    cd /build
    git clone https://www.github.com/ManageIQ/manageiq-appliance-build.git
    ln -s manageiq-appliance-build/bin     bin
    ln -s manageiq-appliance-build/scripts scripts
    ln -s manageiq-appliance-build/config  config
      ```

## Setup Imagefactory:

  * Clone imagefactory as /build/imagefactory

    ```
    cd /build
    git clone https://www.github.com/redhat-imaging/imagefactory.git
    ```

  * Install dependencies:

    ```
    yum install libguestfs
    yum install pycurl
    yum install python-zope-interface
    yum install libxml2
    yum install python-httplib2
    yum install python-paste-deploy
    yum install python-oauth2
    yum install python-pygments
    yum install oz
    ```
  
## Run imagefactory_dev_setup.sh

  * Use /build/bin/setup_imagefactory.sh or manually create with the following and run:

    ```
    # cd /build/imagefactory
    # python ./setup.py sdist install
    # cd imagefactory-plugins
    # python ./setup.py sdist install

    # mkdir /etc/imagefactory/plugins.d
    # cd /etc/imagefactory/plugins.d
    # for PLUGIN in `ls /usr/lib/python2.7/site-packages/imagefactory_plugins |grep -v .py`
    do
      ln -s -v /usr/lib/python2.7/site-packages/imagefactory_plugins/$PLUGIN/$PLUGIN.info ./$PLUGIN.info
    done

    # cd /build/imagefactory
    # scripts/imagefactory_dev_setup.sh
    ```

## Setup for vSphere plugin.

  * Install dependencies:

    ```
    yum install python-psphere
    yum install VMDKstream
    ```

  * Create /root/.psphere/config.yaml

    ```
    general:
        server: 127.0.0.1
        username: foo
        password: bar
        template_dir: ~/.psphere/templates/
    logging:
        destination: ~/.psphere/psphere.log
        level: DEBUG # DEBUG, INFO, etc
    ```

## Setup for oVirt plugin.

  `yum install ovirt-engine-sdk-python`

## Setup for OpenStack images

  `yum install python-glanceclient`

## Setup KVM/Virt

  * Install packages

    ```
    yum install kvm qemu-kvm qemu-kvm-tools libvirt libvirt-python libguestfs-tools virt-install
    yum install virt-manager virt-viewer
    ```
  * Enable libvirtd

    ```
    systemctl enable libvirtd
    systemctl start libvirtd
    ```

  * Package information:

    ```
    qemu-kvm        = QEMU emulator
    qemu-img        = QEMU disk image manager
    virt-install    = Command line tool to create virtual machines.
    libvirt         = Provides libvirtd daemon that manages virtual machines and controls hypervisor.
    libvirt-client  = provides client side API’s for accessing servers and also provides virsh utility
                      which provides command line tool to manage virtual machines.
    virt-viewer     = Graphical console
    ```

## Install guest-agent if running as a RHEVM vm

  `yum install rhevm-guest-agent`

## Configure virtualization hardware

  * In hosting's VM's .vmx file:
    ```
    monitor.virtual_mmu = "hardware"
    monitor.virtual_exec = "hardware"
    vhv.enable = "TRUE"
    ```

  * Start imagefactory vm and verify hardware:

    ```
    egrep '(vmx|svm)' /proc/cpuinfo

    virsh nodeinfo

    lsmod | grep kvm
    ```

  * To manually load kernel modules:

    ```
    modprobe kvm
    modprobe kvm_intel
    ```

  * Start kvm_intel with nested enabled:
    * Append options in /etc/modprobe.d/dist.conf (create file if not there)
      `options kvm-intel nested=y`

## Setup build environment

  ```
  yum install ruby
  gem install trollop
  ```

  * For enabling copying to SSH file server, define the following in Root's .bashrc (optional)

    ```
    export BUILD_FILE_SERVER="your.file.server.com"
    export BUILD_FILE_SERVER_ACCOUNT="your_id"
    export BUILD_FILE_SERVER_BASE="public_html"  # subdirectory off your_id's home where to scp files to
    ```

    * Note: root will need password-less access to the account listed above.


## Setup VNC Server and Viewer

  ```
  yum install tigervnc tigervnc-server*
  cp /lib/systemd/system/vncserver@.service /etc/systemd/system/vncserver@:1.service
  vi /etc/systemd/system/vncserver@:1.service
    replace: <USER> in ExecStart and PIDFile lines with user to allow vnc server

  systemctl daemon-reload
  ```

  * as `<USER>`
    * `vncpasswd`

  * as root again

    ```
    systemctl enable vncserver@:1.service
    systemctl start vncserver@:1.service
    firewall-cmd --permanent --add-service vnc-server
    systemctl restart firewalld.service
    ```
  
## Setup Apache for sharing built images

  ```
  yum install httpd
  firewall-cmd --permanent --add-port=80/tcp
  firewall-cmd --permanent --add-port=443/tcp
  firewall-cmd --reload

  mv /etc/httpd/conf.d/welcome.conf /etc/httpd/conf.d/welcome.conf.orig   (Ok not to have index.html)
  systemctl start httpd
  systemctl enable httpd

  cd /var/www/html
  ln -s /build/fileshare builds
  ln -s /build/isos      isos
  ```

  * For Apache to be able to see the directories above:  (SELinux)

    ```
    chmod -R a+rx /build/fileshare
    chcon -R -t httpd_sys_content_t /build/fileshare
    chmod -R a+rx /build/isos
    chcon -R -t httpd_sys_content_t /build/isos
    ```

  * At each update, or simply disable SELinux

    ```
    vi /etc/sysconfig/selinux
    SELINUX=disabled
    ```

## Cleanup imagefactory temp storage

  * To avoid imagefactory filling up the disk with in flight .meta and .body files,
  we'll create a daily cron job to clean this up:

  ```
  chmod +x /build/bin/clean_imagefactory_storage.sh
  ln -s /build/bin/clean_imagefactory_storage.sh /etc/cron.daily
  ```
  
## File Share (optional)

  * `vi /etc/hosts`
    `a.b.c.d   your.file.share.com`
  
  * Make sure root can ssh/scp to personal account on your.file.share.com
    ```
    su -
    ssh-keygen
    # Press Enter key till you get the prompt

    ssh-copy-id -i your_id@your.file.share.com
    # It will once ask for the password of the host system

    ssh your_id@your.file.share.com
    ```

## To setup a daily build:

* To make the build run every weekday at 8pm local time:

  ```
  # crontab -e

  # run the appliance build week nights at 8 pm
  0 20 * * 1-5 /build/bin/nightly-build.sh
  ```

* Or, we can just run via cron.daily (sometime in the early morning)

  ```
  ln -s /build/bin/nightly-build.sh /etc/cron.daily
  ```

# Usage

With installs, vnc is not directly available, but can be accessed via local vncviewer
installed on the VM hosting imagefactory.

`virsh list`

to determine which VM ID is doing the install and then

`virsh domdisplay <id_of_domain>`

You'll get a local VNC display number for the actual VM doing the install.
(As opposed to a VNC server being run inside of Anaconda on the VM.
And you can use that display to get to a debug shell and do other installer-like things.


So ...

  ```
  # sudo virsh list
   Id    Name                           State
  ----------------------------------------------------
   4     factory-build-4cc03248-2ae3-4614-989e-5982e6850a8c running

  # sudo virsh domdisplay 4
  vnc://127.0.0.1:0

  # vncviewer :0
  ```


Assuming, running in Graphical/X mode.

Above is provided with the `/build/bin/vncviewer_build.sh [--wait]`

Note:
vncviewer has an "F8" menu we need to use if we want to send an "alt" keypress to the VM.
On t540p thinkpad, with the function lock key on, pressing F8 actually disables WIFI.
