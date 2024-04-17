#!/bin/bash

echo -n "=== Checking API Ping..."
ping_success="no"
for (( i=0; i<48; ++i)); do
  ping_response=$(curl --fail -k --silent https://$ip_address/api/ping)
  if [[ "$ping_response" == "pong" ]]; then
    ping_success="yes"
    break
  fi
  echo -n "x"
  sleep 5
done
[[ "$ping_success" != "yes" ]] && exit 1
echo "$ping_response"

echo -n "=== Checking UI Ping..."
ping_success="no"
for (( i=0; i<48; ++i)); do
  ping_response=$(curl --fail -k --silent https://$ip_address/ping)
  if [[ "$ping_response" == "pong" ]]; then
    ping_success="yes"
    break
  fi
  echo -n "x"
  sleep 5
done
[[ "$ping_success" != "yes" ]] && exit 1
echo "$ping_response"
