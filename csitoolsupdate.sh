#!/bin/bash

# -----------------------------------------------------------------------------------
# Script Name: csitoolsupdate - powerup
# Description: CSI Linux PowerUp - updater and installer script for maintaining updates for the OS, CSI Linux Tools, and Third Party Tools.
# Author: Jeremy Martin
# Website: https://csilinux.com
# 
# Copyright: © 2024 CSI Linux - csilinux.com.  All rights reserved.
# 
# This script is proprietary software and is part of the CSI Linux project. It is available for use subject to the following conditions:
# 
# 1. This script may only be used on CSI Linux platforms, and you must possess a valid license for such use. This license does not grant you rights to modify, distribute,
#    or create derivative works unless expressly stated in the terms of the license.
# 
# 2. Unauthorized copying of this script, via any medium, is strictly prohibited. Modifications, derivatives, and distribution are also prohibited without prior
#    written consent from CSI Linux.
# 
# 3. This script is provided "as is" and without warranties as to performance or merchantability. The author and CSI Linux disclaim all warranties, express or 
#    implied, including, but not limited to, implied warranties of merchantability and fitness for a particular purpose, with respect to this script.
# 
# 4. In no event shall CSI Linux or the author be liable for any special, indirect or consequential damages or any damages whatsoever resulting from loss of use, data or
#    profits, whether in an action of contract, negligence, or other tortious action, arising out of or in connection with the use or performance of this script.
# 
# For further information on licensing, please visit CSI Linux Academy: # https://csilinux.com/academy
# Support CSI Linux by purchasing official merchandise: # https://csilinux.com/shop
# -----------------------------------------------------------------------------------


echo "Welcome to CSI Linux. This will take a while, but the update has a LOT of content..."
start_time=$(date +%s)
# Attempt to verify the first argument as a sudo password
key_attempt="$1"
key=""  # Initialize key as an empty string for clarity

if echo "$key_attempt" | sudo -S -v -k &> /dev/null; then
    key="$key_attempt"
    sudo -k  # Reset the sudo timestamp after verification
    echo "sudo access verified with the provided key."
    shift  # Remove the first argument since it's the sudo password
else
    echo "First argument is not a sudo password. It will be treated as a powerup option if applicable."
    # If key_attempt was not empty but failed verification, include it back in arguments for processing
    if [ -n "$key_attempt" ]; then
        set -- "$key_attempt" "$@"
    fi
fi

# Prompt for the sudo password if not already verified
if [ -z "$key" ]; then
    prompt_for_sudo
fi

# All remaining arguments are considered as powerup options
powerup_options=("$@")

# Check if powerup_options is empty
if [[ ${#powerup_options[@]} -eq 0 ]]; then
    powerup_options+=("csi-linux-base" "os-update" "csi-linux-themes" "encryption" "malware-analysis" "sigint" "virtualization" "security")
fi

echo "Power-up options selected:"
for option in "${powerup_options[@]}"; do
    echo "- $option"
done

# Define the function to prompt for sudo password
prompt_for_sudo() {
    while true; do
        key=$(zenity --password --title "Power up your system with an upgrade." --text "Enter your CSI password." --width=400)
        if [ $? -ne 0 ]; then
            zenity --info --text="Operation cancelled. Exiting script." --width=400
            exit 1
        fi
        if echo $key | sudo -S -v -k &> /dev/null; then
            sudo -k 
            echo "sudo access verified."
            break 
        else
            zenity --error --title="Authentication Failure" --text="Incorrect password or lack of sudo privileges. Please try again." --width=400
        fi
    done
}

install_vm_tools() {
    # Define all possible packages for virtualization tools
    vmware_packages="open-vm-tools-desktop"
    virtualbox_packages="virtualbox-guest*"
    qemu_kvm_packages="qemu-guest-agent"
    hyperv_packages="linux-tools-virtual linux-cloud-tools-virtual"
    xen_packages="xe-guest-utilities"
    all_packages="$vmware_packages $virtualbox_packages $qemu_kvm_packages $hyperv_packages $xen_packages"

    # Detect the virtualization environment
    if grep -q VMware /sys/class/dmi/id/product_name; then
        environment="vmware"
        echo "VMware detected. Installing ${vmware_packages}..."
    elif lspci | grep -iq 'virtualbox'; then
        environment="virtualbox"
        echo "VirtualBox detected. Installing ${virtualbox_packages}..."
    elif grep -q 'QEMU' /sys/class/dmi/id/sys_vendor || grep -q 'KVM' /sys/class/dmi/id/sys_vendor; then
        environment="qemu_kvm"
        echo "QEMU/KVM detected. Installing ${qemu_kvm_packages}..."
    elif grep -q 'Microsoft Corporation Hyper-V' /sys/class/dmi/id/sys_vendor; then
        environment="hyperv"
        echo "Hyper-V detected. Installing ${hyperv_packages}..."
    elif grep -q 'Xen' /sys/class/dmi/id/sys_vendor; then
        environment="xen"
        echo "Xen detected. Installing ${xen_packages}..."
    else
        environment="hardware"
        echo "No known virtualization detected or the system is a physical machine."
    fi

    # Install the necessary packages for the detected environment and purge the rest
    case $environment in
        vmware)
            sudo apt install -y $vmware_packages
            sudo apt purge -y ${all_packages//$vmware_packages/}
            ;;
        virtualbox)
            sudo apt purge -y ${all_packages//$virtualbox_packages/}
            ;;
        qemu_kvm)
            sudo apt install -y $qemu_kvm_packages
            sudo apt purge -y ${all_packages//$qemu_kvm_packages/}
            ;;
        hyperv)
            sudo apt install -y $hyperv_packages
            sudo apt purge -y ${all_packages//$hyperv_packages/}
            ;;
        xen)
            sudo apt install -y $xen_packages
            sudo apt purge -y ${all_packages//$xen_packages/}
            ;;
        hardware)
            # If no virtualization is detected, purge all tools
            sudo apt purge -y $all_packages
            ;;
    esac
    echo "System set for running with $environment..."
    # Optional: Remove any packages that were automatically installed to satisfy dependencies
    sudo apt autoremove -y
}


install_missing_programs() {
    local programs=(curl bpytop xterm aria2 yad zenity)
    local missing_programs=()
    local output_file="/tmp/outputfile.txt" # Define the output file path correctly
    echo "Creating file at: $output_file"
    touch "$output_file"
    for program in "${programs[@]}"; do
        if ! dpkg -s "$program" &> /dev/null; then
            echo "$program is not installed. Will attempt to install." | tee -a "$output_file"
            missing_programs+=("$program")
        else
            echo "$program is already installed." | tee -a "$output_file"
        fi
    done

    if [ ${#missing_programs[@]} -ne 0 ]; then
        echo "Updating package lists..." | tee -a "$output_file"
        echo $key | sudo -S apt update | tee -a "$output_file"
        for program in "${missing_programs[@]}"; do
            echo "Attempting to install $program..." | tee -a "$output_file"
            if echo $key | sudo -S -E DEBIAN_FRONTEND=noninteractive apt-get install -yq "$program" 2>&1 | tee -a "$output_file"; then
                echo "$program installed successfully." | tee -a "$output_file"
            else
                echo "Failed to install $program. It may not be available in the repository or another error occurred." | tee -a "$output_file"
            fi
        done
    else
        echo "Starter programs are already installed." | tee -a "$output_file"
    fi
}

install_csi_tools() {
    local flag_file="/tmp/csi_tools_installed.flag"  # Secure location for flag file

    # Check if the flag file exists, indicating the function was already run
    if [[ -f "$flag_file" ]]; then
        echo "CSI Tools have already been installed. Exiting."
        return 0  # Exit the function successfully
    fi

    local backup_dir="/tmp/restorecsitools"
    local backup_file_name="csitools"
    local archive_path="$backup_dir/$backup_file_name.7z"
    echo "$key" | sudo -S DEBIAN_FRONTEND=noninteractive apt install aria2 -y
    echo "Preparing for CSI Tools download..."
    echo "$key" | sudo -S rm -rf "$backup_dir"  # Remove the entire backup directory
    echo "$key" | sudo -S mkdir -p "$backup_dir"
    echo "$key" | sudo -S chmod 777 "$backup_dir"  # Set full permissions temporarily for download
    echo "Downloading CSI Tools..."
    if aria2c -x3 -k1M https://csilinux.com/downloads/csitools.7z -d "$backup_dir" -o "$backup_file_name.7z"; then
        echo "Download successful."
        echo "# Installing CSI Tools..."
        if restore_backup_to_root "$backup_dir" "$backup_file_name"; then
            echo "CSI Tools restored successfully."
            echo "Setting permissions and configurations for CSI Tools..."
            echo "$key" | sudo -S chown csi:csi -R /opt/csitools
            echo "$key" | sudo -S chmod +x /opt/csitools/* -R
            echo "$key" | sudo -S chmod +x ~/Desktop/*.desktop
            echo "Converting DOS format to UNIX format in CSI Tools directories..."
            find /opt/csitools /opt/csitools/helpers -type f -exec sudo dos2unix {} + &>/dev/null
            echo "CSI Tools installation and configuration completed successfully."
            echo "$key" | sudo -S touch "$flag_file"
        else
            echo "Failed to restore CSI Tools from the backup."
            return 1  # Restoration failed
        fi
    else
        echo "Failed to download CSI Tools."
        return 1  # Download failed
    fi

    return 0  # Successfully completed the function
}


restore_backup_to_root() {
    echo $key | sudo -S sleep 1
    sudo -k
    local backup_dir=$1
    local backup_file_name=$2
    local archive_path="$backup_dir/$backup_file_name.7z"
    mkdir -p "/opt/AppImages" 2>/dev/null

    echo "Restoring CSI Tools backup..."
    # Extract the .7z file safely and ensure files are overwritten without prompting
    if ! echo $key | sudo -S 7z x -aoa -o"$backup_dir" "$archive_path"; then
        echo "Failed to extract $archive_path. Please check the file and try again."
        return 1  # Exit the function with an error status
    fi

    local tar_file="$backup_dir/$backup_file_name.tar"
    if [ -f "$tar_file" ]; then
        echo "Restoring backup from tar file..."
        # Extract the tar file and ensure files are overwritten without prompting
        if ! echo $key | sudo -S tar --overwrite -xpf "$tar_file" -C /; then
            echo "Failed to restore from $tar_file. Please check the archive and try again."
            return 1  # Exit the function with an error status
        fi
        echo "Backup restored successfully."
        echo $key | sudo -S rm "$tar_file"
    else
        echo "Backup .tar file not found. Please check the archive path and try again."
        return 1  # Exit the function with an error status
    fi
    return 0  # Successfully completed the function
}

install_packages() {
    local -n packages=$1
    local newpackages=()
    local already_installed=0
    local installed=0
    local failed=0
    local total_packages=${#packages[@]}
    local current_package=0
    
    echo "Checking which packages need installation..."

    # Pre-check installed status to avoid unnecessary operations
    for package in "${packages[@]}"; do
        let current_package++
        if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
            # echo "[$current_package/$total_packages] Package $package is already installed, skipping."
            ((already_installed++))
        else
            newpackages+=("$package")
        fi
    done

    echo "Out of $total_packages packages, $already_installed are already installed."
    
    local new_total=${#newpackages[@]}
    if [ "$new_total" -eq 0 ]; then
        echo "No new packages to install."
        return
    fi

    echo "Starting installation of $new_total new packages..."
    current_package=0

    for package in "${newpackages[@]}"; do
        let current_package++
        echo -n "[$current_package/$new_total] Installing $package... "
	echo $key | sudo -S apt install --fix-broken
        if echo $key | sudo -S -E DEBIAN_FRONTEND=noninteractive apt-get install -yq --assume-yes "$package"; then
            echo "SUCCESS"
            ((installed++))
        else
            echo "FAILED"
            ((failed++))
            echo "$package" >> /opt/csitools/apt-failed.txt
        fi
    done

    echo -e "\nInstallation complete."
    echo "Summary: $already_installed skipped, $installed installed, $failed failed."
    if [ $failed -gt 0 ]; then
        echo "Details of failed installations have been logged to /opt/csitools/apt-failed.txt."
    fi
}

# Function to remove specific files
csi_remove() {
    echo $key | sudo -S sleep 1
    # Assuming $1 is the full path with potential wildcards
    local path="$1"
    if [[ "$path" == *\** ]]; then
        # If there's a wildcard, use find to safely handle file names and check existence
        local files=$(find $(dirname "$path") -name "$(basename "$path")" 2> /dev/null)
        if [ -n "$files" ]; then
            echo "Deleting files: $files"
            echo $files | xargs -I {} echo $key | sudo -S csi_remove "{}"
        fi
    else
        # If it's a specific file or directory, check if it exists and then delete
        if [ -e "$path" ]; then
            echo "Deleting: $path"
            echo $key | sudo -S csi_remove "$path"
        fi
    fi
}

add_repository() {
    echo $key | sudo -S sleep 1
    local repo_type="$1"
    local repo_url="$2"
    local gpg_key_info="$3"  # Contains the keyserver and the keys to receiving for 'key' type
    local repo_name="$4"

    if [ "$repo_type" == "ppa" ]; then
        # Convert PPA URL to a format that is likely used in the .list files
        local ppa_formatted_url="ppa.launchpadcontent.net/${repo_url#ppa:}/ubuntu"
        local ppa_present=$(grep -RlF "$ppa_formatted_url" /etc/apt/sources.list.d/ 2>/dev/null)
        if [[ -n "$ppa_present" ]]; then
            echo "PPA '${repo_url}' already added as found in $ppa_present. Skipping addition."
            return 0
        fi
    elif [ -f "/etc/apt/sources.list.d/${repo_name}.list" ]; then
        echo "Repository '${repo_name}' list file already exists. Skipping addition."
        return 0
    fi

    # First, check if the repository list file already exists
    if [ -f "/etc/apt/sources.list.d/${repo_name}.list" ]; then
        echo "Repository '${repo_name}' list file already exists. Skipping addition."
        return 0
    fi

    # Since the .list file does not exist, proceed with adding the GPG key (for 'apt' and 'key')
    if [[ "$repo_type" == "apt" || "$repo_type" == "key" ]] && [ ! -f "/etc/apt/trusted.gpg.d/${repo_name}.gpg" ]; then
        echo "Adding GPG key for '${repo_name}'..."
	cd /tmp
        if [ "$repo_type" == "apt" ]; then
            echo "$key" | sudo -S curl -fsSL "$gpg_key_info" | sudo gpg --dearmor | sudo tee "/etc/apt/trusted.gpg.d/${repo_name}.gpg" > /dev/null
        elif [ "$repo_type" == "key" ]; then
            # Correctly handle the 'key' type using the original working code snippet
            local keyserver=$(echo "$gpg_key_info" | cut -d ' ' -f1)
            local recv_keys=$(echo "$gpg_key_info" | cut -d ' ' -f2-)
            echo "$key" | sudo -S gpg --no-default-keyring --keyring gnupg-ring:/tmp/"$repo_name".gpg --keyserver "$keyserver" --recv-keys $recv_keys
            echo "$key" | sudo -S gpg --no-default-keyring --keyring gnupg-ring:/tmp/"$repo_name".gpg --export | sudo tee "/etc/apt/trusted.gpg.d/$repo_name.gpg" > /dev/null
        fi
        if [ $? -ne 0 ]; then
            echo "Error adding GPG key for '${repo_name}'."
            return 1
        fi
    fi

    # Add the repository
    echo "Adding repository '${repo_name}'..."
    if [ "$repo_type" == "apt" ] || [ "$repo_type" == "key" ]; then
        echo "deb [signed-by=/etc/apt/trusted.gpg.d/${repo_name}.gpg] $repo_url" | sudo tee "/etc/apt/sources.list.d/${repo_name}.list" > /dev/null
    elif [ "$repo_type" == "ppa" ]; then
        echo "$key" | sudo -S add-apt-repository --no-update -y "$repo_url"
    fi

    if [ $? -eq 0 ]; then
        echo "Repository '${repo_name}' added successfully."
    else
        echo "Error adding repository '${repo_name}'."
        return 1
    fi
}

fix_broken() {
    echo $key | sudo -S sleep 1
    echo "# Verifying and configuring any remaining packages (dpkg --configure -a --force-confold)..."
    echo $key | sudo -S dpkg --configure -a --force-confold
    echo "# Fixing and configuring broken apt installs (dpkg --configure -a)..."
    echo $key | sudo -S dpkg --configure -a
    echo $key | sudo -S apt remove sleuthkit  &>/dev/null
    echo "# Fixing and configuring broken apt installs (apt install --fix-broken -y)..."
    echo $key | sudo -S apt install --fix-broken -y

}

update_git_repository() {
    local repo_name="$1"
    local repo_url="$2"
    local _venv="$3" # Accepting the new _venv argument
    local repo_dir="/opt/$repo_name"

    # Check if the repository directory already exists
    if [ -d "$repo_dir" ]; then
        echo "Repository $repo_name already exists. Skipping..."
        return # Exit the function to avoid further actions
    fi

    # If the directory does not exist, clone the new repository
    echo "Cloning new repository $repo_name..."
    echo $key | sudo -S git clone "$repo_url" "$repo_dir"
    echo $key | sudo -S chown -R $USER:$USER "$repo_dir"

    # After cloning, handle Python dependencies if required
    if [ -f "$repo_dir/requirements.txt" ]; then
        # Setup virtual environment if required
        if [[ -n $_venv ]]; then
            echo "Setting up Python virtual environment and installing dependencies..."
            python -m venv "${repo_dir}/${repo_name}-venv"
            source "${repo_dir}/${repo_name}-venv/bin/activate"
        fi

        # Read each line in requirements.txt and check if the package is installed
        while IFS= read -r requirement; do
            local package_name=$(echo "$requirement" | cut -d= -f1)
            if ! pip show "$package_name" &>/dev/null; then
                echo "Installing $requirement..."
                pip install "$requirement"
                if [ $? -eq 0 ]; then
                    echo "$requirement installed successfully."
                else
                    echo "Failed to install $requirement."
                fi
            else
                echo "$requirement is already installed."
            fi
        done < "${repo_dir}/requirements.txt"

        # Deactivate virtual environment if one was set up
        if [[ -n $_venv ]]; then
            deactivate
            echo "Virtual environment deactivated."
        fi

        echo "Dependencies setup completed."
    fi
}


disable_services() {
    # Define a list of services to disable
    local disableservices=(
	"apache-htcacheclean.service"
        "apache-htcacheclean@.service"
        "apache2.service"
        "apache2@.service"
        "bettercap.service"
        "clamav-daemon.service"
        "clamav-freshclam.service"
	"clamav-milter.service"
        "cups-browsed.service"
        "cups.service"
        "i2p"
        "i2pd"
        "kismet.service"
        "lokinet"
        "lokinet-testnet.service"
        "openfortivpn@.service"
        "openvpn-client@.service"
        "openvpn-server@.service"
        "openvpn.service"
        "openvpn@.service"
        "privoxy.service"
        "rsync.service"
        "systemd-networkd-wait-online.service"
        "NetworkManager-wait-online.service"
	"xl2tpd.service"
 	"mono-xsp4.service"
    )

    # Iterate through the list and disable each service
    for service in "${disableservices[@]}"; do
        echo "Disabling $service..."
        echo $key | sudo -S systemctl stop "$service" &>/dev/null
	echo $key | sudo -S systemctl disable "$service" &>/dev/null
        echo "$service disabled successfully."
    done
}

reset_DNS() {
    check_connection() {
        ping -c 1 8.8.8.8 >/dev/null
    }
    check_dns() {
        ping -c 1 google.com >/dev/null
    }
    echo "# Checking and updating /etc/resolv.conf"
    echo $key | sudo -S mv /etc/resolv.conf /etc/resolv.conf.bak
    echo "nameserver 127.0.0.53" | sudo tee /etc/resolv.conf > /dev/null
    echo "nameserver 127.3.2.1" | sudo tee -a /etc/resolv.conf > /dev/null
    printf "\nDNS nameservers updated.\n"
    echo $key | sudo -S systemctl restart systemd-resolved
    while ! systemctl is-active --quiet systemd-resolved; do
        echo "Waiting for systemd-resolved to restart..."
        sleep 1
    done
    echo "systemd-resolved restarted successfully."

    max_retries=5
    retry_count=0

    while [[ $retry_count -lt $max_retries ]]; do
        if check_connection; then
            echo "Internet connection is working."
            if ! check_dns; then
                echo "The internet is working, but DNS is not working. Please check your resolv.conf file"
                ((retry_count++))
            else
                break
            fi
        else
            echo "Internet connection is not working. Please check your network."
            ((retry_count++))
        fi
    done
    if [[ $retry_count -eq $max_retries ]]; then
        echo "Maximum retries reached. Exiting."
    fi
    echo $key | sudo -S sleep 1
    sudo -k
}

setup_new_csi_system() {
    echo $key | sudo -S sleep 1
    sudo -k
    # Sub-function to check if a user exists
    user_exists() {
        if id "$1" &>/dev/null; then
            return 0
        else
            return 1
        fi
    }
    # sudo apt-get install xubuntu-desktop --no-install-recommends
    # Sub-function to add a user to a group
    add_user_to_group() {
        echo $key | sudo -S adduser "$1" "$2" &>/dev/null
    }

    # Sub-function to set up the user environment
    setup_user_environment() {
        USERNAME="csi"
        echo "# Setting up user $USERNAME"
        if ! user_exists "$USERNAME"; then
            echo $key | sudo -S useradd -m "$USERNAME" -G sudo /bin/bash || { echo -e "${USERNAME}\n${USERNAME}\n" | sudo passwd "$USERNAME"; }
        fi
        add_user_to_group "$USERNAME" vboxsf &>/dev/null
        add_user_to_group "$USERNAME" libvirt &>/dev/null
        add_user_to_group "$USERNAME" kvm &>/dev/null
        
        if ! grep -q "^default_user\s*$USERNAME" /etc/slim.conf; then
            echo "Setting default_user to $USERNAME in SLiM configuration..."
            echo "default_user $USERNAME" | sudo tee -a /etc/slim.conf > /dev/null
        else
            echo "default_user is already set to $USERNAME."
        fi
    }

    # Main user and system setup
    echo "# Initiating CSI Linux system setup..."
    setup_user_environment
    echo 'Acquire::Languages "none";' | sudo tee /etc/apt/apt.conf.d/99disable-translations
    echo "# System setup starting..."
    echo "\$nrconf{'restart'} = 'a';" | sudo tee /etc/needrestart/conf.d/autorestart.conf > /dev/null
    export DEBIAN_FRONTEND=noninteractive
    export apt_LISTCHANGES_FRONTEND=none
    export DISPLAY=:0.0
    export TERM=xterm
    echo $key | sudo -S apt-mark hold lightdm &>/dev/null
    echo $key | sudo -S apt-mark hold lightdm-gtk-greeter &>/dev/null
    echo 'Dpkg::Options {
        "--force-confdef";
        "--force-confold";
    }' | sudo tee /etc/apt/apt.conf.d/99force-conf &>/dev/null

    echo "# Architecture cleanup"
    if dpkg --print-foreign-architectures | grep -q 'i386'; then
        echo "# Cleaning up old Arch"
        i386_packages=$(dpkg --get-selections | awk '/i386/{print $1}')
        if [ ! -z "$i386_packages" ]; then
            echo "Removing i386 packages..."
	    echo $key | sudo -S apt remove sleuthkit &>/dev/null
            echo $key | sudo -S apt remove --purge --allow-remove-essential -y $i386_packages
        fi
        echo "# Standardizing Arch"
        echo $key | sudo -S dpkg --remove-architecture i386
    fi

    echo $key | sudo -S dpkg-reconfigure debconf --frontend=noninteractive
    echo $key | sudo -S DEBIAN_FRONTEND=noninteractive dpkg --configure -a  &>/dev/null
    echo $key | sudo -S NEEDRESTART_MODE=a apt update --ignore-missing &>/dev/null

    echo "# Cleaning old tools"
    csi_remove /var/lib/tor/hidden_service/ &>/dev/null
    csi_remove /var/lib/tor/other_hidden_service/ &>/dev/null
    cd /tmp
    wget -O - https://raw.githubusercontent.com/CSILinux/CSILinux-Powerup/main/csi-linux-terminal.sh | bash #&>/dev/null
    source ~/.bashrc
    git config --global safe.directory '*'

    echo $key | sudo -S sysctl vm.swappiness=10
    echo "vm.swappiness=10" | sudo tee /etc/sysctl.d/99-sysctl.conf
    echo $key | sudo -S systemctl enable fstrim.timer

    
	echo "Warning Banners - Configuring system banners..."
	# Define the security banner
	security_banner="
	+---------------------------------------------------------------------------+
	|                             SECURITY NOTICE                               |
	|                                                                           |
	|         ** Unauthorized Access and Usage is Strictly Prohibited **        |
	|                                                                           |
	| All activities on this system are subject to monitoring and recording for |
	| security purposes. Unauthorized access or usage will be investigated and  |
	|                    may result in legal consequences.                      |
	|                                                                           |
	|        If you are not an authorized user, disconnect immediately.         |
	|                                                                           |
	| By accessing this system, you consent to these terms and acknowledge the  |
	|                     importance of computer security.                      |
	|                                                                           |
	|            Report any suspicious activity to the IT department.           |
	|                                                                           |
	|          Thank you for helping us maintain a secure environment.          |
	|                                                                           |
	|              ** Protecting Our Data, Protecting Our Future **             |
	|                                                                           |
	+---------------------------------------------------------------------------+
	"
	# Print the security banner
	echo "$security_banner"
	echo "$security_banner" | sudo tee /etc/issue.net /etc/issue /etc/motd &>/dev/null
	
	# SSH configuration
	echo "Configuring SSH..."
	echo $key | sudo -S sed -i 's|#Banner none|Banner /etc/issue.net|' /etc/ssh/sshd_config
	echo $key | sudo -S sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
	echo $key | sudo -S sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
	echo $key | sudo -S sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
	echo $key | sudo -S systemctl restart sshd    
    
    sudo -k
}

update_xfce_wallpapers() {
    local wallpaper_path="$1"  # Use the first argument as the wallpaper path
    if [[ -z "$wallpaper_path" ]]; then
        echo "Usage: update_xfce_wallpapers /path/to/your/wallpaper.jpg"
        return 1  # Exit the function if no wallpaper path is provided
    fi
    if [ ! -f "$wallpaper_path" ]; then
        echo "The specified wallpaper file does not exist: $wallpaper_path"
        return 1  # Exit the function if the wallpaper file doesn't exist
    fi
    screens=$(xfconf-query -c xfce4-desktop -l | grep -Eo 'screen[^/]+' | uniq)
    for screen in $screens; do
        monitors=$(xfconf-query -c xfce4-desktop -l | grep "${screen}/" | grep -Eo 'monitor[^/]+' | uniq)
        for monitor in $monitors; do
            workspaces=$(xfconf-query -c xfce4-desktop -l | grep "${screen}/${monitor}/" | grep -Eo 'workspace[^/]+' | uniq)
            for workspace in $workspaces; do
                # Construct the property path
                property_path="/backdrop/${screen}/${monitor}/${workspace}/last-image"
                echo "Updating wallpaper for ${property_path} to ${wallpaper_path}"
                xfconf-query -c xfce4-desktop -p "${property_path}" -n -t string -s "${wallpaper_path}"
            done
        done
    done
}

install_from_requirements_url() {
    local requirements_url="$1"
    rm /tmp/requirements.txt &>/dev/null
    curl -s "$requirements_url" -o /tmp/requirements.txt
    
    # Prepare a list of installed packages for reference
    local installed_packages=$(python3 -m pip list --format=freeze)
    
    local total_packages=$(wc -l < /tmp/requirements.txt)
    local current_package=0
    echo "Checking and installing Python packages..."

    while IFS= read -r package; do
        local package_name=$(echo "$package" | cut -d'=' -f1) # Extract package name
        if ! echo "$installed_packages" | grep -Fq "$package_name"; then
            let current_package++
            if ! python3 -m pip install "$package" --quiet &>/dev/null; then
                echo "Failed to install $package_name"
            fi
        else
            echo "Package $package_name already installed, skipping."
        fi
    done < /tmp/requirements.txt
    echo "Installation complete."
}

installed_packages_desc() {
    local -n packages=$1  # Indirect reference to the array variable
    local descriptions_file="$HOME/Documents/${1}_descriptions.csv"
    local no_descriptions_file="$HOME/Documents/${1}_no_descriptions.csv"

    echo "# Listing Installed Packages and Descriptions"

    # Ensure the Documents directory exists
    mkdir -p "$HOME/Documents"

    # Initialize files with headers
    echo "package_name,description" > "$descriptions_file"
    echo "package_name" > "$no_descriptions_file"

    local description_found=false

    for pkg in "${packages[@]}"; do
        local description=$(apt-cache show "$pkg" 2>/dev/null | grep -m 1 -Po '^Description: \K.*')
        if [ -n "$description" ]; then
            # Append package name and description to CSV, escaping internal quotes in descriptions
            echo "${pkg},\"${description//\"/\"\"}\"" >> "$descriptions_file"
            description_found=true
        else
            # Log packages without descriptions separately
            echo "$pkg" >> "$no_descriptions_file"
        fi
    done

    # Remove the no_descriptions_file if no packages were found without descriptions
    if [ "$description_found" = false ]; then
        rm -f "$no_descriptions_file"
        echo "All packages had descriptions. No packages without descriptions file created."
    else
        echo "Some packages had no descriptions. Check the no_descriptions.csv file."
    fi

    echo "CSV files created in the Documents folder:"
    echo "- With descriptions: $descriptions_file"
    if [ -f "$no_descriptions_file" ]; then
        echo "- Without descriptions: $no_descriptions_file"
    fi
}

# echo "To remember the null output " &>/dev/null
# echo $key | sudo -S ln -s /opt/csitools/csi_app /usr/bin/csi_app &>/dev/null
# Use sudo with the provided key
echo $key | sudo -S sleep 1
echo $key | sudo -S df -h
cd /tmp

# unredactedmagazine

# Main script logic
sudo -k
for option in "${powerup_options[@]}"; do
    echo "Processing option: $option"
    case $option in
        "csi-linux-base")
		cd /tmp
		echo "Cleaning up CSI Linux base..."
		echo $key | sudo -S apt purge sleuthkit &>/dev/null
		echo $key | sudo -S apt-mark hold lightdm &>/dev/null
  		echo $key | sudo -S echo lightdm hold | dpkg --set-selections &>/dev/null
    		echo $key | sudo -S apt-mark hold lightdm-gtk-greeter &>/dev/null
  		echo $key | sudo -S echo lightdm-gtk-greeter hold | dpkg --set-selections &>/dev/null
		echo $key | sudo -S apt-mark hold postfix &>/dev/null
		echo $key | sudo -S echo postfix hold | dpkg --set-selections &>/dev/null
		echo $key | sudo -S apt-mark hold sleuthkit &>/dev/null
		echo $key | sudo -S echo sleuthkit hold | dpkg --set-selections &>/dev/null
  		echo $key | sudo -S ssh-keygen -A 
		echo $key | sudo -S rm -rf /etc/apt/sources.list.d/archive_u* &>/dev/null
		echo $key | sudo -S rm -rf /etc/apt/sources.list.d/brave* &>/dev/null
		echo $key | sudo -S rm -rf /etc/apt/sources.list.d/signal* &>/dev/null
		echo $key | sudo -S rm -rf /etc/apt/sources.list.d/apt-vulns-sexy* &>/dev/null
		echo $key | sudo -S rm -rf /etc/apt/trusted.gpg.d/apt-vulns-sexy* &>/dev/null
  		echo $key | sudo -S rm -rf /etc/apt/sources.list.d/wine* &>/dev/null
		echo $key | sudo -S rm -rf /etc/apt/trusted.gpg.d/wine* &>/dev/null
		echo $key | sudo -S rm -rf /etc/apt/trusted.gpg.d/brave* &>/dev/null
		echo $key | sudo -S rm -rf /etc/apt/trusted.gpg.d/signal* &>/dev/null
		echo $key | sudo -S csi_remove /var/crash/* &>/dev/null
		echo $key | sudo -S rm /var/crash/* &>/dev/null
		rm ~/.vbox* &>/dev/null
		echo "# Setting up CSI Linux environment..."
		setup_new_csi_system
		echo $key | sudo -S apt remove sleuthkit  &>/dev/null
		echo "# Setting up repo environment"

		REPOS=(
		"deb http://archive.ubuntu.com/ubuntu/ jammy main restricted universe multiverse"
		"deb http://archive.ubuntu.com/ubuntu/ jammy-updates main restricted universe multiverse"
		"deb http://archive.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse"
		"deb http://archive.ubuntu.com/ubuntu/ jammy-backports main restricted universe multiverse"
		"deb http://archive.canonical.com/ubuntu/ jammy partner"
		)
		
		# The file to be checked and modified
		FILE="/etc/apt/sources.list"
		
		# Iterate over each repository line
		for repo in "${REPOS[@]}"; do
		    # Use grep to check if the line is already in the file
		    if ! grep -q "^$(echo $repo | sed 's/ /\\ /g')" "$FILE"; then
		        # If the line is not found, append it to the file
		        echo "Adding repository: $repo"
		        echo "$repo" | sudo tee -a "$FILE" > /dev/null
		    else
		        echo "Repository already exists: $repo"
		    fi
		done
  
		cd /tmp
		
		echo "# Setting up apt Repos"
		add_repository "apt" "https://apt.bell-sw.com/ stable main" "https://download.bell-sw.com/pki/GPG-KEY-bellsoft" "bellsoft"
		add_repository "apt" "http://apt.vulns.xyz stable main" "http://apt.vulns.xyz/kpcyrd.pgp" "apt-vulns-sexy"
		add_repository "apt" "https://dl.winehq.org/wine-builds/ubuntu/ focal main" "https://dl.winehq.org/wine-builds/winehq.key" "winehq"
		add_repository "apt" "https://www.kismetwireless.net/repos/apt/release/jammy jammy main" "https://www.kismetwireless.net/repos/kismet-release.gpg.key" "kismet"
		add_repository "apt" "https://packages.element.io/debian/ default main" "https://packages.element.io/debian/element-io-archive-keyring.gpg" "element-io"
		add_repository "apt" "https://deb.oxen.io $(lsb_release -sc) main" "https://deb.oxen.io/pub.gpg" "oxen"
		add_repository "apt" "https://updates.signal.org/desktop/apt xenial main" "https://updates.signal.org/desktop/apt/keys.asc" "signal-desktop"
		add_repository "apt" "https://brave-browser-apt-release.s3.brave.com/ stable main" "https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg" "brave-browser"
		add_repository "apt" "https://packages.microsoft.com/repos/code stable main" "https://packages.microsoft.com/keys/microsoft.asc" "vscode"
		add_repository "apt" "https://packages.cisofy.com/community/lynis/deb/ stable main" "https://packages.cisofy.com/keys/cisofy-software-public.key" "cisofy-lynis"
		add_repository "apt" "https://download.docker.com/linux/ubuntu focal stable" "https://download.docker.com/linux/ubuntu/gpg" "docker"
    
		# add_repository "key" "https://download.onlyoffice.com/repo/debian squeeze main" "hkp://keyserver.ubuntu.com:80 --recv-keys CB2DE8E5" "onlyoffice"
  				
		add_repository "ppa" "ppa:danielrichter2007/grub-customizer" "" "grub-customizer"
		add_repository "ppa" "ppa:phoerious/keepassxc" "" "keepassxc"
		add_repository "ppa" "ppa:cappelikan/ppa" "" "mainline"
		add_repository "ppa" "ppa:apt-fast/stable" "" "apt-fast"
		add_repository "ppa" "ppa:obsproject/obs-studio" "" "obs-studio"
		add_repository "ppa" "ppa:savoury1/backports" "" "savoury1"

  		echo "# Updating APT with updated repos"		
		echo $key | sudo -S apt update
  		fix_broken
    		install_vm_tools
		echo $key | sudo -S apt upgrade -y
  		echo "# Checking Starter Apps"
		install_missing_programs
		echo $key | sudo -S apt remove sleuthkit -y  &>/dev/null
    		echo "# Disabling un-needed Services"
  		disable_services &>/dev/null
    		if ! which python3-venv > /dev/null; then
			echo "# python3-venv"
			echo $key | sudo -S apt install python3-venv  &>/dev/null
		fi
		install_from_requirements_url "https://csilinux.com/downloads/csitools-requirements.txt"
		echo $key | sudo -S ln -s /usr/bin/python3 /usr/bin/python &>/dev/null
		echo $key | sudo -S timedatectl set-timezone UTC     
		echo "# Installing CSI Linux Base Tools"
		cd /tmp
		rm csi_linux_base.txt &>/dev/null
		wget https://csilinux.com/downloads/csi_linux_base.txt -O csi_linux_base.txt
  		dos2unix csi_linux_base.txt
		mapfile -t csi_linux_base < <(grep -vE "^\s*#|^$" csi_linux_base.txt | sed -e 's/#.*//')
		install_packages csi_linux_base
  		# installed_packages_desc csi_linux_base
  		echo "Installing additional system tools..."
		cd /tmp
		if ! which calibre > /dev/null; then
			echo "# Installing calibre"
			echo $key | sudo -S -v && wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | bash
		fi
		if ! which onlyoffice-desktopeditors > /dev/null; then
			wget https://download.onlyoffice.com/install/desktop/editors/linux/onlyoffice-desktopeditors_amd64.deb
			echo $key | sudo -S DEBIAN_FRONTEND=noninteractive apt-get install -y ./onlyoffice-desktopeditors_amd64.deb
		fi 
                echo "Setting up media tools..."
		if ! which xnview > /dev/null; then
			wget https://download.xnview.com/XnViewMP-linux-x64.deb
			echo $key | sudo -S DEBIAN_FRONTEND=noninteractive apt-get install -y ./XnViewMP-linux-x64.deb
		fi
  		# cis_lvl_1 $key
		echo $key | sudo -S ssh-keygen -A
    		reset_DNS
  		sudo -k
		;;
        "csi-linux-themes")
		cd /tmp
		backup_dirct="/tmp/restorecsitheme"
		backup_file_namect="csitools_theme"
		archive_pathct="$backup_dirct/$backup_file_namect.7z"
		echo "$key" | sudo -S DEBIAN_FRONTEND=noninteractive apt install aria2 -y &>/dev/null
		echo "Preparing for the CSI Theme download..."
		echo "$key" | sudo -S rm -rf "$backup_dirctct"  # Remove the entire backup directory
		echo "$key" | sudo -S mkdir -p "$backup_dirct"
		echo "$key" | sudo -S chmod 777 "$backup_dirct"  # Set full permissions temporarily for download
		echo "Downloading the CSI Theme..."
		if aria2c -x3 -k1M "https://csilinux.com/downloads/$backup_file_namect.7z" -d "$backup_dirct" -o "$backup_file_namect.7z"; then
			echo "Download successful."
			echo "# Installing the CSI Theme..."
			if restore_backup_to_root "$backup_dirct" "$backup_file_namect"; then
			    echo "The CSI Theme restored successfully."
			    echo "Setting permissions and configurations for the CSI Theme..."
			    echo "$key" | sudo -S chown csi:csi -R /home/csi/     
			    echo "The CSI Theme installation and configuration completed successfully."
			else
			    echo "Failed to restore the CSI Theme from the backup."
			fi
			else
			echo "Failed to download CSI Tools."
			return 1  # Download failed
		fi
  
		rm csi_linux_themes.txt &>/dev/null
		wget https://csilinux.com/downloads/csi_linux_themes.txt -O csi_linux_themes.txt
  		dos2unix csi_linux_themes.txt
		mapfile -t csi_linux_themes < <(grep -vE "^\s*#|^$" csi_linux_themes.txt | sed -e 's/#.*//')
		install_packages csi_linux_themes
  		# installed_packages_desc csi_linux_themes
		reset_DNS
		echo "# Configuring Background"
		update_xfce_wallpapers "/opt/csitools/wallpaper/CSI-Linux-Dark.jpg"
  		echo "Doing Grub stuff..."
    		echo $key | sudo -S "/sbin/modprobe zfs"
		if echo $key | sudo -S grep -q "GRUB_DISABLE_OS_PROBER=false" /etc/default/grub; then
		    echo $key | sudo -S sed -i 's/#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/g' /etc/default/grub
		    echo "Grub is already configured for os-probe"
		fi
		echo $key | sudo -S sed -i '/recordfail_broken=/{s/1/0/}' /etc/grub.d/00_header
		echo $key | sudo -S update-grub
		PLYMOUTH_THEME_PATH="/usr/share/plymouth/themes/vortex-ubuntu/vortex-ubuntu.plymouth"
		if [ -f "$PLYMOUTH_THEME_PATH" ]; then
		    echo $key | sudo -S update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth "$PLYMOUTH_THEME_PATH" 100 &> /dev/null
		    echo $key | sudo -S update-alternatives --set default.plymouth "$PLYMOUTH_THEME_PATH"
		else
		    echo "Plymouth theme not found: $PLYMOUTH_THEME_PATH"
		fi
		echo $key | sudo -S update-initramfs -u
    		sudo -k
		;;
        "os-update")
           	echo "Updating operating system..."
		cd /tmp
		rm csi_os_update.txt &>/dev/null
		wget https://csilinux.com/downloads/csi_os_update.txt -O csi_os_update.txt
  		dos2unix csi_os_update.txt
		mapfile -t csi_os_update < <(grep -vE "^\s*#|^$" csi_os_update.txt | sed -e 's/#.*//')
		install_packages csi_os_update

		  #!/bin/bash
		
		# Get the list of installed kernels, excluding the currently running one
		installed_kernels=$(dpkg --list | grep linux-image | awk '{print $2}' | sort -V | grep -v "$(uname -r)")
		
		# Separate kernels into version 5 and version 6 groups
		v5_kernels=($(echo "$installed_kernels" | grep -- '-5\.'))
		v6_kernels=($(echo "$installed_kernels" | grep -- '-6\.'))
		
		# Determine the latest version 5 and version 6 kernels
		latest_v5_kernel="${v5_kernels[-1]}"
		latest_v6_kernel="${v6_kernels[-1]}"
		
		echo "Latest version 5 kernel to keep: $latest_v5_kernel"
		echo "Latest version 6 kernel to keep: $latest_v6_kernel"
		
		# Create a list of kernels to remove, excluding the latest v5 and v6 kernels
		kernels_to_remove=()
		for kernel in $installed_kernels; do
		    if [[ "$kernel" != "$latest_v5_kernel" && "$kernel" != "$latest_v6_kernel" ]]; then
		        kernels_to_remove+=("$kernel")
		    fi
		done
		
		if [ ${#kernels_to_remove[@]} -eq 0 ]; then
		    echo "No kernels need to be removed."
		else
	  		echo "Kernels to remove:"
			printf '%s\n' "${kernels_to_remove[@]}"
			
			for kernel in "${kernels_to_remove[@]}"; do
				echo "Removing $kernel..."
				echo $key | sudo -S apt-get purge -y "$kernel"
			done
			# Update grub and clean up
			echo $key | sudo -S update-grub
			echo $key | sudo -S apt-get autoremove -y
			echo "Kernel cleanup complete."
  		fi

  		# installed_packages_desc csi_os_update
		current_kernel=$(uname -r)
		echo $key | sudo -S mainline --install-latest
		# Get the latest installed kernel version, ensuring consistent formatting with current_kernel
		latest_kernel=$(find /boot -name "vmlinuz-*" | sort -V | tail -n 1 | sed -r 's/.*vmlinuz-([^ ]+).*/\1/')
		
		# Echo kernel versions for debugging purposes
		echo "Currently running kernel: $current_kernel"
		echo "Latest installed kernel: $latest_kernel"
		

  		sudo -k
            ;;
        "encryption")
           	echo "Setting up encryption tools..."
		cd /tmp
		rm csi_encryption.txt &>/dev/null
		wget https://csilinux.com/downloads/csi_encryption.txt -O csi_encryption.txt
    		dos2unix csi_encryption.txt
		mapfile -t csi_encryption < <(grep -vE "^\s*#|^$" csi_encryption.txt | sed -e 's/#.*//')
		install_packages csi_encryption
  		# installed_packages_desc csi_encryption
	        
		if ! which veracrypt > /dev/null; then
			echo "Installing veracrypt"
			wget https://github.com/veracrypt/VeraCrypt/releases/download/VeraCrypt_1.26.7/veracrypt-1.26.7-Ubuntu-22.04-amd64.deb
			echo $key | sudo -S DEBIAN_FRONTEND=noninteractive apt-get install -y ./veracrypt-1.26.7-Ubuntu-22.04-amd64.deb -y
		fi
     		sudo -k
            ;;
        "osint")
		cd /tmp
		rm csi_encryption.txt &>/dev/null
		wget https://csilinux.com/downloads/csi_osint.txt -O csi_osint.txt
    		dos2unix csi_osint.txt
		mapfile -t csi_osint < <(grep -vE "^\s*#|^$" csi_osint.txt | sed -e 's/#.*//')
		install_packages csi_osint
  		# installed_packages_des csi_osint
		echo "# Configuring Online Forensic Tools"
		cd /tmp
		echo "# Installing Online Forensic Tools Packages"
		install_packages apt_online_forensic_tools
		install_from_requirements_url "https://csilinux.com/downloads/csitools-online-requirements.txt"
		repositories=(
			"theHarvester|https://github.com/laramies/theHarvester.git|true"
			"ghunt|https://github.com/mxrch/GHunt.git|true"
			"sherlock|https://github.com/sherlock-project/sherlock.git|true"
			"blackbird|https://github.com/p1ngul1n0/blackbird.git|true"
			"Moriarty-Project|https://github.com/AzizKpln/Moriarty-Project|true"
			"Rock-ON|https://github.com/SilverPoision/Rock-ON.git|true"
			"email2phonenumber|https://github.com/martinvigo/email2phonenumber.git|true"
			"Masto|https://github.com/C3n7ral051nt4g3ncy/Masto.git|true"
			"FinalRecon|https://github.com/thewhiteh4t/FinalRecon.git|true"
			"Goohak|https://github.com/1N3/Goohak.git|true"
			"Osintgram|https://github.com/Datalux/Osintgram.git|true"
			"spiderfoot|https://github.com/CSILinux/spiderfoot.git"
			"InstagramOSINT|https://github.com/sc1341/InstagramOSINT.git|true"
			"Photon|https://github.com/s0md3v/Photon.git|true"
			"ReconDog|https://github.com/s0md3v/ReconDog.gi|truet"
			"Geogramint|https://github.com/Alb-310/Geogramint.git|true"
		)
		# Iterate through the repositories and update them
		for entry in "${repositories[@]}"; do
		    IFS="|" read -r repo_name repo_url _venv <<< "$entry"
		    echo "# Checking $repo_name"
		    if [[ -n $_venv ]]; then
		        update_git_repository "$repo_name" "$repo_url" "$_venv" &>/dev/null
		    else
		        update_git_repository "$repo_name" "$repo_url" &>/dev/null
		    fi
		done
		if [ ! -f /opt/routeconverter/RouteConverterLinux.jar ]; then
			cd /opt
			mkdir routeconverter
			cd routeconverter
			wget https://static.routeconverter.com/download/RouteConverterLinux.jar
		fi
		if ! which maltego &>/dev/null; then
			cd /tmp
			wget https://csilinux.com/downloads/Maltego.deb &>/dev/null
			echo $key | sudo -S DEBIAN_FRONTEND=noninteractive apt-get install ./Maltego.deb -y &>/dev/null
		fi
		if ! which discord > /dev/null; then
			echo "disord"
			wget https://dl.discordapp.net/apps/linux/0.0.27/discord-0.0.27.deb -O /tmp/discord.deb
			echo $key | sudo -S DEBIAN_FRONTEND=noninteractive apt-get install -y /tmp/discord.deb
		fi
		if [ -f /opt/Osintgram/main.py ]; then
			cd /opt/Osintgram
			rm -f .git/index
		    git reset
			git reset --hard HEAD; git pull  &>/dev/null
			mv src/* .  &>/dev/null
			find . -type f -exec sed -i 's/from\ src\ //g' {} + &>/dev/null
			find . -type f -exec sed -i 's/src.Osintgram/Osintgram/g' {} + &>/dev/null
		fi
		if ! which google-chrome > /dev/null; then
			wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
			echo $key | sudo -S DEBIAN_FRONTEND=noninteractive apt-get install -y ./google-chrome-stable_current_amd64.deb
		fi

		if ! which sn0int; then
			echo $key | sudo -S DEBIAN_FRONTEND=noninteractive apt-get install -y sn0int &>/dev/null
		fi
		if [ ! -f /opt/PhoneInfoga/phoneinfoga ]; then
			cd /opt
			mkdir PhoneInfoga
			cd PhoneInfoga
			wget https://raw.githubusercontent.com/sundowndev/phoneinfoga/master/support/scripts/install -O - | bash 
			echo $key | sudo -S chmod +x ./phoneinfoga
			echo $key | sudo -S ln -sf ./phoneinfoga /usr/local/bin/phoneinfoga
		fi
		if [ ! -f /opt/Storm-Breaker/install.sh ]; then
			cd /opt
			git clone https://github.com/ultrasecurity/Storm-Breaker.git &>/dev/null
			cd Storm-Breaker
			pip install -r requirments.txt --quiet &>/dev/null
			echo $key | sudo -S bash install.sh &>/dev/null
   			install_packages apache2 apache2-bin apache2-data apache2-utils libapache2-mod-php8.1 libapr1 libaprutil1 libaprutil1-dbd-sqlite3 libaprutil1-ldap php php-common php8.1 php8.1-cli php8.1-common php8.1-opcache php8.1-readline	
		else
			cd /opt/Storm-Breaker
			git reset --hard HEAD; git pull &>/dev/null
			pip install -r requirments.txt --quiet &>/dev/null
			echo $key | sudo -S bash install.sh &>/dev/null
		fi
		echo $key | sudo -S ls
		wget https://github.com/telegramdesktop/tdesktop/releases/download/v4.14.12/tsetup.4.14.12.tar.xz -O tsetup.tar.xz
		echo $key | sudo -S tar -xf tsetup.tar.xz
		echo $key | sudo -S cp Telegram/Telegram /usr/bin/telegram-desktop
		repositories=(
			"OnionSearch|https://github.com/CSILinux/OnionSearch.git|true"
			"i2pchat|https://github.com/vituperative/i2pchat.git|true"
		)
		# Iterate through the repositories and update them
		for entry in "${repositories[@]}"; do
		    IFS="|" read -r repo_name repo_url _venv <<< "$entry"
		    echo "# Checking $repo_name"
		    if [[ -n $_venv ]]; then
		        update_git_repository "$repo_name" "$repo_url" "$_venv" &>/dev/null
		    else
		        update_git_repository "$repo_name" "$repo_url" &>/dev/null
		    fi
		done			
		if ! which onionshare > /dev/null; then
			echo $key | sudo -S snap install onionshare
		fi
		if ! which orjail > /dev/null; then
			wget https://github.com/orjail/orjail/releases/download/v1.1/orjail_1.1-1_all.deb
			echo $key | sudo -S DEBIAN_FRONTEND=noninteractive apt-get install ./orjail_1.1-1_all.deb
		fi
		if [ ! -f "/opt/AppImages/electrum.AppImage" ]; then
		    echo "Installing Electrum Wallet"
		    cd /opt/AppImages
		    wget https://csilinux.com/downloads/electrum.AppImage
		    echo $key | sudo -S chmod +x electrum.AppImage
		    echo $key | sudo -S ln -sf /opt/AppImages/electrum.AppImage /usr/local/bin/electrum
		
		    # Creating the .desktop file for Electrum
		    echo "[Desktop Entry]
Type=Application
Name=Electrum
Comment=Electrum Bitcoin Wallet
Exec=electrum
Icon=electrum
Terminal=false
Categories=Finance;Network;" > ~/.local/share/applications/Electrum.desktop
		
		    # Creating the .desktop file for Electrum Testnet
		    echo "[Desktop Entry]
Type=Application
Name=Electrum Testnet
Comment=Electrum Bitcoin Wallet (Testnet)
Exec=electrum --testnet
Icon=electrum
Terminal=false
Categories=Finance;Network;" > ~/.local/share/applications/ElectrumTestnet.desktop
		fi
		if [ ! -f "/opt/AppImages/oxen-electron-wallet-1.8.1-linux.AppImage" ]; then
			echo "Oxen Wallet"
   			cd /opt/AppImages
			wget https://github.com/oxen-io/oxen-electron-gui-wallet/releases/download/v1.8.1/oxen-electron-wallet-1.8.1-linux.AppImage 
			chmod +x oxen-electron-wallet-1.8.1-linux.AppImage
   			echo $key | sudo -S ln -sf /opt/AppImages/oxen-electron-wallet-1.8.1-linux.AppImage /usr/local/bin/oxen-electron-wallet

		    # Creating the .desktop file for Oxen Wallet
		    echo "[Desktop Entry]
Type=Application
Name=Oxen Wallet
Comment=Oxen Electron Wallet
Exec=oxen-electron-wallet
Icon=oxen
Terminal=false
Categories=Finance;Network;" > ~/.local/share/applications/OxenWallet.desktop
		
		fi
		cd /tmp
		## Create TorVPN environment
		echo $key | sudo -S cp /etc/tor/torrc /etc/tor/torrc.back
		echo $key | sudo -S sed -i 's/#ControlPort/ControlPort/g' /etc/tor/torrc
		echo $key | sudo -S sed -i 's/#CookieAuthentication 1/CookieAuthentication 0/g' /etc/tor/torrc
		echo $key | sudo -S sed -i 's/#SocksPort 9050/SocksPort 9050/g' /etc/tor/torrc
		echo $key | sudo -S sed -i 's/#RunAsDaemon 1/RunAsDaemon 1/g' /etc/tor/torrc
		if grep -q "VirtualAddrNetworkIPv4" /etc/tor/torrc; then
			echo "TorVPN already configured"
		else
			echo $key | sudo -S bash -c "echo 'VirtualAddrNetworkIPv4 10.192.0.0/10' >> /etc/tor/torrc"
			echo $key | sudo -S bash -c "echo 'AutomapHostsOnResolve 1' >> /etc/tor/torrc"
			echo $key | sudo -S bash -c "echo 'TransPort 9040 IsolateClientAddr IsolateClientProtocol IsolateDestAddr IsolateDestPort' >> /etc/tor/torrc"
			echo $key | sudo -S bash -c "echo 'DNSPort 5353' >> /etc/tor/torrc"
			echo "TorVPN configured"
		fi
		echo $key | sudo -S service tor stop
		echo $key | sudo -S service tor start
		wget https://csilinux.com/wp-content/uploads/2024/02/i2pupdate.zip
		echo $key | sudo -S service i2p stop
		echo $key | sudo -S service i2pd stop
		echo $key | sudo -S unzip -o i2pupdate.zip -d /usr/share/i2p
		reset_DNS
    		sudo -k
           	;;
        "incident-response")
		echo "Installing incident response tools..."
		cd /tmp
		rm csi_ir.txt &>/dev/null
		wget https://csilinux.com/downloads/csi_ir.txt -O csi_ir.txt
    		dos2unix csi_ir.txt
		mapfile -t csi_ir < <(grep -vE "^\s*#|^$" csi_ir.txt | sed -e 's/#.*//')
		install_packages csi_ir
  		# installed_packages_des csi_ir
		# Command to install incident response tools
		reset_DNS
    		sudo -k
		;;
        "computer-forensics")
            	echo "Installing computer forensics tools..."
		cd /tmp
		rm csi_cf.txt &>/dev/null
		wget https://csilinux.com/downloads/csi_cf.txt -O csi_cf.txt
    		dos2unix csi_cf.txt
		mapfile -t csi_cf < <(grep -vE "^\s*#|^$" csi_cf.txt | sed -e 's/#.*//')
		install_packages csi_cf
  		# installed_packages_des csi_cf
		echo "# Installing Computer Forensic Tools Packages"		
		install_from_requirements_url "https://csilinux.com/downloads/csitools-disk-requirements.txt"
		if [ ! -f /opt/autopsy/bin/autopsy ]; then
			cd /tmp
			wget https://github.com/sleuthkit/autopsy/releases/download/autopsy-4.21.0/autopsy-4.21.0.zip -O autopsy.zip
			wget https://github.com/sleuthkit/sleuthkit/releases/download/sleuthkit-4.12.1/sleuthkit-java_4.12.1-1_amd64.deb -O sleuthkit-java.deb
			echo $key | sudo -S DEBIAN_FRONTEND=noninteractive apt-get install ./sleuthkit-java.deb -y
			echo "$ Installing Autopsy prereqs..."
			wget https://raw.githubusercontent.com/sleuthkit/autopsy/develop/linux_macos_install_scripts/install_prereqs_ubuntu.sh &>/dev/null
			echo $key | sudo -S bash install_prereqs_ubuntu.sh
			wget https://raw.githubusercontent.com/sleuthkit/autopsy/develop/linux_macos_install_scripts/install_application.sh
			echo "# Installing Autopsy..."
			bash install_application.sh -z ./autopsy.zip -i /tmp/ -j /usr/lib/jvm/java-1.17.0-openjdk-amd64 &>/dev/null
			csi_remove /opt/autopsyold
			mv /opt/autopsy /opt/autopsyold
			chown csi:csi /opt/autopsy
			mv /tmp/autopsy-4.21.0 /opt/autopsy
			sed -i -e 's/\#jdkhome=\"\/path\/to\/jdk\"/jdkhome=\"\/usr\/lib\/jvm\/java-17-openjdk-amd64\"/g' /opt/autopsy/etc/autopsy.conf
			cd /opt/autopsy
			export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
			echo $key | sudo -S chmod +x /opt/autopsy/bin/autopsy
			echo $key | sudo -S chown csi:csi /opt/autopsy -R
			bash unix_setup.sh
			cd ~/Downloads
			git clone https://github.com/sleuthkit/autopsy_addon_modules.git
			# /opt/autopsy/bin/autopsy --nosplash
		fi
  		if ! which fred > /dev/null; then
			wget https://csilinux.com/downloads/fred_0.2.0_amd64.deb
			echo $key | sudo -S DEBIAN_FRONTEND=noninteractive apt-get install -y ./fred_0.2.0_amd64.deb
   			wget https://csilinux.com/downloads/fred-reports_0.2.0_amd64.deb
			echo $key | sudo -S DEBIAN_FRONTEND=noninteractive apt-get install -y ./fred-reports_0.2.0_amd64.deb
		fi
		repositories=(
			"WLEAPP|https://github.com/abrignoni/WLEAPP.git"
			"ALEAPP|https://github.com/abrignoni/ALEAPP.git"
			"iLEAPP|https://github.com/abrignoni/iLEAPP.git"
			"VLEAPP|https://github.com/abrignoni/VLEAPP.git"
			"iOS-Snapshot-Triage-Parser|https://github.com/abrignoni/iOS-Snapshot-Triage-Parser.git"
			"DumpsterDiver|https://github.com/securing/DumpsterDiver.git|true"
			"dumpzilla|https://github.com/Busindre/dumpzilla.git|true"
			"volatility3|https://github.com/volatilityfoundation/volatility3.git"
			"autotimeliner|https://github.com/andreafortuna/autotimeliner.git|true"
			"RecuperaBit|https://github.com/Lazza/RecuperaBit.git|true"
			"dronetimeline|https://github.com/studiawan/dronetimeline.git|true"
			"Carbon14|https://github.com/Lazza/Carbon14.git|true"
		)
		echo $key | sudo -S apt purge zfs* -y  &>/dev/null

		# Iterate through the repositories and update them
		for entry in "${repositories[@]}"; do
		    IFS="|" read -r repo_name repo_url _venv <<< "$entry"
		    echo "# Checking $repo_name"
		    if [[ -n $_venv ]]; then
		        update_git_repository "$repo_name" "$repo_url" "$_venv" &>/dev/null
		    else
		        update_git_repository "$repo_name" "$repo_url" &>/dev/null
		    fi
		done			
		echo "# Installing Video Packages"
		install_packages apt_video
		if ! which xnview > /dev/null; then
			wget  wget https://download.xnview.com/XnViewMP-linux-x64.deb
			echo $key | sudo -S DEBIAN_FRONTEND=noninteractive apt-get install -y ./XnViewMP-linux-x64.deb
		fi
            	;;
        "malware-analysis")
            	echo "Setting up malware analysis environment..."
		cd /tmp
		rm csi_ma.txt &>/dev/null
		wget https://csilinux.com/downloads/csi_ma.txt -O csi_ma.txt
    		dos2unix csi_ma.txt
		mapfile -t csi_ma < <(grep -vE "^\s*#|^$" csi_ma.txt | sed -e 's/#.*//')
		install_packages csi_ma
  		# installed_packages_des csi_ma
		if [ ! -f /opt/AppImages/imhex.AppImage ]; then
			cd /opt/AppImages
			wget https://csilinux.com/downloads/imhex.AppImage
			echo $key | sudo -S chmod +x imhex.AppImage
		fi
		if [ ! -f /opt/ghidra/VERSION ]; then
			cd /tmp
			aria2c -x3 -k1M https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_11.0_build/ghidra_11.0_PUBLIC_20231222.zip
			unzip ghidra_11.0_PUBLIC_20231222.zip
			csi_remove /opt/ghidra
			mv ghidra_11.0_PUBLIC /opt/ghidra
			cd /opt/ghidra
			echo "11.0" > VERSION
			echo $key | sudo -S chmod +x ghidraRun
			/bin/sed -i 's/JAVA\_HOME\_OVERRIDE\=/JAVA\_HOME\_OVERRIDE\=\/opt\/ghidra\/amazon-corretto-11.0.19.7.1-linux-x64/g' ./support/launch.properties
		fi
		if [ ! -f /opt/AppImages/cutter.AppImage ]; then
			cd /opt/AppImages
			wget https://csilinux.com/downloads/cutter.AppImage
			echo $key | sudo -S chmod +x cutter.AppImage
		fi
		if [ ! -f /opt/idafree/ida64 ]; then
			cd /opt
			mkdir idafree
			cd idafree
			wget -O /opt/idafree/ida64 https://out7.hex-rays.com/files/idafree83_linux.run
			echo $key | sudo -S chmod +x /opt/idafree/ida64
		fi
		cd /opt/AppImages
		echo $key | sudo -S rm -f apk-editor-studio.AppImage
		wget https://csilinux.com/downloads/apk-editor-studio.AppImage -O apk-editor-studio.AppImage
		echo $key | sudo -S chmod +x apk-editor-studio.AppImage
		if [ ! -f /opt/jd-gui/jd-gui-1.6.6-min.jar ]; then
			wget https://github.com/java-decompiler/jd-gui/releases/download/v1.6.6/jd-gui-1.6.6.deb
			echo $key | sudo -S DEBIAN_FRONTEND=noninteractive apt-get install -y ./jd-gui-1.6.6.deb
		fi
    		sudo -k
		;;
	"sigint")
		echo "Installing SIGINT tools..."
		cd /tmp
		rm csi_sigint.txt &>/dev/null
		wget https://csilinux.com/downloads/csi_sigint.txt -O csi_sigint.txt
    		dos2unix csi_sigint.txt
		mapfile -t csi_sigint < <(grep -vE "^\s*#|^$" csi_sigint.txt | sed -e 's/#.*//')
		install_packages csi_sigint
  		# installed_packages_des csi_sigint
		if ! which wifipumpkin3 > /dev/null; then
			wget https://github.com/P0cL4bs/wifipumpkin3/releases/download/v1.1.4/wifipumpkin3_1.1.4_all.deb
			echo $key | sudo -S DEBIAN_FRONTEND=noninteractive apt-get install ./wifipumpkin3_1.1.4_all.deb -y
		fi
		if [ ! -f /opt/AppImages/fmradio.AppImage ]; then
			echo "Installing fmradio"
			cd /opt/AppImages
			wget https://csilinux.com/downloads/fmradio.AppImage
			echo $key | sudo -S chmod +x fmradio.AppImage
			echo $key | sudo -S ln -sf fmradio.AppImage /usr/local/bin/fmradio
		fi
		if [ ! -f /opt/AppImages/Chirp-x86_64.AppImage ]; then
			echo "Installing Chirp"
			cd /opt/AppImages
			wget https://csilinux.com/downloads/Chirp-x86_64.AppImage
			echo $key | sudo -S chmod +x Chirp-x86_64.AppImage
			echo $key | sudo -S ln -sf Chirp-x86_64.AppImage /usr/local/bin/Chirp
		fi		
		if [ ! -f /opt/AppImages/qFlipperZero.AppImage ]; then
			cd /tmp
			wget https://update.flipperzero.one/builds/qFlipper/1.3.3/qFlipper-x86_64-1.3.3.AppImage
			mv ./qFlipper-x86_64-1.3.3.AppImage /opt/AppImages/qFlipperZero.AppImage
			cd /opt/AppImages/
			echo $key | sudo -S chmod +x /opt/AppImages/qFlipperZero.AppImage
			echo $key | sudo -S ln -sf /opt/AppImages/qFlipperZero.AppImage /usr/local/bin/qFlipperZero
		fi
		
		if [ ! -f /opt/proxmark3/client/proxmark3 ]; then
			cd /tmp
			wget https://csilinux.com/downloads/proxmark3.zip -O proxmark3.zip
			echo $key | sudo -S unzip -o -d /opt proxmark3.zip
			echo $key | sudo -S ln -sf /opt/proxmark3/client/proxmark3 /usr/local/bin/proxmark3
		fi
		
		if [ ! -f /opt/artemis/Artemis ]; then
			cd /opt
			wget https://csilinux.com/downloads/Artemis-3.2.1.tar.gz
			tar -xf Artemis-3.2.1.tar.gz
			rm Artemis-3.2.1.tar.gz
		fi
		
  		if ! which wxtoimg > /dev/null; then
			wget https://csilinux.com/downloads/wxtoimg_2.10.11-1_i386.deb
			echo $key | sudo -S DEBIAN_FRONTEND=noninteractive apt-get install -y ./wxtoimg_2.10.11-1_i386.deb
		fi

  
		reset_DNS
    		sudo -k
            	;;
        "virtualization")
		echo "Setting up virtualization tools..."
		cd /tmp
		rm csi_virt.txt &>/dev/null
		wget https://csilinux.com/downloads/csi_virt.txt -O csi_virt.txt
    		dos2unix csi_virt.txt
		mapfile -t csi_virt < <(grep -vE "^\s*#|^$" csi_virt.txt | sed -e 's/#.*//')
		install_packages csi_virt
  		# installed_packages_des csi_virt
		echo $key | sudo -S systemctl start libvirtd
		echo $key | sudo -S systemctl enable libvirtd
    		sudo -k
		;;
        "securitytesting")
		echo "Setting up Security tools..."
		cd /tmp
		rm csi_security.txt &>/dev/null
		wget https://csilinux.com/downloads/csi_securitytesting.txt -O csi_securitytesting.txt
    		dos2unix csi_securitytesting.txt
		mapfile -t csi_securitytesting < <(grep -vE "^\s*#|^$" csi_securitytesting.txt | sed -e 's/#.*//')
		install_packages csi_securitytesting
		/etc/init.d/postgresql start
  		# installed_packages_des csi_security
		if ! command -v msfconsole &> /dev/null; then
			cd /tmp
			curl https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > msfinstall && \
 			 chmod 755 msfinstall && \
  			./msfinstall
    			msfdb init
			# Define the file path
			MSFFILE="/etc/postgresql/14/main/pg_hba.conf"
			
			# Check if the line exists without "trust" and then append "trust" using sed
			if grep -q "host *all *all *127.0.0.1/32 *scram-sha-256" "$MSFFILE" && ! grep -q "host *all *all *127.0.0.1/32 *scram-sha-256 *trust" "$MSFFILE"; then
			    echo "Appending 'trust' to the specified line."
			    echo $key | sudo -S systemctl start postgresql sed -i "/host *all *all *127.0.0.1\/32 *scram-sha-256/ s/$/ trust/" "$MSFFILE"
			else
			    echo "The line either does not exist or already contains 'trust'. No changes made."
			fi
			echo $key | sudo -S systemctl enable postgresql
			echo $key | sudo -S systemctl stop postgresql
			echo $key | sudo -S systemctl start postgresql
     
			
			# echo "Installing Armitage..."
			cd /opt
			echo $key | sudo -S git clone https://github.com/CSILinux/armitage.git > /dev/null
			cd armitage
			echo $key | sudo -S ./package.sh > /dev/null
			cd release/unix
			sudo bash -c 'printf "#!/bin/sh\njava -XX:+AggressiveHeap -XX:+UseParallelGC -jar /opt/armitage/release/unix/armitage.jar \$@\n" > armitage' > /dev/null
			sudo ln -s /opt/armitage/release/unix/armitage /usr/local/bin/armitage > /dev/null
			sudo perl -pi -e 's/armitage.jar/\/opt\/armitage\/release\/unix\/armitage.jar/g' /opt/armitage/release/unix/teamserver > /dev/null

		fi
		if ! command -v zap-proxy &> /dev/null; then
  			cd /tmp
			wget https://github.com/zaproxy/zaproxy/releases/download/v2.14.0/ZAP_2_14_0_unix.sh
			echo $key | sudo -S chmod +x ZAP_2_14_0_unix.sh
			echo "This may take a while to set up the ZAP Proxy..."
			echo $key | sudo -S ./ZAP_2_14_0_unix.sh
		fi
		if ! command -v burpsuite &> /dev/null; then
  			cd /tmp
			wget https://csilinux.com/downloads/burpsuite_community_linux.sh
			echo $key | sudo -S chmod +x burpsuite_community_linux.sh
			echo "This may take a while to set up the Burpsuite Proxy..."
			echo $key | sudo -S ./burpsuite_community_linux.sh
		fi    		
		if [ ! -f /opt/AppImages/Packet_Sender_x86_64.AppImage ]; then
			echo "Installing Packet_Sender_x86_64.AppImage"
			cd /opt/AppImages
			wget https://csilinux.com/downloads/Packet_Sender_x86_64.AppImage
			echo $key | sudo -S chmod +x Packet_Sender_x86_64.AppImage
			echo $key | sudo -S ln -sf Packet_Sender_x86_64.AppImage /usr/local/bin/Packet_Sender
		fi
    		sudo -k
		;;
        "virtualization")
		install_csi_tools
		;;
 	*)
		echo "Options to continue"
		;;
    esac
done

cd /tmp
sudo -k
fix_broken
echo "# Upgrading all packages including third-party tools..."
echo $key | sudo -S apt full-upgrade -y --fix-missing
echo "# Removing unused packages and kernels..."
echo $key | sudo -S apt autoremove --purge -y
echo "# Cleaning apt cache..."
echo $key | sudo -S apt autoclean -y
echo "# Adjusting ownership of /opt directory..."
echo $key | sudo -S chown csi:csi /opt
echo "# Updating the mlocate database..."
echo $key | sudo -S updatedb
echo "System maintenance and cleanup completed successfully."
reset_DNS
echo $key | sudo -S rm /tmp/csi_tools_installed.flag

# echo "Listing installed applications with thier descriptions"
# Generate a mapfile of all installed packages on the system
# mapfile -t csi_linux_all_desc < <(dpkg-query -W -f='${binary:Package}\n')

# Now you can use the # installed_packages_desc function with this mapfile
# # installed_packages_desc csi_linux_all_desc

end_time=$(date +%s)
duration=$((end_time - start_time))
duration_minutes=$(echo "$duration / 60" | bc -l)
printf "Time taken to run the script: %.2f minutes\n" "$duration_minutes"
echo ""
echo "Please reboot when finished updating"

# First confirmation to reboot
if zenity --question --title="Reboot Confirmation" --text="Do you want to reboot now?" --width=300; then
    # Reminder to save data
    if zenity --question --title="Save Your Work" --text="Please make sure to save all your work before rebooting. Continue with reboot?" --width=300; then
        # Final confirmation before reboot
        echo "Rebooting now..."
        echo $key | sudo -S reboot
    else
        echo "Reboot canceled. Please save your work."
    fi
else
    echo "Reboot process canceled."
fi
