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
echo "Start time: $start_time"
cd /tmp
if [ -z "$1" ]; then
    key=$(zenity --password --title "Power up your system with an upgrade." --text "Enter your CSI password." --width 400)
    # You can use the 'key' variable for further processing
else
    key=$1
fi

echo "# Setting up users"
USERNAME=csi
useradd -m $USERNAME -G sudo -s /bin/bash && echo -e "$USERNAME\N$USERNAME\n" | passwd $USERNAME > /dev/null 2>&1
echo $key | sudo -S adduser $USERNAME vboxsf > /dev/null 2>&1
echo $key | sudo -S adduser $USERNAME libvirt > /dev/null 2>&1
echo $key | sudo -S adduser $USERNAME kvm > /dev/null 2>&1

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
echo "System setup starting..."
###  System setup
echo $key | sudo -S echo "\$nrconf{restart} = 'a'" | sudo -S tee /etc/needrestart/conf.d/autorestart.conf > /dev/null 2>&1
export DEBIAN_FRONTEND=noninteractive > /dev/null 2>&1
export APT_LISTCHANGES_FRONTEND=none > /dev/null 2>&1
echo "# Building CSI XFCE Theme"
tar -xf /opt/csitools/assets/Win11-blue.tar.xz --directory /home/csi/.icons/ > /dev/null 2>&1
echo $key | sudo -S apt-get remove --purge --allow-remove-essential -y `dpkg --get-selections | awk '/i386/{print $1}'` > /dev/null 2>&1
echo $key | sudo -S dpkg --remove-architecture i386 > /dev/null 2>&1
echo $key | sudo -S rm -rfv /usr/local/bin/kismet* /usr/local/share/kismet* /usr/local/etc/kismet* > /dev/null 2>&1

echo "# Setting up APT Repos"
cd /tmp
echo $key | sudo -S dpkg-reconfigure debconf --frontend=noninteractive > /dev/null 2>&1
echo $key | sudo -S DEBIAN_FRONTEND=noninteractive dpkg --configure -a > /dev/null 2>&1
echo $key | sudo -S NEEDRESTART_MODE=a apt update --ignore-missing > /dev/null 2>&1
echo $key | sudo -S rm -rf /etc/apt/sources.list.d/archive_u* > /dev/null 2>&1
echo $key | sudo -S apt update > /dev/null 2>&1
echo $key | sudo -S apt install curl -y > /dev/null 2>&1

# Function to add a Debian repository securely
add_debian_repository_if_not_exists() {
    local repo_url="$1"
    local gpg_key_url="$2"
    local repo_name="$3"

    # Check if the repository already exists
    if ! grep -q "$repo_url" "/etc/apt/sources.list.d/$repo_name.list"; then
        # Download and install the GPG key if not trusted
        if ! gpg --list-keys | grep -q "$repo_name"; then
            if curl -fsSL "$gpg_key_url" | sudo -S gpg --dearmor | sudo -S tee "/etc/apt/trusted.gpg.d/$repo_name.gpg" > /dev/null; then
                echo "GPG key for '$repo_name' added successfully."
            else
                echo "Error adding GPG key for '$repo_name'."
                return 1
            fi
        fi

        # Add the repository with the GPG key reference
        echo "$key" | sudo -S bash -c "echo 'deb [signed-by=/etc/apt/trusted.gpg.d/$repo_name.gpg] $repo_url' | sudo -S tee '/etc/apt/sources.list.d/$repo_name.list'" > /dev/null
    fi

    # Update APT
    echo "$key" | sudo -S apt update > /dev/null 2>&1
}

# Example usage:
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

echo "# Cleaning old tools"
echo $key | sudo -S apt remove proxychains4 -y > /dev/null 2>&1
echo $key | sudo -S apt remove proxychains -y > /dev/null 2>&1
echo $key | sudo -S apt install apt-transport-https -y > /dev/null 2>&1
echo $key | sudo -S apt install code -y > /dev/null 2>&1
echo $key | sudo -S rm -rf /var/lib/tor/hidden_service/ > /dev/null 2>&1
echo $key | sudo -S rm -rf /var/lib/tor/other_hidden_service/ > /dev/null 2>&1
echo "Reconfiguring Swap"; echo $key | sudo -S wget -O - https://teejeetech.com/scripts/jammy/disable_swapfile | bash > /dev/null 2>&1
echo "Reconfiguring Terminal"; wget -O - https://raw.githubusercontent.com/CSILinux/CSILinux-Powerup/main/csi-linux-terminal.sh | bash > /dev/null 2>&1
echo "# Configuring tools 1"
echo $key | sudo -S apt install -y zram-config > /dev/null 2>&1
echo $key | sudo -S apt install xfce4-cpugraph-plugin -y > /dev/null 2>&1
echo $key | sudo -S apt install xfce4-goodies -y > /dev/null 2>&1
echo $key | sudo -S apt install -y libmagic-dev python3-magic python3-pyregfi > /dev/null 2>&1
echo $key | sudo -S apt install python3-pip -y > /dev/null 2>&1
echo $key | sudo -S apt install python3-pyqt5.qtsql -y > /dev/null 2>&1
echo $key | sudo -S apt install python3-pyqt5.qtsql -y > /dev/null 2>&1
echo $key | sudo -S apt install libc6 libstdc++6 ca-certificates tar -y > /dev/null 2>&1
echo $key | sudo -S apt install bash-completion -y > /dev/null 2>&1
dos2unix /opt/csitools/resetdns > /dev/null 2>&1
echo "# Configuring tools 2"
rm apps.txt > /dev/null 2>&1
wget https://csilinux.com/downloads/apps.txt > /dev/null 2>&1
echo $key | sudo -S apt install -y $(grep -vE "^\s*#" apps.txt | sed -e 's/#.*//'  | tr "\n" " ") > /dev/null 2>&1
echo $key | sudo -S ln -s /usr/bin/python3 /usr/bin/python > /dev/null 2>&1

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
cd /tmp > /dev/null 2>&1
rm  hunchly.deb > /dev/null 2>&1
echo "Checking Hunchly.  If updating, you may need to reinstall the browser extension"
wget -O hunchly.deb https://downloadmirror.hunch.ly/currentversion/hunchly.deb?csilinux_update
echo "# Configuring Hunchly"
echo $key | sudo -S apt-get install ./hunchly.deb -y > /dev/null 2>&1
echo "# Configuring tools 3"
echo $key | sudo -S apt install maltego -y > /dev/null 2>&1
echo $key | sudo -S apt install python3-shodan -y > /dev/null 2>&1
echo $key | sudo -S apt install webhttrack -y > /dev/null 2>&1
echo $key | sudo -S apt install outguess -y > /dev/null 2>&1
echo $key | sudo -S apt install stegosuite -y > /dev/null 2>&1
echo $key | sudo -S apt install wireshark -y > /dev/null 2>&1
echo $key | sudo -S apt install exifprobe -y > /dev/null 2>&1
echo $key | sudo -S apt install ruby-bundler -y > /dev/null 2>&1
echo $key | sudo -S apt install recon-ng -y > /dev/null 2>&1
echo $key | sudo -S apt install cherrytree -y > /dev/null 2>&1
echo "# Configuring tools 4"
echo $key | sudo -S apt install drawing -y > /dev/null 2>&1
echo $key | sudo -S apt install cargo -y > /dev/null 2>&1
echo $key | sudo -S apt install pkg-config -y > /dev/null 2>&1
echo $key | sudo -S apt install npm -y > /dev/null 2>&1
echo $key | sudo -S apt install curl -y > /dev/null 2>&1
echo $key | sudo -S apt install pipx -y > /dev/null 2>&1
echo $key | sudo -S apt install python3-tweepy -y > /dev/null 2>&1
echo $key | sudo -S apt install python3-exifread -y > /dev/null 2>&1
echo $key | sudo -S apt install yt-dlp -y > /dev/null 2>&1

echo "# Checking Python Dependencies"
pip install pyside6 --quiet > /dev/null 2>&1
pip install grequests --quiet > /dev/null 2>&1
pip install sublist3r --quiet > /dev/null 2>&1
echo "  5%"
pip install pyngrok --quiet > /dev/null 2>&1
pip install phonefy --quiet > /dev/null 2>&1
pip install fake-useragent --quiet > /dev/null 2>&1
echo "  10%"
pip install instaloader --quiet > /dev/null 2>&1
pip install osrframework --quiet > /dev/null 2>&1
pip install osrframework --upgrade --quiet > /dev/null 2>&1
echo "  15%"
pip install dnslib --quiet > /dev/null 2>&1
pip install icmplib --quiet > /dev/null 2>&1
echo "  20%"
pip install passwordmeter --quiet > /dev/null 2>&1
pip install image --quiet > /dev/null 2>&1
pip install ConfigParser --quiet > /dev/null 2>&1
echo "  25%"
pip install youtube-dl --quiet > /dev/null 2>&1
pip install dnsdumpster --quiet > /dev/null 2>&1
pip install h8mail --quiet > /dev/null 2>&1
pip install toutatis --quiet > /dev/null 2>&1
echo "  30%"
pip install pyexiv2 --quiet > /dev/null 2>&1
echo "  35%"
pip install oauth2 --quiet > /dev/null 2>&1
echo "  40%"
pip install reload --quiet > /dev/null 2>&1
echo "  45%"
pip install telepathy --quiet > /dev/null 2>&1
echo "  50%"
pip install stem --quiet > /dev/null 2>&1
echo "  55%"
pip install nest_asyncio --quiet > /dev/null 2>&1
echo "  60%"
pip install simplekml --quiet > /dev/null 2>&1
echo "  65%"
pip install libregf-python --quiet > /dev/null 2>&1
echo "  70%"
pip install libesedb-python --quiet > /dev/null 2>&1
echo "  75%"
pip install xmltodict --quiet > /dev/null 2>&1
echo "  80%"
pip install PySimpleGUI --quiet > /dev/null 2>&1
pip install pyudev --quiet > /dev/null 2>&1
echo "  85%"
pip install PySide2 --quiet > /dev/null 2>&1
pip install PySide6 --quiet > /dev/null 2>&1
echo "  90%"

pip install --upgrade git+https://github.com/twintproject/twint.git@origin/master#egg=twint --quiet > /dev/null 2>&1
/bin/sed -i 's/3.6/1/g' ~/.local/lib/python3.10/site-packages/twint/cli.py > /dev/null 2>&1
echo "  100%"

RELEASE_VERSION=$(wget -qO - "https://api.github.com/repos/laurent22/joplin/releases/latest" | grep -Po '"tag_name": ?"v\K.*?(?=")') > /dev/null 2>&1
mkdir -p /opt/csitools/joplin > /dev/null 2>&1
cd /opt/csitools/joplin > /dev/null 2>&1
rm -f *.AppImage ~/.local/share/applications/joplin.desktop VERSION > /dev/null 2>&1
wget -qnv --show-progress -O Joplin.AppImage https://github.com/laurent22/joplin/releases/download/v${RELEASE_VERSION}/Joplin-${RELEASE_VERSION}.AppImage
wget -qnv --show-progress -O joplin.png https://joplinapp.org/images/Icon512.png
chmod +x Joplin.AppImage

echo "Installing Computer Forensic Tools"
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
	mv /tmp/autopsy/autopsy-4.21.0 /opt/autopsy
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
	wget https://launchpad.net/veracrypt/trunk/1.25.9/+download/veracrypt-1.25.9-Ubuntu-21.10-amd64.deb
	echo $key | sudo -S apt install -y ./veracrypt-1.25.9-Ubuntu-21.10-amd64.deb -y
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

if ! which bulk_extractor > /dev/null; then
	cd /tmp
	wget https://digitalcorpora.s3.amazonaws.com/downloads/bulk_extractor/bulk_extractor-2.0.3.tar.gz
	tar -xf bulk_extractor-2.0.3.tar.gz
	mv bulk_extractor-2.0.3 bulk_extractor
	cd bulk_extractor
	./configure
	make
	echo $key | sudo -S make install
fi

if [ ! -f /opt/WLEAPP/wleappGUI.py ]; then
	cd /opt
	git clone https://github.com/abrignoni/WLEAPP.git
	cd /opt/WLEAPP
	pip install -r requirements.txt --quiet
else
	cd /opt/WLEAPP
	git reset --hard HEAD > /dev/null 2>&1; git pull > /dev/null 2>&1
fi

if [ ! -f /opt/ALEAPP/aleappGUI.py ]; then
	cd /opt
	git clone https://github.com/abrignoni/ALEAPP.git
	cd ALEAPP
	pip install -r requirements.txt --quiet
else
	cd /opt/ALEAPP
	git reset --hard HEAD > /dev/null 2>&1; git pull > /dev/null 2>&1
fi

if [ -f /opt/theHarvester/theHarvester.py ]; then
	cd /opt/theHarvester/
	git reset --hard HEAD > /dev/null 2>&1; git pull > /dev/null 2>&1
fi

if [ ! -f /opt/iLEAPP/ileapp.py ]; then
	cd /opt
	git clone https://github.com/abrignoni/iLEAPP.git
	cd iLEAPP
	pip install -r requirements.txt --quiet
else
	cd /opt/iLEAPP
	git reset --hard HEAD > /dev/null 2>&1; git pull > /dev/null 2>&1
fi

if [ ! -f /opt/VLEAPP/vleapp.py ]; then
	cd /opt
	git clone https://github.com/abrignoni/VLEAPP.git
	cd VLEAPP
	pip install -r requirements.txt --quiet
else
	cd /opt/VLEAPP
	git reset --hard HEAD > /dev/null 2>&1; git pull > /dev/null 2>&1
fi

if [ ! -f /opt/iOS-Snapshot-Triage-Parser/SnapshotImageFinder.py ]; then
	cd /opt
	git clone https://github.com/abrignoni/iOS-Snapshot-Triage-Parser.git
	cd iOS-Snapshot-Triage-Parser
else
	cd /opt/iOS-Snapshot-Triage-Parser
	git reset --hard HEAD > /dev/null 2>&1; git pull > /dev/null 2>&1
fi

if [ ! -f /opt/DumpsterDiver/DumpsterDiver.py ]; then
	cd /opt
	git clone https://github.com/securing/DumpsterDiver.git
	cd DumpsterDiver
	pip install -r requirements.txt --quiet
else
	cd /opt/DumpsterDiver
	git reset --hard HEAD > /dev/null 2>&1; git pull > /dev/null 2>&1
fi

if [ ! -f /opt/dumpzilla/dumpzilla.py ]; then
	cd /opt
	git clone https://github.com/Busindre/dumpzilla.git
	cd dumpzilla
else
	cd /opt/dumpzilla
	git reset --hard HEAD > /dev/null 2>&1; git pull > /dev/null 2>&1
fi

if [ ! -f /opt/volatility3/vol.py ]; then
	cd /opt
	git clone https://github.com/volatilityfoundation/volatility3.git
	cd volatility3
	pip install -r requirements.txt --quiet
else
	cd /opt/volatility3
	git reset --hard HEAD > /dev/null 2>&1; git pull > /dev/null 2>&1
fi

if [ ! -f /opt/autotimeliner/autotimeline.py ]; then
	cd /opt
	git clone https://github.com/andreafortuna/autotimeliner.git
	cd autotimeliner
else
	cd /opt/autotimeliner
	git reset --hard HEAD > /dev/null 2>&1; git pull > /dev/null 2>&1
fi

if [ ! -f /opt/RecuperaBit/main.py ]; then
	cd /opt
	git clone https://github.com/Lazza/RecuperaBit.git
	cd RecuperaBit
else
	cd /opt/RecuperaBit
	git reset --hard HEAD > /dev/null 2>&1; git pull > /dev/null 2>&1
fi


if [ ! -f /opt/dronetimeline/src/dtgui.py ]; then
	cd /opt
	git clone https://github.com/studiawan/dronetimeline.git
	cd /opt/dronetimeline
	pip install -r requirements.txt --quiet
	echo $key | sudo -S python setup.py install
else
	cd /opt/dronetimeline
	git reset --hard HEAD > /dev/null 2>&1; git pull > /dev/null 2>&1
fi 

if [ ! -f /opt/routeconverter/RouteConverterLinux.jar ]; then
    cd /opt
	mkdir routeconverter
	cd routeconverter
	wget https://static.routeconverter.com/download/RouteConverterLinux.jar
fi


echo "Installing Online Forensic Tools"

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
else
	echo "sn0int installed"
fi

if [ ! -f /opt/ghunt/main.py ]; then
	cd /opt
	git clone https://github.com/mxrch/GHunt.git ghunt
	cd ghunt 
 	pip install -r requirements.txt --quiet > /dev/null 2>&1
else
	cd /opt/ghunt
	git reset --hard HEAD > /dev/null 2>&1
 	git pull > /dev/null 2>&1
 	pip install -r requirements.txt --quiet > /dev/null 2>&1
fi

if [ ! -f /opt/sherlock/sherlock/sherlock.py ]; then
	cd /opt
	git clone https://github.com/sherlock-project/sherlock.git
	cd /opt/sherlock
	pip install -r requirements.txt --quiet > /dev/null 2>&1
else
	cd /opt/sherlock
	git reset --hard HEAD > /dev/null 2>&1
 	git pull > /dev/null 2>&1
fi

if [ ! -f /opt/blackbird/blackbird.py ]; then
    cd /opt
    git clone https://github.com/p1ngul1n0/blackbird.git
    cd /opt/blackbird
    pip install -r requirements.txt --quiet > /dev/null 2>&1
    echo $key | sudo -S chmod +x blackbird.py
    mkdir results > /dev/null 2>&1
else
    cd /opt/blackbird
    mkdir results > /dev/null 2>&1
    git reset --hard HEAD > /dev/null 2>&1
    git pull > /dev/null 2>&1
fi

if [ ! -f /opt/Moriarty-Project/run.sh ]; then
	cd /opt
	git clone https://github.com/AzizKpln/Moriarty-Project
	cd /opt/Moriarty-Project
	echo $key | sudo -S bash install.sh > /dev/null 2>&1
else
	cd /opt/Moriarty-Project
	git reset --hard HEAD > /dev/null 2>&1
 	git pull > /dev/null 2>&1
fi

if [ ! -f /opt/Rock-ON/rockon.sh ]; then
	cd /opt
	git clone https://github.com/SilverPoision/Rock-ON.git
	cd Rock-ON
	chmod +x rockon.sh
else
	cd /opt/Rock-ON
	git reset --hard HEAD > /dev/null 2>&1
 	git pull > /dev/null 2>&1
fi

if [ ! -f /opt/Carbon14/carbon14.py ]; then
	cd /opt
	git clone https://github.com/Lazza/Carbon14.git
	cd Carbon14
	pip install -r requirements.txt --quiet > /dev/null 2>&1
else
	cd /opt/Carbon14
	git reset --hard HEAD > /dev/null 2>&1
 	git pull > /dev/null 2>&1
fi

if [ ! -f /opt/PhoneInfoga/phoneinfoga ]; then
	cd /opt
	mkdir PhoneInfoga
	cd PhoneInfoga
	wget https://raw.githubusercontent.com/sundowndev/phoneinfoga/master/support/scripts/install -O - | sh 
	echo $key | sudo -S chmod +x ./phoneinfoga > /dev/null 2>&1
	echo $key | sudo -S ln -sf ./phoneinfoga /usr/local/bin/phoneinfoga > /dev/null 2>&1
fi

if [ ! -f /opt/email2phonenumber/email2phonenumber.py ]; then
	cd /opt
	git clone https://github.com/martinvigo/email2phonenumber.git
	cd email2phonenumber
	pip install -r requirements.txt --quiet > /dev/null 2>&1
else
	cd /opt/email2phonenumber
	git reset --hard HEAD > /dev/null 2>&1
 	git pull > /dev/null 2>&1
fi

if [ ! -f /opt/Masto/masto.py ]; then
	cd /opt
	git clone https://github.com/C3n7ral051nt4g3ncy/Masto
	cd Masto
	pip install -r requirements.txt --quiet > /dev/null 2>&1
else
	cd /opt/Masto
	git reset --hard HEAD > /dev/null 2>&1
 	git pull > /dev/null 2>&1
fi

if [ ! -f /opt/FinalRecon/finalrecon.py ]; then
	cd /opt
	git clone https://github.com/thewhiteh4t/FinalRecon.git
	cd FinalRecon
	pip install -r requirements.txt --quiet > /dev/null 2>&1
else
	cd /opt/FinalRecon
	git reset --hard HEAD > /dev/null 2>&1
 	git pull > /dev/null 2>&1
fi

if [ ! -f /opt/spiderfoot/sf.py ]; then
	cd /opt
	wget https://github.com/smicallef/spiderfoot/archive/v4.0.tar.gz
	tar zxvf v4.0.tar.gz
	mv spiderfoot-4.0 spiderfoot
	cd spiderfoot
	pip install -r requirements.txt --quiet > /dev/null 2>&1
else
	cd /opt/spiderfoot
 	pip install -r requirements.txt --quiet > /dev/null 2>&1
fi

if [ ! -f /opt/Goohak/goohak ]; then
	cd /opt
	git clone https://github.com/1N3/Goohak.git
	echo $key | sudo -S chmod +x /opt/Goohak/goohak
else
	cd /opt/Goohak
	git reset --hard HEAD > /dev/null 2>&1; git pull > /dev/null 2>&1
fi

if [ ! -f /opt/LittleBrother/LittleBrother.py ]; then
	cd /opt
	git clone https://github.com/Lulz3xploit/LittleBrother
	cd LittleBrother
	pip install -r requirements.txt --quiet > /dev/null 2>&1
	echo $key | sudo -S chmod +x LittleBrother.py
else
	cd /opt/LittleBrother
	git reset --hard HEAD > /dev/null 2>&1
 	git pull > /dev/null 2>&1
fi

if [ ! -f /opt/Osintgram/main.py ]; then
	cd /opt
	git clone https://github.com/Datalux/Osintgram.git
	cd Osintgram
	pip install -r requirements.txt --quiet
	mv src/* . > /dev/null 2>&1
	find . -type f -exec sed -i 's/from\ src\ //g' {} +
	find . -type f -exec sed -i 's/src.Osintgram/Osintgram/g' {} +
	
else
	cd /opt/Osintgram
	git reset --hard HEAD > /dev/null 2>&1; git pull > /dev/null 2>&1
	mv src/* . > /dev/null 2>&1
	find . -type f -exec sed -i 's/from\ src\ //g' {} +
	find . -type f -exec sed -i 's/src.Osintgram/Osintgram/g' {} +
fi

if [ ! -f /opt/InstagramOSINT/main.py ]; then
	cd /opt
	git clone https://github.com/sc1341/InstagramOSINT.git
	cd InstagramOSINT
	pip install -r requirements.txt --quiet > /dev/null 2>&1
else
	cd /opt/InstagramOSINT
	git reset --hard HEAD > /dev/null 2>&1
 	git pull > /dev/null 2>&1
fi

if [ ! -f /opt/OnionSearch/setup.py ]; then
	cd /opt
	git clone https://github.com/CSILinux/OnionSearch.git
        cd OnionSearch/
        python3 setup.py install > /dev/null 2>&1
else
	cd /opt/OnionSearch
	git reset --hard HEAD > /dev/null 2>&1
 	git pull > /dev/null 2>&1
fi

if [ ! -f /opt/Photon/photon.py ]; then
	cd /opt
	git clone https://github.com/s0md3v/Photon.git
	cd Photon
	pip install -r requirements.txt --quiet > /dev/null 2>&1
else
	cd /opt/Photon
	git reset --hard HEAD > /dev/null 2>&1
 	git pull > /dev/null 2>&1
fi

if [ ! -f /opt/ReconDog/dog ]; then
	cd /opt
	git clone https://github.com/s0md3v/ReconDog.git
	cd ReconDog
	pip install -r requirements.txt --quiet > /dev/null 2>&1
else
	cd /opt/ReconDog
	git reset --hard HEAD > /dev/null 2>&1
 	git pull > /dev/null 2>&1
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

if ! which maltego > /dev/null 2>&1; then
	cd /tmp
	wget https://csilinux.com/downloads/Maltego.deb
	echo $key | sudo -S apt install ./Maltego.deb -y
fi

if ! which onionshare > /dev/null; then
	echo $key | sudo -S snap install onionshare
fi

echo "Installing Darkweb Tools"
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

# i2p
echo $key | sudo -S snap remove i2pi2p > /dev/null 2>&1
echo $key | sudo -S apt install i2p* -y > /dev/null 2>&1
echo $key | sudo -S apt install openjdk-19-jdk
echo $key | sudo -S update-java-alternatives -s /usr/lib/jvm/java-1.19.0-openjdk-amd64

# echo $key | sudo -S groupadd tor-auth
# echo $key | sudo -S usermod -a -G tor-auth debian-tor
# echo $key | sudo -S usermod -a -G tor-auth csi
# echo $key | sudo -S chmod 644 /run/tor/control.authcookie
# echo $key | sudo -S chown root:tor-auth /run/tor/control.authcookie
# echo $key | sudo -S chmod g+r /run/tor/control.authcookie


echo "Installing SIGINT Tools"
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




# Malware Analysis
echo "Installing Malware Analysis Tools"
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



# Network
echo "Installing Network Tools"
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



# Security
echo "Installing Security Tools"

if [ ! -f /opt/exploitdb/searchsploit ]; then
	cd /opt
	git clone https://gitlab.com/exploit-database/exploitdb.git
else
	cd /opt/exploitdb
	git reset --hard HEAD > /dev/null 2>&1; git pull > /dev/null 2>&1
fi









# AppImages
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

if [ ! -f /opt/IMSI-catcher/simple_IMSI-catcher.py ]; then
	# fix later.  gnradio 3.9 issue with  Unknown CMake command "GR_SWIG_MAKE".
	cd /opt
	wget https://github.com/Oros42/IMSI-catcher/archive/master.zip && unzip -q master.zip
	mv IMSI-catcher-master IMSI-catcher
	pip install docutils
	cd IMSI-catcherc
	echo $key | sudo -S apt install -y cmake \
    autoconf \
    libtool \
    pkg-config \
    build-essential \
    libcppunit-dev \
    swig \
    doxygen \
    liblog4cpp5-dev \
    gnuradio-dev \
    gr-osmosdr \
    libosmocore-dev \
    liborc-0.4-dev
	echo $key | sudo -S apt install python3-numpy python3-scipy python3-scapy -y
	git clone -b maint-3.8 https://github.com/velichkov/gr-gsm.git
	cd gr-gsm
	mkdir build
	cd build
	cmake ..
	make -j 4
	sudo make install
	sudo ldconfig
	echo 'export PYTHONPATH=/usr/local/lib/python3/dist-packages/:$PYTHONPATH' >> ~/.bashrc
fi

#install Snaps


echo $key | sudo -S cp /opt/csitools/youtube.lua /usr/lib/x86_64-linux-gnu/vlc/lua/playlist/youtube.luac -rf
echo $key | sudo -S timedatectl set-timezone UTC


# unredactedmagazine


echo $key | sudo -S /opt/csitools/clearlogs > /dev/null 2>&1
echo $key | sudo -S rm -rf /var/crash/* > /dev/null 2>&1
echo $key | sudo -S rm /var/crash/* > /dev/null 2>&1
rm ~/.vbox* > /dev/null 2>&1

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
echo "# Verifying APT installs"
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
