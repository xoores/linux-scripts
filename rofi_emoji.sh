#!/bin/bash
#
# I don't really remember the origin of this but I believe that this 
# script is based on/heavily modified version of the same person that
# created the emoji cachefile [1]. I remember that I needed to rewrite
# clipboard handling in order for this to work correctly (i wanted things
# like restoring previous clipboard state etc...). The only thing I'm
# quite sure about is that I found original script through r/unixporn
#
# Also this script caches emojis from here [2] - you have to atleast once
# run this script with 'update' parameter to save emoji cache in ~/.cache
#
# Links:
#   1: https://gist.github.com/oliveratgithub
#   2: https://gist.github.com/oliveratgithub/0bf11a9aff0d6da7b46f1490f86a71eb
#
# Author: Xoores <whyxoores.cz>

EMOJI_CACHEFILE="${HOME}/.cache/emojis.json"

EMOJI_SOURCE_JSON="https://gist.github.com/0bf11a9aff0d6da7b46f1490f86a71eb.git"

CLIPBOARDS=("primary" "secondary" "clipboard" "buffer-cut")


function print_help()
{
    echo "Usage: $(basename "${0}") <ACTION>"
    echo ""
    echo " ACTIONS"
    echo "   rofi    - Show ROFI-based emoji picker"
    echo "   update  - Update emoji definition"
}

function cleanup()
{
    if [ ${#TMPDIR} -gt 0 ]; then
        [[ -d "${TMPDIR}" ]] && rm -rf "${TMPDIR}"
    fi

}

case "${1}" in

    rofi)
        if [ ! -f "${EMOJI_CACHEFILE}" ]; then
            echo "[!] Emoji cachefile not found, you should run:"
            echo "[!]   $(basename "${0}") update"
            exit 1
        fi

        EMOJI=$(jq -r \
            '.[] | "\(.emoji) \(.name) <\(.shortname)>"' \
            "${EMOJI_CACHEFILE}" | tr -d ':' |\
            rofi -dmenu -i -p "Which one?"\
                -color-normal "#393939, #ffffff, #393939, #268bd2, #ffffff" \
                -color-window "#393939, #268bd2, #268bd2")
        RET=$?

        echo "Picker finished (${RET}): ${EMOJI}"

        [[ "${RET}" -ne 0 ]] && exit 0

        PICKED=$(echo "${EMOJI}" | cut -d' ' -f1 | xargs)

        echo "PICKED='${PICKED}'"

        for CLIP in "${CLIPBOARDS[@]}"; do
            CLIPVAR="CLIP_OLD_${CLIP//-/}"
            
            # Save old clipboard content
            declare CLIP_OLD_"${CLIP//-/}"="$(xclip -selection "${CLIP}" -out)"
            echo " |- ${CLIP}: '${!CLIPVAR}'"
            
            # Set new clipboard content to our emoji
            echo -ne "${PICKED}" | xclip -selection "${CLIP}" -in
        done

        # Wait for just a little bit so original window can get focus back from
        # Rofi.
        sleep .1

        # Keeping it simple - might want to change this to SHIFT+INS because some
        # windows (terminals for example) might want to interpret CTRL+V differently
        xdotool key ctrl+v

        # Restore previous clipboard content
        for CLIP in "${CLIPBOARDS[@]}"; do
            CLIPVAR="CLIP_OLD_${CLIP//-/}"
            echo "${!CLIPVAR}" | xclip -selection "${CLIP}" -in
        done
    ;;

    update)
        trap cleanup EXIT

        TMPDIR=$(mktemp -d)
        if [ ! -d "${TMPDIR}" ]; then
            echo "[!] Failed to create temporary directory!"
            exit 1
        fi

        if ! git clone "${EMOJI_SOURCE_JSON}" "${TMPDIR}"; then
            echo "[!] Failed to clone Emoji source JSON!"
            exit 1
        fi

        if [ ! -f "${TMPDIR}/emojis.json" ]; then
            echo "[!] Cloned repo is missing emojis.json"
            exit 1
        fi

        EMOJI_COUNT_OLD=$(grep -c '"emoji":' "${EMOJI_CACHEFILE}")
        EMOJI_COUNT_NEW=$(grep -c '"emoji":' "${TMPDIR}/emojis.json")
        EMOJI_BACKUP_EXT="$(date "+%d%m%y_%H%M%S").json"
        EMOJI_BACKUP_NAME="${EMOJI_CACHEFILE//.json/}_${EMOJI_BACKUP_EXT}"

        echo "[+] New database has ${EMOJI_COUNT_NEW} (old had ${EMOJI_COUNT_OLD})"
        echo "[+] Backing up old database as ${EMOJI_BACKUP_NAME}.gz"

        if ! cp "${EMOJI_CACHEFILE}" "${EMOJI_BACKUP_NAME}"; then
            echo "[!] Failed to copy '${EMOJI_CACHEFILE}' -> '${EMOJI_BACKUP_NAME}'"
            exit 1
        fi

        if ! gzip -9 "${EMOJI_BACKUP_NAME}"; then
            echo "[!] Failed to compress backup file ${EMOJI_BACKUP_NAME}"
            exit 1
        fi


        if ! jq '[.emojis[] | {emoji,name,shortname}]' \
            /tmp/emojis.json > "${EMOJI_CACHEFILE}"; then
            echo "[!] Failed to filter out emojis.json and create cahcefile @ ${EMOJI_CACHEFILE}"
            exit 1
        fi

        echo "[+] Emoji database successfully updated :-)"
        ;;

    *h|*help) print_help ;;
    *)
        echo "Unknown action: '${1}'"
        print_help
        ;;
esac
