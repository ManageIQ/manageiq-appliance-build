#!/bin/bash

imgfac_storage=/build/storage

# Note: -mtime +0 finds files within the past 24 hours
find $imgfac_storage -type f -mtime +0 -regex ".*\.\(body\|meta\|qcow2\)$" | xargs rm -vf
