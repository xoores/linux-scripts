#!/bin/bash
#
# Common functions - this file is meant to be included basically in every
# script I create. By default I keep all scripts are in /scripts/
#
# Author: Xoores <whyxoores.cz>


_THIS_SCRIPT="$(readlink -f "${0}")"


function uncolor()
{
	sed -r "s/[[:cntrl:]]\[([0-9]{1,3};)*[0-9]{1,3}m//g"< /dev/stdin
}


# $1 = <optional> Message
# $2 = <optional> Color
function polybar_vpn()
{
	[[ ${#XDG_RUNTIME_DIR} -eq 0 ]] && XDG_RUNTIME_DIR="/run/user/1000"
	COLOR="#aaa"
	[[ ${#1} -ne 0 ]] && COLOR="#0f0"
	[[ ${#2} -ne 0 ]] && COLOR="${2}"
	
	
	echo -n " %{A2:/scripts/net.sh vpn toggle:}%{F${COLOR}}" > "${XDG_RUNTIME_DIR}/i3/connection_vpn"
	echo -n "%{T1}%{T-}" >> "${XDG_RUNTIME_DIR}/i3/connection_vpn"
	
	[[ ${#1} -ne 0 ]] && echo -n " ${1}" >> "${XDG_RUNTIME_DIR}/i3/connection_vpn"
	
	echo -n "%{F-}%{A} " >> "${XDG_RUNTIME_DIR}/i3/connection_vpn"
	
	echo "action:#connection_vpn.send.$(cat "${XDG_RUNTIME_DIR}/i3/connection_vpn")" > /tmp/polybar_mqueue.*			
}



# DUNST:
#  - 9000 = vpn
#  - 9010 = volume
#  - 9020 = brightness

function BOOTSTRAP_ROOT()
{
	if [ ${UID} -ne 0 ]; then
		sudo "${0}" "${@}"
		exit
	fi
}

function LOG()
{
	[[ ${#_LOG_NAME} -eq 0 ]] && _LOG_NAME="$(basename "${0}")"
	logger --id=$$ -s -t "${_LOG_NAME}" "${@}"
	
	# [[ -z ${_LOG_STDOUT} ]] && echo "$(date "+%D %T")> ${@}"
}

function LOG_ERR()    { LOG -p3 "${@}"; }
function LOG_WARN()   {	LOG -p4 "${@}"; }
function LOG_NOTICE() {	LOG -p5 "${@}"; }
function LOG_INFO()   { LOG -p6 "${@}"; }
function LOG_DBG()    { LOG -p7 "${@}"; }


function LLOG()
{
	echo -e "$(date "+%D %T")>  ${*}"
}

function LLOG_N()
{
	echo -ne "$(date "+%D %T")>  ${*}"
}

# Save password with:
#    secret-tool store --label="Nice description" id ID_I_WANT
function getSecret()
{
    secret-tool lookup id "${1}"
}


#####################################################################
# FPO math taken from [1] because I can't be bothered enough to re-invent
# the BC wheel :-) I kinda cleaned it up a bit though...
#
# Use like this:
#   X=$(float_eval "100.4 / 4.2 + 3.2 * 6.5")
#   
#   if float_cond "${X} > 9.3"; then
#		blah blah
#   fi
#
#  [1] https://www.linuxjournal.com/content/floating-point-math-bash

# Default scale used by float functions.


# Evaluate a floating point number expression.
function float_eval()
{
    R=0
    RES=0.0
	FLOAT_SCALE=2
    
    if [ ${#} -gt 0 ]; then
        RES=$(bc -q 2>/dev/null <<<"scale=${FLOAT_SCALE}; ${*}" )
        R=${?}
        [[ ${R} -eq 0  &&  -z "${RES}" ]] && R=1;
    fi
    
    echo "${RES}"
    return ${R}
}

# Evaluate a floating point number conditional expression.
function float_cond()
{
    C=$(float_eval "${@}")
    #C=0
    #if [ ${#} -gt 0 ]; then        
    #    C=$(bc -q  2>/dev/null <<<"${*}")
    #    [[ -z "${C}" ]] && C=0
    #    [[ "${C}" -ne 0  &&  "${C}" -ne 1 ]] && C=0
    #fi
    
    return $((C == 0))
}

# Some very basic & lazy testing routines I made when I was cleaning up
# those float_ functions... Have fun with them.
function float_check_result()
{
	RESULT=$(float_eval "${1}")
	
	echo -ne "${1} = ${RESULT}"
	
	if [ "${RESULT}" != "${2}" ]; then
		echo -e "  [ FAIL ]\n  expected '${2}', got '${RESULT}'"
		return 1
	fi
	
	echo "  [PASSED]"
}

function float_test()
{
	FAIL=0
	float_check_result "1.1 * 2" 			"2.2"  	|| let FAIL++;
	float_check_result "1.1 * 2.1" 			"2.31" 	|| let FAIL++;
	float_check_result "1.1 < 2.1" 			"1" 	|| let FAIL++;
	float_check_result "1.1 >= 2.1" 		"0" 	|| let FAIL++;
	float_check_result "2*3*0.1 > 1*3.2" 	"0" 	|| let FAIL++;
	
	if [ ${FAIL} -gt 0 ]; then
		echo "Not passed, ${FAIL} failed :-("
	else
		echo "All tests passed"
	fi
}


# Connect to RDP session
# $1  MANDATORY     Server addres
# $2  MANDATORY     Username/Login
# $3  OPTIONAL      Password
# $4  OPTIONAL      Server alias (for nicer logs)
# -- DEPRECATED
function rdpConnect()
{
	/scripts/rdpConnect.sh "${@}"
}

function sshTerminal()
{

	if ! pgrep gpg-agent>/dev/null; then
		gpg-agent --options /home/xoores/.gnupg/gpg-agent.conf --daemon >! "${HOME}/.gnupg/.env" 2>/dev/null
	fi
	
	[[ -f "${HOME}/.gnupg/.env" ]] && source "${HOME}/.gnupg/.env"


    SSH_HOST="${1//*@/}"
    SSH_ALIAS="${SSH_HOST}"

    [[ ${#3} -ne 0 ]] && SSH_ALIAS="${3}"

    logger -p6 -t "SSHconnect" "${SSH_ALIAS}> Trying to connect to '${SSH_HOST}'"
    
	kitty --class="SSH-${SSH_ALIAS}" -- ssh -v -oStrictHostKeyChecking=no "${1}"	
	RET=$?

    case "${RET}" in
        0)      ERROR="SSH_CLOSED_GRACEFULLY"       ;;
        1)      ERROR="CONNECTION_CANCELLED"        ;;
        5)      ERROR="PERMISSION_DENIED"           ;;
        6)      ERROR="UNKNOWN_RSA_FINGERPRINT"     ;;
        255)    ERROR="SSH_CANNOT_CONNECT"          ;;
        *)      ERROR="UNKNOWN"                     ;;
    esac

    logger -p6 -t  "SSHconnect" "${SSH_ALIAS}> SSH finished with return code '${RET}' (${ERROR})"
    echo
    read -p "Press <ENTER> to close this window..."
}


# Connect to SSH server
# $1  MANDATORY     Server connection string
# $2  OPTIONAL      Password
# $3  OPTIONAL      Server alias (for nicer logs)
# $4  OPTIONAL      SSH command (only with password...)
function sshConnect()
{
    SSH_HOST="${1//*@/}"
    SSH_ALIAS="${SSH_HOST}"

    [[ ${#3} -ne 0 ]] && SSH_ALIAS="${3}"

    logger -p6 -t "SSHconnect" "${SSH_ALIAS}> Trying to connect to '${SSH_HOST}'"
    
    # GnuPG SSH agent
	[[ -f "${HOME}/.gnupg/.env" ]] && source "${HOME}/.gnupg/.env"
	
    if ! ssh-add -L | grep -qc "cardno"; then
		sudo /scripts/reload_yubi.sh
	fi
		
	if ! pgrep gpg-agent>/dev/null; then
		gpg-agent --options "${HOME}/.gnupg/gpg-agent.conf" --daemon >! "${HOME}/.gnupg/.env" 2>/dev/null
	fi

	[[ -f "${HOME}/.gnupg/.env" ]] && source "${HOME}/.gnupg/.env"
	
	

    if [ ${#2} -eq 0 ]; then
        kitty --class="SSH-${SSH_ALIAS}" -- /scripts/ssh.py "${1}"
        RET=$?
    else
        #SSHPASS="${2}" termite -e "sshpass -e ssh ${1}"
        SSHPASS="${2}" termite -e "/scripts/autoSSH.sh '${1}' '${SSH_ALIAS}' '${4}'"
        RET=$?
    fi

	PRIO=6
	[[ ${RET} -ne 0 ]] && PRIO=3
	
    case "${RET}" in
        0)      ERROR="SSH_CLOSED_GRACEFULLY"       ;;
        1)      ERROR="CONNECTION_CANCELLED"        ;;
        5)      ERROR="PERMISSION_DENIED"           ;;
        6)      ERROR="UNKNOWN_RSA_FINGERPRINT"     ;;
        255)    ERROR="SSH_CANNOT_CONNECT"          ;;
        *)      ERROR="UNKNOWN"                     ;;
    esac
    
    
	[[ ${RET} -ne 0 ]] && notify-send "${SSH_ALIAS} failed" "Failed to connect: ${ERROR}"

    logger -p"${PRIO}" -t  "SSHconnect" "${SSH_ALIAS}> SSH finished with return code '${RET}' (${ERROR})"
    echo
    read -p "Press <ENTER> to close this window..."
}



function mediaPlay()
{
    PLAYER="mpv"

    case "${1}" in
        --vlc)
            shift
            PLAYER="vlc"
            ;;
    esac

    if [ -d "${1}" ] || [ -f "${1}" ]; then
        case "${PLAYER}" in
            mpv)
                mpv --cache-secs=30 --shuffle --volume=100 \
                    --loop-playlist "${@}" &
                ;;

            vlc)
                vlc --random --loop "${@}" &
        esac

        return 0
    else
        notify-send -t 4000 -i "gtk-dialog-warning" "Cesta nedostupná" "${V_PATH}"
        return 1
    fi
}
