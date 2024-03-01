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
        if echo "$key" | sudo -S -v -k &> /dev/null; then
            sudo -k # Reset the sudo timestamp after verification
            echo "Sudo access verified."
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
    echo "Sudo access verified with the provided key."
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

echo "Power-up options selected:"
for option in "${powerup_options[@]}"; do
    echo "- $option"
done

# Use sudo with the provided key
echo $key | sudo -S sleep 1
echo $key | sudo -S df -h
cd /tmp

# Function to remove specific files
csi_remove() {
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
        echo "$key" | sudo -S git clone "$repo_url" "$repo_dir"
        echo "$key" | sudo -S chown csi:csi "$repo_dir"
    fi
    if [ -d "$repo_dir/.git" ]; then
        cd "$repo_dir" || return
        echo "$key" | sudo -S git reset --hard HEAD
        echo "$key" | sudo -S git pull
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
    )

    # Iterate through the list and disable each service
    for service in "${disableservices[@]}"; do
        echo "Disabling $service..."
        echo $key | sudo -S systemctl disable "$service" &>/dev/null
        echo $key | sudo -S systemctl stop "$service" &>/dev/null
        echo "$service disabled successfully."
    done
}

reset_DNS() {
    echo "# Checking and updating /etc/resolv.conf"
    echo $key | sudo -S mv /etc/resolv.conf /etc/resolv.conf.bak
    echo "nameserver 127.0.0.53" | sudo tee /etc/resolv.conf > /dev/null
    echo "nameserver 127.3.2.1" | sudo tee -a /etc/resolv.conf > /dev/null
    echo "DNS nameservers updated."

    # Restart systemd-resolved service
    echo $key | sudo -S systemctl restart systemd-resolved

    # Wait for systemd-resolved to be active
    while ! systemctl is-active --quiet systemd-resolved; do
        echo "Waiting for systemd-resolved to restart..."
        sleep 1
    done
    echo "systemd-resolved restarted successfully."

    # Perform connectivity test
    if ping -c 1 8.8.8.8 >/dev/null; then
        echo "Internet connection is working."
        if ! ping -c 1 google.com >/dev/null; then
            yad --title "Connectivity Issue" --text "The internet is working, but DNS is not working. Please check your resolv.conf file" --button=gtk-ok:0
        fi
    else
        echo "Internet connection is not working. Please check your network."
    fi
    sudo -k
}

setup_new_csi_system() {
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
            sudo useradd -m "$USERNAME" -G sudo -s /bin/bash || { echo -e "${USERNAME}\n${USERNAME}\n" | sudo passwd "$USERNAME"; }
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
	    sudo apt remove sleuthkit &>/dev/null
            echo $key | sudo -S apt remove --purge --allow-remove-essential -y $i386_packages
        fi
        echo "# Standardizing Arch"
        echo $key | sudo -S dpkg --remove-architecture i386
    fi

    sudo dpkg-reconfigure debconf --frontend=noninteractive
    sudo DEBIAN_FRONTEND=noninteractive dpkg --configure -a  &>/dev/null
    sudo NEEDRESTART_MODE=a apt update --ignore-missing &>/dev/null

    echo "# Cleaning old tools"
    csi_remove /var/lib/tor/hidden_service/ &>/dev/null
    csi_remove /var/lib/tor/other_hidden_service/ &>/dev/null

    wget -O - https://raw.githubusercontent.com/CSILinux/CSILinux-Powerup/main/csi-linux-terminal.sh | bash &>/dev/null
    git config --global safe.directory '*'

    sudo sysctl vm.swappiness=10
    echo "vm.swappiness=10" | sudo tee /etc/sysctl.d/99-sysctl.conf
    sudo systemctl enable fstrim.timer
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

cis_lvl_1() {
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

    # Configure SSH to use the banner
    sudo sed -i 's|#Banner none|Banner /etc/issue.net|' /etc/ssh/sshd_config &>/dev/null
    sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config &>/dev/null
    sudo sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config &>/dev/null
    sudo systemctl restart sshd &>/dev/null
    sudo -k
    echo "Coming soon...."
}

install_packages() {
    local -n packages=$1
    local total_packages=${#packages[@]}
    local installed=0
    local current_package=0

    # Ensure the directory exists
    echo $key | sudo -S mkdir -p /opt/csitools
    sudo apt remove sleuthkit  &>/dev/null
    # Attempt to fix any broken dependencies before starting installations
 
    for package in "${packages[@]}"; do
        sudo apt remove sleuthkit  &>/dev/null
        let current_package++
        # Ignore empty values
        if [[ -n $package ]]; then
            # Check if the package is already installed
            if ! dpkg -l | grep -qw "$package"; then
                printf "Installing package %s (%d of %d)...\n" "$package" "$current_package" "$total_packages"
                # Attempt to install the package
                if sudo apt-get install -y --assume-yes "$package"; then
                    printf "."
                    ((installed++))
                else
		    sudo apt remove sleuthkit  &>/dev/null
                    # If installation failed, try to fix broken dependencies and try again
                    if sudo apt-get install -y --assume-yes "$package"; then
                        printf "."
                        ((installed++))
                    else
                        printf "Installation failed for %s, logging to /opt/csitools/apt-failed.txt\n" "$package"
                        echo "$package" | sudo tee -a /opt/csitools/apt-failed.txt > /dev/null
                    fi
                fi
            else
                printf "Package %s is already installed, skipping (%d of %d).\n" "$package" "$current_package" "$total_packages"
            fi
        fi
    done
    echo "Installation complete. $installed out of $total_packages packages installed."
    sudo -k
}

function install_missing_programs() {
    local programs=(curl bpytop xterm aria2 yad zenity)
    local missing_programs=()
    local output_file="~/logfile.log" # Specify your output file path

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
        echo $key | sudo -S apt-get update | tee -a "$output_file"
        
        for program in "${missing_programs[@]}"; do
            echo "Attempting to install $program..." | tee -a "$output_file"
            if echo $key | sudo -S apt-get install -y "$program" 2>&1 | tee -a "$output_file"; then
                echo "$program installed successfully." | tee -a "$output_file"
            else
                echo "Failed to install $program. It may not be available in the repository or another error occurred." | tee -a "$output_file"
            fi
        done
    else
        echo "All programs are already installed." | tee -a "$output_file"
    fi
    sudo -k
}

echo "To remember the null output " &>/dev/null
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

add_repository "key" "https://download.onlyoffice.com/repo/debian squeeze main" "hkp://keyserver.ubuntu.com:80 --recv-keys CB2DE8E5" "onlyoffice"

add_repository "ppa" "ppa:danielrichter2007/grub-customizer" "" "grub-customizer"
add_repository "ppa" "ppa:phoerious/keepassxc" "" "keepassxc"
add_repository "ppa" "ppa:cappelikan/ppa" "" "mainline"
add_repository "ppa" "ppa:apt-fast/stable" "" "apt-fast"
add_repository "ppa" "ppa:obsproject/obs-studio" "" "obs-studio"
add_repository "ppa" "ppa:savoury1/backports" "" "savoury1"

echo $key | sudo -S apt update
echo $key | sudo -S apt upgrade -y
install_missing_programs
echo $key | sudo -S apt remove sleuthkit -y  &>/dev/null

cis_lvl_1

# echo $key | sudo -S ln -s /opt/csitools/csi_app /usr/bin/csi_app &>/dev/null
reset_DNS
cd /tmp

apt_computer_forensic_tools=(
    "dcfldd"
    "dc3dd"
    "binwalk"
    "gparted"
)

apt_video=(
    "ffmpeg"
    "obs-studio"
    "vlc"
)

apt_image=(
    "tesseract-ocr"
)


install_from_requirements_url "https://csilinux.com/downloads/csitools-requirements.txt"
dos2unix /opt/csitools/resetdns
echo $key | sudo -S ln -s /usr/bin/python3 /usr/bin/python &>/dev/null
echo $key | sudo -S timedatectl set-timezone UTC

# unredactedmagazine
# echo $key | sudo -S /opt/csitools/clearlogs

# Main script logic
if [[ $powerup_options_string == "all" ]]; then
    update_all_options
else
    IFS=',' read -r -a powerup_options <<< "$powerup_options_string"
    for option in "${powerup_options[@]}"; do
        process_option "$option"  # Make sure to define process_option to handle individual options
    done
fi
sudo -k
for option in "${powerup_options[@]}"; do
    echo "Processing option: $option"
    case $option in
        "csi-linux-base")
		cd /tmp
  		disable_services &>/dev/null
  		apt_system=(
		    "auditd"
		    "baobab"
		    "code"
		    "apt-transport-https"
		    "tmux"
		    "mainline"
		    "zram-config"
		    "xfce4-cpugraph-plugin"
		    "xfce4-goodies"
		    "bash-completion"
		    "tre-command"
		    "tre-agrep"
		    "libc6"
		    "libstdc++6"
		    "ca-certificates"
		    "tar"
		    "neovim"
		)
  		install_packages apt_system
    		echo "# Installing Bulk Packages from apps.txt"
		rm apps.txt &>/dev/null
		wget https://csilinux.com/downloads/apps.txt -O apps.txt
		mapfile -t apt_bulk_packages < <(grep -vE "^\s*#|^$" apps.txt | sed -e 's/#.*//')
		install_packages apt_bulk_packages
  		echo "Installing additional system tools..."
		cd /tmp
		install_packages apt_system
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
		reset_DNS
  		sudo -k
		;;
        "csi-linux-themes")
                install_csi_tools
		reset_DNS
		echo "# Configuring Background"
		update_xfce_wallpapers "/opt/csitools/wallpaper/CSI-Linux-Dark.jpg"
  		echo "Doing Grub stuff..."
		if echo $key | sudo -S grep -q "GRUB_DISABLE_OS_PROBER=false" /etc/default/grub; then
		    echo $key | sudo -S sed -i 's/#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/g' /etc/default/grub
		    echo "Grub is already configured for os-probe"
		fi
		echo "$key" | sudo -S sed -i '/recordfail_broken=/{s/1/0/}' /etc/grub.d/00_header
		echo "$key" | sudo -S systemctl disable mono-xsp4.service
		echo "$key" | sudo -S update-grub
		PLYMOUTH_THEME_PATH="/usr/share/plymouth/themes/vortex-ubuntu/vortex-ubuntu.plymouth"
		if [ -f "$PLYMOUTH_THEME_PATH" ]; then
		    echo "$key" | sudo -S update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth "$PLYMOUTH_THEME_PATH" 100 &> /dev/null
		    echo "$key" | sudo -S update-alternatives --set default.plymouth "$PLYMOUTH_THEME_PATH"
		else
		    echo "Plymouth theme not found: $PLYMOUTH_THEME_PATH"
		fi
		echo "$key" | sudo -S update-initramfs -u
    		sudo -k
		;;
        "os-update")
           	echo "Updating operating system..."
		current_kernel=$(uname -r)
		echo $key | sudo -S mainline --install-latest
		# Get the latest installed kernel version, ensuring consistent formatting with current_kernel
		latest_kernel=$(find /boot -name "vmlinuz-*" | sort -V | tail -n 1 | sed -r 's/.*vmlinuz-([^ ]+).*/\1/')
		
		# Echo kernel versions for debugging purposes
		echo "Currently running kernel: $current_kernel"
		echo "Latest installed kernel: $latest_kernel"
		
		# Compare the current running kernel with the latest installed kernel
		if [[ "$current_kernel" != "$latest_kernel" ]]; then
		    zenity_response=$(zenity --question --title="Reboot Required" --text="A newer kernel is installed ($latest_kernel).\nDo you want to reboot into the new kernel now?" --width=300 --height=200; echo $?)
		    if [ "$zenity_response" -eq 0 ]; then
		        zenity --info --title="Run Powerup Again" --text="Remember to save your work before you hit OK and run the powerup script again after the system has rebooted." --width=300 --height=200
		        echo "Rebooting the system..."
		        echo $key | sudo -S reboot
		    else
		        # User chose not to reboot
		        echo "Continuing without rebooting."
		    fi
		else
		    echo "The running kernel is the latest installed version."
		fi
		reset_DNS
  		sudo -k
            ;;
        "encryption")
            echo "Setting up encryption tools..."
			cd /tmp
			if ! which veracrypt > /dev/null; then
				echo "Installing veracrypt"
				wget https://github.com/veracrypt/VeraCrypt/releases/download/VeraCrypt_1.26.7/veracrypt-1.26.7-Ubuntu-22.04-amd64.deb
				echo $key | sudo -S apt install -y ./veracrypt-1.26.7-Ubuntu-22.04-amd64.deb -y
			fi
     		sudo -k
            ;;
        "osint")
		apt_online_forensic_tools=(
		    "brave-browser"
		    "tor"
		    "wireshark"
		    "lokinet"
		)
  		install_packages apt_online_forensic_tools
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
		# Command to install incident response tools
		reset_DNS
    		sudo -k
		;;
        "computer-forensics")
            	echo "Installing computer forensics tools..."
		cd /tmp
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
		# Command to install virtualization tools
    		sudo -k
		;;
        *)
		echo "Option $option not recognized."
		;;
    esac
done

cd /tmp
sudo -k
fix_broken
echo "# Upgrading all packages including third-party tools..."
echo "$key" | sudo -S apt full-upgrade -y --fix-missing
echo "# Removing unused packages and kernels..."
echo "$key" | sudo -S apt autoremove --purge -y
echo "# Cleaning apt cache..."
echo "$key" | sudo -S apt autoclean -y
echo "# Adjusting ownership of /opt directory..."
echo "$key" | sudo -S chown csi:csi /opt
echo "# Updating the mlocate database..."
echo "$key" | sudo -S updatedb
echo "System maintenance and cleanup completed successfully."

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
        echo "$key" | sudo -S reboot
    else
        echo "Reboot canceled. Please save your work."
    fi
else
    echo "Reboot process canceled."
fi

