#!/usr/bin/env bash
#shellcheck disable=SC2155,SC2034
#shellcheck source=/dev/null

#  /usr/share/bigbashview/bcc/apps/big-store/big-store-start.sh
#  Description: Big Store installing programs for BigLinux
#
#  Created: 2020/01/11
#  Altered: 2023/09/25
#
#  Copyright (c) 2023-2023, Vilmar Catafesta <vcatafesta@gmail.com>
#                2022-2023, Bruno Gonçalves <www.biglinux.com.br>
#                2022-2023, Rafael Ruscher <rruscher@gmail.com>
#  All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions
#  are met:
#  1. Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#  2. Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#
#  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
#  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
#  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
#  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
#  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
#  NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
#  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
#  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
#  THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

APP="${0##*/}"
_VERSION_="1.0.0-20230925"
export BOOTLOG="/tmp/bigstore-$USER-$(date +"%d%m%Y").log"
export LOGGER='/dev/tty8'
export HOME_FOLDER="$HOME/.bigstore"
export TMP_FOLDER="/tmp/bigstore-$USER"
export INI_FILE_BIG_STORE="$HOME_FOLDER/big-store.ini"
LIBRARY=${LIBRARY:-'/usr/share/bigbashview/bcc/shell'}
[[ -f "${LIBRARY}/bcclib.sh" ]] && source "${LIBRARY}/bcclib.sh"
[[ -f "${LIBRARY}/bstrlib.sh" ]] && source "${LIBRARY}/bstrlib.sh"
[[ -f "${LIBRARY}/tinilib.sh" ]] && source "${LIBRARY}/tinilib.sh"

function sh_config() {
	#Translation
	export TEXTDOMAINDIR="/usr/share/locale"
	export TEXTDOMAIN=big-store
	declare -g bigstorepath='/usr/share/bigbashview/bcc/apps/big-store'
	declare -g snap_cache_file="$HOME_FOLDER/snap.cache"
	declare -g flatpak_cache_file="$HOME_FOLDER/flatpak.cache"
	declare -g bigstore_icon_file='icons/icon.svg'
	declare -g TITLE="Big-Store"
	declare -gA Amsg=(
			[error_open]=$(gettext $"Outra instância do Big-Store já está em execução.")
			[error_access_dir]=$(gettext $"Erro ao acessar o diretório:")
	)
}

function sh_big_store_check_dirs {
	[[ ! -d "$HOME_FOLDER" ]] && mkdir -p "$HOME_FOLDER" "$TMP_FOLDER"
	[[ ! -d "$TMP_FOLDER" ]] && mkdir -p "$TMP_FOLDER"
}
export -f sh_big_store_check_dirs

function sh_check_big_store_is_running() {
	local PID

	if PID=$(pgrep -f 'Big-Store') && [[ -n "$PID" ]]; then
		#		notify-send -u critical --icon=big-store --app-name "$0" "$TITLE" "${Amsg[error_open]}" --expire-time=2000
		#		kdialog --title "$TITLE" --icon warning --msgbox "${Amsg[error_open]}"
		yad --title "$TITLE" --image=big-store --text "${Amsg[error_open]}\nPID:$PID" --button="OK":0
		exit 1
	fi
}

function sh_big_store_start_sh_main {
	local height
	local widht
	local half_height
	local half_widht
	local processamento_em_paralelo=1
	local ident_keys=1

	sh_big_store_check_dirs
	cd "$bigstorepath" || {
		notify-send --icon=big-store --app-name "$0" "$TITLE" "${Amsg[error_access_dir]}\n$bigstorepath" --expire-time=2000
		return 1
	}

	# reformat pretry .ini
	[[ -e "$INI_FILE_BIG_STORE" ]] && big-tini-pretty -q "$INI_FILE_BIG_STORE"
#	[[ -e "$INI_FILE_BIG_STORE" ]] && TIni.AlignIniFile "$INI_FILE_BIG_STORE"

	if TIni.Exist "$INI_FILE_BIG_STORE" "snap" "snap_active" '1' && [[ -e "/usr/lib/libpamac-snap.so" ]]; then
		[[ ! -e "$snap_cache_file" ]] || [[ "$(find "$snap_cache_file" -mtime +1 -print)" ]] && sh_update_cache_snap "$processamento_em_paralelo" &
	fi

	if TIni.Exist "$INI_FILE_BIG_STORE" "flatpak" "flatpak_active" '1' && [[ -e "/usr/lib/libpamac-flatpak.so" ]]; then
		[[ ! -e "$flatpak_cache_file" ]] || [[ "$(find "$flatpak_cache_file" -mtime +1 -print)" ]] && sh_update_cache_flatpak "$processamento_em_paralelo" &
	fi

	width=$(xrandr | grep -oP 'primary \K[0-9]+(?=x)')
	height=$(xrandr | grep -oP 'primary \K[0-9]+x\K[0-9]+')
	half_width=$((width / 2))
	half_height=$((height / 2))

	# Save dynamic screenshot resolution
	echo "$half_height" >"${TMP_FOLDER}/screenshot-resolution.txt"

	COMMON_OPTIONS="QT_QPA_PLATFORM=xcb SDL_VIDEODRIVER=x11 WINIT_UNIX_BACKEND=x11 GDK_BACKEND=x11 bigbashview -n \"$TITLE\" -s ${half_width}x${half_height}"
	if [[ -n "$1" ]]; then
		case "$1" in
		"category") eval "$COMMON_OPTIONS index.sh.htm?category=\"$2\"          -i $bigstore_icon_file" ;;
		"appstream") eval "$COMMON_OPTIONS view_appstream.sh.htm?pkg_name=\"$2\" -i $bigstore_icon_file" ;;
		"aur") eval "$COMMON_OPTIONS view_aur.sh.htm?pkg_name=\"$2\"       -i $bigstore_icon_file" ;;
		"flatpak") eval "$COMMON_OPTIONS view_flatpak.sh.htm?pkg_name=\"$2\"   -i $bigstore_icon_file" ;;
		"snap") eval "$COMMON_OPTIONS view_snap.sh.htm?pkg_id=\"$2\"        -i $bigstore_icon_file" ;;
		*) eval "$COMMON_OPTIONS index.sh.htm?search=\"$1\"            -i $bigstore_icon_file" ;;
		esac
	else
		eval "$COMMON_OPTIONS index.sh.htm -i $bigstore_icon_file"
	fi
}

#sh_debug
sh_config
sh_check_big_store_is_running
sh_big_store_start_sh_main "$@"
