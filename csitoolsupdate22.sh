#!/bin/bash

key=$(zenity --password --title "Power up your system with an upgrade." --text "Enter your CSI password." --width 400)
cd /tmp
echo "Powerup has been updated.  This will update CSI Tools with the newest updated powerup"
echo "Press Enter to continue"
read DoNothing
echo "Installing CSI Linux Tools and Menu update"
rm csi* > /dev/null 2>&1
echo "Downloading CSI Tools"
wget https://csilinux.com/download/csitools22.zip -O csitools22.zip
echo "# Installing CSI Tools"
echo $key | sudo -S unzip -o -d / csitools22.zip
echo $key | sudo -S chown csi:csi -R /opt/csitools
echo $key | sudo -S chmod +x /opt/csitools/* -R
echo $key | sudo -S chmod +x /opt/csitools/*
echo $key | sudo -S chown csi:csi /home/csi -R
echo $key | sudo -S chmod +x /opt/csitools/powerup 
echo $key | sudo -S ln -sf /opt/csitools/powerup /usr/local/bin/powerup

echo "run the powerup will run again to finish the upgrade"

