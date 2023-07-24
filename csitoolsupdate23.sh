#!/usr/bin/env bash
# CSI Linux 2023.2 updater.

export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none
cd /tmp
key=$(zenity --password --title "Power up your system with an upgrade." --text "Enter your CSI password." --width 400)
echo "Installing CSI Linux Tools and Menu update"
rm csi* > /dev/null 2>&1
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
echo $key | sudo -S mkdir /iso
echo $key | sudo -S chown csi:csi /iso -R
tar -xf /opt/csitools/assets/Win11-blue.tar.xz --directory /home/csi/.icons/

echo $key | sudo -S /bin/sed -i 's/http\:\/\/in./http\:\/\//g' /etc/apt/sources.list
echo $key | sudo -S echo "\$nrconf{restart} = 'a'" | sudo -S tee /etc/needrestart/conf.d/autorestart.conf > /dev/null

echo $key | sudo -S chmod +x /opt/csitools/powerup > /dev/null 2>&1
echo $key | sudo -S ln -sf /opt/csitools/powerup /usr/local/bin/powerup > /dev/null 2>&1

echo $key | sudo -S apt install curl -y

echo "# Cleaning up apt keys"
cd /tmp

sudo apt-key del 5345B8BF43403B93
sudo apt-key del 76F1A20FF987672F
sudo apt-key del 750179FCEA62
echo $key | sudo -S rm -rf /etc/apt/sources.list.d/archive_u*

echo $key | sudo -S sudo curl -fsSL https://download.bell-sw.com/pki/GPG-KEY-bellsoft | sudo -S gpg --dearmor | sudo -S tee /etc/apt/trusted.gpg.d/bellsoft.gpg >/dev/null
echo $key | sudo -S bash -c "echo 'deb [arch=amd64] https://apt.bell-sw.com/ stable main' | sudo -S tee /etc/apt/sources.list.d/bellsoft.list"
echo $key | sudo -S sudo curl -fsSL https://apt.vulns.sexy/kpcyrd.pgp | sudo -S gpg --dearmor | sudo -S tee /etc/apt/trusted.gpg.d/apt-vulns-sexy.gpg >/dev/null
echo $key | sudo -S bash -c "echo 'deb [arch=amd64] http://apt.vulns.sexy stable main' | sudo -S tee /etc/apt/sources.list.d/apt-vulns-sexy.list"
echo $key | sudo -S sudo curl -fsSL https://dl.winehq.org/wine-builds/winehq.key | sudo -S gpg --dearmor | sudo -S tee /etc/apt/trusted.gpg.d/winehq.gpg >/dev/null
echo $key | sudo -S bash -c "echo 'deb https://dl.winehq.org/wine-builds/ubuntu/ focal main' | sudo -S tee /etc/apt/sources.list.d/wine.list"
echo $key | sudo -S sudo curl -fsSL https://www.kismetwireless.net/repos/kismet-release.gpg.key | sudo -S gpg --dearmor | sudo -S tee /etc/apt/trusted.gpg.d/kismet-release.gpg >/dev/null
echo $key | sudo -S bash -c "echo 'deb [arch=amd64] https://www.kismetwireless.net/repos/apt/release/jammy jammy main' | sudo -S tee /etc/apt/sources.list.d/kismet.list"
echo $key | sudo -S sudo curl -fsSL https://deb.oxen.io/pub.gpg | sudo -S gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/oxen.gpg >/dev/null
echo $key | sudo -S bash -c "echo 'deb [arch=amd64] https://deb.oxen.io $(lsb_release -sc) main' | sudo -S tee /etc/apt/sources.list.d/oxen.list"
echo $key | sudo -S curl -fsSL https://packages.element.io/debian/element-io-archive-keyring.gpg | sudo -S gpg --dearmor | sudo -S tee /etc/apt/trusted.gpg.d/element-io-archive-keyring.gpg >/dev/null
echo $key | sudo -S bash -c "echo 'deb [arch=amd64] https://packages.element.io/debian/ default main' | sudo -S tee > element-io.list"
echo $key | sudo -S curl -so /etc/apt/trusted.gpg.d/oxen.gpg https://deb.oxen.io/pub.gpg
echo $key | sudo -S bash -c " echo 'deb [arch=amd64] https://deb.oxen.io $(lsb_release -sc) main' | sudo -S tee /etc/apt/sources.list.d/oxen.list"
echo $key | sudo -S apt-add-repository ppa:i2p-maintainers/i2p -y
#echo $key | sudo -S add-apt-repository ppa:micahflee/ppa
sudo add-apt-repository ppa:danielrichter2007/grub-customizer

echo "# Updating APT repository"
echo $key | sudo -S dpkg-reconfigure debconf --frontend=noninteractive
echo $key | sudo -S DEBIAN_FRONTEND=noninteractive dpkg --configure -a
echo $key | sudo -S NEEDRESTART_MODE=a apt update --ignore-missing
echo $key | sudo -S apt install xfce4-cpugraph-plugin -y
echo $key | sudo -S apt install xfce4-goodies -y
echo $key | sudo -S apt purge proxychains4 -y > /dev/null 2>&1
echo $key | sudo -S apt purge proxychains -y > /dev/null 2>&1
echo $key | sudo -S apt autoremove -y

echo $key | sudo -S ln -s /usr/bin/python3 /usr/bin/python

#wget https://csilinux.com/downloads/apps.txt
#sudo apt install -y $(grep -vE "^\s*#" apps.txt | sed -e 's/#.*//'  | tr "\n" " ")

echo $key | sudo -S apt install python3-pip -y
echo $key | sudo -S apt install python3-pyqt5.qtsql -y
echo $key | sudo -S apt install bash-completion -y
echo $key | sudo -S apt install openjdk-19-jdk -y
echo $key | sudo -S apt install dos2unix -y
dos2unix /opt/csitools/resetdns
echo $key | sudo -S apt install hexchat -y

python3 -m pip install pip --upgrade > /dev/null 2>&1

cd /tmp

echo "Installing Darkweb Tools"
cd /tmp


if ! which lokinet-gui > /dev/null; then
         echo $key | sudo -S apt install lokinet-gui -y
fi
if [ ! -f /opt/OxenWallet/oxen-electron-wallet-1.8.1-linux.AppImage ]; then
	cd /opt
	mkdir OxenWallet
        cd OxenWallet
	wget https://github.com/oxen-io/oxen-electron-gui-wallet/releases/download/v1.8.1/oxen-electron-wallet-1.8.1-linux.AppImage .
        chmod +x oxen-electron-wallet-1.8.1-linux.AppImage
fi


## Create TorVPN environment
echo $key | sudo -S sed -i 's/#ControlPort/ControlPort/g' /etc/tor/torrc
echo $key | sudo -S sed -i 's/#CookieAuthentication 1/CookieAuthentication 0/g' /etc/tor/torrc
echo $key | sudo -S sed -i 's/#SocksPort 9050/SocksPort 9050/g' /etc/tor/torrc
echo $key | sudo -S sed -i 's/#RunAsDaemon 1/RunAsDaemon 1/g' /etc/tor/torrc
echo $key | sudo -S cp /etc/tor/torrc /etc/tor/torrc.back

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
echo $key | sudo -S update-java-alternatives -s /usr/lib/jvm/java-1.19.0-openjdk-amd64

echo $key | sudo -S timedatectl set-timezone UTC

echo $key | sudo -S apt install --fix-broken -y
echo "# Fixing broken APT installs level 2"
echo $key | sudo -S dpkg --configure -a
echo "# Upgrading third party tools"
echo $key | sudo -S full-upgrade -y
echo "# Fixing broken APT installs level 3"
echo $key | sudo -S apt -f install
echo "# Fixing broken APT installs level 4"
echo $key | sudo -S apt upgrade --fix-missing -y
echo "# Verifying APT installs"
echo $key | sudo -S dpkg --configure -a
echo "# Fixing broken APT installs level 6"
echo $key | sudo -S dpkg --configure -a --force-confold
echo "# Removing old software APT installs"
echo $key | sudo -S apt autoremove -y
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
echo $key | sudo -S adduser $USER vboxsf > /dev/null 2>&1
echo $key | sudo -S updatedb

echo $key | sudo -S bash -c "mv /etc/resolv.conf /etc/resolv.conf.bak" > /dev/null 2>&1

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
if grep -q "GRUB_DISABLE_OS_PROBER=false" /etc/default/grub; then
    echo $key | sudo -S sed -i 's/#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/g' /etc/default/grub
    echo "Grub is already configured for os-probe"
else
    echo $key | sudo -S bash -c "echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub"
fi

echo $key | sudo -S apt purge privoxy -y
echo $key | sudo -S apt purge lighttpd curl -y
echo $key | sudo -S systemctl disable mono-xsp4.service > /dev/null 2>&1
echo $key | sudo -S update-grub &> /dev/null
echo $key | sudo -S update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/vortex-ubuntu/vortex-ubuntu.plymouth 100  &> /dev/null;
echo $key | sudo -S update-alternatives --set default.plymouth /usr/share/plymouth/themes/vortex-ubuntu/vortex-ubuntu.plymouth  &> /dev/null ;
echo $key | sudo -S update-initramfs -u &> /dev/null ;

echo "Please reboot when finished updating"
