#!/bin/bash
#
# Small script for my Polybar - it pings 1 network host of choice and 
# default gateway and returns icons/info about the result.
#
# There is some floating average being calculated so the small anomalies
# don't disturb us that much...
#
# Author: Xoores <whyxoores.cz>

. /scripts/_common.sh

# Host of choice in the internet...
NET_HOST="8.8.8.8"

# How many samples to keep for AVG
AVG_SAMPLES=5

PAUSEFILE="/tmp/.pingnet.paused"

function get_average()
{
    # Get remaining time (charge/discharge) and calculate minues so we can
    # do averages easily...
    AVGFILE="${1}"
    SAMPLE="${2}"

    # Add our sample to sample log (I'd suggest somewhere on TMPFS)
     [[ ${DBG} -eq 0 ]] && echo ${SAMPLE} >> "${AVGFILE}"

    # Calculate average from that file (BC for rounding)
    AVERAGE=$(awk '{ total += $1; count++ } END { print total"/"count }' "${AVGFILE}" | bc)
    
    # Trim to have only X lines for AVG...
    echo "$(tail -${AVG_SAMPLES} "${AVGFILE}" 2>/dev/null)" > "${AVGFILE}"

	echo "${AVERAGE}"
}


function do_ping()
{
	MS="$(ping -c1 -W1 "${@}" 2>&1)"
	RET=${?}
	
	[[ ${RET} -ne 0 ]] && return ${RET}
	
	echo "${MS}" | awk '$1~/rtt/{print $4; exit}' | cut -d'/' -f2 | cut -d'.' -f1
	return 0
}

case "${1}" in
	toggle)
		if [ -f "${PAUSEFILE}" ]; then
			notify-send --expire-time=3000 --icon=media-playback-start "Pingnet resumed"
			rm "${PAUSEFILE}"
		else
			notify-send --expire-time=3000 --icon=media-playback-pause "Pingnet paused"
			touch "${PAUSEFILE}"
		fi
		;;
		
	polybar)
		if [ -f "${PAUSEFILE}" ]; then
			echo -ne " %{F#ff0} %{F-} "
			exit 0
		fi
		
		GW=$(route -n | awk '$4~/G/{print $2; exit}')
		
		if [ "${GW}" == "0.0.0.0" ] || [ ${#GW} -eq 0 ]; then
			echo -ne " %{F#aaa}%{F-} "
			rm "/tmp/quad8.avg" "/tmp/gw.avg" >/dev/null 2>&1
			exit 0
		fi
		
		if VAL=$(do_ping "${NET_HOST}"); then
			NET_ICON=""
			NET_COLOR="#0f0"
			AVG="$(get_average "/tmp/quad8.avg" "${VAL}")"
			
			if [ ${AVG} -gt 200 ]; then
				NET_COLOR="#ff0"
				NET_ICON+=" [${AVG}ms]"
			fi
		else
			NET_COLOR="#f00"
			NET_ICON=""
		fi
		
		
		if VAL=$(do_ping "${GW}"); then
			GW_ICON=""
			GW_COLOR="#0f0"
			AVG="$(get_average "/tmp/gw.avg" "${VAL}")"
			
			if [ ${AVG} -gt 100 ]; then
				GW_COLOR="#ff0"
				GW_ICON+=" [${AVG}ms]"
			fi
		else
			GW_COLOR="#f00"
			GW_ICON=""
		fi
			
		echo -ne " %{F${NET_COLOR}}${NET_ICON}%{F-} "
		echo "%{F${GW_COLOR}}${GW_ICON}%{F-} "
		;;
esac
