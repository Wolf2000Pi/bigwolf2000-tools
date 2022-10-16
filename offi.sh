#!/bin/sh
#
#docker exec $(docker ps -l -q --filter "name=srv-captain--offi.1") /var/www/onlyoffice/documentserver/npm/json -f /etc/onlyoffice/documentserver/local.json 'services.CoAuthoring.secret.session.string' &&
docker exec $(docker ps -l -q --filter "name=srv-captain--offi.1") supervisorctl start ds:example &&
docker exec $(docker ps -l -q --filter "name=srv-captain--offi.1") sed 's,autostart=false,autostart=true,' -i /etc/supervisor/conf.d/ds-example.conf
