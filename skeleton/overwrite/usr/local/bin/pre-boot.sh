#!/bin/sh

run_oem()
{
	touch /etc/firstboot
}

[ x"$HOST_DIR" = x ] && export HOST_DIR="/host"
[ -e /etc/firstboot ] || run_oem&
[ -e $HOST_DIR/oem/scripts/preboot.sh ] && $HOST_DIR/oem/scripts/preboot.sh&
