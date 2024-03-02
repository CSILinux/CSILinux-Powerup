#!/bin/bash
echo "Welcome to CSI Linux 2024. This will take a while, but the update has a LOT of content..."

# Define the function to prompt for sudo password
prompt_for_sudo() {
    while true; do
        key=$(zenity --password --title "Power up your system with an upgrade." --text "Enter your CSI password." --width=400)
        if [ $? -ne 0 ]; then
            zenity --info --text="Operation cancelled. Exiting script." --width=400
            exit 1
        fi
        if echo $key | sudo -S -v -k &> /dev/null; then
            sudo -k # Reset the sudo timestamp after verification
            echo "sudo access verified."
            break # Exit loop if the password is correct
        else
            zenity --error --title="Authentication Failure" --text="Incorrect password or lack of sudo privileges. Please try again." --width=400
        fi
    done
}

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
    powerup_options+=("csi_fresh")
fi

echo "Power-up options selected:"
for option in "${powerup_options[@]}"; do
    echo "- $option"
done

# Use sudo with the provided key
echo $key | sudo -S sleep 1
echo $key | sudo -S df -h
cd /tmp

install_csi_tools() {
    local backup_dir="/tmp/restore"
    local backup_file_name="csitools"
    local archive_path="$backup_dir/$backup_file_name.7z"

    echo "Preparing for CSI Tools download..."
    # Ensuring /tmp and backup_dir are clean before downloading CSI Tools
    echo "Cleaning up old CSI Tools files and directory..."
    echo $key | sudo -S rm -rf "$backup_dir"  # Remove the entire backup_dir
    
    # Recreating the backup_dir with appropriate permissions
    echo $key | sudo -S mkdir -p "$backup_dir"
    echo $key | sudo -S chmod 777 "$backup_dir"  # Set full permissions temporarily for download

    echo "Downloading CSI Tools"
    # Using sudo with aria2c to ensure permissions aren't an issue
    echo $key | sudo -S aria2c -x3 -k1M https://csilinux.com/downloads/csitools.7z -d "$backup_dir" -o "$backup_file_name.7z"

    # Adjust permissions back after download, if necessary
    echo $key | sudo -S chmod 755 "$backup_dir"

    echo "# Installing CSI Tools"
    restore_backup_to_root "$backup_dir" "$backup_file_name"

    # Post-restoration operations such as setting permissions
    echo "Setting permissions and configurations for CSI Tools..."
    echo $key | sudo -S chown csi:csi -R /opt/csitools
    echo $key | sudo -S chmod +x /opt/csitools/* -R
    echo $key | sudo -S chmod +x ~/Desktop/*.desktop
    # Ensure other necessary configurations or permissions adjustments here...
}

restore_backup_to_root() {
    echo $key | sudo -S sleep 1
    sudo -k
    local backup_dir=$1
    local backup_file_name=$2
    local archive_path="$backup_dir/$backup_file_name.7z"

    echo "Restoring CSI Tools backup..."
    # Extract the .7z file safely
    if ! echo $key | sudo -S 7z x -o"$backup_dir" "$archive_path"; then
        echo "Failed to extract $archive_path. Please check the file and try again."
        return 1  # Exit the function with an error status
    fi

    local tar_file="$backup_dir/$backup_file_name.tar"
    if [ -f "$tar_file" ]; then
        echo "Restoring backup from tar file..."
        if ! echo $key | sudo -S tar -xpf "$tar_file" -C /; then
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

update_current_time() {
  current_time=$(date +"%Y-%m-%d %H:%M:%S")
}

calculate_duration() {
  start_seconds=$(date -d "$start_time" +%s)
  end_seconds=$(date -d "$current_time" +%s)
  duration=$((end_seconds - start_seconds))
}

add_repository() {
    echo $key | sudo -S sleep 1
    local repo_type="$1"
    local repo_url="$2"
    local gpg_key_info="$3"  # Contains the keyserver and the keys to receiving for 'key' type
    local repo_name="$4"

    # First, check if the repository list file already exists
    if [ -f "/etc/apt/sources.list.d/${repo_name}.list" ]; then
        echo "Repository '${repo_name}' list file already exists. Skipping addition."
        return 0
    fi

    # Since the .list file does not exist, proceed with adding the GPG key (for 'apt' and 'key')
    if [[ "$repo_type" == "apt" || "$repo_type" == "key" ]] && [ ! -f "/etc/apt/trusted.gpg.d/${repo_name}.gpg" ]; then
        echo "Adding GPG key for '${repo_name}'..."
        if [ "$repo_type" == "apt" ]; then
            curl -fsSL "$gpg_key_info" | sudo gpg --dearmor | sudo tee "/etc/apt/trusted.gpg.d/${repo_name}.gpg" > /dev/null
        elif [ "$repo_type" == "key" ]; then
            # Correctly handle the 'key' type using the original working code snippet
            local keyserver=$(echo "$gpg_key_info" | cut -d ' ' -f1)
            local recv_keys=$(echo "$gpg_key_info" | cut -d ' ' -f2-)
            sudo gpg --no-default-keyring --keyring gnupg-ring:/tmp/"$repo_name".gpg --keyserver "$keyserver" --recv-keys $recv_keys
            sudo gpg --no-default-keyring --keyring gnupg-ring:/tmp/"$repo_name".gpg --export | sudo tee "/etc/apt/trusted.gpg.d/$repo_name.gpg" > /dev/null
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
        sudo add-apt-repository --no-update -y "$repo_url"
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
    echo "# Fixing and configuring broken apt installs..."
    sudo apt update
    sudo apt remove sleuthkit  &>/dev/null
    sudo apt install --fix-broken -y
    sudo dpkg --configure -a
    echo "# Verifying and configuring any remaining packages..."
    sudo dpkg --configure -a --force-confold
}

update_git_repository() {
    local repo_name="$1"
    local repo_url="$2"
    local repo_dir="/opt/$repo_name"
    if [ ! -d "$repo_dir" ]; then
        # Clone the Git repository with sudo
        echo $key | sudo -S git clone "$repo_url" "$repo_dir"
        echo $key | sudo -S chown csi:csi "$repo_dir"
    fi
    if [ -d "$repo_dir/.git" ]; then
        cd "$repo_dir" || return
        echo $key | sudo -S git reset --hard HEAD
        echo $key | sudo -S git pull
        if [ -f "$repo_dir/requirements.txt" ]; then
            python3 -m venv "${repo_dir}/${repo_name}-venv"
            source "${repo_dir}/${repo_name}-venv/bin/activate"
            pip3 install -r requirements.txt
        fi
    else
        echo "   -  ."
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
    sudo apt-mark hold lightdm &>/dev/null
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

    wget -O - https://raw.githubusercontent.com/CSILinux/CSILinux-Powerup/main/csi-linux-terminal.sh | bash &>/dev/null
    git config --global safe.directory '*'

    echo $key | sudo -S sysctl vm.swappiness=10
    echo "vm.swappiness=10" | sudo tee /etc/sysctl.d/99-sysctl.conf
    echo $key | sudo -S systemctl enable fstrim.timer
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
    echo "Downloading requirements list"
    rm /tmp/requirements.txt &>/dev/null
    curl -s "$requirements_url" -o /tmp/requirements.txt
    local total_packages=$(wc -l < /tmp/requirements.txt)
    local current_package=0
    echo "Installing Python packages..."
    while IFS= read -r package; do
        let current_package++
        echo -ne "Installing packages: $current_package/$total_packages\r"
        python3 -m pip install "$package" --quiet &>/dev/null
    done < /tmp/requirements.txt
    echo -ne '\n'
    echo "Installation complete."
}

# echo "To remember the null output " &>/dev/null
# echo $key | sudo -S ln -s /opt/csitools/csi_app /usr/bin/csi_app &>/dev/null

cd /tmp

# unredactedmagazine

# Main script logic
sudo -k
for option in "${powerup_options[@]}"; do
    echo "Processing option: $option"
    case $option in
        "csi-linux-base")
		cd /tmp
		echo "Cleaning up..."
		echo $key | sudo -S apt remove sleuthkit &>/dev/null
		echo $key | sudo -S apt-mark hold lightdm &>/dev/null
		echo lightdm hold | dpkg --set-selections &>/dev/null
		echo $key | sudo -S apt-mark hold sleuthkit &>/dev/null
		echo sleuthkit hold | dpkg --set-selections &>/dev/null
		echo $key | sudo -S rm -rf /etc/apt/sources.list.d/archive_u* &>/dev/null
		echo $key | sudo -S rm -rf /etc/apt/sources.list.d/brave* &>/dev/null
		echo $key | sudo -S rm -rf /etc/apt/sources.list.d/signal* &>/dev/null
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
		fix_broken
		echo "# Setting up repo environment"
		cd /tmp
		
		echo "# Setting up apt Repos"
		add_repository "apt" "https://apt.bell-sw.com/ stable main" "https://download.bell-sw.com/pki/GPG-KEY-bellsoft" "bellsoft"
		add_repository "apt" "http://apt.vulns.sexy stable main" "https://apt.vulns.sexy/kpcyrd.pgp" "apt-vulns-sexy"
		add_repository "apt" "https://dl.winehq.org/wine-builds/ubuntu/ focal main" "https://dl.winehq.org/wine-builds/winehq.key" "winehq"
		add_repository "apt" "https://www.kismetwireless.net/repos/apt/release/jammy jammy main" "https://www.kismetwireless.net/repos/kismet-release.gpg.key" "kismet"
		add_repository "apt" "https://packages.element.io/debian/ default main" "https://packages.element.io/debian/element-io-archive-keyring.gpg" "element-io"
		add_repository "apt" "https://deb.oxen.io $(lsb_release -sc) main" "https://deb.oxen.io/pub.gpg" "oxen"
		add_repository "apt" "https://updates.signal.org/desktop/apt xenial main" "https://updates.signal.org/desktop/apt/keys.asc" "signal-desktop"
		add_repository "apt" "https://brave-browser-apt-release.s3.brave.com/ stable main" "https://brave-browser-apt-release.s3.brave.com/brave-core.asc" "brave-browser"
		add_repository "apt" "https://packages.microsoft.com/repos/code stable main" "https://packages.microsoft.com/keys/microsoft.asc" "vscode"
		add_repository "apt" "https://packages.cisofy.com/community/lynis/deb/ stable main" "https://packages.cisofy.com/keys/cisofy-software-public.key" "cisofy-lynis"
		add_repository "apt" "https://download.docker.com/linux/ubuntu focal stable" "https://download.docker.com/linux/ubuntu/gpg" "docker"
    
    		add_repository "key" "deb http://ftp.debian.org/debian stable main contrib non-free" "keyring.debian.org --recv-keys 0x2404C9546E145360" "debian"
		add_repository "key" "https://download.onlyoffice.com/repo/debian squeeze main" "hkp://keyserver.ubuntu.com:80 --recv-keys CB2DE8E5" "onlyoffice"
		
		add_repository "ppa" "ppa:danielrichter2007/grub-customizer" "" "grub-customizer"
		add_repository "ppa" "ppa:phoerious/keepassxc" "" "keepassxc"
		add_repository "ppa" "ppa:cappelikan/ppa" "" "mainline"
		add_repository "ppa" "ppa:apt-fast/stable" "" "apt-fast"
		add_repository "ppa" "ppa:obsproject/obs-studio" "" "obs-studio"
		add_repository "ppa" "ppa:savoury1/backports" "" "savoury1"
		add_repository "ppa" "  ppa:alexlarsson/flatpak" "" "flatpack"

		
		echo $key | sudo -S apt update
		echo $key | sudo -S apt upgrade -y
		install_missing_programs
		echo $key | sudo -S apt remove sleuthkit -y  &>/dev/null
  		disable_services &>/dev/null
		install_from_requirements_url "https://csilinux.com/downloads/csitools-requirements.txt"
		echo $key | sudo -S ln -s /usr/bin/python3 /usr/bin/python &>/dev/null
		echo $key | sudo -S timedatectl set-timezone UTC     
    		echo "# Installing Bulk Packages from apps.txt"
		rm csi_linux_base.txt &>/dev/null
		wget https://csilinux.com/downloads/csi_linux_base.txt -O csi_linux_base.txt
  		dos2unix csi_linux_base.txt
		mapfile -t csi_linux_base < <(grep -vE "^\s*#|^$" csi_linux_base.txt | sed -e 's/#.*//')
		install_packages csi_linux_base
  		echo "Installing additional system tools..."
		cd /tmp
		echo "# Configuring Investigation Tools"
		if ! which calibre > /dev/null; then
			echo "# Installing calibre"
			echo $key | sudo -S -v && wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | echo $key | sudo -S sh /dev/stdin
		fi
                echo "Setting up media tools..."
		if ! which xnview > /dev/null; then
			wget  wget https://download.xnview.com/XnViewMP-linux-x64.deb
			echo $key | sudo -S apt install -y ./XnViewMP-linux-x64.deb
		fi
  		# cis_lvl_1 $key
    		reset_DNS
  		sudo -k
		;;
        "csi-linux-themes")
                install_csi_tools
		cd /tmp
		rm csi_linux_themes.txt &>/dev/null
		wget https://csilinux.com/downloads/csi_linux_themes.txt -O csi_linux_themes.txt
  		dos2unix csi_linux_themes.txt
		mapfile -t csi_linux_themes < <(grep -vE "^\s*#|^$" csi_linux_themes.txt | sed -e 's/#.*//')
		install_packages csi_linux_themes
		reset_DNS
		echo "# Configuring Background"
		update_xfce_wallpapers "/opt/csitools/wallpaper/CSI-Linux-Dark.jpg"
  		echo "Doing Grub stuff..."
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
	        
		if ! which veracrypt > /dev/null; then
			echo "Installing veracrypt"
			wget https://github.com/veracrypt/VeraCrypt/releases/download/VeraCrypt_1.26.7/veracrypt-1.26.7-Ubuntu-22.04-amd64.deb
			echo $key | sudo -S apt install -y ./veracrypt-1.26.7-Ubuntu-22.04-amd64.deb -y
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
		echo "# Configuring Online Forensic Tools"
		cd /tmp
		echo "# Installing Online Forensic Tools Packages"
		install_packages apt_online_forensic_tools
		install_from_requirements_url "https://csilinux.com/downloads/csitools-online-requirements.txt"
		repositories=(
			"theHarvester|https://github.com/laramies/theHarvester.git"
			"ghunt|https://github.com/mxrch/GHunt.git"
			"sherlock|https://github.com/sherlock-project/sherlock.git"
			"blackbird|https://github.com/p1ngul1n0/blackbird.git"
			"Moriarty-Project|https://github.com/AzizKpln/Moriarty-Project"
			"Rock-ON|https://github.com/SilverPoision/Rock-ON.git"
			"email2phonenumber|https://github.com/martinvigo/email2phonenumber.git"
			"Masto|https://github.com/C3n7ral051nt4g3ncy/Masto.git"
			"FinalRecon|https://github.com/thewhiteh4t/FinalRecon.git"
			"Goohak|https://github.com/1N3/Goohak.git"
			"Osintgram|https://github.com/Datalux/Osintgram.git"
			"spiderfoot|https://github.com/CSILinux/spiderfoot.git"
			"InstagramOSINT|https://github.com/sc1341/InstagramOSINT.git"
			"Photon|https://github.com/s0md3v/Photon.git"
			"ReconDog|https://github.com/s0md3v/ReconDog.git"
			"Geogramint|https://github.com/Alb-310/Geogramint.git"
		)
		# Iterate through the repositories and update them
		for entry in "${repositories[@]}"; do
			IFS="|" read -r repo_name repo_url <<< "$entry"
			echo "# Checking $entry"
			update_git_repository "$repo_name" "$repo_url"  &>/dev/null
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
			echo $key | sudo -S apt install ./Maltego.deb -y &>/dev/null
		fi
		if ! which discord > /dev/null; then
			echo "disord"
			wget https://dl.discordapp.net/apps/linux/0.0.27/discord-0.0.27.deb -O /tmp/discord.deb
			echo $key | sudo -S apt install -y /tmp/discord.deb
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
			echo $key | sudo -S apt install -y ./google-chrome-stable_current_amd64.deb
		fi

		if ! which sn0int; then
			echo $key | sudo -S apt install -y sn0int -y &>/dev/null
		fi
		if [ ! -f /opt/PhoneInfoga/phoneinfoga ]; then
			cd /opt
			mkdir PhoneInfoga
			cd PhoneInfoga
			wget https://raw.githubusercontent.com/sundowndev/phoneinfoga/master/support/scripts/install -O - | sh 
			echo $key | sudo -S chmod +x ./phoneinfoga
			echo $key | sudo -S ln -sf ./phoneinfoga /usr/local/bin/phoneinfoga
		fi
		if [ ! -f /opt/Storm-Breaker/install.sh ]; then
			cd /opt
			git clone https://github.com/ultrasecurity/Storm-Breaker.git &>/dev/null
			cd Storm-Breaker
			pip install -r requirments.txt --quiet &>/dev/null
			echo $key | sudo -S bash install.sh &>/dev/null
			echo $key | sudo -S apt install -y apache2 apache2-bin apache2-data apache2-utils libapache2-mod-php8.1 libapr1 libaprutil1 libaprutil1-dbd-sqlite3 libaprutil1-ldap php php-common php8.1 php8.1-cli php8.1-common php8.1-opcache php8.1-readline	
		else
			cd /opt/Storm-Breaker
			git reset --hard HEAD; git pull &>/dev/null
			pip install -r requirments.txt --quiet &>/dev/null
			echo $key | sudo -S bash install.sh &>/dev/null
		fi

		wget https://github.com/telegramdesktop/tdesktop/releases/download/v4.14.12/tsetup.4.14.12.tar.xz -O tsetup.tar.xz
		tar -xf tsetup.tar.xz
		echo $key | sudo -S cp Telegram/Telegram /usr/bin/telegram-desktop
		repositories=(
			"OnionSearch|https://github.com/CSILinux/OnionSearch.git"
			"i2pchat|https://github.com/vituperative/i2pchat.git"
		)
		# Iterate through the repositories and update them
		for entry in "${repositories[@]}"; do
			IFS="|" read -r repo_name repo_url <<< "$entry"
			echo "# Checking $entry"
			update_git_repository "$repo_name" "$repo_url"  &>/dev/null
		done			
		if ! which onionshare > /dev/null; then
			echo $key | sudo -S snap install onionshare
		fi
		if ! which orjail > /dev/null; then
				wget https://github.com/orjail/orjail/releases/download/v1.1/orjail_1.1-1_all.deb
			echo $key | sudo -S apt install ./orjail_1.1-1_all.deb
		fi
		
		if [ ! -f /opt/OxenWallet/oxen-electron-wallet-1.8.1-linux.AppImage ]; then
			cd /opt
			mkdir OxenWallet
			cd OxenWallet
			wget https://github.com/oxen-io/oxen-electron-gui-wallet/releases/download/v1.8.1/oxen-electron-wallet-1.8.1-linux.AppImage 
			chmod +x oxen-electron-wallet-1.8.1-linux.AppImage
		fi
		
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
		echo "# Installing Computer Forensic Tools Packages"
		install_packages apt_computer_forensic_tools
		install_from_requirements_url "https://csilinux.com/downloads/csitools-disk-requirements.txt"
		if [ ! -f /opt/autopsy/bin/autopsy ]; then
			cd /tmp
			wget https://github.com/sleuthkit/autopsy/releases/download/autopsy-4.21.0/autopsy-4.21.0.zip -O autopsy.zip
			wget https://github.com/sleuthkit/sleuthkit/releases/download/sleuthkit-4.12.1/sleuthkit-java_4.12.1-1_amd64.deb -O sleuthkit-java.deb
			echo $key | sudo -S apt install ./sleuthkit-java.deb -y
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
		repositories=(
			"WLEAPP|https://github.com/abrignoni/WLEAPP.git"
			"ALEAPP|https://github.com/abrignoni/ALEAPP.git"
			"iLEAPP|https://github.com/abrignoni/iLEAPP.git"
			"VLEAPP|https://github.com/abrignoni/VLEAPP.git"
			"iOS-Snapshot-Triage-Parser|https://github.com/abrignoni/iOS-Snapshot-Triage-Parser.git"
			"DumpsterDiver|https://github.com/securing/DumpsterDiver.git"
			"dumpzilla|https://github.com/Busindre/dumpzilla.git"
			"volatility3|https://github.com/volatilityfoundation/volatility3.git"
			"autotimeliner|https://github.com/andreafortuna/autotimeliner.git"
			"RecuperaBit|https://github.com/Lazza/RecuperaBit.git"
			"dronetimeline|https://github.com/studiawan/dronetimeline.git"
			"Carbon14|https://github.com/Lazza/Carbon14.git"
		)

		# Iterate through the repositories and update them
		for entry in "${repositories[@]}"; do
			IFS="|" read -r repo_name repo_url <<< "$entry"
			echo "# Checking $entry"
			update_git_repository "$repo_name" "$repo_url"  &>/dev/null
		done			
		echo "# Installing Video Packages"
		install_packages apt_video
		if ! which xnview > /dev/null; then
			wget  wget https://download.xnview.com/XnViewMP-linux-x64.deb
			echo $key | sudo -S apt install -y ./XnViewMP-linux-x64.deb
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
		if [ ! -f /opt/ImHex/imhex.AppImage ]; then
			cd /opt
			mkdir ImHex
			cd ImHex
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
		if [ ! -f /opt/cutter/cutter.AppImage ]; then
			cd /opt
			mkdir cutter
			cd cutter
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
		cd /opt
		mkdir apk-editor-studio
		cd apk-editor-studio
		rm apk-editor-studio.AppImage
		wget https://csilinux.com/downloads/apk-editor-studio.AppImage -O apk-editor-studio.AppImage
		echo $key | sudo -S chmod +x apk-editor-studio.AppImage
		if [ ! -f /opt/jd-gui/jd-gui-1.6.6-min.jar ]; then
			wget https://github.com/java-decompiler/jd-gui/releases/download/v1.6.6/jd-gui-1.6.6.deb
			echo $key | sudo -S apt install -y ./jd-gui-1.6.6.deb
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
		if ! which wifipumpkin3 > /dev/null; then
			wget https://github.com/P0cL4bs/wifipumpkin3/releases/download/v1.1.4/wifipumpkin3_1.1.4_all.deb
			echo $key | sudo -S apt install ./wifipumpkin3_1.1.4_all.deb -y
		fi
		if [ ! -f /opt/fmradio/fmradio.AppImage ]; then
			echo "Installing fmradio"
			cd /opt
			mkdir fmradio
			cd fmradio
			wget https://csilinux.com/downloads/fmradio.AppImage
			echo $key | sudo -S chmod +x fmradio.AppImage
			echo $key | sudo -S ln -sf fmradio.AppImage /usr/local/bin/fmradio
		fi
		
		if [ ! -f /opt/FlipperZero/qFlipperZero.AppImage ]; then
			cd /tmp
			wget https://update.flipperzero.one/builds/qFlipper/1.3.3/qFlipper-x86_64-1.3.3.AppImage
			mkdir /opt/FlipperZero
			mv ./qFlipper-x86_64-1.3.3.AppImage /opt/FlipperZero/qFlipperZero.AppImage
			cd /opt/FlipperZero/
			echo $key | sudo -S chmod +x /opt/FlipperZero/qFlipperZero.AppImage
			echo $key | sudo -S ln -sf /opt/FlipperZero/qFlipperZero.AppImage /usr/local/bin/qFlipperZero
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
		
		if ! which chirp-snap.chirp > /dev/null; then
			echo "# chirp-snap takes time"
			echo $key | sudo -S snap install chirp-snap --edge
			echo $key | sudo -S snap connect chirp-snap:raw-usb
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
		echo $key | sudo -S systemctl start libvirtd
		echo $key | sudo -S systemctl enable libvirtd
    		sudo -k
		;;
        *)
		install_csi_tools
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

update_current_time
calculate_duration
echo "End time: $current_time"
echo "Total duration: $duration seconds"
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

