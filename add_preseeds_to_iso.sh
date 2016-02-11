#!/bin/bash

# We follow these methods:
# https://wiki.debian.org/DebianInstaller/Preseed/EditIso
# https://wiki.debian.org/DebianInstaller/Modify/CD

# ------------------------------------------------

check_prerequisites() {
	if ! which 7z &> /dev/null; then
		echo "We need to have 7z installed." >&2
		exit 1
	fi

	if ! which xorriso &> /dev/null; then
		echo "We need to have xorriso installed." >&2
		exit 1
	fi
}

search_isolinux() {
	# Search for an isolinux isohdpfx.bin image
	# in the default locations and the content of
	# ISOLINUX_HINT.
	# If none is found at the usual locations
	# return 1

	for path in "$ISOLINUX_HINT" /usr/lib/ISOLINUX; do
		if [ -f "$path/isohdpfx.bin" ]; then
			ISOLINUX_BIN="$path/isohdpfx.bin"
			return 0
		fi
	done
	return 1
}

ask_for_locale() {
	# Ask user for the locale and keyboard layout he wishes to use
	#
	# Stores values in $LOCALE and $LAYOUT
	
	local QUERY
	if ! QUERY=$(setxkbmap -query); then
		LAYOUT="en"
	else
		LAYOUT="$(echo "$QUERY" | awk '
				/^layout:/ { printf $2 }
				# As far as I know the installer does not recognise this
				# /^variant:/ { printf "(" $2 ")" }
				END { print "" }
			')"
	fi

	read -p "Enter locale to use:           " -e -i "$LANG" LOCALE
	read -p "Enter keyboard layout to use:  " -e -i "$LAYOUT" LAYOUT
}

ask_for_authorised_keys() {
	# Ask user for the authorised keys to include as login keys for
	# the root user.
	#
	# Stores the concatinated content in AUTHORISED_KEYS


	echo "   You may store a number of ssh keys on the installation medium, "
	echo "   which may be used as the inital authorized_keys for root. "
	echo "   Enter them as a colon(:) separated list."

	local LINE

	for key in $HOME/.ssh/id_*.pub; do
		[ ! -f "$key" ] && continue
		if [ -z "$LINE" ]; then
			LINE="$key"
		else
			LINE="$LINE:$key"
		fi
	done

	read -p "Enter ssh key files:           " -e -i "$LINE" LINE

	AUTHORISED_KEYS=$(
		IFS=":"
		for key in $LINE; do
			if [ -r "$key" ]; then
				cat "$key"
			else
				echo "Key file not readable: $key" >&2
				return 1
			fi
		done
	)
}

copy_iso() {
	#$1: isofile
	# echos the dir where the extracted copy can be found
	# returns 1 if problems

	local ISO="$1"
	local EXTRACTDIR=$(mktemp -d)

	if ! 7z -o"$EXTRACTDIR" x "$ISO" >/dev/null; then
		echo "Error extracting iso file" >&2
		return 1
	fi

	# delete the [BOOT] folder
	rm -rf "$EXTRACTDIR/[BOOT]"

	echo "$EXTRACTDIR"
	return 0
}

add_preseed() {
	#$1 dir where extracted iso files are located.
	#
	# dumps the contents of the variable AUTHORISED_KEYS
	# for installation as the initial authorized keys for 
	# root.

	local EXTRACTDIR="$1"
	if [ ! -d "$EXTRACTDIR" ] ; then
		echo "Loopdir does not exist: $EXTRACTDIR" >&2
		return 1
	fi

	# top level dir where the preseed files are located
	local PRESEEDSDIR="preseeds"

	# sanity check: is the "menu begin advanced" there
	if ! < "$EXTRACTDIR/isolinux/menu.cfg" grep -q 'menu begin advanced'; then
		echo "\"$EXTRACTDIR/isolinux/main.cfg\" has an unknown format." >&2
		return 1
	fi

	# copy the preseedsdir over
	if ! rsync -a -H "$PRESEEDSDIR" "$EXTRACTDIR/"; then
		echo "Error copying the preseeds dir \"$PRESEEDSDIR\"" >&2
		return 1
	fi

	# copy the authorized_keys for root
	echo "$AUTHORISED_KEYS" > "$EXTRACTDIR/$PRESEEDSDIR/root_keys"

	# drop the locale.cfg
	echo "d-i  debian-installer/locale string $LOCALE" > "$EXTRACTDIR/$PRESEEDSDIR/parts/locale.cfg"
	echo "d-i  keyboard-configuration/xkb-keymap select $LAYOUT" >> "$EXTRACTDIR/$PRESEEDSDIR/parts/locale.cfg"
	
	local MENUFILE="menu_extra.cfg" # menu files
	if ! cp "$MENUFILE" "$EXTRACTDIR/isolinux/preseed.cfg"; then
		echo "Error copying the preseed menu: \"$MENUFILE\"" >&2
		return 1
	fi

	local SUBFILE="$EXTRACTDIR/isolinux/preseedsub.cfg"
	for preseedfile in $PRESEEDSDIR/*.cfg; do
		NAME=$(echo "$preseedfile" | sed "s/\.cfg$//; s#^$PRESEEDSDIR/##; s/[^a-zA-Z0-9]/_/g")
		cat <<-EOF
			label $NAME
			    menu label Preseed with $(basename "$preseedfile")
			    kernel /install.amd/vmlinuz
			    append auto=true file=/cdrom/$preseedfile preseed-md5=$(md5sum "$preseedfile" | cut -f 1 -d " ") priority=critical vga=788 initrd=/install.amd/initrd.gz --- quiet
		EOF
	done > "$SUBFILE"

	# finally enable the preseed stuff:
	sed --in-place "/^menu begin advanced/iinclude preseed.cfg" "$EXTRACTDIR/isolinux/menu.cfg"

	return 0
}

make_new_iso() {
	# Reads the global variable
	# 	ISOLINUX_BIN	the location of the isolinx binary to use 
	#			or "" if no isolinux boot image should be
	#			available.


	local LOOPDIR="$1"
	local ISOIMAGE="$2"

	local MBR=()
	if [ "$ISOLINUX_BIN" ]; then
		MBR=(-isohybrid-mbr "$ISOLINUX_BIN")
	fi

	OPTIONS=(
		#
		# Generic options
		# 
		# Output file
		-o "$ISOIMAGE" 
		#
		# Use long joliet (more than 64char filenames)
		# as well as Rock Ridge extension
		-J -r -joliet-long 
		#
		# ?? 
		-cache-inodes 
		#
		# Copy an ISOLINUX mbr template, which executes the boot image from BIOS
		# Also announce it as a GPT partition for booting via EFI and as MBR partition
		${MBR[@]}
		#
		# First boot option
		#
		# an legacy iso image
		-b isolinux/isolinux.bin -c isolinux/boot.cat -boot-load-size 4 -boot-info-table -no-emul-boot
		#
		# have another:
		-eltorito-alt-boot
		#
		# an efi iso image
		-e boot/grub/efi.img -no-emul-boot -isohybrid-gpt-basdat
	)

	# Be quiet if not in debug
	local DUMP=""
	[ "$DEBUG" != "y" ] && DUMP=">/dev/null"

	# run xorriso
	xorriso -as mkisofs "${OPTIONS[@]}" "$LOOPDIR" $DUMP
}

usage() {
	cat <<-EOF
	$(basename "$0") [ -h | --help | --debug | -d ] <iso>

	Add preseeds to a debian iso file. 

	--debug or -d causes debug files to be kept after the 
	script has run.
	EOF
}

# ------------------------------------------------

check_prerequisites

DEBUG=n
while [ "$1" ]; do
	case "$1" in
		-h|--help)
			usage
			exit 0
			;;
		-d|--debug)
			DEBUG="y"
			;;
		*)
			break
			;;
	esac
	shift
done
ISOFILE="$1"

if [ ! -f "$ISOFILE" ]; then
	echo "The first argument \"$ISOFILE\" is not a valid debian iso" >&2
	exit 1
fi

NEWISO="$(basename "$ISOFILE" ".iso")-preseeded.iso"
if [ -f "$NEWISO" ]; then
	echo "Output iso: $NEWISO already exists" >&2
	exit 1
fi

if ! search_isolinux; then
	echo "WARNING: Could not find ISOLINUX on the system" >&2
	echo "         Either install isolinux package or set ISOLINUX_HINT to" >&2
	echo "         the isolinux directory (e.g. /usr/lib/ISOLINUX)" >&2
	echo "" >&2
	echo "         Proceeding without ISOLINUX MBR image. Perhaps iso is not bootable ...">&2
fi

ask_for_locale || exit 1
echo
ask_for_authorised_keys || exit 1
echo
echo Please wait ...

if ! MODIFYDIR=$(copy_iso "$ISOFILE"); then
	echo "Error copying the iso: Is it a valid iso file?" >&2
	exit 1
fi

if ! add_preseed "$MODIFYDIR"; then
	echo "Error adding the preseed stuff." >&2
	exit 1
fi

if ! make_new_iso "$MODIFYDIR" "$NEWISO"; then
	echo "Creating new iso failed" >&2
	exit 1
fi

echo "Preseeded iso can be found in \"$NEWISO\"."
exit 0
