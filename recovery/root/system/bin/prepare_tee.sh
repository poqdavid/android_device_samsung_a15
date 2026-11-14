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
#                       only if the installed firmware is the one this
#                       recovery was built for
# prepare_tee.sh stop:  stop the TEE services and release efs
#
# The /data keys are bound to the Android version and patch levels. If the
# TEE saw newer patch levels than the ones the keys were made with, it would
# upgrade them, and the installed (older) firmware could no longer use them.
# So the TEE only runs when the installed system and vendor have exactly the
# patch levels of this build (PLATFORM_SECURITY_PATCH); otherwise recovery
# goes on without decryption.
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

# what this recovery was built with (the file, not getprop, so nothing that
# changes properties at runtime can affect the check)
built_prop() {
	for f in /prop.default /system/etc/prop.default /vendor/build.prop; do
		v=$(prop_of "$f" "$1")
		[ -n "$v" ] && { echo "$v"; return; }
	done
	getprop "$1"
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
	our_spl=$(built_prop ro.build.version.security_patch)
	our_vendor_spl=$(built_prop ro.vendor.build.security_patch)
	log "installed: $rom_build, Android $rom_release, patch $rom_spl, vendor patch $rom_vendor_spl"
	log "recovery built for: patch $our_spl, vendor patch $our_vendor_spl"

	if [ -z "$rom_release" ] || [ -z "$rom_spl" ] || [ -z "$rom_vendor_spl" ]; then
		finish skipped "cannot read the installed firmware's version; decryption off"
	fi
	if [ "$rom_spl" != "$our_spl" ] || [ "$rom_vendor_spl" != "$our_vendor_spl" ]; then
		finish mismatch "the installed firmware has other patch levels than this recovery; decryption off"
	fi

	# keymint reads the Android version from this property; the build sets
	# it to the recovery's own (12)
	rp=$(resetprop_bin)
	[ -n "$rp" ] || finish failed "resetprop is missing; decryption off"
	"$rp" ro.build.version.release "$rom_release"
	"$rp" ro.build.version.release_or_codename "$rom_release"

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
