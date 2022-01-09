#!/bin/bash
#
# Based on [1]. Author of the original script also wrote very nice
# blogpost [2] that is worth reading as well.
#
#
# Links:
#  1: https://github.com/vincentbernat/i3wm-configuration/blob/master/bin/rofi-wifi
#  2: https://vincent.bernat.ch/en/blog/2021-i3-window-manager
#
# Author: Xoores <whyxoores.cz>

. /scripts/_common.sh

function rofi_opextra() { echo -en "\0${1}\x1f${2}\n"; }
function rofi_menuitem() { echo -en "${1}"; rofi_opextra "info" "${2}"; }


function create_menu()
{
	WIFI_ENABLED=0
	[[ "$(nmcli radio wifi)" == "enabled" ]] && WIFI_ENABLED=1
	
	rofi_opextra "prompt" "WIFI"
	rofi_opextra "markup-rows" "true"
	rofi_opextra "no-custom" "true"
	
	
	if [ "${WIFI_ENABLED}" -eq 1 ]; then
			rofi_menuitem "<b></b>  Refresh (5s)" "refresh"
			rofi_menuitem "<b></b>  Copy wifi info to clipboard" "clipboard"
	else
			rofi_menuitem "<span color=\"green\"><b>Enable WIFI</b></span>" "on"
	fi
	rofi_menuitem "<span color=\"green\"><b></b> Edit connections</span>" "edit"
	

	# todo: mac identify
	nmcli -f IN-USE,SSID,BSSID,SECURITY,FREQ,SIGNAL,CHAN -m multiline device wifi list --rescan no \
	| sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' \
	| awk -F': *' '{
					 property=$1;
					 value=gensub(property ": *", "", 1);
					 p[property]=value;
				   }
				   ($1 == "SIGNAL") {
					 if (p["IN-USE"] == "*") {
					   printf("Connected to <i>%s</i> (%s%%)         \r" \
							  "<small><i>%s, AP %s @ %s</i></small>\n",
							  p["SSID"], p["SIGNAL"], p["SECURITY"], p["BSSID"], p["FREQ"]) > "/dev/stderr";
					 } else {
					   chan = p["CHAN"] ? " @ ch" p["CHAN"] : ""
					   printf("<b>%s</b> " \
							  "<span>" \
							  "(<i><small>%s, %s%s</small></i>)</span>",
							  p["SSID"], p["SECURITY"], p["BSSID"], chan);
					   signal=p["SIGNAL"]
					   printf("\00info\x1f%s\x1ficon\x1fnm-signal-%s%s\n",
							  p["BSSID"],
							  (signal > 75)?"100":\
							  (signal > 50)?"75":\
							  (signal > 25)?"50":\
							  "00",
							  (p["SECURITY"] == "--")?"":"-secure");
					 }
				   }' 2>/tmp/rofi.tmp 
	
	#if [ "${WIFI_ENABLED}" -eq 1 ]; then
	#	rofi_menuitem "<span color=\"red\"><b>睊</b>  Disable WIFI</span>" "off"
	#	rofi_menuitem "<span color=\"blue\"><b></b>  Switch to LTE</span>" "lte"
	#fi
	
	rofi_opextra "message" "$(cat /tmp/rofi.tmp)"
}



case "${1}" in
	clipboard)
			iwctl station wlan0 show | uncolor | xclip -selection clipboard
			exit
		;;
		
	rescan)
		(
			touch /tmp/wifiscan
			#dunstify "Wifi scanning" "Please wait, this can take ~20s" --timeout=60000 --replace=9999 --urgency=critical
			#>/dev/null nmcli device wifi list --rescan yes
			nmcli device wifi rescan
			sleep 5
			#>/dev/null nmcli device wifi list --rescan yes
			#dunstify "Wifi scanning" "Done :-)" --timeout=3000 --replace=9999
			rm /tmp/wifiscan
		) &
		exit
		;;
esac


function cleanup()
{
	dunstify "end" --timeout=1000
}


# ROFI_RETV is set like this:
# - 0: Initial call of script
# - 1: Selected an entry
# - 2: Selected a custom entry
# - 10-28: Custom keybinding 1-19 (need to be explicitly enabled by script)
case "${ROFI_RETV}" in
    0) create_menu ;;
		
	1)
		case "${ROFI_INFO}" in
			clipboard)
					>/dev/null "${0}" clipboard &
				;;
				
			edit)
					>/dev/null nm-connection-editor &
				;;
				
			refresh)
				# Trigger rescan :-)
				if [ ! -f /tmp/wifiscan ]; then
					>/dev/null "${0}" rescan &
				fi
			
				create_menu
				
				MSG="$(cat /tmp/rofi.tmp)"
				if [ -f /tmp/wifiscan ]; then
					#MSG+="   <span color=\"red\"><b>[SCANNING]</b></span>"
					MSG="$(cat /tmp/rofi.tmp | sed -e "s|\r|<span color=\"red\"><b>[SCANNING]</b></span>\r|g")"
				else
					MSG="$(cat /tmp/rofi.tmp)"
				fi
				
				MSG+="\r<i><small>Updated @ $(date +%T)</small></i>"
				
				
				rofi_opextra "message" "${MSG}"
				;;
			
				on)
					>&2 nmcli radio wifi on
					>/dev/null nmcli device wifi list --rescan yes
					;;
				off)
					>&2 nmcli radio wifi off
					;;
				*)
					>&2 nmcli -w 0 device wifi connect ${ROFI_INFO}
					;;
		esac
		;;
		
	*) 
		trap 'cleanup' INT TERM EXIT RETURN HUP QUIT ALRM USR1
		
		exec rofi  -show-icons -modi "wifi:$0" -show wifi \
					-hover-select -me-select-entry '' -me-accept-entry MousePrimary \
					-timeout-delay 5 -timeout-action "kb-select-1"
		;;
esac
