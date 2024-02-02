#!/bin/bash

cd /tmp
echo "Powerup has been updated.  This will update CSI Tools with the newest updated powerup"
read "Press Enter to continue"
echo "Installing CSI Linux Tools and Menu update"
rm csi* > /dev/null 2>&1
echo "Downloading CSI Tools"
wget https://csilinux.com/download/csitools22.zip -O csitools22.zip
echo "# Installing CSI Tools"
echo $key | sudo -S unzip -o -d / csitools22.zip > /dev/null 2>&1
echo $key | sudo -S chown csi:csi -R /opt/csitools  > /dev/null 2>&1
echo $key | sudo -S chmod +x /opt/csitools/* -R > /dev/null 2>&1
echo $key | sudo -S chmod +x /opt/csitools/* > /dev/null 2>&1
echo $key | sudo -S chown csi:csi /home/csi -R > /dev/null 2>&1
echo $key | sudo -S chmod +x /opt/csitools/powerup > /dev/null 2>&1
echo $key | sudo -S ln -sf /opt/csitools/powerup /usr/local/bin/powerup > /dev/null 2>&1
echo $key | sudo -S mkdir /iso > /dev/null 2>&1

echo "The powerup will run again to finish they upgrade"
/opt/csitools/powerup
