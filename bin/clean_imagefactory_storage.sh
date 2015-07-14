#!/bin/bash

days_to_keep_storage=1
imgfac_storage=/build/storage

find $imgfac_storage -type f -mtime +$days_to_keep_storage -regex ".*\.\(body\|meta\|\.qcow2\)$" | xargs rm -vf
