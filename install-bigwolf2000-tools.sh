#!/bin/sh
#
echo
echo "   \033[36m Autoinstaller für Bigwolf200-Tools\033[0m"
echo
echo "   \033[36m Author:     Wolf2000\033[0m"
echo "   \033[36m Version:         1.0\033[0m"
echo "   \033[36m https://wolf2000.at\033[0m"
echo
echo "   \033[32m Wollen sie Bigwolf2000-Tools installieren\033[0m"
echo "   \033[32m Ihre Antwort, n/j:\033[0m"
read answer
#echo Das installieren wurde abgebrochen
echo     Ihre Antwort war: $answer
# if [ "$answer" = "j" ]
if [ "$answer" != "n" ]
 then 
chmod +x bigwolf2000-config.sh omv-install-6.x.sh deinstall-bigwolf2000-tools.sh &&
sleep 1
chmod +x backup.sh offi.sh &&
sleep 1
cp deinstall-bigwolf2000-tools.sh /root/ &&
sleep 1
cp bigwolf2000-config.sh /usr/bin/bigwolf2000-config &&
sleep 1
cp omv-install-6.x.sh /usr/bin/omv-install-6.x.sh &&
sleep 1 
cd &&
sleep 1
chmod +x deinstall-bigwolf2000-tools.sh &&
sleep 1
cd &&
bigwolf2000-config
echo
echo
echo "   \033[32m Das wars Bigwolf2000-Tools\033[0m"
else echo "   \033[31m Die Installation wurde abgebrochen\033[0m"
fi 