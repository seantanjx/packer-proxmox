#!/bin/bash
# Check if Packer is installed
if command -v packer &>/dev/null; then
    echo "Packer is already installed."
else
    # Install Packer using Homebrew
    echo "Packer not found. Installing via Homebrew..."
    brew install packer
    packer plugins install github.com/hashicorp/proxmox
fi

# List of required environment variables
required_variables=("proxmox_api_url" "proxmox_api_token_id" "proxmox_api_token_secret")

# Check if all required environment variables are set
for variable in "${required_variables[@]}"; do
    if [ -z "${!variable}" ]; then
        echo "Error: $variable environment variable is not set."
        exit 1
    fi
done

# Ask user for VM linux distro type (rocky9 or ubuntu)
# Prompt the user for input
read -p "Which distro do you want to install (rocky9/ubuntu): " user_input
echo $user_input

# Check the user's input
if [ "$user_input" == "ubuntu" ]; then
    echo "ubuntu"
    packer_template='ubuntu-template.pkr.hcl'
elif [ "$user_input" == "rocky9" ]; then
    echo "rocky9"
    packer_template='rocky9-template.pkr.hcl'
else
    echo "Invalid input. Please enter 'ubuntu' or 'rocky9'."
    exit 1
fi
echo $packer_template
# Get next VM_ID
file_path='./VM_tracker.txt'
vm_id=$(($(tail -n 1 "$file_path") + 1))

result=$(packer validate -var "proxmox_api_url=$proxmox_api_url" -var "proxmox_api_token_id=$proxmox_api_token_id" -var "proxmox_api_token_secret=$proxmox_api_token_secret" -var "vm_id=$vm_id" $packer_template)
if [ $? -eq 0 ]; then
    echo "Validation successful for VM_ID=$vm_id. Proceeding with subsequent commands."
    build_status=$(packer build -var "proxmox_api_url=$proxmox_api_url" -var "proxmox_api_token_id=$proxmox_api_token_id" -var "proxmox_api_token_secret=$proxmox_api_token_secret" -var "vm_id=$vm_id" $packer_template)
    if [ $? -eq 0 ]; then
        echo "\n$vm_id" >>"$file_path"
    else
        echo "Build Failed"
        echo $build_status
        exit 1
    fi
else
    echo "Validation Failed"
    echo "$result"
fi
