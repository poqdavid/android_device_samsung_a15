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
#                       with the installed firmware's TEE files, reporting
#                       its versions
# prepare_tee.sh stop:  stop the TEE services and release efs
# prepare_tee.sh fallback [reason]: turn decryption off and restart
#                       OrangeFox now (for testing)
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
# not started.
#
# Without the TEE, keystore2 keeps aborting for want of keymint, and
# OrangeFox, which waits for keystore2 before it decrypts /data, stays on
# its splash screen. So if the TEE cannot be started, or OrangeFox does not
# get past decrypting /data in time, decryption is turned off for this
# boot: OrangeFox takes its /data flags from the installed vendor's fstab,
# and ro.boot.fstab_suffix points it at a copy of the recovery fstab
# without the encryption flags instead. The logs are saved to
# /cache/Fox/tee and OrangeFox is restarted if it is still stuck. /data
# then shows as not mountable; the next boot tries again.
#
# OrangeFox mounts the installed vendor over /vendor for a moment while it
# starts, to read its build.prop and fstab, at about the time the TEE files
# are copied. Anything written to /vendor meanwhile lands on that read-only
# mount and fails, so the files are only copied while /vendor is the
# ramdisk's, and copied again if OrangeFox mounted over it in the meantime.
#

TAG="tee"
LOG=/tmp/tee.log
SYSTEM_DEV=/dev/block/mapper/system
VENDOR_DEV=/dev/block/mapper/vendor
SYSTEM_MNT=/mnt/tee_system
VENDOR_MNT=/mnt/tee_vendor
LIST=/vendor/etc/tee-files.list
NOCRYPT_SUFFIX=fox_nocrypt
NOCRYPT_FSTAB=/system/etc/fstab.$NOCRYPT_SUFFIX
SAVED_LOGS=Fox/tee
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

# finish <state> <message>: ready starts the TEE (see init.recovery.teegris.rc);
# anything else turns decryption off
finish() {
	cleanup
	log "$2"
	setprop vendor.recovery.tee_state "$1"
	if [ "$1" = ready ]; then
		watch_startup 40
	else
		fallback "" 10
	fi
	exit 0
}

# fox_started: OrangeFox loads its UI only once it is past decrypting /data
fox_started() {
	grep -q 'Loading package: OrangeFox' /tmp/recovery.log 2>/dev/null
}

# watch_startup <seconds>: turn decryption off if OrangeFox is not past
# decrypting /data in time
watch_startup() {
	t=0
	while [ "$t" -lt $(($1 * 5)) ]; do
		fox_started && return 0
		sleep 0.2
		t=$((t + 1))
	done
	fallback "OrangeFox did not get past decrypting /data within $1 s" 0
}

# save_logs: this boot's TEE, OrangeFox, kernel and logcat logs to
# /cache/Fox/tee, where OrangeFox keeps its settings
save_logs() {
	mnt=""
	if grep -q '^[^ ]* /cache ' /proc/mounts; then
		dir=/cache/$SAVED_LOGS
	else
		mnt=/mnt/tee_cache
		mkdir -p "$mnt"
		if ! mount -t ext4 /dev/block/by-name/cache "$mnt" 2>/dev/null; then
			log "cannot mount cache; logs not saved"
			return
		fi
		dir=$mnt/$SAVED_LOGS
	fi
	log "saving the logs to /cache/$SAVED_LOGS"
	mkdir -p "$dir"
	cp /tmp/tee.log "$dir/tee.log" 2>/dev/null
	cp /tmp/recovery.log "$dir/recovery.log" 2>/dev/null
	dmesg > "$dir/dmesg.txt" 2>/dev/null
	logcat -d > "$dir/logcat.txt" 2>/dev/null
	sync
	[ -n "$mnt" ] && umount "$mnt"
}

# hide_decryption [reason]: OrangeFox reads its /data and /metadata flags
# from the first fstab.<suffix> it finds, trying fstab_suffix before
# hardware (mt6789, the installed vendor's fstab); with the suffix set, it
# finds the copy without encryption flags first. Fails if it is off already.
hide_decryption() {
	[ "$(getprop vendor.recovery.decrypt)" = off ] && return 1
	log "turning decryption off${1:+: $1}"
	rp=$(resetprop_bin)
	if [ -z "$rp" ]; then
		log "resetprop is missing; cannot turn decryption off"
		return 1
	fi
	sed -E 's/,(fileencryption|keydirectory|metadata_encryption)=[^,[:space:]]*//g' \
		/system/etc/recovery.fstab > "$NOCRYPT_FSTAB" || return 1
	"$rp" ro.boot.fstab_suffix "$NOCRYPT_SUFFIX"
	setprop vendor.recovery.decrypt off
	# keystore2 only aborts without keymint; free efs for restores
	setprop ctl.stop keystore2
	stop_tee
	return 0
}

# fallback [reason] <seconds>: decryption off; then restart OrangeFox
# unless it gets past decrypting /data within <seconds> (an unencrypted
# /data, after a format, does not need the TEE)
fallback() {
	hide_decryption "$1" || return
	t=0
	while [ "$t" -lt $(($2 * 5)) ]; do
		if fox_started; then
			save_logs
			return
		fi
		sleep 0.2
		t=$((t + 1))
	done
	save_logs
	log "restarting OrangeFox without decryption"
	setprop ctl.restart recovery
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

# vendor_mounted: OrangeFox has the installed vendor mounted over /vendor
vendor_mounted() {
	grep -q '^[^ ]* /vendor ' /proc/mounts
}

# copy_tee_files: the installed firmware's own TEE services and libraries
# ($TEE_FILES) over the copies in the ramdisk, so they match its TEE; the
# ramdisk copies stay for anything the firmware lacks. Fails if /vendor was
# mounted over while copying.
copy_tee_files() {
	copied=0
	kept=0
	missing=""
	for f in $TEE_FILES; do
		src="$VENDOR_MNT${f#/vendor}"
		if [ -f "$src" ]; then
			mkdir -p "${f%/*}"
			if cp "$src" "$f.new" && mv -f "$f.new" "$f"; then
				case "$f" in
					*/bin/*) chmod 0755 "$f" ;;
					*) chmod 0644 "$f" ;;
				esac
				copied=$((copied + 1))
				continue
			fi
			rm -f "$f.new" 2>/dev/null
			vendor_mounted && return 1
		fi
		if [ -f "$f" ]; then
			kept=$((kept + 1))
		else
			missing="$missing ${f##*/}"
		fi
	done
	return 0
}

# install_tee_files: the trusted apps and the TEE files, on the ramdisk's
# /vendor; fails if it is mounted over before or while copying
install_tee_files() {
	vendor_mounted && return 1
	[ -n "$TEE_FILES" ] || TEE_FILES=$(grep '^/vendor/' "$LIST" 2>/dev/null)
	rm -rf /vendor/tee 2>/dev/null
	[ -e /vendor/tee ] && return 1
	cp -a "$VENDOR_MNT/tee" /vendor/ 2>/dev/null || return 1
	copy_tee_files || return 1
	! vendor_mounted
}

start_tee() {
	[ -n "$(getprop vendor.recovery.tee_state)" ] && exit 0

	# the list is only in the ramdisk; read before OrangeFox maps super and
	# can mount the installed vendor over /vendor (and again later if not)
	TEE_FILES=$(grep '^/vendor/' "$LIST" 2>/dev/null)

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

	# the trusted apps of the installed firmware, so they match its TEE, and
	# its TEE services and libraries
	if [ ! -d "$VENDOR_MNT/tee" ]; then
		finish failed "the installed vendor has no /vendor/tee; decryption off"
	fi
	tries=1
	until install_tee_files; do
		if [ "$tries" -ge 150 ]; then
			vendor_mounted || rm -rf /vendor/tee
			finish failed "copying the TEE files failed; decryption off"
		fi
		sleep 0.2
		tries=$((tries + 1))
	done
	[ "$tries" -gt 1 ] && log "copied on try $tries: OrangeFox had the installed vendor mounted on /vendor"
	if [ -n "$TEE_FILES" ]; then
		log "TEE files: $copied from the installed firmware, $kept from the ramdisk${missing:+, missing:$missing}"
	else
		log "no $LIST; using the TEE files in the ramdisk"
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
	fallback) fallback "${2:-requested}" 0 ;;
	*) echo "usage: $0 start|stop|fallback [reason]" >&2; exit 1 ;;
esac
exit 0
