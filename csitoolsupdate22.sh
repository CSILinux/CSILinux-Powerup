#!/bin/bash
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
cd /tmp
if [ -z "$1" ]; then
    key=$(zenity --password --title "Power up your system with an upgrade." --text "Enter your CSI password." --width 400)
    # You can use the 'key' variable for further processing
else
    key=$1
fi

add_debian_repository() {
    local repo_url="$1"
    local gpg_key_url="$2"
    local repo_name="$3"

    # Check if the repository already exists
    echo "# Checking repo for $repo_name"
    if ! grep -q "$repo_url" "/etc/apt/sources.list.d/$repo_name.list"; then
        # Download and install the GPG key if not trusted
        if ! gpg --list-keys | grep -q "$repo_name"; then
            if curl -fsSL "$gpg_key_url" | sudo -S gpg --dearmor | sudo -S tee "/etc/apt/trusted.gpg.d/$repo_name.gpg"; then
                echo "# GPG key for '$repo_name' added successfully."
            else
                echo "   - Error adding GPG key for '$repo_name'."
                return 1
            fi
        fi
        # Add the repository with the GPG key reference
        echo "$key" | sudo -S bash -c "echo 'deb [signed-by=/etc/apt/trusted.gpg.d/$repo_name.gpg] $repo_url' | sudo -S tee '/etc/apt/sources.list.d/$repo_name.list'"
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
        echo "$key" | sudo -S git reset --hard HEAD > /dev/null 2>&1
        echo "$key" | sudo -S git pull > /dev/null 2>&1

        if [ -f "$repo_dir/requirements.txt" ]; then
            python3 -m venv "${repo_dir}/${repo_name}-venv" > /dev/null 2>&1
            source "${repo_dir}/${repo_name}-venv/bin/activate" > /dev/null 2>&1
            pip3 install -r requirements.txt > /dev/null 2>&1
            deactivate
        else
            echo "No requirements.txt found in $repo_dir"
        fi
    else
        echo "   - Directory $repo_dir is not a valid Git repository."
    fi
}


echo $key | sudo -S swapoff -a || exit 1

conf=/etc/fstab

if grep '^/swapfile' /etc/fstab &> /dev/null ;then
    echo $key | sudo -S sed -i '/\/swapfile/s/^/#/' ${conf} || exit 1
    echo "Updated '${conf}'"
fi

if [ -f /swapfile ] ; then
    echo $key | sudo -S rm -vf /swapfile || exit 1
    
fi

echo "Installing CSI Linux Tools and Menu update"
rm csi* > /dev/null 2>&1
echo "Downloading CSI Tools"
wget https://csilinux.com/download/csitools22.zip -O csitools22.zip
echo "# Installing CSI Tools"
echo $key | sudo -S unzip -o -d / csitools22.zip > /dev/null 2>&1
echo $key | sudo -S chown csi:csi -R /opt/csitools  > /dev/null 2>&1
echo $key | sudo -S chmod +x /opt/csitools/* -R > /dev/null 2>&1
echo $key | sudo -S chmod +x /opt/csitools/* > /dev/null 2>&1
echo $key | sudo -S chmod +x ~/Desktop/*.desktop > /dev/null 2>&1
echo $key | sudo -S chown csi:csi /usr/bin/bash-wrapper > /dev/null 2>&1
echo $key | sudo -S chown csi:csi /home/csi -R > /dev/null 2>&1
echo $key | sudo -S chmod +x /usr/bin/bash-wrapper  > /dev/null 2>&1
echo $key | sudo -S chmod +x /opt/csitools/powerup > /dev/null 2>&1
echo $key | sudo -S ln -sf /opt/csitools/powerup /usr/local/bin/powerup > /dev/null 2>&1
echo $key | sudo -S mkdir /iso > /dev/null 2>&1
echo $key | sudo -S chown csi:csi /iso -R > /dev/null 2>&1
echo $key | sudo -S chmod +x /etc/grub.d/39_iso > /dev/null 2>&1

echo "# Setting up users"
USERNAME=csi
useradd -m $USERNAME -G sudo -s /bin/bash  > /dev/null 2>&1
echo -e "$USERNAME\N$USERNAME\n" | passwd $USERNAME > /dev/null 2>&1
echo $key | sudo -S adduser $USERNAME vboxsf > /dev/null 2>&1
echo $key | sudo -S adduser $USERNAME libvirt > /dev/null 2>&1
echo $key | sudo -S adduser $USERNAME kvm > /dev/null 2>&1

echo "# System setup starting..."
###  System setup
echo $key | sudo -S echo "\$nrconf{restart} = 'a'" | sudo -S tee /etc/needrestart/conf.d/autorestart.conf > /dev/null 2>&1
export DEBIAN_FRONTEND=noninteractive > /dev/null 2>&1
export APT_LISTCHANGES_FRONTEND=none > /dev/null 2>&1
echo "# Cleaning up old Arch"
echo $key | sudo -S apt-get remove --purge --allow-remove-essential -y `dpkg --get-selections | awk '/i386/{print $1}'` > /dev/null 2>&1
echo "# Standardizing Arch"
echo $key | sudo -S dpkg --remove-architecture i386 > /dev/null 2>&1

echo "# Setting up repo environment"
cd /tmp
echo $key | sudo -S dpkg-reconfigure debconf --frontend=noninteractive > /dev/null 2>&1
echo $key | sudo -S DEBIAN_FRONTEND=noninteractive dpkg --configure -a > /dev/null 2>&1
echo $key | sudo -S NEEDRESTART_MODE=a apt update --ignore-missing > /dev/null 2>&1
echo $key | sudo -S rm -rf /etc/apt/sources.list.d/archive_u* > /dev/null 2>&1


if ! which curl > /dev/null; then
	echo "# Installing Curl"
	echo $key | sudo -S apt update > /dev/null 2>&1
	echo $key | sudo -S apt install curl -y > /dev/null 2>&1
fi

echo "# Setting up APT Repos"
add_debian_repository "https://apt.bell-sw.com/ stable main" "https://download.bell-sw.com/pki/GPG-KEY-bellsoft" "bellsoft"
add_debian_repository "http://apt.vulns.sexy stable main" "https://apt.vulns.sexy/kpcyrd.pgp" "apt-vulns-sexy"
add_debian_repository "https://dl.winehq.org/wine-builds/ubuntu/ focal main" "https://dl.winehq.org/wine-builds/winehq.key" "winehq"
add_debian_repository "https://www.kismetwireless.net/repos/apt/release/jammy jammy main" "https://www.kismetwireless.net/repos/kismet-release.gpg.key" "kismet"
add_debian_repository "https://packages.element.io/debian/ default main" "https://packages.element.io/debian/element-io-archive-keyring.gpg" "element-io"
add_debian_repository "https://deb.oxen.io $(lsb_release -sc) main" "https://deb.oxen.io/pub.gpg" "oxen"
add_debian_repository "https://updates.signal.org/desktop/apt xenial main" "https://updates.signal.org/desktop/apt/keys.asc" "signal-desktop"
add_debian_repository "https://brave-browser-apt-release.s3.brave.com/ stable main" "https://brave-browser-apt-release.s3.brave.com/brave-core.asc" "brave-browser"
add_debian_repository "https://packages.microsoft.com/repos/code stable main" "https://packages.microsoft.com/keys/microsoft.asc" "vscode"

echo $key | sudo -S apt-add-repository ppa:i2p-maintainers/i2p -y > /dev/null 2>&1
echo $key | sudo -S add-apt-repository ppa:danielrichter2007/grub-customizer > /dev/null 2>&1
echo $key | sudo -S add-apt-repository ppa:phoerious/keepassxc > /dev/null 2>&1
echo $key | sudo -S add-apt-repository -y ppa:beineri/opt-qt-5.14.2-focal

echo "# Cleaning old tools"
echo $key | sudo -S apt install apt-transport-https -y > /dev/null 2>&1
echo $key | sudo -S apt install code -y > /dev/null 2>&1
echo $key | sudo -S rm -rf /var/lib/tor/hidden_service/ > /dev/null 2>&1
echo $key | sudo -S rm -rf /var/lib/tor/other_hidden_service/ > /dev/null 2>&1
echo "Reconfiguring Swap"; echo $key | sudo -S wget -O -
echo "Reconfiguring Terminal"; wget -O - https://raw.githubusercontent.com/CSILinux/CSILinux-Powerup/main/csi-linux-terminal.sh | bash > /dev/null 2>&1

git config --global safe.directory '*'
# List of Python packages to install
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
    "robotframework"
    "s3fs"
    "sounddevice"
    "stix2"
    "stumpy"
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
    "pytorch"
    "pytube"
    "sounddevice"
    "streamlink"
    "tweepy"
)

# Combine and sort the lists
python_packages=($(printf "%s\n" "${computer_forensic_tools[@]}" "${online_forensic_tools[@]}" "${system_utilities[@]}" | sort -u))

# Sort the list alphabetically
sorted_packages=($(for pkg in "${python_packages[@]}"; do echo "$pkg"; done | sort))

total_packages=${#sorted_packages[@]}
percentage=0

echo "# Updating pip"
python3 -m pip install pip --upgrade  > /dev/null 2>&1
((percentage++))

echo "# Checking Python Dependencies"

for package in "${sorted_packages[@]}"; do
    echo "  - Checking $package: $((percentage * 100 / total_packages))% complete..."
    pip install $package --quiet  > /dev/null 2>&1
    ((percentage++))
done

echo "  100%"

echo "# Configuring third party tools 1"
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
    update_git_repository "$repo_name" "$repo_url"
done


if [ -f /opt/Osintgram/main.py ]; then
	cd /opt/Osintgram
	git reset --hard HEAD > /dev/null 2>&1; git pull > /dev/null 2>&1
	mv src/* . > /dev/null 2>&1
	find . -type f -exec sed -i 's/from\ src\ //g' {} +
	find . -type f -exec sed -i 's/src.Osintgram/Osintgram/g' {} +
fi


echo "# Configuring tools 1"
echo $key | sudo -S apt install -y zram-config > /dev/null 2>&1
echo $key | sudo -S apt install -y xfce4-cpugraph-plugin -y > /dev/null 2>&1
echo $key | sudo -S apt install -y xfce4-goodies > /dev/null 2>&1
echo $key | sudo -S apt install -y libmagic-dev python3-magic python3-pyregfi > /dev/null 2>&1
echo $key | sudo -S apt install -y python3-pip > /dev/null 2>&1
echo $key | sudo -S apt install -y python3-pyqt5.qtsql > /dev/null 2>&1
echo $key | sudo -S apt install -y libc6 libstdc++6 ca-certificates tar > /dev/null 2>&1
echo $key | sudo -S apt install -y bash-completion > /dev/null 2>&1
echo $key | sudo -S apt install -y tre-command > /dev/null 2>&1
echo $key | sudo -S apt install -y tre-agrep > /dev/null 2>&1


dos2unix /opt/csitools/resetdns > /dev/null 2>&1
echo "# Configuring tools 2"
rm apps.txt > /dev/null 2>&1
wget https://csilinux.com/downloads/apps.txt > /dev/null 2>&1
echo $key | sudo -S apt install -y $(grep -vE "^\s*#" apps.txt | sed -e 's/#.*//'  | tr "\n" " ") > /dev/null 2>&1
echo $key | sudo -S ln -s /usr/bin/python3 /usr/bin/python > /dev/null 2>&1


echo "# Configuring Investigation Tools"
if ! which maltego > /dev/null 2>&1; then
	cd /tmp
	wget https://csilinux.com/downloads/Maltego.deb
	echo $key | sudo -S apt install ./Maltego.deb -y
fi

echo "# Configuring Computer Forensic Tools"
cd /tmp
if [ ! -f /opt/autopsy/bin/autopsy ]; then
	cd /tmp
	wget https://github.com/sleuthkit/autopsy/releases/download/autopsy-4.21.0/autopsy-4.21.0.zip -O autopsy.zip
	wget https://github.com/sleuthkit/sleuthkit/releases/download/sleuthkit-4.12.1/sleuthkit-java_4.12.1-1_amd64.deb -O sleuthkit-java.deb
	echo $key | sudo -S apt install ./sleuthkit-java.deb -y > /dev/null 2>&1
	wget https://raw.githubusercontent.com/sleuthkit/autopsy/develop/linux_macos_install_scripts/install_prereqs_ubuntu.sh
	echo $key | sudo -S bash install_prereqs_ubuntu.sh
	wget https://raw.githubusercontent.com/sleuthkit/autopsy/develop/linux_macos_install_scripts/install_application.sh
	bash install_application.sh -z ./autopsy.zip -i /tmp/ -j /usr/lib/jvm/java-1.17.0-openjdk-amd64
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
	echo $key | sudo -S -v && wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sudo sh /dev/stdin
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

if ! which sn0int > /dev/null 2>&1; then
	echo $key | sudo -S apt install -y sn0int > /dev/null 2>&1
fi
if [ ! -f /opt/PhoneInfoga/phoneinfoga ]; then
	cd /opt
	mkdir PhoneInfoga
	cd PhoneInfoga
	wget https://raw.githubusercontent.com/sundowndev/phoneinfoga/master/support/scripts/install -O - | sh 
	echo $key | sudo -S chmod +x ./phoneinfoga > /dev/null 2>&1
	echo $key | sudo -S ln -sf ./phoneinfoga /usr/local/bin/phoneinfoga > /dev/null 2>&1
fi
if [ ! -f /opt/Storm-Breaker/install.sh ]; then
	cd /opt
	git clone https://github.com/ultrasecurity/Storm-Breaker.git > /dev/null 2>&1
	cd Storm-Breaker
 	pip install -r requirments.txt --quiet > /dev/null 2>&1
	echo $key | sudo -S bash install.sh > /dev/null 2>&1
	echo $key | sudo -S apt install -y apache2 apache2-bin apache2-data apache2-utils libapache2-mod-php8.1 libapr1 libaprutil1 libaprutil1-dbd-sqlite3 libaprutil1-ldap php php-common php8.1 php8.1-cli php8.1-common php8.1-opcache php8.1-readline > /dev/null 2>&1	
else
	cd /opt/Storm-Breaker
	git reset --hard HEAD > /dev/null 2>&1; git pull > /dev/null 2>&1
 	pip install -r requirments.txt --quiet > /dev/null 2>&1
  	echo $key | sudo -S bash install.sh > /dev/null 2>&1
fi




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
	wget https://github.com/oxen-io/oxen-electron-gui-wallet/releases/download/v1.8.1/oxen-electron-wallet-1.8.1-linux.AppImage .
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




echo "# Configuring SIGINT Tools"
cd /tmp
if ! which wifipumpkin3 > /dev/null; then
	wget  https://github.com/P0cL4bs/wifipumpkin3/releases/download/v1.1.4/wifipumpkin3_1.1.4_all.deb
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
	wget https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_11.0_build/ghidra_11.0_PUBLIC_20231222.zip
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

if [ ! -f /opt/apk-editor-studio/apk-editor-studio.AppImage ]; then
	cd /opt
	mkdir apk-editor-studio
	cd apk-editor-studio
	wget https://github.com/kefir500/apk-editor-studio/releases/download/v1.7.1/apk-editor-studio_linux_1.7.1.AppImage -O apk-editor-studio.AppImage
	echo $key | sudo -S chmod +x apk-editor-studio.AppImage
fi



echo "# Configuring Network Forensic Tools"
if [ ! -f /opt/NetworkMiner/NetworkMiner.exe ]; then
	cd /tmp
	wget https://www.netresec.com/?download=NetworkMiner -O networkminer.zip
    unzip networkminer.zip
	rm -rf /opt/NetworkMiner
	mv NetworkMiner* /opt/NetworkMiner
else
	cd /opt/exploitdb
	git reset --hard HEAD > /dev/null 2>&1; git pull > /dev/null 2>&1
fi



echo "# Configuring Security Tools"
if [ ! -f /opt/exploitdb/searchsploit ]; then
	cd /opt
	git clone https://gitlab.com/exploit-database/exploitdb.git
else
	cd /opt/exploitdb
	git reset --hard HEAD > /dev/null 2>&1; git pull > /dev/null 2>&1
fi


# extras
if [ ! -f /opt/qr-code-generator-desktop/qr-code-generator-desktop.AppImage ]; then
	cd /opt
	mkdir qr-code-generator-desktop
	cd qr-code-generator-desktop
	wget https://csilinux.com/downloads/qr-code-generator-desktop.AppImage
	echo $key | sudo -S chmod +x qr-code-generator-desktop.AppImage
fi

if ! which keepassxc > /dev/null 2>&1; then
	echo $key | sudo -S apt install keepassxc -y
fi

echo $key | sudo -S cp /opt/csitools/youtube.lua /usr/lib/x86_64-linux-gnu/vlc/lua/playlist/youtube.luac -rf


echo "# Configuring Background"
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -n -t string -s /opt/csitools/wallpaper/CSI-Linux-Dark.jpg > /dev/null 2>&1
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorVirtual1/workspace0/last-image -n -t string -s /opt/csitools/wallpaper/CSI-Linux-Dark.jpg > /dev/null 2>&1
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorVirtual-1/workspace0/last-image -n -t string -s /opt/csitools/wallpaper/CSI-Linux-Dark.jpg > /dev/null 2>&1
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitoreDP-1/workspace0/last-image -n -t string -s /opt/csitools/wallpaper/CSI-Linux-Dark.jpg > /dev/null 2>&1
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorHDMI-A-0/workspace0/last-image -n -t string -s /opt/csitools/wallpaper/CSI-Linux-Dark.jpg > /dev/null 2>&1
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorVirtual1/workspace0/last-image -n -t string -s /opt/csitools/wallpaper/CSI-Linux-Dark.jpg > /dev/null 2>&1
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorVirtual-1/workspace0/last-image -n -t string -s /opt/csitools/wallpaper/CSI-Linux-Dark.jpg > /dev/null 2>&1
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitoreDP-2/workspace0/last-image -n -t string -s /opt/csitools/wallpaper/CSI-Linux-Dark.jpg > /dev/null 2>&1
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorHDMI-A-1/workspace0/last-image -n -t string -s /opt/csitools/wallpaper/CSI-Linux-Dark.jpg > /dev/null 2>&1

# ---

echo $key | sudo -S timedatectl set-timezone UTC


# unredactedmagazine


echo $key | sudo -S /opt/csitools/clearlogs > /dev/null 2>&1
echo $key | sudo -S rm -rf /var/crash/* > /dev/null 2>&1
echo $key | sudo -S rm /var/crash/* > /dev/null 2>&1
rm ~/.vbox* > /dev/null 2>&1

echo "# Checking resolv.conf"
echo $key | sudo -S touch /etc/resolv.conf
echo $key | sudo -S bash -c "mv /etc/resolv.conf /etc/resolv.conf.bak" > /dev/null 2>&1
echo $key | sudo -S touch /etc/resolv.conf

if grep -q "nameserver 127.0.0.53" /etc/resolv.conf > /dev/null 2>&1; then
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
echo $key | sudo -S systemctl disable mono-xsp4.service > /dev/null 2>&1
echo $key | sudo -S update-grub > /dev/null 2>&1
echo $key | sudo -S update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/vortex-ubuntu/vortex-ubuntu.plymouth 100  &> /dev/null;
echo $key | sudo -S update-alternatives --set default.plymouth /usr/share/plymouth/themes/vortex-ubuntu/vortex-ubuntu.plymouth > /dev/null 2>&1
echo $key | sudo -S update-initramfs -u  > /dev/null 2>&1

cd /tmp	

# echo $key | sudo -S ubuntu-drivers autoinstall
echo $key | sudo -S apt install --fix-broken -y > /dev/null 2>&1
echo "# Fixing broken APT installs level 2"
echo $key | sudo -S dpkg --configure -a > /dev/null 2>&1
echo "# Upgrading third party tools"
echo $key | sudo -S full-upgrade -y > /dev/null 2>&1
echo "# Fixing broken APT installs level 3"
echo $key | sudo -S apt -f install > /dev/null 2>&1
echo "# Fixing broken APT installs level 4"
echo $key | sudo -S apt upgrade --fix-missing -y > /dev/null 2>&1
echo "# Verifying APT installs level 5"
echo $key | sudo -S dpkg --configure -a > /dev/null 2>&1
echo "# Fixing broken APT installs level 6"
echo $key | sudo -S dpkg --configure -a --force-confold > /dev/null 2>&1
echo "# Removing old software APT installs"
echo $key | sudo -S apt autoremove -y > /dev/null 2>&1
echo "# Removing APT cache to save space"
echo $key | sudo -S apt autoclean -y > /dev/null 2>&1
echo $key | sudo -S chown csi:csi /opt
echo $key | sudo -S updatedb
# Capture the end time
update_current_time
calculate_duration
echo "End time: $current_time"
echo "Total duration: $duration seconds"
echo "Please reboot when finished updating"
