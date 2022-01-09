#!/bin/bash
#
# Script to restart yubi.
#
# Sometimes the GPG agent will stop working correctly and the only 
# way to get it working was to disconnect and reconnect Yubikey. This
# will do it via sw.
#
# Author: Xoores <whyxoores.cz>

. /scripts/_common.sh


YUBI_USB_PID="1050:0406"


YUBI_COUNT="$(lsusb -d "${YUBI_USB_PID}" | wc -l)"

BOOTSTRAP_ROOT

if [ "${YUBI_COUNT}" -ne 1 ]; then
	LOG_ERR "Invalid YUBI_COUNT, expected 1 and got ${YUBI_COUNT}"
	exit 1
fi

killall gpg-agent 2>/dev/null

while read -r USBDEV; do
	
	USB_DEVID="$(basename "$(dirname "${USBDEV}")")"
	
	echo "> ${USBDEV} -> ${USB_DEVID}"
	LOG_DBG "Found Yubi as USB ${USB_DEVID} -> will unbind/bind"
	
	echo "${USB_DEVID}" > /sys/bus/usb/drivers/usb/unbind
	sleep .5
	echo "${USB_DEVID}" > /sys/bus/usb/drivers/usb/bind
	
done < <(grep -li "yubikey" /sys/bus/usb/devices/*/* 2>/dev/null)

/etc/init.d/pcscd restart


