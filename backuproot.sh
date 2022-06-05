#!/bin/bash
cd /
DATE=$(date +%d-%m-%Y-%H_%M_%S)
BACKUP_DIR="/srv/backup/root"
SOURCE="/root/"

find $BACKUP_DIR -name '*' -mtime +30 -exec rm -rf {} \;
#find $BACKUP_DIR -name '*.tar.gz' -mtime +30 -exec sudo rm -rf {} \;

cd /
sudo cp -R /root/ $BACKUP_DIR/$DATE
#sudo tar -czf $BACKUP_DIR/$DATE.tar.gz $SOURCE
