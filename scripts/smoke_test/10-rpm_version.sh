#!/bin/bash

echo "=== Checking RPM Version..."
rpm_version=$(sshpass -p $newpassword ssh -tt root@$ip_address "rpm -q --qf %{VERSION} ${product_name}-core")
echo "--- Found: ${rpm_version}"
[[ "$product_version_number" != $(echo "$rpm_version" | cut -d. -f1) ]] && exit 1
