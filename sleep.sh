#!/bin/bash
#
# Put system to sleep + few routines I want to do before sleep/after
# wakeup.
#
# Author: Xoores <whyxoores.cz>


_LOG_NAME="sleeper"

. /scripts/_common.sh


T_WAIT=3
export DISPLAY=:0





function run_as_user()
{
	su -c "${1}" xoores
}


case "${1}" in
	new-window)
		exec kitty --class="SLEEPER" --title="Preparing for sleep" -- "${0}"
		exit
		;;
		
	"") true ;;

	*)
		echo "Unknown action '${1}'"
		#exit 1
		;;
esac

BOOTSTRAP_ROOT

/scripts/xrandr.sh INTERNAL_ONLY

echo "***** GOING TO SLEEP *****"
echo
echo


CONNECTIONS_ACTIVE=$(nmcli -t -f NAME conn show --active --order -type | egrep -v "(virbr)")
CONNECTIONS_COUNT=$(echo "${CONNECTIONS_ACTIVE}" | wc -l)

if [ "${CONNECTIONS_COUNT}" -gt 0 ]; then
	echo "[+] Shutting down connections"
	while read -r CONN; do
		echo -ne "     |- ${CONN}\t\t\t"
		
		case "${CONN}" in
			vnet*) 
				echo -e "\e[33;1m[SKIP]\e[0m"
				continue
				;;
		esac
		
		sleep .2
		RSP=$(nmcli conn down "${CONN}" 2>&1)
		RET=$?
		
		if [ ${RET} -eq 0 ]; then
			echo -e "\e[32;1m[ OK ]\e[0m"
		else
			echo -e "\e[31;1m[FAIL]\e[0m  (${RSP})"
		fi
	done <<< "${CONNECTIONS_ACTIVE}"
	
	echo
fi

echo -n "Sleep in "
for W in $(seq ${T_WAIT} -1 1); do
	echo -n " ${W}"
	sleep .5
done
echo
echo

echo "... Naptime ..."

killall picom 2>/dev/null


/scripts/screenlock.sh



LOG_INFO "Suspending to RAM"

# Sleep for fucks sake, not just "pretend to sleep". Took me like 3 days
# of screwing around and swearing profusely before I found the real
# reason why my notebook was cooking itself in my backpack...
echo deep > /sys/power/mem_sleep
echo 2000  > /sys/power/pm_freeze_timeout
echo "mem" > /sys/power/state
RET=$?

if [ ${RET} -ne 0 ]; then
	echo "Sleep failed with return code ${RET}"
	LOG_ERR "Failed to sleep with return code ${RET}"
	exit 1
fi

WAKEUP_REASON=$(dmidecode | grep Wake | cut -d':' -f2-)

LOG_NOTICE "Good morning :-) [REASON=${WAKEUP_REASON}]"


# Shut down WWAN & eth and enable WIFI
ifconfig eno2 down
nmcli radio wwan off
nmcli radio wifi on
/etc/init.d/iwd restart >/dev/null
#/etc/init.d/i8kmon restart >/dev/null

#run_as_user "pactl set-sink-mute 0 1"
xset dpms force on


/scripts/reload_yubi.sh >/dev/null 2>&1 &

nvme set-feature /dev/nvme{2,3} -f 0x2 -v 4

read -p "Hello!" X
