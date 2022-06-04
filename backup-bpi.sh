#!/bin/bash
mount 192.168.1.25:/Data2 /media/banane2
DATE=$(date +%d-%m-%Y-%H_%M_%S)
BACKUP_DIR="/media/banane2/banane2"
SOURCE="/dev/mmcblk0"

find $BACKUP_DIR -name '*.img' -mtime +30 -exec sudo rm -rf {} \;
#find $BACKUP_DIR -name '*.tar.gz' -mtime +30 -exec sudo rm -rf {} \;

cd /
sudo dd bs=1M if=/dev/mmcblk0 of=$BACKUP_DIR/$DATE.img
#sudo tar -czf $BACKUP_DIR/$DATE.tar.gz $SOURCE

echo "Hallo Wolf2000 es wurde ein Backup vom Teastserver am $DATE erstellt" | mail -s "Backup" wolf2000@aon.at

