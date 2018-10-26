# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)


## Unreleased as of Sprint 97 ending 2018-10-22

### Added
- Add pylxca python module for Lenovo [(#293)](https://github.com/ManageIQ/manageiq-appliance-build/pull/293)
- Add vspk python module for Nuage [(#292)](https://github.com/ManageIQ/manageiq-appliance-build/pull/292)

## Hammer Beta-1 - Released 2018-10-12

### Added
- Add RPMs needed for Ansible playbooks and roles for oVirt [(#281)](https://github.com/ManageIQ/manageiq-appliance-build/pull/281)
- Update appliances to ruby 2.4.4 [(#280)](https://github.com/ManageIQ/manageiq-appliance-build/pull/280)
- Add support for OpenID-Connect [(#272)](https://github.com/ManageIQ/manageiq-appliance-build/pull/272)
- Add sqlite-devel package [(#260)](https://github.com/ManageIQ/manageiq-appliance-build/pull/260)
- Remove enable for docker service [(#251)](https://github.com/ManageIQ/manageiq-appliance-build/pull/251)
- Add the docker package to run awx locally on the appliance [(#250)](https://github.com/ManageIQ/manageiq-appliance-build/pull/250)
- Add post compression support [(#288)](https://github.com/ManageIQ/manageiq-appliance-build/pull/288)
- Compress Azure, HyperV and EC2 images [(#289)](https://github.com/ManageIQ/manageiq-appliance-build/pull/289)
- Move from apache module mod_auth_kerb to mod_auth_gssapi [(#282)](https://github.com/ManageIQ/manageiq-appliance-build/pull/282)

### Fixed
- Update vSphere ova [(#278)](https://github.com/ManageIQ/manageiq-appliance-build/pull/278)
- Increase filesystem sizes [(#232)](https://github.com/ManageIQ/manageiq-appliance-build/pull/232)
- Set commit_sha just once [(#290)](https://github.com/ManageIQ/manageiq-appliance-build/pull/290)

## Gaprindashvili-4 - Released 2018-07-16

### Fixed
- Remove non-existing "server-policy" yum group [(#268)](https://github.com/ManageIQ/manageiq-appliance-build/pull/268)

## Gaprindashvili-3 - Released 2018-05-15

### Added
- Create ref symlink for release build [(#265)](https://github.com/ManageIQ/manageiq-appliance-build/pull/265)
- Clear yarn cache [(#264)](https://github.com/ManageIQ/manageiq-appliance-build/pull/264)

## Gaprindashvili-1 - Released 2018-01-31

### Added
- Update to CentOS 7.4 [(#244)](https://github.com/ManageIQ/manageiq-appliance-build/pull/244)
- Use a master copr repo on the master branch [(#230)](https://github.com/ManageIQ/manageiq-appliance-build/pull/230)
- Add qpid-proton-c libs [(#228)](https://github.com/ManageIQ/manageiq-appliance-build/pull/228)
- Add screen package [(#224)](https://github.com/ManageIQ/manageiq-appliance-build/pull/224)
- Add a script to resize/convert Azure image [(#222)](https://github.com/ManageIQ/manageiq-appliance-build/pull/222)
- Delete temporary files created during build [(#218)](https://github.com/ManageIQ/manageiq-appliance-build/pull/218)

### Fixed
- Install 'mime-types' outside of bundle [(#254)](https://github.com/ManageIQ/manageiq-appliance-build/pull/254)
- Run `bundle clean --force` after we `bundle install` [(#248)](https://github.com/ManageIQ/manageiq-appliance-build/pull/248)
- Change config path to be relative to script [(#252)](https://github.com/ManageIQ/manageiq-appliance-build/pull/252)
- Use update:ui task instead of update:bower [(#220)](https://github.com/ManageIQ/manageiq-appliance-build/pull/220)

## Initial changelog added
