#!/bin/bash
#
# Backlight control w/ notifications
#
# This script can handle multiple backlight sources such as xbacklight
# or raw file access.
#
# ID of notification is hardocded to be 9020
#
# Author: Xoores <whyxoores.cz>


. /scripts/_common.sh


INCREMENT_STEP=2
METHOD="file" # auto, xbacklight, file
DEBUG=0

function help()
{
	echo "USAGE: $(basename "${0}") <ACTION>"
	echo
	echo "  ACTIONS:"
	echo "    u|up     - Increase brightness by ${INCREMENT_STEP}%"
	echo "    d|down   - Decrease brightness by ${INCREMENT_STEP}%"
	echo "    t|toggle - Toggle between min and max brightness"
	echo "    min      - Set brightness to minimum"
	echo "    max      - Set brightness to maximum"
	echo "    [0-100]  - Set brightness to corresponding % value"
}


function brigthness_notify()
{
	BRIGHTNESS=${1:-0}
	
	# Remove decimals...
	BRIGHTNESS=${BRIGHTNESS/.[0-9]*/}
	
	NOTIFY_ICON="display-brightness-symbolic.symbolic"
	
	dunstify --appname=volumeupdate \
				--icon="${NOTIFY_ICON}" \
				--timeout=1000 --replace=9020 \
				-h int:value:"${BRIGHTNESS}" \
				"Brightness: ${BRIGHTNESS}%"
	
}

function DBG()
{
	[[ ${DEBUG} -eq 0 ]] && return
	echo -ne "${@}"
}

# Some helper functions
function test_xbacklight() { [[ "$(xbacklight -get)" != "" ]]; }
function test_file()
{ [[ "$(cat /sys/class/backlight/*/actual_brightness | head -n1)" != "" ]]; }


function set_brightness()
{
	B_SET=${1}
	

	case "${METHOD}" in
		auto)
			if test_xbacklight; then
				METHOD="xbacklight"
			elif test_file; then
				METHOD="file"
			else
				LOG_ERR "No backlight method seems to work!"
				return 1
			fi
			;;
			
		xbacklight)
			if ! test_xbacklight; then
				LOG_ERR "Selected method (${METHOD}) does not work!"
				return 1
			fi
			;;
			
		file)
			if ! test_file; then
				LOG_ERR "Selected method (${METHOD}) does not work!"
				return 1
			fi
			;;
	esac



	
	case "${METHOD}" in
		xbacklight)
			B_NOW=$(xbacklight -get | cut -d'.' -f1)
			B_MAX=100
			B_MIN=0.2
			;;
			
		file)
			B_RAW=$(cat /sys/class/backlight/*/actual_brightness | head -n1)
			B_MAX=$(cat /sys/class/backlight/*/max_brightness | head -n1)
			B_MIN=1
			B_NOW=${B_RAW}
			
			# If not in range 0-100, recalculate...
			if [ ${B_MAX} -ne 100 ]; then
				DBG "NOW_RAW=${B_NOW}"
				B_NOW=$( float_eval "(${B_RAW}*100)/${B_MAX}")
			fi
			;;
	esac

	# Step is 10% if light level is >20%
	float_cond "${B_NOW} > 20" && INCREMENT_STEP=10
	float_cond "${B_NOW} < 5" && INCREMENT_STEP=1
	
	
	
	DBG " <${B_MIN}-${B_MAX}>   ${B_NOW}% ${B_SET} ${INCREMENT_STEP}%"
	
	
	case "${METHOD}" in
		xbacklight)
			case "${B_SET}" in
				[0-9]*)
					[[ ${B_SET} -gt ${B_MAX} ]] && B_SET=${B_MAX}
					[[ ${B_SET} -le 0 ]] && B_SET=${B_MIN}
					PAR="-set ${B_SET}"
					;;
				tgl)
					if [ ${B_NOW} -le 1 ]; then
						PAR="-set ${B_MAX}"
					else
						PAR="-set ${B_MIN}"
					fi
					;;
					
				inc) PAR="-inc ${INCREMENT_STEP}" ;;
				dec) PAR="-dec ${INCREMENT_STEP}" ;;
				*) echo "UNHANDLED: ${1}" ;;
			esac
			
			DBG "|| xbacklight ${PAR}"
			xbacklight ${PAR}
			
			
			B_NOW=$(xbacklight -get | cut -d'.' -f1)
			;;
			
		file)		
			case "${B_SET}" in
				[0-9]*)
					PAR="${B_SET}"
					;;
				tgl)
					if [ ${B_NOW} -le 1 ]; then
						PAR="${B_MAX}"
					else
						PAR="${B_MIN}"
					fi
					;;
					
				inc) PAR=$(float_eval "${B_NOW}+${INCREMENT_STEP}") ;;
				dec) PAR=$(float_eval "${B_NOW}-${INCREMENT_STEP}") ;;
				*) echo "UNHANDLED: ${1}" ;;
			esac
			
			DBG " = ${PAR}%"
			# If not in range 0-100, recalculate...
			if [ ${B_MAX} -ne 100 ]; then
				PAR=$(float_eval "(${B_MAX}/100)*${PAR}")
			fi
			
			if float_cond "${PAR} == ${B_RAW}"; then				
				case "${B_SET}" in
					inc) PAR=$(float_eval "${PAR}+1") ;;
					dec) PAR=$(float_eval "${PAR}-1") ;;
				esac
				DBG "*"
			fi
			
			
			float_cond "${PAR} > ${B_MAX}" && PAR=${B_MAX}
			float_cond "${PAR} < ${B_MIN}" && PAR=${B_MIN}
			
			# Remove decimal part...
			PAR=${PAR/.[0-9]*/}
			
			DBG " => ${PAR}\n"
			
			DBG"|| ${PAR} >> CONTROL_FILE"
			echo "${PAR}" >> /sys/class/backlight/*/brightness
			
			
			B_NOW=$(cat /sys/class/backlight/*/actual_brightness | head -n1)
			
			# If not in range 0-100, recalculate...
			if [ ${B_MAX} -ne 100 ]; then
				B_NOW=$(float_eval "(${B_NOW}*100)/${B_MAX}")
			fi
			;;
	esac
	
	
	brigthness_notify "${B_NOW}" &
}


case "${1}" in
	[0-9]*) 	set_brightness "${1}" 	;;
	t|toggle) 	set_brightness "tgl" 	;;
	u|up) 		set_brightness "inc" 	;;
	d|down) 	set_brightness "dec" 	;;
	max) 		set_brightness 100 		;;
	min) 		set_brightness 0 		;;
		
	*h|*help) help ;;
	*)
		echo "Unknown command: '${1}'"
		echo 
		
		help
		;;
esac
