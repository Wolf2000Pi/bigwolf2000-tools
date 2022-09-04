#!/bin/bash
cd /
DATE=$(date +%d-%m-%Y-%H_%M_%S)
BACKUP_DIR="/srv/backup/docker"
SOURCE="/srv/docker/"

find $BACKUP_DIR -name '*' -mtime +20 -exec sudo rm -rf {} \;
#find $BACKUP_DIR -name '*.tar.gz' -mtime +30 -exec sudo rm -rf {} \;

cd /
cp -R /srv/docker/ $BACKUP_DIR/$DATE
#sudo tar -czf $BACKUP_DIR/$DATE.tar.gz $SOURCE
