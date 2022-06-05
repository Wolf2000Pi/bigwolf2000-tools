#!/bin/bash 

echo
echo -e "\033[36m Autoinstaller für Openmediavault 6.x und Extras.org\033[0m"
echo
echo -e "\033[36m Author:     Wolf2000\033[0m"
echo -e "\033[36m Version:         1.0\033[0m"
echo -e "\033[36m https://wolf2000.at\033[0m"
echo
echo -e "\033[32m Wollen sie Openmediaut mit Plugins installieren\033[0m"
echo -e "\033[32m Ihre Antwort, n/j:\033[0m"
read answer
#echo Das installieren wurde abgebrochen
echo  Ihre Antwort war: $answer
# if [ "$answer" = "j" ]
if [ "$answer" != "n" ]
apt-get update &&
sleep 1
wget -O - https://github.com/OpenMediaVa…Script/raw/master/install | sudo bash &&
sleep 1
apt-get update &&
sleep 1
apt-get --yes --force-yes --allow-unauthenticated install openmediavault php-apc &&
sleep 1
wget https://github.com/OpenMediaVault-Plugin-Developers/installScript/raw/master/install
chmod +x install
sudo ./install -n &&
sleep 1

apt-get update
echo
echo
echo -e "\033[32m Das wars Openmediavult und Extras.org ist jetzt Installiert\033[0m"
else echo -e "\033[31m Die Installation wurde abgebrochen\033[0m"
fi



