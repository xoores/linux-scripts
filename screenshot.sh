#!/bin/bash
#
# Main screenshot interface to be called from wherever
#
# Author: Xoores <whyxoores.cz>

# Active window:
# maim -i $(xdotool getactivewindow) ~/mypicture.jpg
#
# Full workspace:
# maim ~/Pictures/$(date +%s).png

function screenshot_selection()
{
	maim --hidecursor --select \
			--bordersize=5 --highlight --color=0.3,0.4,0.6,0.4 \
            | xclip -selection clipboard -t image/png
	notify-send -i camera-photo "Screenshot" "Saved to clipboard"
}

case "${1}" in

	*) screenshot_selection ;;
esac
