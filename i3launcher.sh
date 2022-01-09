#!/bin/bash
#
# Small launcher based on Rofi. Have to document this but basically it 
# creates Rofi menus based on directory structure like this:
#
#  ls ~/.i3launcher 
#    00-  VirtualBox/
#    05-*  CPU scaling
#    05-*  CPU scaling.dynentry
#    25-  Media/
#    handler.sh
#  ls ~/.i3launcher/00-\ \ VirtualBox 
#    00-Win 7
#    05-Win 7 (new)
#    10-Alarm UD
#    15-iTunes
#    20-Linux dummy
#    handler.sh
#
# When you choose directory, it will enter it & display rofi based on that
# dirs content. If you choose simple file, it will look up the tree to look
# for handler.sh which will be executed & passed current path as params.
#
# Author: Xoores <whyxoores.cz>

# If we don't disable this, shellcheck will bitch aboud sourced .sh files...

# shellcheck disable=1091

source /scripts/_common.sh

LAUNCHER_ROOT="${HOME}/.i3launcher"


if [ ! -d "${LAUNCHER_ROOT}" ]; then
    fLog -p 2 "No launcher root directory found: '${LAUNCHER_ROOT}'"
    exit 1
fi

function run_handler()
{
  # If selected menu item is a file, it means that we have reached
    # the end of our menu journey and it is time to act!


    # First thing we need to do is prepare "normalized path", which
    # will be passed as parameters to handler of our menu item.
    #
    # "Normalized path" is basically for giving the handlers means to
    # easily distinguish different sub-menus by separating full menu
    # path to separate parameters. It strips numerics used to sort
    # menu items and every non-ASCII character. Parameter $1 is
    # always full and unchanged path! But wait, there's more: the
    # parameters passed in ${2} onwards are *relative* to the handler
    # so the handler does not have to worry if it is in level 4 or 5
    # in the menu itself! It will allways get items in its directory
    # as ${2} and first relative submenu items in ${3} etc!
    #
    # For example: item 00-aa/10-bb/14-cd will be passed to handler as
    # $1=00-aa/10-bb/14-cd  $2=a  $3=bb  $4=cd when handler is in 00-aa
    # If the handler is in 00-aa/10-bb, it will get the following:
    # $1=00-aa/10-bb/14-cd $2=cd
    declare -a PARAMS_RAW HANDLER_PARAMS
    #while read -r PATH_PART; do
    #    #[[ "${#PATH_PART}" -eq 0 ]] && continue
    #    PARAMS_RAW+=( "${PATH_PART}" )
    #    #echo "NORM> ${PATH_PART}"
    #done< <(echo -e "${CHOICE//\/[0-9][0-9]\-/\\n}" | grep -Po "[\x20-\x7F]*")

    readarray -s1 -td '' PARAMS_RAW < <(echo "${CHOICE//[![:ascii:]]/}/99-" | \
            awk '{ gsub(/\/[0-9]{2}\-[ ]*/, "\0"); print; }')
    unset "PARAMS_RAW[-1]";

    # Now there are 2 possibilities:
    #  1) The menu item itself is a runnable file
    #  2) The menu item is a plain file
    #
    # In (1) the item file is exeuted with normalized parameters (see
    # above). In the (2) situation we try to look up for executable
    # named handler in menu items directory. If there is none, we try
    # again in parent directory and again until we either find a real
    # handler (there should be atleast one global!) or we hit our root
    # path.
    #
    # In any case, if we run the file or handler, it will get full path
    # as an array of parameters. First parameter is always full and
    # unaltered path to the menu item, the rest is full path chopped
    # to individual bits (directories) and stripped of unnecessary
    # symbols (non-ASCII) and information (e.g. sorting numbers)
    
    if [ -x "${LAUNCHER_ROOT}/${CHOICE}" ]; then
        # shellcheck disable=2164,1090

        # The menu item can be a symlink as well pointing to some app
        # so if that is the case, we just run it and *DONT GIVE IT
        # ANY PARAMETERS* as we assume that it is a direct app that
        # might get confused by our args!
        #
        # Also some apps are quite picky and badly written and assume
        # that they are run from "their" directory - so we just cd into
        # their workdir (link target) and then run them from that point...
        if [ -L "${LAUNCHER_ROOT}/${CHOICE}" ]; then
            LINK_TARGET="$(readlink "${LAUNCHER_ROOT}/${CHOICE}")"
            cd "$(dirname "${LINK_TARGET}")"
            ./"$(basename "${LINK_TARGET}")" &
        else
            . "${LAUNCHER_ROOT}/${CHOICE}" "${PARAMS_RAW[@]}" &
        fi

        return
    fi

    HANDLER_DIR="${LAUNCHER_ROOT}/$(dirname "${CHOICE}")"
    HANDLER_LEVEL=${#PARAMS_RAW[@]}
    while [ "${HANDLER_LEVEL}" -ge 0 ] ; do
        let HANDLER_LEVEL--;

        HANDLER="${HANDLER_DIR}/handler.sh"
        #fLog -p 7 ">> Searching for handler: ${HANDLER_DIR}"

        HANDLER_PARAMS=( "${PARAMS_RAW[${HANDLER_LEVEL}]}" \
                         "${HANDLER_PARAMS[@]}" )

        # Found executable handler? Then run it!
        if [ -x "${HANDLER}" ]; then
			echo "Got handler: ${HANDLER}"
            # shellcheck disable=1090
            . "${HANDLER}" "${CHOICE}" "${HANDLER_PARAMS[@]}"
            return
        fi

        HANDLER_DIR="$(dirname "${HANDLER_DIR}")"
    done

    fLog -p 3 "No handler found for choice '${CHOICE}'"
    return	
}



function construct_menu()
{
	# Some global menu-related variables...
	MENU_COUNT=0        # Menu item counter
	MENU_INACTIVES=""   # List of "titles" (inactive menu elements)
	MENU_ENTRIES=""     # List of selectable (active) menu entries
	MENU_DYNENTRIES=0	# How many .dynentries we have

		
	# We have to prepare our menu, so we crawl selected directory for necessary
	# files (or LAUNCHER_ROOT if nothing else is specified)...
	while read -r ENTRY; do
		ENTRY_FULLPATH="${LAUNCHER_ROOT}/${1}/${ENTRY}"

		# Everything we find is by default a menu entry, which is stripped
		# of its sorting number (XX-) and prepended with 2 digit menu counter.
		MENU_NUM="$(printf "%02d" "${MENU_COUNT}")"
		MENU_ENTRY=" [${MENU_NUM}] ${ENTRY:3}"

		# Next we check for dirs (submenus)
		if [ -d "${ENTRY_FULLPATH}" ]; then
			# If a menu item is a directory, it means it is a submenu so
			# we append a nice icon to it... And if we are not in a root
			# menu, we make submenus BOLD so they stand out more
			[[ ${#1} -ne 0 ]] && MENU_ENTRY="<b>${MENU_ENTRY}</b> "
			# TODO: Add color: MENU_ENTRY+=" <span color='#66AbFF'></span>"
			MENU_ENTRY+=" "

			# If the name of an entry begins with '#' (e.g. XX-#something) it
			# means it is a title. Titles are inactive menu items used as
			# separators and cannot be used by the user...
		elif [[ "${ENTRY}" =~ ^[0-9]{2}-# ]]; then
			MENU_ENTRY="--- ${ENTRY:4}"
			MENU_INACTIVES+="${MENU_COUNT},"
		elif [[ "${ENTRY}" =~ ^[0-9]{2}-\* ]]; then
			MENU_ENTRY=" [${MENU_NUM}] ${ENTRY:4}"
		fi

		# Check if there is a runnable "xxx.dynentry" file, which can be
		# used to creating dynamically named entries - basically we append
		# the result (50 chars of first line only) to the entry name...
		if [ -x "${ENTRY_FULLPATH}.dynentry" ]; then
			DYNENTRY=$(bash "${ENTRY_FULLPATH}.dynentry" | head -n1 | head -c50)
			MENU_ENTRY+="${DYNENTRY}"
			let MENU_DYNENTRIES++
		fi
		
		
		# Now we construct our list of menu entries
		[[ ${#MENU_ENTRIES} -ne 0 ]] && MENU_ENTRIES+="\n"
		MENU_ENTRIES+="${MENU_ENTRY}"

		let MENU_COUNT++;
	done< <(find "${LAUNCHER_ROOT}/${1}/" -maxdepth 1 -mindepth 1 -name "[0-9]*" ! -name "*.dynentry" -printf "%f\n" | sort -n)


	# If there is a ".prompt" file, we load the first line and trim it to 20
	# characters if necessary.
	if [ -f "${LAUNCHER_ROOT}/${1}/.prompt" ]; then
		# TODO: Maybe we should crawl up the tree if there is no .prompt in
		#       the current directory and we could use one .prompt file
		#       for a whole subtree!
		MENU_PROMPT=$(head -n1 "${LAUNCHER_ROOT}/${1}/.prompt" | head -c20 )
	fi
}


construct_menu "${@}"

MENU_SELECTED="${2}"

# By this point we already have a full menu built, so we need to display it!
while [ "${CHOICE}" == "" ] ; do
    #RSP=$(echo -e "${MENU_ENTRIES}" | \
    #        rofi -dmenu -f -p "${MENU_PROMPT:-"Your choice?"}" \
    #        -format "d s" -select "${MENU_SELECTED}" -markup-rows -no-click-to-exit \
    #        -color-normal "#393939, #ffffff, #393939, #268bd2, #ffffff" \
    #        -color-window "#393939, #268bd2, #268bd2" \
    #        -u "${MENU_INACTIVES}" -no-custom)
             
    RSP=$(echo -e "${MENU_ENTRIES}" | \
            rofi -dmenu -i -f -p "${MENU_PROMPT:-"Your choice?"}" \
             -format "d s" -select "${MENU_SELECTED}" -markup-rows -no-click-to-exit \
             -theme xoores \
             -u "${MENU_INACTIVES}" -no-custom)
         
    RET=$?
    SEQ="$(echo "${RSP}" | awk '{print $1}')"
    echo "ROFI:  RET=${RET}  SEQ=${SEQ}  RSP='${RSP}'"

    # If ROFI returns 1, it means user pressed [ESC] or something similar
    if [ ${RET} -eq 1 ]; then
        # In that case we check whether we are at the top of the menu. If
        # we are on the top, we quit. Otherwise we just go 'up' one step.
        if [ ${#1} -eq 0 ] || [ "${1}" == "/" ]; then
            echo "Last level, quittin' time!"
        else
            LAUNCHER_UP="$(dirname "${1}")"
            [[ "${LAUNCHER_UP}" == "/" ]] && LAUNCHER_UP=""

            UP_MENUITEM="$(basename "${1}")"
            UP_MENUITEM="${UP_MENUITEM##[0-9][0-9]\-}"
            echo "Shall go one level up: '${LAUNCHER_UP}' to '${UP_MENUITEM}'"
            $0 "${LAUNCHER_UP}" "${UP_MENUITEM}"
        fi
        exit
    fi

    # Check whether the user has tried to choose the separator (title) or if
    # the user just mashed the keyboard and pressed enter... If this is the
    # case, we simply display the menu again to enable the user to make a
    # valid choice
    [[ "${RSP}" == *"---"* ]] || [ "${SEQ}" -eq 0 ] && continue

    # If we get to this point, the user made a valid choice. That means that
    # we need to get full name of the selected item (remember, we stripped the
    # sorting numbers etc). We use index given to us by ROFI which we stored
    # in variable ${SEQ}
    CHOICE="${1}/$(find "${LAUNCHER_ROOT}/${1}" -maxdepth 1 -mindepth 1 -name "[0-9]*" ! -name "*.dynentry" -printf "%f\n" | sort -n | sed "${SEQ}q;d")"
	
	# Check, whether our choice has "don't close menu" flag
	if [[ "${CHOICE}" =~ [0-9]{2,}-\* ]]; then
		run_handler
		
		# Reset choice = display the same menu again
		CHOICE=""
		
		# Since the entries might have changed, we use just substring.
		# TODO: Use actual line number instead of text...
		MENU_SELECTED="${RSP:3:8}"
		
		# Check if there are any dynentries and reconstruct the whole menu
		# if that's the case
		[[ ${MENU_DYNENTRIES} -gt 0 ]] && construct_menu
	fi
done


# If we get here, it means that user has made a valid choice and we have
# all the information we need for making things happen!

if [ -d "${LAUNCHER_ROOT}/${CHOICE}" ]; then
    # If selected menu item is a directory (== submenu), we re-run
    # this again with selected dir as a menu root...
    echo "Choice '${CHOICE}' is a SUBMENU!"
    $0 "${CHOICE}"
else
	run_handler
fi











if false; then	

    # If selected menu item is a file, it means that we have reached
    # the end of our menu journey and it is time to act!


    # First thing we need to do is prepare "normalized path", which
    # will be passed as parameters to handler of our menu item.
    #
    # "Normalized path" is basically for giving the handlers means to
    # easily distinguish different sub-menus by separating full menu
    # path to separate parameters. It strips numerics used to sort
    # menu items and every non-ASCII character. Parameter $1 is
    # always full and unchanged path! But wait, there's more: the
    # parameters passed in ${2} onwards are *relative* to the handler
    # so the handler does not have to worry if it is in level 4 or 5
    # in the menu itself! It will allways get items in its directory
    # as ${2} and first relative submenu items in ${3} etc!
    #
    # For example: item 00-aa/10-bb/14-cd will be passed to handler as
    # $1=00-aa/10-bb/14-cd  $2=a  $3=bb  $4=cd when handler is in 00-aa
    # If the handler is in 00-aa/10-bb, it will get the following:
    # $1=00-aa/10-bb/14-cd $2=cd
    declare -a PARAMS_RAW HANDLER_PARAMS
    #while read -r PATH_PART; do
    #    #[[ "${#PATH_PART}" -eq 0 ]] && continue
    #    PARAMS_RAW+=( "${PATH_PART}" )
    #    #echo "NORM> ${PATH_PART}"
    #done< <(echo -e "${CHOICE//\/[0-9][0-9]\-/\\n}" | grep -Po "[\x20-\x7F]*")

    readarray -s1 -td '' PARAMS_RAW < <(echo "${CHOICE//[![:ascii:]]/}/99-" | \
            awk '{ gsub(/\/[0-9]{2}\-[ ]*/, "\0"); print; }')
    unset "PARAMS_RAW[-1]";

    # Now there are 2 possibilities:
    #  1) The menu item itself is a runnable file
    #  2) The menu item is a plain file
    #
    # In (1) the item file is exeuted with normalized parameters (see
    # above). In the (2) situation we try to look up for executable
    # named handler in menu items directory. If there is none, we try
    # again in parent directory and again until we either find a real
    # handler (there should be atleast one global!) or we hit our root
    # path.
    #
    # In any case, if we run the file or handler, it will get full path
    # as an array of parameters. First parameter is always full and
    # unaltered path to the menu item, the rest is full path chopped
    # to individual bits (directories) and stripped of unnecessary
    # symbols (non-ASCII) and information (e.g. sorting numbers)
    
    if [ -x "${LAUNCHER_ROOT}/${CHOICE}" ]; then
        # shellcheck disable=2164,1090

        # The menu item can be a symlink as well pointing to some app
        # so if that is the case, we just run it and *DONT GIVE IT
        # ANY PARAMETERS* as we assume that it is a direct app that
        # might get confused by our args!
        #
        # Also some apps are quite picky and badly written and assume
        # that they are run from "their" directory - so we just cd into
        # their workdir (link target) and then run them from that point...
        if [ -L "${LAUNCHER_ROOT}/${CHOICE}" ]; then
            LINK_TARGET="$(readlink "${LAUNCHER_ROOT}/${CHOICE}")"
            cd "$(dirname "${LINK_TARGET}")"
            ./"$(basename "${LINK_TARGET}")" &
        else
            . "${LAUNCHER_ROOT}/${CHOICE}" "${PARAMS_RAW[@]}" &
        fi

        exit
    fi

    HANDLER_DIR="${LAUNCHER_ROOT}/$(dirname "${CHOICE}")"
    HANDLER_LEVEL=${#PARAMS_RAW[@]}
    while [ "${HANDLER_LEVEL}" -ge 0 ] ; do
        let HANDLER_LEVEL--;

        HANDLER="${HANDLER_DIR}/handler.sh"
        #fLog -p 7 ">> Searching for handler: ${HANDLER_DIR}"

        HANDLER_PARAMS=( "${PARAMS_RAW[${HANDLER_LEVEL}]}" \
                         "${HANDLER_PARAMS[@]}" )

        # Found executable handler? Then run it!
        if [ -x "${HANDLER}" ]; then
			echo "Got handler: ${HANDLER}"
            # shellcheck disable=1090
            . "${HANDLER}" "${CHOICE}" "${HANDLER_PARAMS[@]}"
            exit
        fi

        HANDLER_DIR="$(dirname "${HANDLER_DIR}")"
    done

    fLog -p 3 "No handler found for choice '${CHOICE}'"
    exit 1;
fi
