#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

# Check if the correct number of arguments was provided
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <source_iso> <output_iso> <post_install_scripts_dir> <packages_to_install>"
    exit 1
fi

# Assign arguments to variables
SOURCE_ISO=$1
OUTPUT_ISO=$2
POST_INSTALL_SCRIPTS_DIR=$3
PACKAGES_TO_INSTALL=$4

# Define temporary directories
MNT_DIR=$(mktemp -d /tmp/iso_mount.XXXXXX)
EXTRACT_DIR=$(mktemp -d /tmp/iso_extract.XXXXXX)
SQUASHFS_DIR=$(mktemp -d /tmp/squashfs.XXXXXX)
CUSTOM_DIR=$(mktemp -d /tmp/custom.XXXXXX)

# Function to check for required dependencies
check_dependencies() {
    local dependencies=(squashfs-tools genisoimage xorriso mtools)
    for dep in "${dependencies[@]}"; do
        if ! command -v $dep &> /dev/null; then
            echo "Error: Required dependency '$dep' is not installed."
            exit 1
        fi
    done
}

# Check dependencies before proceeding
check_dependencies

# Mount the ISO
mount -o loop "$SOURCE_ISO" "$MNT_DIR"

# Copy the contents to a working directory
cp -rT "$MNT_DIR" "$EXTRACT_DIR"

# Unpack the filesystem
unsquashfs -f -d "$SQUASHFS_DIR" "$EXTRACT_DIR/casper/filesystem.squashfs"

# Customize the filesystem and bootloaders
customize_and_repackage() {
    # Mount proc, sys, and dev to the chroot environment
    mount --bind /proc "$SQUASHFS_DIR/proc"
    mount --bind /sys "$SQUASHFS_DIR/sys"
    mount --bind /dev "$SQUASHFS_DIR/dev"
    cp /etc/resolv.conf "$SQUASHFS_DIR/etc/resolv.conf"

    # Pre-setup: Install curl in chroot for fetching GPG keys
    chroot "$SQUASHFS_DIR" /bin/bash -c "apt-get update && apt-get install -y curl"

    # Function to add repository and GPG keys within the chroot
    add_repository() {
        local repo_type="$1"
        local repo_url="$2"
        local gpg_key_info="$3"
        local repo_name="$4"
    
        # Check if the repository list file already exists
        if [ -f "$SQUASHFS_DIR/etc/apt/sources.list.d/${repo_name}.list" ]; then
            echo "Repository '${repo_name}' list file already exists. Skipping addition."
            return 0
        fi
    
        # Add the GPG key
        echo "Adding GPG key for '${repo_name}'..."
        if [[ "$repo_type" == "apt" ]]; then
            curl -fsSL "$gpg_key_info" | gpg --dearmor > "$SQUASHFS_DIR/etc/apt/trusted.gpg.d/${repo_name}.gpg"
        elif [[ "$repo_type" == "key" ]]; then
            local keyserver=$(echo "$gpg_key_info" | cut -d ' ' -f1)
            local recv_keys=$(echo "$gpg_key_info" | cut -d ' ' -f2-)
            gpg --no-default-keyring --keyring gnupg-ring:/tmp/"$repo_name".gpg --keyserver "$keyserver" --recv-keys $recv_keys
            gpg --no-default-keyring --keyring gnupg-ring:/tmp/"$repo_name".gpg --export > "$SQUASHFS_DIR/etc/apt/trusted.gpg.d/$repo_name.gpg"
        fi
    
        # Add the repository
        echo "Adding repository '${repo_name}'..."
        echo "deb [signed-by=/etc/apt/trusted.gpg.d/${repo_name}.gpg] $repo_url" > "$SQUASHFS_DIR/etc/apt/sources.list.d/${repo_name}.list"
    }

    # Add repositories - Example calls
    # Make sure to replace the placeholder URLs and keys with the actual ones for your repositories
	# Add the repository
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

    chroot "$SQUASHFS_DIR" /bin/bash -c "apt-get remove -y \
	ubuntu-desktop \
	aisleriot \
	brltty \
	duplicity \
	empathy empathy-common \
	example-content \
	gnome-accessibility-themes \
	gnome-contacts \
	gnome-mahjongg \
	gnome-mines \
	gnome-orca \
	gnome-screensaver \
	gnome-sudoku \
	gnome-video-effects \
	landscape-common \
	libreoffice-avmedia-backend-gstreamer \
	libreoffice-base-core \
	libreoffice-calc \
	libreoffice-common \
	libreoffice-core \
	libreoffice-draw \
	libreoffice-gnome \
	libreoffice-gtk \
	libreoffice-impress \
	libreoffice-math \
	libreoffice-ogltrans \
	libreoffice-pdfimport \
	libreoffice-style-galaxy \
	libreoffice-style-human \
	libreoffice-writer \
	libsane libsane-common \
	python3-uno \
	rhythmbox rhythmbox-plugins rhythmbox-plugin-zeitgeist \
	sane-utils \
	shotwell shotwell-common \
	telepathy-gabble telepathy-haze telepathy-idle telepathy-indicator telepathy-logger telepathy-mission-control-5 telepathy-salut \
	totem totem-common totem-plugins \
	printer-driver-brlaser \
	printer-driver-foo2zjs printer-driver-foo2zjs-common \
	printer-driver-m2300w \
	printer-driver-ptouch \
	printer-driver-splix \
	lightdm \
	sleuthkit \
	account-plugin-aim \
	account-plugin-facebook \
	account-plugin-flickr \
	account-plugin-jabber \
	account-plugin-salut \
	account-plugin-yahoo \
	landscape-client-ui-install \
	unity-lens-music \
	unity-lens-photos \
	unity-lens-video \
	unity-scope-audacious \
	unity-scope-chromiumbookmarks \
	unity-scope-clementine \
	unity-scope-colourlovers \
	unity-scope-devhelp \
	unity-scope-firefoxbookmarks \
	unity-scope-gmusicbrowser \
	unity-scope-gourmet \
	unity-scope-guayadeque \
	unity-scope-musicstores \
	unity-scope-musique \
	unity-scope-openclipart \
	unity-scope-texdoc \
	unity-scope-tomboy \
	unity-scope-video-remote \
	unity-scope-virtualbox \
	unity-scope-zotero \
	unity-webapps-common \
	nautilus"

    chroot "$SQUASHFS_DIR" /bin/bash -c "apt-get update && apt-get install -y \
	ca-certificates \
	libfuse2 \
	libnss-mdns \
	xorg \
	xserver-xorg-input-all \
	xserver-xorg-input-synaptics \
	fonts-dejavu-core \
	fonts-freefont-ttf \
	fonts-indic \
	fonts-kacst-one \
	fonts-khmeros-core \
	fonts-lao \
	fonts-liberation \
	fonts-lklug-sinhala \
	fonts-noto-cjk \
	fonts-noto-hinted \
	fonts-opensymbol \
	fonts-sil-abyssinica \
	fonts-sil-padauk \
	fonts-symbola \
	fonts-thai-tlwg \
	fonts-tibetan-machine \
	fonts-ubuntu \
	dmz-cursor-theme \
	gtk2-engines-pixbuf \
	alsa-base \
	alsa-utils \
	libasound2-plugins \
	slim \
	xfce4 \
	xfce4-goodies \
	thunar \
	thunar-archive-plugin \
	thunar-data \
	thunar-gtkhash \
	thunar-media-tags-plugin \
	thunar-vcs-plugin \
	thunar-dropbox-plugin \
	thunar-volman \
	xfce4-appfinder \
	xfce4-panel \
	xfce4-session \
	xfce4-settings \
	xfdesktop4 \
	xfwm4 \
	xfce4-power-manager \
	xfce4-screensaver \
	xfce4-terminal \
	xfburn \
	xfce4-appmenu-plugin \
	xfce4-clipman-plugin \
	xfce4-cpufreq-plugin \
	xfce4-cpugraph-plugin \
	xfce4-datetime-plugin \
	xfce4-dict \
	xfce4-diskperf-plugin \
	xfce4-fsguard-plugin \
	xfce4-genmon-plugin \
	xfce4-indicator-plugin \
	xfce4-mailwatch-plugin \
	xfce4-mount-plugin \
	xfce4-netload-plugin \
	xfce4-places-plugin \
	xfce4-pulseaudio-plugin \
	xfce4-sensors-plugin \
	xfce4-smartbookmark-plugin \
	xfce4-statusnotifier-plugin \
	xfce4-systemload-plugin \
	xfce4-taskmanager \
	xfce4-timer-plugin \
	xfce4-verve-plugin \
	xfce4-wavelan-plugin \
	xfce4-weather-plugin \
	xfce4-whiskermenu-plugin \
	xfce4-xkb-plugin \
	network-manager-gnome \
	curl \
	gpg \
	aria2c \
	xdg-user-dirs \
	xdg-user-dirs-gtk \
	xdg-utils \
	xdg-dbus-proxy \
	anacron \
	bc \
	doc-base \
	foomatic-db-compressed-ppds \
	ghostscript-x \
	inputattach \
	language-selector-common \
	openprinting-ppds \
	printer-driver-pnm2ppa \
	rfkill \
	spice-vdagent \
	ubuntu-drivers-common \
	unzip \
	wireless-tools \
	wpasupplicant \
	xkb-data \
	xterm \
	xubuntu-artwork \
	xubuntu-default-settings \
	zip \
	acpi-support \
	avahi-autoipd \
	avahi-daemon \
	bluez \
	bluez-cups \
	cups \
	cups-bsd \
	cups-client \
	cups-filters \
	fwupd \
	fwupd-signed \
	gucharmap \
	hplip \
	kerneloops \
	laptop-detect \
	libnotify-bin \
	libpam-gnome-keyring \
	memtest86+ \
	numlockx \
	packagekit \
	pavucontrol \
	pcmciautils \
	pinentry-gtk2 \
	policykit-desktop-privileges \
	printer-driver-brlaser \
	printer-driver-c2esp \
	printer-driver-foo2zjs \
	printer-driver-m2300w \
	printer-driver-min12xxw \
	printer-driver-ptouch \
	printer-driver-pxljr \
	printer-driver-sag-gdi \
	printer-driver-splix \
	software-properties-gtk \
	synaptic \
	xcape \
	elementary-xfce-icon-theme \
	greybird-gtk-theme \
	plymouth-theme-spinner \
	plymouth-theme-ubuntu-text \
	sound-theme-freedesktop \
	apparmor \
	x11-utils \
	x11-xkb-utils \
	x11-xserver-utils \
	traceroute \
	vlc \
	vlc-bin \
	vlc-data \
	vlc-l10n \
	vlc-plugin-access-extra \
	vlc-plugin-base \
	vlc-plugin-notify \
	vlc-plugin-qt \
	vlc-plugin-samba \
	vlc-plugin-skins2 \
	vlc-plugin-video-output \
	vlc-plugin-video-splitter \
	vlc-plugin-visualization \
	zram-config \
	wireshark \
	zstd \
	zulucrypt-gui \
	zulumount-gui \
	zulupolkit \
	zulusafe-cli \
	zenity \
	yad \
	zerofree \
	youtube-dl \
	whois \
	wget \
	usb-creator-gtk \
	adb \
	tree \
	pkexec \
	menulibre \
	mediainfo \
	hashcat \
	gpa \
	dos2unix \
	dosfstools \
	cherrytree \
	chntpw \
	cifs-utils \
	ccrypt \
	clamav \
	cmake \
	aircrack-ng \
	bettercap \
	bleachbit \
	cmake-data \
	conky-all \
	cpu-checker \
	cryptcat \
	cryptsetup \
	cupp \
	cutter \
	cutycapt \
	dcfldd \
	fuse2fs \
	fuse3 \
	fuse-convmvfs \
	dump1090-mutability \
	edb-debugger \
	ethtool \
	ewf-tools \
	exfatprogs \
	exif \
	foremost \
	ffmpeg \
	ffmpegthumbnailer \
	ffmpegthumbs \
	fuse-emulator-common \
	fuse-emulator-gtk \
	fuse-emulator-sdl \
	fuse-emulator-utils \
	fuseext2 \
	fusefat \
	fuseiso \
	fuseiso9660 \
	fuse-overlayfs \
	fuse-posixovl \
	fusesmb \
	fuse-zip \
	ghostscript \
	gimp \
	git \
	gnupg \
	gdb \
	gddrescue \
	gdebi \
	gdebi-core \
	gdisk \
	gparted \
	gtkhash \
	gufw \
	guymager \
	hexchat \
	openssl \
	openvpn \
	hostapd \
	htop \
	httrack \
	hunspell-en-us \
	hwinfo \
	hwloc \
	hydra \
	hydra-gtk \
	ncrack \
	imagemagick \
	inetutils-ping \
	inetutils-traceroute \
	inotify-tools \
	macchanger \
	magicrescue \
	keepassxc \
	iw \
	javascript-common \
	jd-gui \
	john \
	lynx \
	ndiff \
	neofetch \
	netcat \
	ophcrack \
	ophcrack-cli \
	network-manager-fortisslvpn \
	network-manager-iodine \
	network-manager-l2tp \
	network-manager-openconnect \
	network-manager-openconnect-gnome \
	network-manager-openvpn \
	network-manager-pptp \
	network-manager-ssh \
	network-manager-vpnc \
	nmap \
	nm-tray \
	nm-tray-l10n \
	orjail \
	osinfo-db \
	os-prober \
	ntfs-3g \
	obfs4proxy \
	outguess \
	p7zip-full \
	parted \
	pdfresurrect \
	pidgin \
	plocate \
	testdisk \
	vokoscreen-ng \
	terminator \
	stegcracker \
	preload \
	proxycheck \
	pulseaudio-module-bluetooth \
	steghide \
	stegosuite \
	recon-ng \
	resolvconf \
	socat \
	ristretto \
	rkhunter \
	scalpel \
	rsync \
	rtkit \
	rtl-433 \
	rtl-sdr \
	rtmpdump \
	scrounge-ntfs \
	stegsnow \
	vinetto \
	tor \
	tumbler \
	update-manager \
	apport-gtk \
	apturl \
	atril \
	baobab \
	blueman \
	brltty \
	brltty-x11 \
	catfish \
	desktop-file-utils \
	engrampa \
	espeak \
	gigolo \
	gnome-disk-utility \
	gstreamer1.0-pulseaudio \
	gvfs-backends \
	gvfs-fuse \
	im-config \
	indicator-messages \
	inxi \
	lightdm-gtk-greeter-settings \
	mate-calc \
	mugshot \
	network-manager-pptp \
	network-manager-pptp-gnome \
	numix-gtk-theme \
	onboard \
	parole \
	pastebinit \
	policykit-desktop-privileges \
	rhythmbox \
	sgt-launcher \
	simple-scan \
	software-properties-gtk \
	speech-dispatcher \
	system-config-printer \
	thunar-archive-plugin \
	thunar-media-tags-plugin \
	transmission-gtk \
	update-notifier \
	whoopsie \
	xfce4-clipman-plugin \
	xfce4-cpugraph-plugin \
	xfce4-dict \
	xfce4-indicator-plugin \
	xfce4-mailwatch-plugin \
	xfce4-netload-plugin \
	xfce4-notes-plugin \
	xfce4-panel-profiles \
	xfce4-places-plugin \
	xfce4-power-manager \
	xfce4-pulseaudio-plugin \
	xfce4-screensaver \
	xfce4-screenshooter \
	xfce4-statusnotifier-plugin \
	xfce4-systemload-plugin \
	xfce4-taskmanager \
	xfce4-verve-plugin \
	xfce4-weather-plugin \
	xfce4-whiskermenu-plugin \
	xfce4-xkb-plugin \
	xubuntu-community-wallpapers \
	xubuntu-docs \
	xul-ext-ubufox"






    # Bootloader and branding customizations
    # Ensure these sed commands and update-alternatives calls are adjusted for your specific customizations
    sed -i 's/Ubuntu/CSI Linux/g' "$EXTRACT_DIR/boot/grub/grub.cfg"
    sed -i 's/Ubuntu/CSI Linux/g' "$EXTRACT_DIR/isolinux/txt.cfg"
    sed -i 's/Ubuntu/CSI Linux/g' "$EXTRACT_DIR/isolinux/isolinux.cfg"
    sed -i 's/#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/g' "$SQUASHFS_DIR/etc/default/grub"
    sed -i '/recordfail_broken=/{s/1/0/}' "$SQUASHFS_DIR/etc/grub.d/00_header"
    sed -i 's/Ubuntu/CSI Linux/g' "$SQUASHFS_DIR/etc/lsb-release"
    sed -i 's/Ubuntu/CSI Linux/g' "$SQUASHFS_DIR/etc/os-release"
    echo "csi-linux" > "$SQUASHFS_DIR/etc/hostname"

    # Customize Plymouth theme
    PLYMOUTH_THEME_PATH="/usr/share/plymouth/themes/vortex-ubuntu/vortex-ubuntu.plymouth"
    chroot "$SQUASHFS_DIR" update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth "$PLYMOUTH_THEME_PATH" 100 &> /dev/null
    chroot "$SQUASHFS_DIR" update-alternatives --set default.plymouth "$PLYMOUTH_THEME_PATH"

    # Add user csi with password csi
    USERNAME="csi"
    PASSWORD="csi"
    chroot "$SQUASHFS_DIR" /bin/bash -c "useradd -m $USERNAME -G sudo,adm -s /bin/bash && echo $USERNAME:$PASSWORD | chpasswd"

    # Configure SLiM login manager
    if ! chroot "$SQUASHFS_DIR" grep -q "^default_user\s*$USERNAME" /etc/slim.conf; then
        echo "Setting default_user to $USERNAME in SLiM configuration..."
        echo "default_user $USERNAME" | chroot "$SQUASHFS_DIR" tee -a /etc/slim.conf > /dev/null
    else
        echo "default_user is already set to $USERNAME."
    fi

    # Copy post-install scripts
    mkdir -p "$SQUASHFS_DIR/root/post-install"
    cp -r "$POST_INSTALL_SCRIPTS_DIR"/* "$SQUASHFS_DIR/root/post-install/"

    # Unmount proc, sys, and dev
    umount "$SQUASHFS_DIR/proc" "$SQUASHFS_DIR/sys" "$SQUASHFS_DIR/dev"
}

# Execute customization functions
customize_and_repackage

# Repackage the filesystem with zstd compression at maximum level
mksquashfs "$SQUASHFS_DIR" "$EXTRACT_DIR/casper/filesystem.squashfs" -comp zstd -Xcompression-level 22 -noappend

# Update the filesystem.size file
printf $(du -sx --block-size=1 "$SQUASHFS_DIR" | cut -f1) > "$EXTRACT_DIR/casper/filesystem.size"

# Create the new ISO with support for both BIOS and UEFI
xorriso -as mkisofs -r -V "CSI Linux" -o "$OUTPUT_ISO"\
    -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot\
    -boot-load-size 4 -boot-info-table -isohybrid-mbr "$EXTRACT_DIR"/isolinux/isohdpfx.bin\
    -eltorito-alt-boot -e /EFI/BOOT/BOOTx64.EFI -no-emul-boot -isohybrid-gpt-basdat\
    "$EXTRACT_DIR"
