#!/system/bin/sh
#
# Copyright (C) 2026 The OrangeFox Recovery Project
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Based on: https://gitlab.com/OrangeFox/device/a33x/-/blob/fox_12.1/recovery/root/system/bin/runatboot.sh
#
# The OrangeFox settings are kept on /cache (see FOX_SETTINGS_ROOT_DIRECTORY
# in vendorsetup.sh), so they do not depend on /data being decrypted. Make
# sure it is mounted and has the folders OrangeFox expects.
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

# ---
prepare_cache_partition;
exit 0;
#
