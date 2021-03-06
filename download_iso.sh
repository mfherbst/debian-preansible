#!/bin/bash

download_and_verify() {
	local ISO="$1"

	BASEURL=$( dirname "$ISO" )
	BASENAME=$( basename "$ISO" )

	wget --continue "$ISO" || return 1
	echo

	wget --continue "$BASEURL/SHA512SUMS.sign" || return 1
	echo

	wget --continue "$BASEURL/SHA512SUMS" || return 1
	echo

	gpg --verify SHA512SUMS.sign || return 1
	echo

	if ! < SHA512SUMS grep "$BASENAME" | sha512sum --quiet -c -; then
		echo "sha512sum signature check of  $BASENAME failed."
		return 1
	else
		echo "sha512sum signature verification successful."
		return 0
	fi
}

# ------------------------------------------------

if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
	echo "Downloads a debian iso and verifies it." 
	echo "Supply the url to the iso as first argument."
	exit 0
fi

ISO="$1"
download_and_verify "$ISO"
