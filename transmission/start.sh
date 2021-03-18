#!/bin/bash

mkdir -p /data/torrents
mkdir -p /data/.watch
mkdir -p /data/.session

rm -f /data/.session/rtorrent.lock

chown -R $UID:$GID /data /home/torrent /tmp /usr/flood/dist /flood-db /etc/s6.d

if [ ${RTORRENT_SOCK} = "false" ]; then
    sed -i -e 's|^scgi_local.*$|scgi_port = 0.0.0.0:5000|' /home/torrent/.rtorrent.rc
fi

exec su-exec $UID:$GID /bin/s6-svscan /etc/s6.d

# Source our persisted env variables from container startup
. /etc/transmission/environment-variables.sh

# This script will be called with tun/tap device name as parameter 1, and local IP as parameter 4
# See https://openvpn.net/index.php/open-source/documentation/manuals/65-openvpn-20x-manpage.html (--up cmd)
echo "Up script executed with $*"
if [[ "$4" = "" ]]; then
  echo "ERROR, unable to obtain tunnel address"
  echo "killing $PPID"
  kill -9 $PPID
  exit 1
fi

# Configure port forwarding if applicable
if [[ -x /etc/openvpn/${OPENVPN_PROVIDER,,}/update-port.sh && -z $DISABLE_PORT_UPDATER ]]; then
  echo "Provider ${OPENVPN_PROVIDER^^} has a script for automatic port forwarding. Will run it now."
  echo "If you want to disable this, set environment variable DISABLE_PORT_UPDATER=true"
  exec /etc/openvpn/${OPENVPN_PROVIDER,,}/update-port.sh &
fi

echo "OpenVPN startup script complete."
