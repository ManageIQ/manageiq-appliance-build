#!/bin/bash

stop_on_existing_build ()
{
  CUR_BUILD="`virsh list | sed '1,2d'`"
  if [ -n "${CUR_BUILD}" ]
  then
    echo "Current ImageFactory Build ongoing, cannot kick-off build"
    exit 1
  fi
}
