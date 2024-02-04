#!/bin/bash

key=$1
cd /tmp
update_current_time() {
  current_time=$(date +"%Y-%m-%d %H:%M:%S")
}
calculate_duration() {
  start_seconds=$(date -d "$start_time" +%s)
  end_seconds=$(date -d "$current_time" +%s)
  duration=$((end_seconds - start_seconds))
}

update_current_time
start_time="$current_time"
echo "CSI Linux Powerup Start time: $start_time"

add_debian_repository() {
    local repo_url="$1"
    local gpg_key_url="$2"
    local repo_name="$3"
    curl -fsSL "$gpg_key_url" | sudo -S gpg --dearmor | sudo -S tee "/etc/apt/trusted.gpg.d/$repo_name.gpg"
    if [ $? -eq 0 ]; then
        echo "# GPG key for '$repo_name' updated successfully."
    else
        echo "   - Error adding GPG key for '$repo_name'."
        return 1
    fi
    echo "# Updating $repo_name repository"
    echo "deb [signed-by=/etc/apt/trusted.gpg.d/$repo_name.gpg] $repo_url" | sudo -S tee "/etc/apt/sources.list.d/$repo_name.list"
    if [ $? -eq 0 ]; then
        printf "  - Repository '$repo_name' updated successfully."
    else
        printf "  - Error adding repository '$repo_name'."
        return 1
    fi
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

setup_new_csi_user_and_system() {
    echo "# Setting up users"
    USERNAME=csi
    useradd -m "$USERNAME" -G sudo -s /bin/bash || echo -e "${USERNAME}\n${USERNAME}\n" | passwd "$USERNAME"
    echo $key | sudo -S adduser "$USERNAME" vboxsf
    echo $key | sudo -S adduser "$USERNAME" libvirt
    echo $key | sudo -S adduser "$USERNAME" kvm
    echo "# System setup starting..."
    ###  System setup
    echo $key | sudo -S bash -c 'echo "$nrconf{restart} = '"'"'a'"'"'" | tee /etc/needrestart/conf.d/autorestart.conf'
    export DEBIAN_FRONTEND=noninteractive
    export apt_LISTCHANGES_FRONTEND=none
    export DISPLAY=:0.0
    export TERM=xterm
	if dpkg --print-foreign-architectures | grep -q 'i386'; then
	    echo "# Cleaning up old Arch"
	    i386_packages=$(dpkg --get-selections | awk '/i386/{print $1}')
	    if [ ! -z "$i386_packages" ]; then
		echo "Removing i386 packages..."
		echo $key | sudo -S apt remove --purge --allow-remove-essential -y $i386_packages
	    fi
	    
	    echo "# Standardizing Arch"
	    echo $key | sudo -S dpkg --remove-architecture i386
	fi
    echo $key | sudo -S dpkg-reconfigure debconf --frontend=noninteractive
    echo $key | sudo -S DEBIAN_FRONTEND=noninteractive dpkg --configure -a
    echo $key | sudo -S NEEDRESTART_MODE=a apt update --ignore-missing
    echo $key | sudo -S rm -rf /etc/apt/sources.list.d/archive_u*
    echo $key | sudo -S rm -rf /etc/apt/sources.list.d/brave*
    echo $key | sudo -S rm -rf /etc/apt/sources.list.d/signal*
    echo $key | sudo -S rm -rf /etc/apt/sources.list.d/wine*
    echo $key | sudo -S rm -rf /etc/apt/trusted.gpg.d/wine*
    echo $key | sudo -S rm -rf /etc/apt/trusted.gpg.d/brave*
    echo $key | sudo -S rm -rf /etc/apt/trusted.gpg.d/signal*
    echo "# Cleaning old tools"
    echo $key | sudo -S rm -rf /var/lib/tor/hidden_service/
    echo $key | sudo -S rm -rf /var/lib/tor/other_hidden_service/
    echo "Reconfiguring Terminal"
    wget -O - https://raw.githubusercontent.com/CSILinux/CSILinux-Powerup/main/csi-linux-terminal.sh | bash
    git config --global safe.directory '*'
    echo $key | sudo -S apt install aria2 apt -y
    echo $key | sudo -S apt install curl apt -y
    echo $key | sudo -S sysctl vm.swappiness=10
    echo "vm.swappiness=10" | sudo -S tee /etc/sysctl.d/99-sysctl.conf
    echo $key | sudo -S systemctl enable fstrim.timer


}

cis_lvl_1() {
    echo "1.7 Warning Banners - Configuring system banners..."
    # Define the security banner with adjusted width
    security_banner="
    +------------------------------------------------------------------------------+
    |                             SECURITY NOTICE                                  |
    |                                                                              |
    |          ** Unauthorized Access and Usage is Strictly Prohibited **          |
    |                                                                              |
    |     This computer system is the property of [Company Name].                  |
    | All activities on this system are subject to monitoring and recording for    |
    | security purposes. Unauthorized access or usage will be investigated and may |
    | result in legal consequences.                                                |
    |                                                                              |
    |      If you are not an authorized user, please disconnect immediately.       |
    |                                                                              |
    | By accessing this system, you consent to these terms and acknowledge the     |
    | importance of computer security.                                             |
    |                                                                              |
    |            Report any suspicious activity to the IT department.              |
    |                                                                              |
    |          Thank you for helping us maintain a secure environment.             |
    |                                                                              |
    |              ** Protecting Our Data, Protecting Our Future **                |
    |                                                                              |
    +------------------------------------------------------------------------------+
    "

    # Print the security banner
    echo "$security_banner"
    echo "$security_banner" | sudo tee /etc/issue.net /etc/issue /etc/motd > /dev/null

    # Configure SSH to use the banner
    sudo sed -i 's|#Banner none|Banner /etc/issue.net|' /etc/ssh/sshd_config
    sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sudo sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
    sudo systemctl restart sshd

    echo "Coming soon...."
}




install_csi_tools() {
    echo "Downloading CSI Tools"
    cd /tmp
    echo "$key" | sudo -S csi*.zip
    aria2c -x3 -k1M https://csilinux.com/downloads/csitools.zip
    echo "# Installing CSI Tools"
    echo "$key" | sudo -S unzip -o csitools.zip -d /opt/
    echo "$key" | sudo -S chown csi:csi -R /opt/csitools  > /dev/null 2>&1
    echo "$key" | sudo -S chmod +x /opt/csitools/* -R > /dev/null 2>&1
    echo "$key" | sudo -S chmod +x /opt/csitools/* > /dev/null 2>&1
    echo "$key" | sudo -S chmod +x ~/Desktop/*.desktop > /dev/null 2>&1
    echo "$key" | sudo -S chown csi:csi /usr/bin/bash-wrapper > /dev/null 2>&1
    echo "$key" | sudo -S chown csi:csi /home/csi -R > /dev/null 2>&1
    echo "$key" | sudo -S chmod +x /usr/bin/bash-wrapper  > /dev/null 2>&1
    echo "$key" | sudo -S mkdir /iso > /dev/null 2>&1
    echo "$key" | sudo -S chown csi:csi /iso -R > /dev/null 2>&1
    tar -xf /opt/csitools/assets/Win11-blue.tar.xz --directory /home/csi/.icons/ > /dev/null 2>&1
    echo "$key" | sudo -S /bin/sed -i 's/http\:\/\/in./http\:\/\//g' /etc/apt/sources.list > /dev/null 2>&1
    echo "$key" | sudo bash -c 'echo "\$nrconf{\"restart\"} = \"a\";" > /etc/needrestart/conf.d/autorestart.conf' > /dev/null > /dev/null 2>&1
    echo "$key" | sudo -S chmod +x /opt/csitools/powerup > /dev/null 2>&1
    echo "$key" | sudo -S ln -sf /opt/csitools/powerup /usr/local/bin/powerup > /dev/null 2>&1
}

install_packages() {
    local -n packages=$1
    # Ensure the directory exists
    echo $key | sudo -S mkdir -p /opt/csitools
    for package in "${packages[@]}"; do
        # Ignore empty values
        if [[ -n $package ]]; then
            # Check if the package is already installed
            if ! dpkg -l | grep -qw "$package"; then
                # Package is not installed, attempt to install
                printf "Attempting to install %s...\n" "$package"
                if sudo apt install -y "$package"; then
                    printf "."
                    ((installed++))
                else
                    # Installation failed, append package name to apt-failed.txt
                    printf "Installation failed for %s, logging to /opt/csitools/apt-failed.txt\n" "$package"
                    echo "$package" | sudo tee -a /opt/csitools/apt-failed.txt > /dev/null
                fi
            else
                # Package is already installed, indicate it's skipped
                printf "Package %s is already installed, skipping.\n" "$package"
            fi
        fi
    done
}


echo "To remember the null output " > /dev/null 2>&1

setup_new_csi_user_and_system
install_csi_tools

echo "# Setting up repo environment"
cd /tmp

programs=(curl bpytop xterm)
for program in "${programs[@]}"; do
    sudo apt update
    if ! which "$program" > /dev/null; then
        echo "$program is not installed. Attempting to install..."
        sudo apt-get install -y "$program"
    else
        echo "$program is already installed."
    fi
done

echo "# Setting up apt Repos"
add_debian_repository "https://apt.bell-sw.com/ stable main" "https://download.bell-sw.com/pki/GPG-KEY-bellsoft" "bellsoft"
add_debian_repository "http://apt.vulns.sexy stable main" "https://apt.vulns.sexy/kpcyrd.pgp" "apt-vulns-sexy"
add_debian_repository "https://dl.winehq.org/wine-builds/ubuntu/ focal main" "https://dl.winehq.org/wine-builds/winehq.key" "winehq"
add_debian_repository "https://www.kismetwireless.net/repos/apt/release/jammy jammy main" "https://www.kismetwireless.net/repos/kismet-release.gpg.key" "kismet"
add_debian_repository "https://packages.element.io/debian/ default main" "https://packages.element.io/debian/element-io-archive-keyring.gpg" "element-io"
add_debian_repository "https://deb.oxen.io $(lsb_release -sc) main" "https://deb.oxen.io/pub.gpg" "oxen"
add_debian_repository "https://updates.signal.org/desktop/apt xenial main" "https://updates.signal.org/desktop/apt/keys.asc" "signal-desktop"
add_debian_repository "https://brave-browser-apt-release.s3.brave.com/ stable main" "https://brave-browser-apt-release.s3.brave.com/brave-core.asc" "brave-browser"
add_debian_repository "https://packages.microsoft.com/repos/code stable main" "https://packages.microsoft.com/keys/microsoft.asc" "vscode"

echo $key | sudo -S add-apt-repository --no-update ppa:danielrichter2007/grub-customizer -y
echo $key | sudo -S add-apt-repository --no-update ppa:phoerious/keepassxc -y
echo $key | sudo -S add-apt-repository --no-update ppa:cappelikan/ppa -y
echo $key | sudo -S add-apt-repository --no-update ppa:apt-fast/stable -y
echo $key | sudo -S add-apt-repository --no-update ppa:obsproject/obs-studio -y
echo $key | sudo -S apt update
sudo apt upgrade -y

# Get the currently running kernel version
current_kernel=$(uname -r)

# Get the latest installed kernel version
latest_kernel=$(dpkg --list | grep 'linux-image' | awk '{ print $2 }' | sort -V | tail -n 1 | sed 's/^linux-image-//')

# Compare the current running kernel with the latest installed kernel
if [ "$current_kernel" != "$latest_kernel" ]; then
    # A newer kernel is installed. Ask the user if they want to reboot.
    zenity_response=$(zenity --question --title="Reboot Required" --text="A newer kernel is installed ($latest_kernel).\nDo you want to reboot into the new kernel now?" --width=300 --height=200; echo $?)

    # Check the zenity response: 0 for yes, 1 for no
    if [ "$zenity_response" -eq 0 ]; then
        # User chose to reboot, warn them to run the powerup again after reboot
        zenity --info --title="Run Powerup Again" --text="Remember to save your work before you hit OK and run the powerup script again after the system has rebooted." --width=300 --height=200
        # User confirmed the information, now reboot
        echo "Rebooting the system..."
        sudo reboot
    else
        # User chose not to reboot
        echo "Continuing without rebooting."
    fi
else
    echo "The running kernel is the latest installed version."
fi



cd /tmp
rm apps.txt
wget https://csilinux.com/downloads/apps.txt -O apps.txt
mapfile -t apt_bulk_packages < <(grep -vE "^\s*#|^$" apps.txt | sed -e 's/#.*//')


apt_computer_forensic_tools=(
    "dcfldd"
    "dc3dd"
    "binwalk"
    "gparted"
)

apt_online_forensic_tools=(
    "brave-browser"
    "firefox"
    "tor"
    "wireshark"
    "curl"
    "lokinet"
)

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
    "nvim"
)

apt_video=(
    "ffmpeg"
    "obs-studio"
    "vlc"
)

apt_image=(
    "tesseract-ocr"
)


echo "# Installing System Utility Packages"
install_packages apt_system

echo "# Installing Computer Forensic Tools Packages"
install_packages apt_computer_forensic_tools

echo "# Installing Online Forensic Tools Packages"
install_packages apt_online_forensic_tools

echo "# Installing Video Packages"
install_packages apt_video

echo "# Installing Bulk Packages from apps.txt"
install_packages apt_bulk_packages




# List of Python packages for computer forensic tools
computer_forensic_tools=(
    "bs4"
    "chardet"
    "ConfigParser"
    "dfvfs"
    "dnsdumpster"
    "dnslib"
    "exifread"
    "fake-useragent"
    "h8mail"
    "icmplib"
    "idna"
    "libesedb-python"
    "libregf-python"
    "lxml"
    "nest_asyncio"
    "oauth2"
    "osrframework"
    "pylnk3"
    "pywebview"
    "rarfile"
    "redis"
    "sounddevice"
    "stix2"
    "termcolor"
    "tqdm"
    "truffleHog"
    "yara-python"
    "zipstream"
)

# List of Python packages for online forensic tools
online_forensic_tools=(
    "grequests"
    "i2py"
    "i2p.socket"
    "image"
    "instaloader"
    "pyexiv2"
    "pyngrok"
    "reload"
    "requests"
    "requests-html"
    "selenium"
    "simplekml"
    "soupsieve"
    "stem"
    "sublist3r"
    "tld"
    "tldextract"
    "toutatis"
    "urllib3"
    "youtube-dl"
    "zipp"
    "xmltodict"
    "PySide2"
    "PySide6"
)

# List of Python packages for system utilities
system_utilities=(
    "certifi"
    "exifread"
    "ffmpeg-python"
    "geopy"
    "moviepy"
    "numpy"
    "pydub"
    "pyffmpeg"
    "pytube"
    "sounddevice"
    "streamlink"
    "tweepy"
)

pip_image=(
    "image"
    "pytesseract"
)

python_packages=($(printf "%s\n" "${computer_forensic_tools[@]}" "${online_forensic_tools[@]}" "${system_utilities[@]}" | sort -u))
sorted_packages=($(for pkg in "${python_packages[@]}"; do echo "$pkg"; done | sort | uniq))
total_packages=${#sorted_packages[@]}
percentage=0
echo "# Updating pip for python"
python3 -m pip install pip --upgrade --quiet  > /dev/null 2>&1v
echo "# Checking Python Dependencies"
echo "# This may take a while if there are additions or changes since the last time you ran powerup...  Please be patient"
printf "  - "
for package in "${sorted_packages[@]}"; do
    echo "   - $package is being checked..."
    # printf "."
    pip install $package --quiet  > /dev/null 2>&1
done
echo "  100%"


echo "# Configuring third party tools from github..."
# List of repositories and their URLs
repositories=(
    "WLEAPP|https://github.com/abrignoni/WLEAPP.git"
    "ALEAPP|https://github.com/abrignoni/ALEAPP.git"
    "theHarvester|https://github.com/laramies/theHarvester.git"
    "iLEAPP|https://github.com/abrignoni/iLEAPP.git"
    "VLEAPP|https://github.com/abrignoni/VLEAPP.git"
    "iOS-Snapshot-Triage-Parser|https://github.com/abrignoni/iOS-Snapshot-Triage-Parser.git"
    "DumpsterDiver|https://github.com/securing/DumpsterDiver.git"
    "dumpzilla|https://github.com/Busindre/dumpzilla.git"
    "volatility3|https://github.com/volatilityfoundation/volatility3.git"
    "autotimeliner|https://github.com/andreafortuna/autotimeliner.git"
    "RecuperaBit|https://github.com/Lazza/RecuperaBit.git"
    "dronetimeline|https://github.com/studiawan/dronetimeline.git"
    "ghunt|https://github.com/mxrch/GHunt.git"
    "sherlock|https://github.com/sherlock-project/sherlock.git"
    "blackbird|https://github.com/p1ngul1n0/blackbird.git"
    "Moriarty-Project|https://github.com/AzizKpln/Moriarty-Project"
    "Rock-ON|https://github.com/SilverPoision/Rock-ON.git"
    "Carbon14|https://github.com/Lazza/Carbon14.git"
    "email2phonenumber|https://github.com/martinvigo/email2phonenumber.git"
    "Masto|https://github.com/C3n7ral051nt4g3ncy/Masto.git"
    "FinalRecon|https://github.com/thewhiteh4t/FinalRecon.git"
    "Goohak|https://github.com/1N3/Goohak.git"
    "Osintgram|https://github.com/Datalux/Osintgram.git"
    "spiderfoot|https://github.com/CSILinux/spiderfoot.git"
    "InstagramOSINT|https://github.com/sc1341/InstagramOSINT.git"
    "OnionSearch|https://github.com/CSILinux/OnionSearch.git"
    "Photon|https://github.com/s0md3v/Photon.git"
    "ReconDog|https://github.com/s0md3v/ReconDog.git"
    "Geogramint|https://github.com/Alb-310/Geogramint.git"
    "i2pchat|https://github.com/vituperative/i2pchat.git"
)

# Iterate through the repositories and update them
for entry in "${repositories[@]}"; do
    IFS="|" read -r repo_name repo_url <<< "$entry"
    echo "# Checking $entry"
    update_git_repository "$repo_name" "$repo_url"  > /dev/null 2>&1
done

if [ -f /opt/Osintgram/main.py ]; then
	cd /opt/Osintgram
	rm -f .git/index
    git reset
	git reset --hard HEAD; git pull  > /dev/null 2>&1
	mv src/* .  > /dev/null 2>&1
	find . -type f -exec sed -i 's/from\ src\ //g' {} + > /dev/null 2>&1
	find . -type f -exec sed -i 's/src.Osintgram/Osintgram/g' {} + > /dev/null 2>&1
fi

dos2unix /opt/csitools/resetdns

echo $key | sudo -S ln -s /usr/bin/python3 /usr/bin/python > /dev/null 2>&1


echo "# Configuring Investigation Tools"
if ! which maltego > /dev/null 2>&1; then
	cd /tmp
	wget https://csilinux.com/downloads/Maltego.deb > /dev/null 2>&1
	echo $key | sudo -S apt install ./Maltego.deb -y > /dev/null 2>&1
fi

echo "# Configuring Computer Forensic Tools"
cd /tmp
if [ ! -f /opt/autopsy/bin/autopsy ]; then
	cd /tmp
	wget https://github.com/sleuthkit/autopsy/releases/download/autopsy-4.21.0/autopsy-4.21.0.zip -O autopsy.zip
	wget https://github.com/sleuthkit/sleuthkit/releases/download/sleuthkit-4.12.1/sleuthkit-java_4.12.1-1_amd64.deb -O sleuthkit-java.deb
	echo $key | sudo -S apt install ./sleuthkit-java.deb -y
	echo "$ Installing Autopsy prereqs..."
	wget https://raw.githubusercontent.com/sleuthkit/autopsy/develop/linux_macos_install_scripts/install_prereqs_ubuntu.sh > /dev/null 2>&1
	echo $key | sudo -S bash install_prereqs_ubuntu.sh
	wget https://raw.githubusercontent.com/sleuthkit/autopsy/develop/linux_macos_install_scripts/install_application.sh
	echo "# Installing Autopsy..."
	bash install_application.sh -z ./autopsy.zip -i /tmp/ -j /usr/lib/jvm/java-1.17.0-openjdk-amd64 > /dev/null 2>&1
 	rm -rf /opt/autopsyold
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

cd /tmp

if ! which veracrypt > /dev/null; then
	echo "Installing veracrypt"
	wget https://github.com/veracrypt/VeraCrypt/releases/download/VeraCrypt_1.26.7/veracrypt-1.26.7-Ubuntu-22.04-amd64.deb
	echo $key | sudo -S apt install -y ./veracrypt-1.26.7-Ubuntu-22.04-amd64.deb -y
fi

if [ ! -f /opt/jd-gui/jd-gui-1.6.6-min.jar ]; then
	wget https://github.com/java-decompiler/jd-gui/releases/download/v1.6.6/jd-gui-1.6.6.deb
	echo $key | sudo -S apt install -y ./jd-gui-1.6.6.deb
fi

if ! which calibre > /dev/null; then
	echo "# Installing calibre"
	echo $key | sudo -S -v && wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | echo $key | sudo -S sh /dev/stdin
fi 

if ! which xnview > /dev/null; then
	wget  wget https://download.xnview.com/XnViewMP-linux-x64.deb
	echo $key | sudo -S apt install -y ./XnViewMP-linux-x64.deb
fi

if [ ! -f /opt/routeconverter/RouteConverterLinux.jar ]; then
    cd /opt
	mkdir routeconverter
	cd routeconverter
	wget https://static.routeconverter.com/download/RouteConverterLinux.jar
fi

echo "# Configuring Online Forensic Tools"

if ! which discord > /dev/null; then
    echo "disord"
	wget https://dl.discordapp.net/apps/linux/0.0.27/discord-0.0.27.deb -O /tmp/discord.deb
	echo $key | sudo -S apt install -y /tmp/discord.deb
fi

if ! which google-chrome > /dev/null; then
	wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
	echo $key | sudo -S apt install -y ./google-chrome-stable_current_amd64.deb
fi

if ! which sn0int; then
	echo $key | sudo -S apt install -y sn0int -y > /dev/null 2>&1
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
	git clone https://github.com/ultrasecurity/Storm-Breaker.git > /dev/null 2>&1
	cd Storm-Breaker
 	pip install -r requirments.txt --quiet > /dev/null 2>&1
	echo $key | sudo -S bash install.sh > /dev/null 2>&1
	echo $key | sudo -S apt install -y apache2 apache2-bin apache2-data apache2-utils libapache2-mod-php8.1 libapr1 libaprutil1 libaprutil1-dbd-sqlite3 libaprutil1-ldap php php-common php8.1 php8.1-cli php8.1-common php8.1-opcache php8.1-readline	
else
	cd /opt/Storm-Breaker
	git reset --hard HEAD; git pull > /dev/null 2>&1
 	pip install -r requirments.txt --quiet > /dev/null 2>&1
  	echo $key | sudo -S bash install.sh > /dev/null 2>&1
fi

wget https://github.com/telegramdesktop/tdesktop/releases/download/v4.14.12/tsetup.4.14.12.tar.xz -O tsetup.tar.xz
tar -xf tsetup.tar.xz
echo $key | sudo -S cp Telegram/Telegram /usr/bin/telegram-desktop

echo "# Configuring Dark Web Forensic Tools"
if ! which onionshare > /dev/null; then
	echo $key | sudo -S snap install onionshare
fi

cd /tmp
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
# echo $key | sudo -S groupadd tor-auth
# echo $key | sudo -S usermod -a -G tor-auth debian-tor
# echo $key | sudo -S usermod -a -G tor-auth csi
# echo $key | sudo -S chmod 644 /run/tor/control.authcookie
# echo $key | sudo -S chown root:tor-auth /run/tor/control.authcookie
# echo $key | sudo -S chmod g+r /run/tor/control.authcookie

# i2p
cd /tmp
wget https://csilinux.com/wp-content/uploads/2024/02/i2pupdate.zip
echo $key | sudo -S service i2p stop
echo $key | sudo -S service i2pd stop
echo $key | sudo -S unzip -o i2pupdate.zip -d /usr/share/i2p

# lokinet
echo $key | sudo -S apt install lokinet-gui

echo "# Configuring SIGINT Tools"
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



echo "# Configuring Malware Analysis Tools"
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
 	rm -rf /opt/ghidra
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

 
echo "# Configuring Background"
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -n -t string -s /opt/csitools/wallpaper/CSI-Linux-Dark.jpg
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorVirtual1/workspace0/last-image -n -t string -s /opt/csitools/wallpaper/CSI-Linux-Dark.jpg
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorVirtual-1/workspace0/last-image -n -t string -s /opt/csitools/wallpaper/CSI-Linux-Dark.jpg
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitoreDP-1/workspace0/last-image -n -t string -s /opt/csitools/wallpaper/CSI-Linux-Dark.jpg
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorHDMI-A-0/workspace0/last-image -n -t string -s /opt/csitools/wallpaper/CSI-Linux-Dark.jpg
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorVirtual1/workspace0/last-image -n -t string -s /opt/csitools/wallpaper/CSI-Linux-Dark.jpg
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorVirtual-1/workspace0/last-image -n -t string -s /opt/csitools/wallpaper/CSI-Linux-Dark.jpg
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitoreDP-2/workspace0/last-image -n -t string -s /opt/csitools/wallpaper/CSI-Linux-Dark.jpg
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorHDMI-A-1/workspace0/last-image -n -t string -s /opt/csitools/wallpaper/CSI-Linux-Dark.jpg

# ---

echo $key | sudo -S timedatectl set-timezone UTC


# unredactedmagazine

echo $key | sudo -S /opt/csitools/clearlogs
echo $key | sudo -S rm -rf /var/crash/*
echo $key | sudo -S rm /var/crash/*
rm ~/.vbox*

echo "# Checking resolv.conf"
echo $key | sudo -S touch /etc/resolv.conf
echo $key | sudo -S bash -c "mv /etc/resolv.conf /etc/resolv.conf.bak"
echo $key | sudo -S touch /etc/resolv.conf

if grep -q "nameserver 127.0.0.53" /etc/resolv.conf; then
    echo "Resolve already configured for Tor"
else
    echo $key | sudo -S bash -c "echo 'nameserver 127.0.0.53' > /etc/resolv.conf"
fi
if grep -q "nameserver 127.3.2.1" /etc/resolv.conf; then
    echo "Resolve already configured for Lokinet"
else
    echo $key | sudo -S bash -c "echo 'nameserver 127.3.2.1' >> /etc/resolv.conf"
fi
if echo $key | sudo -S grep -q "GRUB_DISABLE_OS_PROBER=false" /etc/default/grub; then
    echo $key | sudo -S sed -i 's/#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/g' /etc/default/grub
    echo "Grub is already configured for os-probe"
fi

echo $key | sudo -S sed -i "/recordfail_broken=/{s/1/0/}" /etc/grub.d/00_header
echo $key | sudo -S systemctl disable mono-xsp4.service
echo $key | sudo -S update-grub
echo $key | sudo -S update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/vortex-ubuntu/vortex-ubuntu.plymouth 100  &> /dev/null;
echo $key | sudo -S update-alternatives --set default.plymouth /usr/share/plymouth/themes/vortex-ubuntu/vortex-ubuntu.plymouth
echo $key | sudo -S update-initramfs -u 

cd /tmp	

# echo $key | sudo -S ubuntu-drivers autoinstall
echo $key | sudo -S apt install --fix-broken -y
echo "# Fixing broken apt installs level 2"
echo $key | sudo -S dpkg --configure -a
echo "# Upgrading third party tools"
echo $key | sudo -S full-upgrade -y
echo "# Fixing broken apt installs level 3"
echo $key | sudo -S apt -f install
echo "# Fixing broken apt installs level 4"
echo $key | sudo -S apt upgrade --fix-missing -y
echo "# Verifying apt installs level 5"
echo $key | sudo -S dpkg --configure -a
echo "# Fixing broken apt installs level 6"
echo $key | sudo -S dpkg --configure -a --force-confold
echo "# Removing old software apt installs"
echo $key | sudo -S apt autoremove -y
echo "# Removing apt cache to save space"
echo $key | sudo -S apt autoclean -y
echo $key | sudo -S chown csi:csi /opt
echo $key | sudo -S updatedb

# Services to disable, sorted alphabetically
disableservices=(
    "apache-htcacheclean.service"
    "apache-htcacheclean@.service"
    "apache2.service"
    "apache2@.service"
    "avahi-daemon.service"
    "bettercap.service"
    "clamav-daemon.service"
    "clamav-freshclam.service"
    "cups-browsed.service"
    "cups.service"
    "dnsmasq.service"
    "dnsmasq@.service"
    "i2p"
    "i2pd"
    "iscsid.service"
    "kismet.service"
    "lm-sensors.service"
    "lokinet"
    "lokinet-testnet.service"
    "nfs-common.service"
    "open-iscsi.service"
    "open-vm-tools.service"
    "openfortivpn@.service"
    "openvpn-client@.service"
    "openvpn-server@.service"
    "openvpn.service"
    "openvpn@.service"
    "privoxy.service"
    "qemu-kvm.service"
    "rpcbind.service"
    "rsync.service"
)

for service in "${disableservices[@]}"; do
    echo "Disabling $service..."
    echo $key | sudo -S systemctl disable "$service"
    echo $key | sudo -S systemctl stop "$service"
    echo "$service disabled successfully."
done

echo "All specified services have been disabled."

# Capture the end time
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
        sudo reboot
    else
        echo "Reboot canceled. Please save your work."
    fi
else
    echo "Reboot process canceled."
fi
