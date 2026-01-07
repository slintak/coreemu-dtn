#!/bin/bash

# check if we have a custom services file
if [ -f /update-custom-services.sh ]; then
	echo "Using custom services file"
	/update-custom-services.sh
fi

core-daemon -c /opt/core/etc/core.conf > /var/log/core-daemon.log 2>&1 &
dockerd > /var/log/dockerd.log 2>&1 &

if [ ! -z "$SSHKEY" ]; then
	echo "Adding ssh key: $SSHKEY"
	mkdir /root/.ssh
	chmod 755 ~/.ssh
	echo $SSHKEY > /root/.ssh/authorized_keys
    chmod 644 /root/.ssh/authorized_keys	
fi

if command -v xrdb >/dev/null 2>&1 && [ -f /root/.Xresources ]; then
  xrdb -merge /root/.Xresources || true
fi

sleep 1
core-gui
