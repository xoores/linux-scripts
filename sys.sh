#!/bin/bash
#
# Configure system after launching X session.
#
# Author: Xoores <whyxoores.cz>

. /scripts/_common.sh

BOOTSTRAP_ROOT

case "${1}" in

	startup)
		LOG_NOTICE "System startup script"
		
		LOCKDOWN_STATE="$(egrep -o "\[[^/]*]" /sys/kernel/security/lockdown)"
		
		case "${LOCKDOWN_STATE}" in
			*none*)
				LOG_INFO "Lockdown is not set, preparing for lockdown..."
				#/scripts/dell-bios-fan-control 0
				#/etc/init.d/i8kmon start
				
				echo integrity >> /sys/kernel/security/lockdown
				LOG_NOTICE "Kernel locked down!"
				;;
				
			*)
				LOG_WARN "Kernel already locked down!"
		esac
			
			
		#define DBGLVL1 (IWL_DL_INFO)
		#define DBGLVL2 (DBGLVL1 | IWL_DL_FW_ERRORS)
		#define DBGLVL3 (DBGLVL2 | IWL_DL_TEMP | IWL_DL_POWER)
		#define DBGLVL4 (DBGLVL3 | IWL_DL_ASSOC | IWL_DL_TE)
		#define DBGLVL5 (DBGLVL4 | IWL_DL_DROP | IWL_DL_RADIO)
		#define DBGLVL6 (DBGLVL5 | IWL_DL_SCAN | IWL_DL_HT)
		#define DBGLVL7 (DBGLVL6 | IWL_DL_MAC80211 | IWL_DL_FW)
		#
		#
		#define IWL_DL_INFO			0x00000001
		#define IWL_DL_MAC80211		0x00000002  <<
		#define IWL_DL_HCMD			0x00000004
		#define IWL_DL_TDLS			0x00000008
		#
		#define IWL_DL_QUOTA		0x00000010
		#define IWL_DL_TE			0x00000020  <<
		#define IWL_DL_EEPROM		0x00000040  <<
		#define IWL_DL_RADIO		0x00000080  <<
		#
		#define IWL_DL_POWER		0x00000100  <<
		#define IWL_DL_TEMP			0x00000200  <<
		#define IWL_DL_WOWLAN		0x00000400
		#define IWL_DL_SCAN			0x00000800
		#
		#define IWL_DL_ASSOC		0x00001000  <<
 		#define IWL_DL_DROP			0x00002000  <<
		#define IWL_DL_LAR			0x00004000
		#define IWL_DL_COEX			0x00008000
		echo "0x32E2" >> /sys/module/iwlwifi/parameters/debug
		
		chmod 777 /tmp/env
		chmod o+w /sys/class/backlight/*/brightness
		
		#modprobe jc42
		#echo jc42 0x18 > /sys/bus/i2c/devices/i2c-2/new_device
		#echo jc42 0x19 > /sys/bus/i2c/devices/i2c-2/new_device
		#echo jc42 0x1a > /sys/bus/i2c/devices/i2c-2/new_device
		#echo jc42 0x1b > /sys/bus/i2c/devices/i2c-2/new_device
		;;
esac
