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
apt-get install --yes gnupg &&
wget -O "/etc/apt/trusted.gpg.d/openmediavault-archive-keyring.asc" https://packages.openmediavault.org/public/archive.key &&
apt-key add "/etc/apt/trusted.gpg.d/openmediavault-archive-keyring.asc" &&

cat <<EOF >> /etc/apt/sources.list.d/openmediavault.list
deb https://packages.openmediavault.org/public shaitan main
# deb https://downloads.sourceforge.net/project/openmediavault/packages shaitan main
## Uncomment the following line to add software from the proposed repository.
# deb https://packages.openmediavault.org/public shaitan-proposed main
# deb https://downloads.sourceforge.net/project/openmediavault/packages shaitan-proposed main
## This software is not part of OpenMediaVault, but is offered by third-party
## developers as a service to OpenMediaVault users.
# deb https://packages.openmediavault.org/public shaitan partner
# deb https://downloads.sourceforge.net/project/openmediavault/packages shaitan partner
EOF
export LANG=C.UTF-8 &&
export DEBIAN_FRONTEND=noninteractive &&
export APT_LISTCHANGES_FRONTEND=none &&
apt-get update &&
apt-get --yes --auto-remove --show-upgraded \
    --allow-downgrades --allow-change-held-packages \
    --no-install-recommends \
    --option DPkg::Options::="--force-confdef" \
    --option DPkg::Options::="--force-confold" \
    install openmediavault-keyring openmediavault &&
omv-confdbadm populate &&
apt-get update &&
sleep 1
wget -O - https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master/install | bash &&
sleep 1
apt-get update
echo
echo
echo -e "\033[32m Das wars Openmediavult und Extras.org ist jetzt Installiert\033[0m"
echo -e "\033[31m Die Installation wurde abgebrochen\033[0m"
else
fi



