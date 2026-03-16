#!/bin/bash

# Function to ensure KubeVirt VM configuration file exists
# Copies template to config file if it doesn't exist
# Usage: ensure_kubevirt_config [config_file] [template_file]
# Returns: 2 if config was created from template (caller should exit)
#          1 if error occurred
#          0 if config already existed
ensure_kubevirt_config() {
    local config_file="${1:-config/kubevirt_vm_overrides.conf}"
    local template_file="${2:-config/kubevirt_vm_overrides.conf.tmpl}"

    if [[ ! -f "$config_file" ]]; then
        if [[ -f "$template_file" ]]; then
            echo "Info: Configuration file not found. Creating $config_file from template..."
            cp "$template_file" "$config_file"
            echo ""
            echo "IMPORTANT: Please review and customize $config_file before running this script again."
            echo "Edit the file to set your passwords, SSH keys, and other configuration values."
            echo ""
            return 2
        else
            echo "Error: Template file $template_file not found."
            return 1
        fi
    fi

    return 0
}

# Function to load KubeVirt VM configuration from shell config file
# Usage: load_kubevirt_config [config_file]
# Sources the config file to set environment variables
# Exits with 0 if config was just created (user needs to customize)
# Exits with 1 if error occurred
# Returns 0 if config loaded successfully
load_kubevirt_config() {
    local config_file="${1:-config/kubevirt_vm_overrides.conf}"

    # Ensure config file exists (copy from template if needed)
    ensure_kubevirt_config "$config_file"
    local result=$?
    if [[ $result -eq 2 ]]; then
        # Config was just created from template, exit so user can customize it
        exit 0
    elif [[ $result -ne 0 ]]; then
        echo "ERROR: Failed to load configuration"
        exit 1
    fi

    # Source the configuration file (simple shell variable assignments)
    # shellcheck disable=SC1090
    source "$config_file"

    return 0
}
