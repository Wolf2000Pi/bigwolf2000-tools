#!/bin/sh
#
echo
echo "   \033[36m deinstaller für Bigwolf2000-Tools\033[0m"
echo
echo "   \033[36m Author:     Wolf2000\033[0m"
echo "   \033[36m Version:         1.0\033[0m"
echo "   \033[36m https://wolf2000.at\033[0m"
echo
echo "   \033[32m Wollen sie Bigwolf2000-Tools Deinstallieren\033[0m"
echo "   \033[32m Ihre Antwort, n/j:\033[0m"
read answer
#echo Das installieren wurde abgebrochen
echo     Ihre Antwort war: $answer
# if [ "$answer" = "j" ]
if [ "$answer" != "n" ]
 then rm -r bigwolf2000-tools && 
 rm -r deinstall-bigwolf2000-tools.sh &&
 cd /usr/bin/ && 
 rm -r omv-install-6.x.sh  bigwolf2000-config &&
 cd /root/
echo
echo
echo "   \033[32m Das wars Bigwolf2000-Tools ist Deinstalliert\033[0m"
else echo "   \033[31m Die Installation wurde abgebrochen\033[0m"
fi
