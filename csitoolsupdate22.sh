#!/usr/bin/env bash

cd /tmp
key=$(zenity --password --title "Power up your system with an upgrade." --text "Enter your CSI password." --width 400)
echo "Installing CSI Linux Tools and Menu update"
rm csi* > /dev/null 2>&1
rm /opt/csitools/csitools* > /dev/null 2>&1
rm -rf /opt/OSINT-Search > /dev/null 2>&1
rm -rf /opt/Moriarty-Project > /dev/null 2>&1
rm -rf /opt/csitools/helper/dcfldd > /dev/null 2>&1
rm -rf /opt/csitools/helper/exif > /dev/null 2>&1
rm -f /opt/csitools/helper/sn0int*
rm /opt/csitools/helper/cewl
rm /opt/csitools/helper/sn0*

echo "Downloading CSI Tools"
wget https://csilinux.com/downloads/csitools22.zip -O csitools22.zip

echo "# Installing CSI Tools"
echo $key | sudo -S unzip -o -d / csitools22.zip
echo $key | sudo -S chown csi:csi -R /opt/csitools 
echo $key | sudo -S chmod +x /opt/csitools/* -R
echo $key | sudo -S chmod +x /opt/csitools/*
echo $key | sudo -S chmod +x ~/Desktop/*.desktop
echo $key | sudo -S chown csi:csi /usr/bin/bash-wrapper
echo $key | sudo -S chown csi:csi /home/csi -R
echo $key | sudo -S chmod +x /usr/bin/bash-wrapper 
echo $key | sudo -S /bin/sed -i 's/http\:\/\/in./http\:\/\//g' /etc/apt/sources.list

mkdir /home/csi/Cases

echo $key | sudo -S chmod +x /opt/csitools/powerup
echo $key | sudo -S ln -sf /opt/csitools/powerup /usr/local/bin/powerup
echo $key | sudo -S apt remove modemmanager -y


echo "# Verifying APT installs"
echo $key | sudo -S DEBIAN_FRONTEND=noninteractive dpkg --configure -a


#cleaning up apt keys
sudo apt-key del 5345B8BF43403B93
sudo apt-key del 76F1A20FF987672F

echo $key | sudo -S sudo curl -fsSL https://dl.winehq.org/wine-builds/winehq.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/winehq.gpg >/dev/null
echo $key | sudo -S bash -c "echo 'deb https://dl.winehq.org/wine-builds/ubuntu/ focal main' | tee /etc/apt/sources.list.d/wine.list"
echo $key | sudo -S sudo curl -fsSL https://www.kismetwireless.net/repos/kismet-release.gpg.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/kismet-release.gpg >/dev/null
echo $key | sudo -S bash -c "echo 'deb https://www.kismetwireless.net/repos/apt/release/jammy jammy main' | tee /etc/apt/sources.list.d/kismet.list"
echo $key | sudo -S sudo curl -fsSL https://deb.oxen.io/pub.gpg | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/oxen.gpg >/dev/null
echo $key | sudo -S bash -c "echo 'deb [arch=amd64] https://deb.oxen.io $(lsb_release -sc) main' | tee /etc/apt/sources.list.d/oxen.list"
echo $key | sudo -S sudo curl -fsSL https://packages.element.io/debian/element-io-archive-keyring.gpg | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/element-io-archive-keyring.gpg >/dev/null
echo $key | sudo -S bash -c "echo 'deb https://packages.element.io/debian/ default main' | tee > element-io.list"

echo "# Updating APT repository"
echo $key | sudo -S dpkg --add-architecture i386
echo $key | sudo -S apt update --ignore-missing
echo $key | sudo -S DEBIAN_FRONTEND=noninteractive apt install postfix -y

echo $key | sudo -S apt autoremove -y

cd /tmp
rm  hunchly.deb
wget -O hunchly.deb https://downloadmirror.hunch.ly/currentversion/hunchly.deb?csilinux_update
echo $key | sudo -S DEBIAN_FRONTEND=noninteractive apt-get install ./hunchly.deb -y

echo $key | sudo -S DEBIAN_FRONTEND=noninteractive apt install -y libmagic-dev python3-magic python3-pyregfi
echo $key | sudo -S apt purge onionshare proxychains4 -y

mv ~/.local/share/applications/menulibre-kvm-/-virt-manager.desktop ~/.local/share/applications/menulibre-kvm---virt-manager.desktop

echo $key | sudo -S ln -s /usr/bin/python3 /usr/bin/python

wget https://csilinux.com/downloads/apps.txt
sudo apt install -y $(grep -vE "^\s*#" apps.txt | sed -e 's/#.*//'  | tr "\n" " ")


echo $key | sudo -S apt install python3-pip -y
echo $key | sudo -S apt install python3-pyqt5.qtsql -y
echo $key | sudo -S apt install bash-completion -y
echo $key | sudo -S apt install openjdk-19-jdk -y

python3 -m pip install pip --upgrade
pip uninstall twint -y
pip install grequests 
pip install sublist3r
# pip install fb-friend-list-scraper
pip install pyngrok
# pip install onlyfans-scraper
pip install --upgrade git+https://github.com/twintproject/twint.git@origin/master#egg=twint
/bin/sed -i 's/3.6/1/g' ~/.local/lib/python3.10/site-packages/twint/cli.py
pip install instaloader 
pip install dnslib 
pip install icmplib 
pip install passwordmeter 
pip install image 
pip install ConfigParser 
pip install pyexiv2 
pip install urllib 
pip install oauth2 
pip install reload
pip install onionsearch
pip install telepathy
pip install stem 
pip install nest_asyncio 
pip install simplekml 
pip install magic
pip install libregf-python
pip install libesedb-python
pip install xmltodict
pip install PySimpleGUI




# computer Forensics
echo "Installing Computer Forensic Tools"
cd /tmp
if [ ! -f /opt/autopsy/bin/autopsy ]; then
	wget https://github.com/sleuthkit/autopsy/releases/download/autopsy-4.20.0/autopsy-4.20.0.zip -O autopsy.zip
	wget https://github.com/sleuthkit/sleuthkit/releases/download/sleuthkit-4.12.0/sleuthkit-java_4.12.0-1_amd64.deb -O sleuthkit-java.deb
	echo $key | sudo -S apt install ./sleuthkit-java.deb -y
	wget https://raw.githubusercontent.com/sleuthkit/autopsy/develop/linux_macos_install_scripts/install_prereqs_ubuntu.sh
	echo $key | sudo -S bash install_prereqs_ubuntu.sh
	wget https://raw.githubusercontent.com/sleuthkit/autopsy/develop/linux_macos_install_scripts/install_application.sh
	bash install_application.sh -z ./autopsy.zip -i /tmp/autopsy -j /usr/lib/jvm/bellsoft-java8-full-amd64
	mv /tmp/autopsy/autopsy-4.20.0 /opt/autopsy
	echo $key | sudo -S chmod +x /opt/autopsy/bin/autopsy
	sed -i -e 's/\#jdkhome=\"\/path\/to\/jdk\"/jdkhome=\"\/usr\/lib\/jvm\/bellsoft-java8-full-amd64\/jre\"/g' /opt/autopsy/etc/autopsy.conf
	cd /opt/autopsy
	if [ "$JAVA_HOME" == "" ]; then
		export JAVA_HOME="/usr/lib/jvm/bellsoft-java8-full-amd64/jre"
	fi
	echo $key | sudo -S bash linux_macos_install_scripts/install_prereqs_ubuntu.sh
	bash unix_setup.sh
	# /opt/autopsy/bin/autopsy --nosplash
	cd ~/Downloads
	git clone https://github.com/sleuthkit/autopsy_addon_modules.git
fi

cd /tmp

if ! which veracrypt > /dev/null; then
	echo "Installing veracrypt"
	wget https://launchpad.net/veracrypt/trunk/1.25.9/+download/veracrypt-1.25.9-Ubuntu-21.10-amd64.deb
	echo $key | sudo -S DEBIAN_FRONTEND=noninteractive apt install -y ./veracrypt-1.25.9-Ubuntu-21.10-amd64.deb -y
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
	pip install -r requirements.txt
else
	cd /opt/WLEAPP
	git pull
fi

if [ ! -f /opt/ALEAPP/aleappGUI.py ]; then
	cd /opt
	git clone https://github.com/abrignoni/ALEAPP.git
	cd ALEAPP
	pip install -r requirements.txt
else
	cd /opt/ALEAPP
	git pull
fi

if [ -f /opt/theHarvester/theHarvester.py ]; then
	cd /opt/theHarvester/
	git pull
fi

if [ ! -f /opt/iLEAPP/ileapp.py ]; then
	cd /opt
	git clone https://github.com/abrignoni/iLEAPP.git
	cd iLEAPP
	pip install -r requirements.txt
else
	cd /opt/iLEAPP
	git pull
fi

if [ ! -f /opt/VLEAPP/vleapp.py ]; then
	cd /opt
	git clone https://github.com/abrignoni/VLEAPP.git
	cd VLEAPP
	pip install -r requirements.txt
else
	cd /opt/VLEAPP
	git pull
fi

if [ ! -f /opt/iOS-Snapshot-Triage-Parser/SnapshotImageFinder.py ]; then
	cd /opt
	git clone https://github.com/abrignoni/iOS-Snapshot-Triage-Parser.git
	cd iOS-Snapshot-Triage-Parser
else
	cd /opt/iOS-Snapshot-Triage-Parser
	git pull
fi

if [ ! -f /opt/DumpsterDiver/DumpsterDiver.py ]; then
	cd /opt
	git clone https://github.com/securing/DumpsterDiver.git
	cd DumpsterDiver
	pip install -r requirements.txt
else
	cd /opt/DumpsterDiver
	git pull
fi

if [ ! -f /opt/dumpzilla/dumpzilla.py ]; then
	cd /opt
	git clone https://github.com/Busindre/dumpzilla.git
	cd dumpzilla
else
	cd /opt/dumpzilla
	git pull
fi

if [ ! -f /opt/volatility3/vol.py ]; then
	cd /opt
	git clone https://github.com/volatilityfoundation/volatility3.git
	cd volatility3
	pip install -r requirements.txt
else
	cd /opt/volatility3
	git pull
fi

if [ ! -f /opt/autotimeliner/autotimeline.py ]; then
	cd /opt
	git clone https://github.com/andreafortuna/autotimeliner.git
	cd autotimeliner
else
	cd /opt/autotimeliner
	git pull
fi


if [ ! -f /opt/RecuperaBit/main.py ]; then
	cd /opt
	git clone https://github.com/Lazza/RecuperaBit.git
	cd RecuperaBit
else
	cd /opt/RecuperaBit
	git pull
fi


if [ ! -f /opt/dronetimeline/src/dtgui.py ]; then
	cd /opt
	git clone https://github.com/studiawan/dronetimeline.git
	cd /opt/dronetimeline
	pip install -r requirements.txt
	echo $key | sudo -S python setup.py install
else
	cd /opt/dronetimeline
	git pull
fi 

if [ ! -f /opt/routeconverter/RouteConverterLinux.jar ]; then
    cd /opt
	mkdir routeconverter
	cd routeconverter
	wget https://static.routeconverter.com/download/RouteConverterLinux.jar
fi













# Online Forensics
echo "Installing Online Forensic Tools"

if ! which discord > /dev/null; then
    echo "disord"
	wget https://dl.discordapp.net/apps/linux/0.0.27/discord-0.0.27.deb -O /tmp/discord.deb
	echo $key | sudo -S apt install -y /tmp/discord.deb
fi

if ! which google-chrome > /dev/null; then
	wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
	echo $key | sudo -S DEBIAN_FRONTEND=noninteractive apt install -y ./google-chrome-stable_current_amd64.deb
fi

if ! which sn0int; then
	echo "sn0int NOT installed"
    cd tmp
	echo $key | sudo -S apt install -y curl sq
	curl -sSf https://apt.vulns.sexy/kpcyrd.pgp | sq dearmor | tee apt-vulns-sexy.gpg 
	echo $key | sudo -S cp apt-vulns-sexy.gpg /etc/apt/trusted.gpg.d/apt-vulns-sexy.gpg > /dev/null
	echo $key | sudo -S echo "deb [arch=amd64] http://apt.vulns.sexy stable main" | tee apt-vulns-sexy.list
	echo $key | sudo -S cp apt-vulns-sexy.list /etc/apt/sources.list.d/apt-vulns-sexy.list
	echo $key | sudo -S apt update
	echo $key | sudo -S apt install -y sn0int
else
	echo "sn0int installed"
fi

if [ ! -f /opt/sherlock/sherlock/sherlock.py ]; then
	cd /opt
	git clone https://github.com/sherlock-project/sherlock.git
	cd /opt/sherlock
	pip install -r requirements.txt
else
	cd /opt/sherlock
	git pull
fi

if [ ! -f /opt/Moriarty-Project/run.sh ]; then
	cd /opt
	git clone https://github.com/AzizKpln/Moriarty-Project
	cd /opt/Moriarty-Project
	echo $key | sudo -S apt bash install.sh
else
	cd /opt/Moriarty-Project
	git pull
fi

if [ ! -f /opt/Carbon14/carbon14.py ]; then
	cd /opt
	git clone https://github.com/Lazza/Carbon14.git
	cd Carbon14
	pip install -r requirements.txt
else
	cd /opt/Carbon14
	git pull
fi

if [ ! -f /opt/PhoneInfoga/phoneinfoga ]; then
	cd /opt
	mkdir PhoneInfoga
	cd PhoneInfoga
	wget https://raw.githubusercontent.com/sundowndev/phoneinfoga/master/support/scripts/install -O - | sh 
	echo $key | sudo -S chmod +x ./phoneinfoga
	echo $key | sudo -S ln -sf ./phoneinfoga /usr/local/bin/phoneinfoga
fi

if [ ! -f /opt/email2phonenumber/email2phonenumber.py ]; then
	cd /opt
	git clone https://github.com/martinvigo/email2phonenumber.git
	cd email2phonenumber
	pip install -r requirements.txt
else
	cd /opt/email2phonenumber
	git pull
fi

if [ ! -f /opt/Masto/masto.py ]; then
	cd /opt
	git clone https://github.com/C3n7ral051nt4g3ncy/Masto
	cd Masto
	pip install -r requirements.txt
else
	cd /opt/Masto
	git pull
fi

if [ ! -f /opt/FinalRecon/finalrecon.py ]; then
	cd /opt
	git clone https://github.com/thewhiteh4t/FinalRecon.git
	cd FinalRecon
	pip install -r requirements.txt
else
	cd /opt/FinalRecon
	git pull
fi

if [ ! -f /opt/spiderfoot/sf.py ]; then
	cd /opt
	wget https://github.com/smicallef/spiderfoot/archive/v4.0.tar.gz
	tar zxvf v4.0.tar.gz
	mv spiderfoot-4.0 spiderfoot
	cd spiderfoot
	pip install -r requirements.txt
else
	cd /opt/spiderfoot
	pip install -r requirements.tx
fi

if [ ! -f /opt/Goohak/goohak ]; then
	cd /opt
	git clone https://github.com/1N3/Goohak.git
	echo $key | sudo -S chmod +x /opt/Goohak/goohak
else
	cd /opt/Goohak
	git pull
fi

rm -rf /opt/Osintgram
if [ ! -f /opt/Osintgram/main.py ]; then
	cd /opt
	git clone https://github.com/Datalux/Osintgram.git
	cd Osintgram
	pip install -r requirements.txt
else
	cd /opt/Osintgram
	git pull
fi

if [ ! -f /opt/InstagramOSINT/main.py ]; then
	cd /opt
	git clone https://github.com/sc1341/InstagramOSINT.git
	cd InstagramOSINT
	pip install -r requirements.txt
else
	cd /opt/InstagramOSINT
	git pull
fi

if [ ! -f /opt/blackbird/blackbird.py ]; then
	cd /opt
	git clone https://github.com/p1ngul1n0/blackbird
	cd blackbird
	pip install -r requirements.txt
else
	cd /opt/blackbird
	git pull
fi

if [ ! -f /opt/Photon/photon.py ]; then
	cd /opt
	git clone https://github.com/s0md3v/Photon.git
	cd Photon
	pip install -r requirements.txt
else
	cd /opt/Photon
	git pull
fi

if [ ! -f /opt/ReconDog/dog ]; then
	cd /opt
	git clone https://github.com/s0md3v/ReconDog.git
	cd ReconDog
	pip install -r requirements.txt
else
	cd /opt/ReconDog
	git pull
fi

if [ ! -f /opt/Storm-Breaker/st.py ]; then
	cd /opt
	git clone https://github.com/ultrasecurity/Storm-Breaker.git
	cd Storm-Breaker
	echo $key | sudo -S bash install.sh
	echo $key | sudo -S apt install -y apache2 apache2-bin apache2-data apache2-utils libapache2-mod-php8.1 libapr1 libaprutil1 libaprutil1-dbd-sqlite3 libaprutil1-ldap php php-common php8.1 php8.1-cli php8.1-common php8.1-opcache php8.1-readline
	pip install -r requirements.txt
else
	cd /opt/Storm-Breaker
	git pull
fi

if ! which zoom; then
	cd /opt
	mkdir zoom
	cd zoom
	wget https://zoom.us/client/5.14.7.2928/zoom_amd64.deb
	echo $key | sudo -S apt install ./zoom_amd64.deb
	rm zoom_amd64.deb
fi

if ! which maltego; then
	cd /tmp
	wget https://csilinux.com/downloads/Maltego.deb
	echo $key | sudo -S apt install ./Maltego.deb -y
fi

if ! which onionshare > /dev/null; then
	echo $key | sudo -S snap install onionshare
fi

# Dark Web

cd /tmp

if grep -q "nameserver 127.0.0.53" /etc/resolve.conf
then
    echo "Resolve already configured"
else
    echo $key | sudo -S bash -c "echo 'nameserver 127.0.0.53' >> /etc/resolve.conf"
fi

echo $key | sudo -S apt install lokinet-gui
echo $key | sudo -S echo "nameserver
if grep -q "nameserver 127.3.2.1" /etc/resolve.conf
then
    echo "Lokinet already configured"
else
    echo $key | sudo -S bash -c "echo 'nameserver 127.3.2.1' >> /etc/resolve.conf"
fi

## create TorVPN environment
echo $key | sudo -S /bin/sed -i 's/\#ControlPort/ControlPort/g' /etc/tor/torrc 
echo $key | sudo -S /bin/sed -i 's/\#CookieAuthentication\ 1/CookieAuthentication\ 0/g' /etc/tor/torrc 
echo $key | sudo -S /bin/sed -i 's/\#SocksPort\ 9050/SocksPort\ 9050/g' /etc/tor/torrc 
echo $key | sudo -S /bin/sed -i 's/\#RunAsDaemon\ 1/RunAsDaemon\ 1/g' /etc/tor/torrc 
echo $key | sudo -S cp /etc/tor/torrc /etc/tor/torrc.back
if grep -q "VirtualAddrNetworkIPv4" /etc/tor/torrc
then
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
echo $key | sudo -S apt purge i2p* -y
echo $key | sudo -S snap install --edge i2pi2p



# echo $key | sudo -S groupadd tor-auth
# echo $key | sudo -S usermod -a -G tor-auth debian-tor
# echo $key | sudo -S usermod -a -G tor-auth csi
# echo $key | sudo -S chmod 644 /run/tor/control.authcookie
# echo $key | sudo -S chown root:tor-auth /run/tor/control.authcookie
# echo $key | sudo -S chmod g+r /run/tor/control.authcookie






# SIGINT
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
	wget https://update.flipperzero.one/builds/qFlipper/1.3.1-rc1/qFlipper-x86_64-1.3.1-rc1.AppImage
	mkdir /opt/FlipperZero
	mv ./qFlipper-x86_64-1.3.1-rc1.AppImage /opt/FlipperZero/qFlipperZero.AppImage
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

if [ ! -f /opt/ghidra/ghidraRun ]; then
	cd /tmp
	echo $key | sudo -S apt-get install openjdk-19-jdk
	wget https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_10.2.3_build/ghidra_10.2.3_PUBLIC_20230208.zip
	unzip ghidra_10.2.3_PUBLIC_20230208.zip
	mv ghidra_10.2.3_PUBLIC /opt/ghidra
	cd /opt/ghidra
	echo $key | sudo -S chmod +x ghidraRun
	/bin/sed -i 's/JAVA\_HOME\_OVERRIDE\=/JAVA\_HOME\_OVERRIDE\=\/opt\/ghidra\/amazon-corretto-11.0.19.7.1-linux-x64/g' ./support/launch.properties
else
	cd /opt/ghidra
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







# Security
echo "Installing Security Tools"

if [ ! -f /opt/exploitdb/searchsploit ]; then
	cd /opt
	git clone https://gitlab.com/exploit-database/exploitdb.git
else
	cd /opt/exploitdb
	git pull
fi









# AppImages
if [ ! -f /opt/qr-code-generator-desktop/qr-code-generator-desktop.AppImage ]; then
	cd /opt
	mkdir qr-code-generator-desktop
	cd qr-code-generator-desktop
	wget https://csilinux.com/downloads/qr-code-generator-desktop.AppImage
	echo $key | sudo -S chmod +x qr-code-generator-desktop.AppImage
fi

if ! which keepassxc; then
	echo $key | sudo -S add-apt-repository ppa:phoerious/keepassxc
	echo $key | sudo -S apt update
	echo $key | sudo -S apt install keepassxc -y
fi

if [ ! -f /opt/IMSI-catcher/simple_IMSI-catcher.py ]; then
	# fix later.  gnradio 3.9 issue with  Unknown CMake command "GR_SWIG_MAKE".
	cd /opt
	wget https://github.com/Oros42/IMSI-catcher/archive/master.zip && unzip -q master.zip
	mv IMSI-catcher-master IMSI-catcher
	pip install docutils
	cd IMSI-catcher
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

echo $key | sudo -S DEBIAN_FRONTEND=noninteractive apt install --fix-broken -y
echo "# Fixing broken APT installs level 2"
echo $key | sudo -S DEBIAN_FRONTEND=noninteractive dpkg --configure -a
echo "# Upgrading third party tools"
echo $key | sudo -S DEBIAN_FRONTEND=noninteractive full-upgrade -y
echo "# Fixing broken APT installs level 3"
echo $key | sudo -S DEBIAN_FRONTEND=noninteractive apt -f install
echo "# Fixing broken APT installs level 4"
echo $key | sudo -S DEBIAN_FRONTEND=noninteractive apt upgrade --fix-missing -y
echo "# Verifying APT installs"
echo $key | sudo -S DEBIAN_FRONTEND=noninteractive dpkg --configure -a
echo "# Fixing broken APT installs level 6"
echo $key | sudo -S DEBIAN_FRONTEND=noninteractive dpkg --configure -a --force-confold
echo "# Removing old software APT installs"
echo $key | sudo -S DEBIAN_FRONTEND=noninteractive apt autoremove -y
echo "# Removing APT cache to save space"
echo $key | sudo -S chown csi:csi /opt

# unredactedmagazine

xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorVirtual1/workspace0/last-image -n -t string -s /opt/csitools/wallpaper/CSI-Linux-Dark.jpg
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitoreDP-1/workspace0/last-image -n -t string -s /opt/csitools/wallpaper/CSI-Linux-Dark.jpg
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorHDMI-A-0/workspace0/last-image -n -t string -s /opt/csitools/wallpaper/CSI-Linux-Dark.jpg
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorVirtual1/workspace0/last-image -n -t string -s /opt/csitools/wallpaper/CSI-Linux-Dark.jpg
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitoreDP-2/workspace0/last-image -n -t string -s /opt/csitools/wallpaper/CSI-Linux-Dark.jpg
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorHDMI-A-1/workspace0/last-image -n -t string -s /opt/csitools/wallpaper/CSI-Linux-Dark.jpg

echo $key | sudo -S /opt/csitools/clearlogs > /dev/null 2>&1
echo $key | sudo -S rm -rf /var/crash/* > /dev/null 2>&1
echo $key | sudo -S rm /var/crash/* > /dev/null 2>&1
rm ~/.vbox* > /dev/null 2>&1

echo $key | sudo -S updatedb
echo "Please reboot when finished updating"
