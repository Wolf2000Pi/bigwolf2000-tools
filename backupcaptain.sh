#!/bin/bash
cd /
DATE=$(date +%d-%m-%Y-%H_%M_%S)
BACKUP_DIR="/srv/backup/captain"
SOURCE="/captain/"

find $BACKUP_DIR -name '*' -mtime +22 -exec sudo rm -rf {} \;
#find $BACKUP_DIR -name '*.tar.gz' -mtime +30 -exec sudo rm -rf {} \;

cd /
cp -R /captain/ $BACKUP_DIR/$DATE
#sudo tar -czf $BACKUP_DIR/$DATE.tar.gz $SOURCE

