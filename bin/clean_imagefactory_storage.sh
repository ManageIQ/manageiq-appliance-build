#!/bin/bash

days_to_keep_storage=0 # keep only files modified within the past day
imgfac_storage=/build/storage

find $imgfac_storage -type f -mtime +$days_to_keep_storage -regex ".*\.\(body\|meta\|qcow2\)$" | xargs rm -vf
