#!/system/bin/sh
#
#	This file is part of the OrangeFox Recovery Project
# 	Copyright (C) 2026 The OrangeFox Recovery Project
#
#	OrangeFox is free software: you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation, either version 3 of the License, or
#	any later version.
#
#	OrangeFox is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
# 	This software is released under GPL version 3 or any later version.
#	See <http://www.gnu.org/licenses/>.
#
# 	Please maintain this if you use this script or any part of it
#
# prepare_tee.sh start: let init start Samsung's TEE for /data decryption,
#                       reporting the installed firmware's versions to it
# prepare_tee.sh stop:  stop the TEE services and release efs
#
# The /data keys are bound to the Android version, the OS patch level and
# the vendor patch level. The keymint trusted app takes these from the
# keymint service, which reads them from ro.build.version.release,
# ro.build.version.security_patch and ro.vendor.build.security_patch; the
# values in the image header are only its fallback when those are missing
# or malformed. The boot patch level comes from vbmeta, the same partition
# Android boots with. So recovery sets the three properties to the installed
# firmware's values before keymint starts, and the TEE sees exactly what it
# sees under Android, whatever the firmware date. A TEE that saw newer
# levels than the keys were made with would upgrade them, and the installed
# firmware could no longer use them; if a value cannot be read, the TEE is
# not started and recovery goes on without decryption.
#

TAG="tee"
LOG=/tmp/tee.log
SYSTEM_DEV=/dev/block/mapper/system
VENDOR_DEV=/dev/block/mapper/vendor
SYSTEM_MNT=/mnt/tee_system
VENDOR_MNT=/mnt/tee_vendor
SERVICES="hermesd vendor.gatekeeper-1-0 vendor.fkeymaster-default vendor.keymint-default tzts_service tz_service"

log() {
	echo "$TAG: $*" > /dev/kmsg
	echo "$*" >> "$LOG"
}

# prop_of <build.prop> <name>
prop_of() {
	grep -m 1 "^$2=" "$1" 2>/dev/null | cut -d= -f2-
}

resetprop_bin() {
	for r in /system/bin/resetprop /sbin/resetprop; do
		[ -x "$r" ] && { echo "$r"; return; }
	done
}

cleanup() {
	umount "$SYSTEM_MNT" 2>/dev/null
	umount "$VENDOR_MNT" 2>/dev/null
}

# finish <state> <message>: ready starts the TEE (see init.recovery.teegris.rc)
finish() {
	cleanup
	log "$2"
	setprop vendor.recovery.tee_state "$1"
	exit 0
}

# mount_ro <device> <dir>: a few tries, the device-mapper node can show up
# a moment before it is ready
mount_ro() {
	mkdir -p "$2"
	for _try in 1 2 3 4 5; do
		mount -t erofs -o ro "$1" "$2" 2>/dev/null && return 0
		mount -t ext4 -o ro "$1" "$2" 2>/dev/null && return 0
		sleep 1
	done
	return 1
}

start_tee() {
	[ -n "$(getprop vendor.recovery.tee_state)" ] && exit 0

	# the logical partitions appear once OrangeFox has mapped super; the
	# TEE has to be up soon after, while OrangeFox waits for keymint
	i=0
	while [ ! -e "$SYSTEM_DEV" ] || [ ! -e "$VENDOR_DEV" ]; do
		[ "$i" -ge 300 ] && finish skipped "system/vendor were not mapped within 60 s; decryption off"
		sleep 0.2
		i=$((i + 1))
	done

	mount_ro "$SYSTEM_DEV" "$SYSTEM_MNT" || finish skipped "cannot mount the installed system; decryption off"
	mount_ro "$VENDOR_DEV" "$VENDOR_MNT" || finish skipped "cannot mount the installed vendor; decryption off"

	rom_release=$(prop_of "$SYSTEM_MNT/system/build.prop" ro.build.version.release)
	rom_spl=$(prop_of "$SYSTEM_MNT/system/build.prop" ro.build.version.security_patch)
	rom_vendor_spl=$(prop_of "$VENDOR_MNT/build.prop" ro.vendor.build.security_patch)
	rom_build=$(prop_of "$SYSTEM_MNT/system/build.prop" ro.build.version.incremental)
	log "installed: $rom_build, Android $rom_release, patch $rom_spl, vendor patch $rom_vendor_spl"

	# malformed values would make the trusted app fall back to the header
	echo "$rom_release" | grep -qE '^[0-9]+(\.[0-9]+){0,2}$' ||
		finish skipped "cannot read the installed Android version; decryption off"
	for v in "$rom_spl" "$rom_vendor_spl"; do
		echo "$v" | grep -qE '^20[0-9]{2}-[01][0-9]-[0-3][0-9]$' ||
			finish skipped "cannot read the installed patch levels; decryption off"
	done

	# what keymint reports to the TEE: the installed firmware's values, not
	# the recovery's own (Android 12, the build's patch level)
	rp=$(resetprop_bin)
	[ -n "$rp" ] || finish failed "resetprop is missing; decryption off"
	"$rp" ro.build.version.release "$rom_release"
	"$rp" ro.build.version.release_or_codename "$rom_release"
	"$rp" ro.build.version.security_patch "$rom_spl"
	"$rp" ro.vendor.build.security_patch "$rom_vendor_spl"

	# the trusted apps of the installed firmware, so they match its TEE
	if [ ! -d "$VENDOR_MNT/tee" ]; then
		finish failed "the installed vendor has no /vendor/tee; decryption off"
	fi
	rm -rf /vendor/tee
	if ! cp -a "$VENDOR_MNT/tee" /vendor/tee; then
		rm -rf /vendor/tee
		finish failed "copying the trusted apps failed; decryption off"
	fi

	finish ready "starting the TEE"
}

stop_tee() {
	for s in $SERVICES; do
		setprop ctl.stop "$s"
	done
	# wait for them to exit before releasing efs
	i=0
	while [ "$i" -lt 10 ]; do
		running=""
		for s in $SERVICES; do
			[ "$(getprop "init.svc.$s")" = "running" ] && running="$running $s"
		done
		[ -z "$running" ] && break
		sleep 1
		i=$((i + 1))
	done
	if grep -q " /mnt/vendor/efs " /proc/mounts; then
		if umount /mnt/vendor/efs; then
			log "TEE stopped, efs released"
		else
			log "TEE stopped, but efs is still busy"
		fi
	fi
	setprop vendor.recovery.tee_state stopped
}

case "$1" in
	start) start_tee ;;
	stop) stop_tee ;;
	*) echo "usage: $0 start|stop" >&2; exit 1 ;;
esac
exit 0
