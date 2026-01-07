#!/bin/sh

DIR="/shared/myservices"
if [ -d "$DIR" ]; then  
  echo "Adding ${DIR} to custom services dir of core"
  echo custom_services_dir = /shared/myservices >> /opt/core/etc/core.conf
else
  echo custom_services_dir = /root/.core/myservices >> /opt/core/etc/core.conf
fi
