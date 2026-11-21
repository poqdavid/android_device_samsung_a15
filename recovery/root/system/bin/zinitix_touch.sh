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
# Zinitix touch
#
# The touch controller comes with the panel: FocalTech FT3418 or Zinitix
# ZT7650M. A Zinitix controller only reports touches once the kernel has
# powered the panel down and brought it up again. Android does that the
# first time the screen goes off. Recovery starts with the panel still on
# from the bootloader, and OrangeFox never powers it down (it only dims it,
# see TW_NO_SCREEN_BLANK), so touch stayed dead. Once the driver is up, this
# turns the display off and on with display_cycle, before OrangeFox takes
# the display. That is the order that was tested: driver first, then the
# display.
#
# The driver is loaded here rather than by OrangeFox so that it does not
# find zt7650m_a15.bin. It flashes that file whenever it is newer than the
# controller's firmware, and on these panels it always is (the controller
# keeps reporting register data version 0x15, the file has 0x21), so it
# flashes at every boot, in Android too, for about 18 seconds. Touch works
# without it. The ramdisk has no copy, and this runs before OrangeFox
# mounts the installed vendor, whose /vendor/firmware has one. The driver
# then logs "Firmware image zt7650m_a15.bin not available" and keeps the
# firmware the controller has, and OrangeFox later skips the module as
# already loaded. On FocalTech panels the driver does not bind, and the
# display is left alone.
#

PATH=/system/bin:/sbin:$PATH
MODDIR=/lib/modules
MODULE=zt7650m_ts.ko
DRIVER=/sys/bus/i2c/drivers/zt_ts_device
TAG=zinitix_touch

# Userspace lines do not reliably make it into the kernel log here, so they
# also go to the log OrangeFox appends to when it starts
LOG=/tmp/recovery.log

log() {
	echo "$TAG: $*" > /dev/kmsg
	echo "$TAG: $*" >> $LOG
}

if [ -e /vendor/firmware/zt7650m_a15.bin ]; then
	log "/vendor/firmware/zt7650m_a15.bin is in the ramdisk and the driver would spend 18 seconds flashing it; leaving touch to OrangeFox, where it will not work"
	exit 0
fi
if [ ! -f "$MODDIR/$MODULE" ]; then
	log "$MODULE is not in the ramdisk"
	exit 0
fi

# modules.dep lists the module first, then everything it needs, in an
# order that loads from the end. Most are loaded already and fail with
# "File exists"; that is fine.
list=""
for d in $(grep "^$MODDIR/$MODULE:" "$MODDIR/modules.dep" 2>/dev/null | cut -d: -f2); do
	list="$d $list"
done
for d in $list; do
	[ -f "$d" ] && insmod "$d" 2>/dev/null
done
insmod "$MODDIR/$MODULE" 2>/dev/null

for dev in "$DRIVER"/*-*; do
	if [ -e "$dev" ]; then
		log "Zinitix touch is up, without flashing its firmware"
		if display_cycle 2>> $LOG; then
			log "display turned off and on, touch should work"
		else
			log "display_cycle failed, touch stays dead until the screen has really been off"
		fi
		exit 0
	fi
done
log "no Zinitix touch controller (a FocalTech panel, or the probe failed)"
exit 0
