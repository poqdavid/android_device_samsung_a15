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
# ZT7650M. When the stock Zinitix driver probes, it flashes zt7650m_a15.bin
# if that file is newer than the controller's firmware. On these panels it
# always is (the controller keeps reporting register data version 0x15, the
# file has 0x21), so the driver flashes at every boot, in Android too, which
# takes about 18 seconds. After the flash the controller only works again
# once it has really lost power, and its 3.0 V supply (GPIO 19) is switched
# by the panel driver: the touch driver's own power off changes nothing, and
# only turning the display off and on does it. Recovery never turns the
# display off, so touch never came back.
#
# So the recovery does not flash: the ramdisk has no zt7650m_a15.bin, and
# this loads the driver from init, before OrangeFox mounts the installed
# vendor, whose /vendor/firmware has one. Without the file the driver logs
# "Firmware image zt7650m_a15.bin not available", skips the update and
# keeps the firmware the controller has. OrangeFox later skips the module
# as already loaded. On FocalTech panels the driver does not bind.
#

PATH=/system/bin:/sbin:$PATH
MODDIR=/lib/modules
MODULE=zt7650m_ts.ko
DRIVER=/sys/bus/i2c/drivers/zt_ts_device
TAG=zinitix_touch

log() {
	echo "$TAG: $*" > /dev/kmsg
}

if [ -e /vendor/firmware/zt7650m_a15.bin ]; then
	log "/vendor/firmware/zt7650m_a15.bin exists, so the driver would flash it; leaving it to OrangeFox"
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
		exit 0
	fi
done
log "no Zinitix touch controller (a FocalTech panel, or the probe failed)"
exit 0
