#!/system/bin/sh
#
# Copyright (C) 2026 The OrangeFox Recovery Project
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Based on: https://gitlab.com/OrangeFox/device/a33x/-/blob/fox_12.1/recovery/root/system/bin/runatboot.sh
#
# Run by OrangeFox at startup:
# - The OrangeFox settings are kept on /cache (see FOX_SETTINGS_ROOT_DIRECTORY
#   in vendorsetup.sh), so they do not depend on /data being decrypted. Make
#   sure it is mounted and has the folders OrangeFox expects.
# - Log which firmware set this build carries, and warn when the bootloader
#   is of another One UI generation.
#

# DEBUG mode?
DEBUG=0; # change to 0 for release builds
[ "$DEBUG" = "1" ] && set -o xtrace;

# log the messages
LOGMSG() {
  echo "I:$*" >> /tmp/recovery.log;
}

# test-phase log messages
TESTING_LOG() {
	[ "$DEBUG" = "1" ] && LOGMSG "$@";
}

is_mounted() {
	mountpoint -q "$1";
}

# prepare the partition
prepare_cache_partition() {
local FOX_DIR=/cache/Fox;

	if (! is_mounted "/cache"); then
		TESTING_LOG "Mounting the '/cache' partition";
		mount /cache 2>/dev/null;
	fi

	if (! is_mounted "/cache"); then
		LOGMSG "OrangeFox: the '/cache' partition could not be mounted. Settings will not persist.";
		return;
	fi

	mkdir -p $FOX_DIR/.theme;
	mkdir -p $FOX_DIR/.navbar;
	sync;

	TESTING_LOG "Setting permissions for the Fox folder in '/cache'";
	[ -x /sbin/set_media_rw ] && /sbin/set_media_rw $FOX_DIR/;
}

# Each build carries the kernel and modules of one One UI generation (a
# firmware set of the tree), and they only work with a bootloader of the
# same generation; with another one, touch does not work. Without touch the
# log is all there is to go on (adb pull /tmp/recovery.log), so say it there.
check_firmware() {
local fw=$(getprop ro.vendor.a15.firmware);
local want=$(getprop ro.vendor.a15.firmware.os);
local bootloader=$(getprop ro.boot.bootloader);
local os;

	[ -z "$fw" -o -z "$want" -o -z "$bootloader" ] && return;
	# the OS letter is the 4th character from the end: B in A155MUBS6BYE1
	os=$(echo "$bootloader" | sed -n 's/^.*\([A-Z]\)[A-Z0-9]\{3\}$/\1/p');
	[ -z "$os" ] && return;
	case "$want" in
		*"$os"*)
			LOGMSG "OrangeFox: $fw build ($(getprop ro.vendor.a15.firmware.build)), bootloader $bootloader";
		;;
		*)
			LOGMSG "OrangeFox: this is the $fw build, for OS $want bootloaders, but this bootloader is $bootloader (OS $os). Touch may not work: flash the build for this firmware.";
			echo "a15: $fw build on bootloader $bootloader (OS $os, not $want): touch may not work" > /dev/kmsg;
		;;
	esac
}

# ---
check_firmware;
prepare_cache_partition;
exit 0;
#
