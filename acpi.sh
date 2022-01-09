#!/bin/sh
#
# Replacement for /etc/acpi/default.sh - can be "installed" just by ln.
#
# This script contains my modifications to the original default.sh that
# came with my Gentoo
#
# Author: Xoores <whyxoores.cz>

set $*

_LOG_NAME="ACPIhandler"

. /scripts/_common.sh

group="${1%%/*}"
action="${1#*/}"
device="${2}"
id="${3}"
value="${4}"

log_unhandled() {
	logger -t "ACPI" "Unhandled event  [GRP=${group}  ACTION=${action}  DEV='${device}'  ID='${id}'  VALUE='${value}']"
}

#log_unhandled

export DISPLAY=:0

case "$group" in
	button)
		case "$action" in
			mute)
				/scripts/volume.sh mute
				;;
				
			f20)
				logger -t "ACPI" "Mic mute button pressed!"
				amixer set Capture toggle
				;;
				
			lid)
				case "${id}" in
				close)
					/scripts/screenlock.sh &
					xset dpms force off
					;;
					
				open)
					xset dpms force on
					
					if [ -f /tmp/.lullabylock ]; then
						LOG_INFO "Previous lock was initiated by lullaby, resetting PM!"
						/scripts/performance.sh auto
						rm /tmp/.lullabylock
					fi
					;;
					
				*)	log_unhandled ;;
				esac
				;;

			*)	log_unhandled ;;
		esac
		;;

	ac_adapter)
		case "$value" in
			# Add code here to handle when the system is unplugged
			# (maybe change cpu scaling to powersave mode).  For
			# multicore systems, make sure you set powersave mode
			# for each core!
			*0)
				LOG_NOTICE "AC adapter unplugged"
				;;

			# Add code here to handle when the system is plugged in
			# (maybe change cpu scaling to performance mode).  For
			# multicore systems, make sure you set performance mode
			# for each core!
			*1)
				LOG_NOTICE "AC adapter plugged in"
				;;

			*)	log_unhandled ;;
		esac
		
		sleep 1
		/scripts/performance.sh auto
		#rm /tmp/battery.avg &2>/dev/null
		;;
		
	processor)
		case "${action}" in
			processor) 	true ;;
			*)	log_unhandled ;;
		esac
		;;
		

	video)
		case "${action}" in
			brightnessup) 	su -c "/scripts/brightness.sh up" xoores ;;
			brightnessdown) su -c "/scripts/brightness.sh down" xoores ;;
			*)	log_unhandled ;;
		esac

		;;
	
	"9DBB5994-A997-"|\
	jack)
		true
		;;

	battery)
		case "${value}" in
			*1)
				true
				;;

			*)	log_unhandled ;;
		esac
		;;
		
		

	*)	log_unhandled ;;
esac
