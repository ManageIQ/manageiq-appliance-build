# ManageIQ Appliance Build

[![Build Status](https://api.travis-ci.org/ManageIQ/manageiq-appliance-build.svg)](https://travis-ci.org/ManageIQ/manageiq-appliance-build)
[![License](http://img.shields.io/badge/license-APACHE2-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0.html)

# Introduction

This repository contains code to build ManageIQ appliances in the various virtualization formats.

Below are instructions on configuring a dedicated build machine to generate appliance images.

# Installation

  **Note: All instructions are as root unless specified**

## Setup CentOS 8 build machine

  * RAM: 12GB minimum
  * HD: 80GB Minimum - 200GB Recommended

  * If setting up as a VM:
    * NAT or Bridged
    * Enable Intel Hardware Virtualization VT-x/EPT
    * Time Sync with Host
    * Install appropriate guest agent (`rhevm-guest-agent` for RHV, `open-vm-tools` for vSphere)

  * Create a personal userid with admin privileges.
  * Enable Network and set to start on boot.
  * Add /root/.ssh/authorized_key with id_rsa.pub if desired to ssh to root without password.

  * Install Updates and reboot

## Add repositories

  * Add EPEL repo
    ```
    yum install epel-release
    ```

  * Enable CentOS PowerTools repo
    ```
    yum config-manager --set-enabled PowerTools
    ```

  * Add ManageIQ Build repo
    ```
    pushd /etc/yum.repos.d/
      wget https://copr.fedorainfracloud.org/coprs/manageiq/ManageIQ-Build/repo/epel-8/manageiq-ManageIQ-Build-epel-8.repo
    popd
    ```

## Setup the /build directory

  * Create the directories:
    ```
    /build
      /fileshare
      /images
      /isos
      /logs
      /storage
    ```

  * Clone the build scripts and setup symlinks
    ```
    cd /build
    git clone https://www.github.com/ManageIQ/manageiq-appliance-build.git
    ln -s manageiq-appliance-build/bin bin
    ```

## Setup Imagefactory:

  * Install dependencies:
    ```
    yum install @development
    yum install python3-pycurl python3-libguestfs python3-zope-interface python3-libxml2 python3-httplib2 python3-libs oz python3-m2crypto
    pip3 install oauth2 cherrypy boto monotinic
    ```
  
  * Clone imagefactory as /build/imagefactory
    ```
    cd /build
    git clone https://www.github.com/redhat-imaging/imagefactory.git
    ```

  * Set up imagefactory plugins
    ```
    cd /build/imagefactory/scripts
    (set PYTHON_PATH to "/usr/lib/python3.6" in imagefactory_dev_setup.sh)
    ./imagefactory_dev_setup.sh
    ```

  * Set environment variable for libguestfs
    ```
    echo "export LIBGUESTFS_BACKEND=direct" >> ~/.bash_profile
    ```

## Setup KVM/Virt

  * Install packages
    ```
    yum install qemu-kvm libvirt libguestfs-tools virt-install virt-manager virt-viewer
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

## Setup docker for container build

  * Install docker and start service
    ```
    yum config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
    yum install docker-ce --nobest
    systemctl enable --now docker
    ```

  * Login to a registry (for pushing image)
    ```
    docker login --username <user> <server> (e.g. docker.io)
    ```

## Configure virtualization hardware

  * Enable virtualization

    * For vSphere: in hosting's VM's .vmx file:
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
  yum install ruby ruby-devel
  gem install bundler
  cd /build/manageiq-appliance-build/scripts
  bundle install
  ```

## Setup and start VNC Server/Viewer

  * Install GNOME Desktop
    ```
    yum groupinstall "Server with GUI"
    systemctl set-default graphical
    reboot
    ```
    Change to "WaylandEnable=false" in "/etc/gdm/custom.conf"

  * Install VNC and configure as user service
    ```
    yum install tigervnc tigervnc-server tigervnc-server-module
    loginctl enable-linger
    ```

  * Set VNC password as `<USER>`
    ```
    su - <USER>
    vncpasswd
    exit
    ```

  * Start VNC server
    ```
    mkdir -p ~/.config/systemd/user
    cp /usr/lib/systemd/user/vncserver@.service ~/.config/systemd/user/
    systemctl --user daemon-reload
    systemctl --user enable vncserver@:<display>.service --now
      replace: <display> with a display number (e.g. 1)
    ```

  * Set firewall
    ```
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

## Optional: Copying builds to a File Share via SSH

  * `vi /etc/hosts`
    `a.b.c.d   your.file.server.com`

  * Make sure root can ssh/scp to personal account on your.file.server.com

    ```
    su -
    ssh-keygen
    # Press Enter key till you get the prompt

    ssh-copy-id -i your_id@your.file.server.com
    # It will once ask for the password of the host system

    ssh your_id@your.file.server.com
    ```

  * Define the following in Root's .bashrc

    ```
    export BUILD_FILE_SERVER="your.file.server.com"
    export BUILD_FILE_SERVER_ACCOUNT="your_id"
    export BUILD_FILE_SERVER_BASE="public_html"  # subdirectory off your_id's home where to scp files to
    ```

    * Note: root will need password-less access to the account listed above.

## Optional: Using local registry for npm/yarn

To use a local registry to download npm/yarn packages, set registry url using `NPM_REGISTRY_OVERRIDE`
environment variable:

`NPM_REGISTRY_OVERRIDE=https://local.repository`

To clear out the registry override and set to default values at the end of install, use `NPM_REGISTRY_RESET`:

`NPM_REGISTRY_RESET=true`

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

# License

See [LICENSE.txt](LICENSE.txt)
