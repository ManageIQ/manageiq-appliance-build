#!/bin/bash

echo "=== Checking evmserverd..."
evmserverd_active=$(sshpass -p $newpassword ssh -tt root@$ip_address "systemctl is-active evmserverd")
echo "--- Expected: active  Found: ${evmserverd_active}"
[[ "${evmserverd_active%$'\r'}" != "active" ]] && exit 1
