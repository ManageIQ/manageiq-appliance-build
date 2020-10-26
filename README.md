# ManageIQ Appliance Build

[![Build Status](https://api.travis-ci.com/ManageIQ/manageiq-appliance-build.svg?branch=kasparov)](https://travis-ci.com/ManageIQ/manageiq-appliance-build)
[![License](http://img.shields.io/badge/license-APACHE2-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0.html)

# Introduction

This repository contains code to build ManageIQ appliances in the various virtualization formats.

Below are instructions on configuring a dedicated build machine to generate appliance images.

# Installation
  * Hardware requirements:
    * CPU: 2 cores minimum
    * RAM: 12GB minimum
    * HD: 80GB Minimum - 200GB Recommended

  Get the kickstart from `kickstarts/centos8_build_machine.ks` and adjust it as needed based on your environment and hardware.  Example iPXE boot script for the kickstart:

  ```
  #!ipxe

  kernel http://pxeserver.example.com/sources/centos/8/vmlinuz inst.ks=http://pxeserver.example.com/ipxe/mac/centos8_build_machine.ks net.ifnames=0 biosdevname=0
  #ramdisk_size=10000
  initrd http://pxeserver.example.com/sources/centos/8/initrd.img
  boot
  ```
## Download CentOS 8 ISO
  * Download latest CentOS 8 ISO from http://isoredirect.centos.org/centos/8/isos/x86_64/
    ```
    curl -L http://isoredirect.centos.org/centos/8/isos/x86_64/CentOS-8.1.1911-x86_64-dvd1.iso \
      -o /build/isos/CentOS-8.1.1911-x86_64-dvd1.iso
    ```
    
## Setup docker for container build

  * Install docker and start service
    ```
    dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
    dnf install docker-ce --nobest
    systemctl enable --now docker
    ```

  * Login to a registry (for pushing image)
    ```
    docker login --username <user> <server> (e.g. docker.io)
    ```

## Configure virtualization hardware (if running build machine in a VM)

  * Network: NAT or Bridged
  * Time Sync with Host
  * Install appropriate guest agent (`rhevm-guest-agent` for RHV, `open-vm-tools` for vSphere)

  * Enable nested virtualization

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


## Optional: Setup Apache for sharing built images

  ```
  dnf install httpd
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
