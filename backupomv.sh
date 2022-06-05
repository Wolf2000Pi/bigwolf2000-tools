#!/bin/bash
cd /
DATE=$(date +%d-%m-%Y-%H_%M_%S)
BACKUP_DIR="/srv/backup/openmediavault"
SOURCE="/etc/openmediavault/"

find $BACKUP_DIR -name '*' -mtime +30 -exec rm -rf {} \;
#find $BACKUP_DIR -name '*.tar.gz' -mtime +30 -exec sudo rm -rf {} \;

cd /
sudo cp -R /etc/openmediavault/ $BACKUP_DIR/$DATE
#sudo tar -czf $BACKUP_DIR/$DATE.tar.gz $SOURCE