#!/bin/bash

# -----------------------------------------------------------------------------------
# Script Name: csitoolsupdate - powerup
# Description: CSI Linux PowerUp - updater and installer script for maintaining updates for the OS, CSI Linux Tools, and Third Party Tools.
# Author: Jeremy Martin
# Website: https://csilinux.com
# 
# Copyright: © 2025 CSI Linux - csilinux.com.  All rights reserved.
# 
# This script is proprietary software and is part of the CSI Linux project. It is available for use subject to the following conditions:
# 
# 1. This script may only be used on CSI Linux platforms, and you must have a valid license for that use. This license does not grant you rights to modify, distribute,
#    or create derivative works unless expressly stated in the license terms.
# 
# 2. Unauthorized copying of this script, via any medium, is strictly prohibited. Modifications, derivatives, and distribution are also prohibited without prior
#    written consent from CSI Linux.
# 
# 3. This script is provided "as is" and without warranties as to performance or merchantability. The author and CSI Linux disclaim all warranties, express or 
#    implied, including, but not limited to, implied warranties of merchantability and fitness for a particular purpose, concerning this script.
# 
# 4. In no event shall CSI Linux or the author be liable for any special, indirect, or consequential damages or any damages whatsoever resulting from loss of use, data or
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
    if aria2c -x3 -k1M http://echothislabs.com/downloads/csitools.7z https://csilinux.com/downloads/csitools.7z https://informationwarfarecenter.com/downloads/csitools.7z -d "$backup_dir" -o "$backup_file_name.7z"; then
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


fix_broken() {
    echo $key | sudo -S sleep 1
    echo "# Verifying and configuring any remaining packages (dpkg --configure -a --force-confold)..."
    echo $key | sudo -S dpkg --configure -a --force-confold
    echo "# Fixing and configuring broken apt installs (dpkg --configure -a)..."
    echo $key | sudo -S dpkg --configure -a
    echo "# Fixing and configuring broken apt installs (apt install --fix-broken -y)..."
    echo $key | sudo -S apt install --fix-broken -y
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

sudo -k
if [ -z "$key" ]; then
    prompt_for_sudo
fi

echo $key | sudo -S sleep 1
echo $key | sudo -S df -h
cd /tmp
install_csi_tools
disable_services
update_xfce_wallpapers

echo $key | sudo -S echo ""
cd /tmp
sudo -k
fix_broken
echo "# Removing unused packages and kernels..."
echo $key | sudo -S apt autoremove --purge -y
echo "# Cleaning apt cache..."
echo $key | sudo -S apt autoclean -y
echo "# Adjusting ownership of /opt directory..."
echo $key | sudo -S chown csi:csi /opt
echo "# Updating the mlocate database..."
echo $key | sudo -S updatedb
echo "System maintenance and cleanup completed successfully."
echo $key | sudo -S rm /tmp/csi_tools_installed.flag

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
