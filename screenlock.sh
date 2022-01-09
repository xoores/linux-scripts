#!/bin/bash
#
# Script used as main screenlock interface.
#
# I use xss-lock with i3lock
#
# Author: Xoores <whyxoores.cz>

_LOG_NAME="screenlock"

. /scripts/_common.sh

#PARAM=(-e -c 303030 -f -n)

FONT="BitstreamVeraSansMono Nerd Font"
FONT_COLOR="FFFFFFAA"
GREETERS=("What now?" "Just leave" "Have a day" "But... why?" "Don't bother" "Too late" "Try to forget")
CONNECTED_DISPLAYS="$(xrandr | grep -c " connected ")"

# Pick random greeter
GREETER=${GREETERS[RANDOM%${#GREETERS[@]}]}


PARAM=(-fe --clock --indicator --inside-color=00000099 \
		--fill --image=/home/xoores/Pictures/wp_a/0ed2bfd1b896e404e23103bfc95d8cd2.jpg \
		--greeter-color=ffffffff --greeteroutline-color=000000aa \
		--greeteroutline-width=1 --greeter-pos="w/2:h/2-150" \
		--time-size=30 --greeter-size=50 --date-str="%A" \
		--noinput-text="(-_-)" \
		--wrong-text='Oi!' \
		--verif-text="Hmmm..."  \
		)

# Greeter should be displayed only if there is just the one screen
if [ "${CONNECTED_DISPLAYS}" -eq 1 ]; then
	PARAM+=(--greeter-text="${GREETER}")
fi

# Fonts...
PARAM+=(--time-font="${FONT}" --date-font="${FONT}" --layout-font="${FONT}" \
		--verif-font="${FONT}" --wrong-font="${FONT}" --greeter-font="${FONT}" )
		
# Font colors
PARAM+=(--time-color="${FONT_COLOR}" --date-color="${FONT_COLOR}" \
		--modif-color="${FONT_COLOR}" --layout-color="${FONT_COLOR}")

SCREENLOCK_TIMEOUT=300
#NOTIFY_BEFORE=10
NOTIFY_BEFORE=$((SCREENLOCK_TIMEOUT/10))
NOTIFY_TIMEOUT=$((SCREENLOCK_TIMEOUT-NOTIFY_BEFORE))

function on_useractivity()
{
	LOG_DBG "Dimmer killed[${PID_DIMMER}]: User activity detected..."
	kill "${PID_DIMMER}"
}

function on_screenlocked()
{
	LOG_DBG "Dimmer killed[${PID_DIMMER}]: Screen locked"
	kill "${PID_DIMMER}"
}

function configure_x()
{
		xset s "${NOTIFY_TIMEOUT}" "${NOTIFY_BEFORE}"
		xset s noblank
		xset +dpms
		xset dpms 0 0 $((5*SCREENLOCK_TIMEOUT))
}

function lock()
{
	if pgrep i3lock >/dev/null; then
		#LOG_DBG "Already locked, ignoring..."	
		return
	fi
	
	if [ ${UID} -eq 0 ]; then
		LOG_DBG "Should bootstrap ${0} to user"
		su -c "${0} lock" xoores
		exit
	fi

	dunstctl set-paused true
	
	LOG_INFO "Locking screen as UID ${UID}"
	if ! i3lock "${PARAM[@]}" >/dev/null 2>&1; then
		LOG_ERR "Failed to lock screen, trying again!"
		if ! i3lock -n >/dev/null 2>&1 ; then
			LOG_ERR "Failed to fail! Fuck..."
		fi
	fi
	

	LOG_INFO "Screen unlocked"
	dunstctl set-paused false
	configure_x
}


case "${1}" in
	start)
		LOG_DBG "Starting  [SCREENLOCK=${SCREENLOCK_TIMEOUT}s  NOTIFY=${NOTIFY_BEFORE}s->${NOTIFY_TIMEOUT}s]"
		
		# Just to be sure that our config works as expected!
		configure_x
		
        exec xss-lock \
						--notifier="${_THIS_SCRIPT} prepare" \
						-- \
						"${_THIS_SCRIPT}" activate &
		;;
		
	prepare)
		if pgrep i3lock >/dev/null; then
			exit 0
		fi
		
		LOG_DBG "Prepare fired..."
		
        trap 'on_useractivity' HUP  # user activity
        trap 'on_screenlocked' TERM # locker started
        
		/scripts/xss-dim --delay ${NOTIFY_BEFORE} &
		PID_DIMMER="${!}"
		
        wait
        exit 0
		;;
		
	*h|*help)
		echo "Usage: screenlock.sh [ACTION]"
		echo ""
		echo "  ACTIONS:"
		echo "    l|lock    - Lock screen"
		echo ""
		;;
		
	is-locked)
		pgrep i3lock >/dev/null
		;;
	
	activate) lock ;;
	

	*l|*lock) xset s activate ;;
	*) xset s activate ;;

esac
