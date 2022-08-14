#!/bin/sh
#
echo
echo "   \033[36m Autoinstaller für Backup\033[0m"
echo "   \033[36m Bitte alle .sh editieren\033[0m"
echo "   \033[36m backupcaptain.sh -root - omv -docker\033[0m"
echo
echo
echo "   \033[36m Author:     Wolf2000\033[0m"
echo "   \033[36m Version:         1.1\033[0m"
echo "   \033[36m https://wolf2000.at\033[0m"
echo
echo "   \033[32m Wollen sie Backup-Tools installieren\033[0m"
echo "   \033[32m Ihre Antwort, n/j:\033[0m"
read answer
#echo Das installieren wurde abgebrochen
echo     Ihre Antwort war: $answer
# if [ "$answer" = "j" ]
if [ "$answer" != "n" ]
 then
cd /root/bigwolf2000-tools&&
chmod +x backupcaptain.sh backupomv.sh backupdocker.sh backuproot.sh &&
sleep 1
cp backupcaptain.sh /usr/bin/backupcaptain &&
sleep 1
cp backupomv.sh /usr/bin/backupomv &&
sleep 1 
cp backupdocker.sh /usr/bin/backupdocker &&
sleep 1
cp backuproot.sh /usr/bin/backuproot &&
sleep 1
echo
echo
echo "   \033[32m Das wars Backup-Tools\033[0m"
else echo "   \033[31m Die Installation wurde abgebrochen\033[0m"
fi 
