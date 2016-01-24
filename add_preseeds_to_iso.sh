#!/bin/bash

# We follow this method:
# https://wiki.debian.org/DebianInstaller/Preseed/EditIso

# ------------------------------------------------

check_prerequisites() {
	if ! which 7z &> /dev/null; then
		echo "We need to have 7z installed." >&2
		exit 1
	fi
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
	local LOOPDIR="$1"
	local ISOIMAGE="$2"

	genisoimage -o "$ISOIMAGE" -r -J -quiet -no-emul-boot -boot-load-size 4 -boot-info-table -b isolinux/isolinux.bin -c isolinux/boot.cat "$LOOPDIR"
}

# ------------------------------------------------

ISOFILE="$1"

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
	echo "First arg is the Debian iso file, second arg is the preseed file."
	exit 0
fi

check_prerequisites

if [ ! -f "$ISOFILE" ]; then
	echo "The first argument \"$ISOFILE\" is not a valid debian iso" >&2
	exit 1
fi

NEWISO="$(basename "$ISOFILE" ".iso")-preseeded.iso"
if [ -f "$NEWISO" ]; then
	echo "Output iso: $NEWISO already exists" >&2
	exit 1
fi

ask_for_locale || exit 1

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

rm -r "$MODIFYDIR"
echo "Preseeded iso can be found in \"$NEWISO\"."
exit 0
