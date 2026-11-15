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
# CPU temperature
#
# The SoC temperature sensor driver (LVTS, soc_temp_lvts.ko) lives in
# vendor_dlkm and is not part of the stock recovery's module set, so its
# thermal zones (soc_max, cpu_little1-4, cpu_big1-4, gpu1-2, soc1-2, md)
# do not exist in recovery.
#
# This loads it from the ramdisk with its dependencies and links
# /tmp/cpu_temp (TW_CUSTOM_CPU_TEMP_PATH) to the soc_max zone, the hottest
# sensor. It runs from init before OrangeFox starts, because OrangeFox
# checks that path only once, at startup. If the module is not in the
# ramdisk or does not load, the link is not made and OrangeFox hides the
# temperature.
#

PATH=/system/bin:/sbin:$PATH
MODDIR=/lib/modules
MODULE=soc_temp_lvts.ko
LINK=/tmp/cpu_temp
ZONES="soc_max cpu_big1"
TAG=cpu_temp

log() {
	echo "$TAG: $*" > /dev/kmsg
}

# find_zone <type>: the first thermal zone of that type
find_zone() {
	for z in /sys/class/thermal/thermal_zone*; do
		[ -r "$z/type" ] || continue
		if [ "$(cat "$z/type")" = "$1" ]; then
			echo "$z"
			return 0
		fi
	done
	return 1
}

find_any_zone() {
	for t in $ZONES; do
		find_zone "$t" && return 0
	done
	return 1
}

# Load the module after its dependencies. modules.dep lists the module
# first, then everything it needs, in an order that loads from the end.
# Modules that are already loaded fail with "File exists"; that is fine.
load_module() {
	list=""
	if [ ! -f "$MODDIR/$MODULE" ]; then
		log "$MODULE is not in the ramdisk"
		return 1
	fi
	deps=$(grep "^$MODDIR/$MODULE:" "$MODDIR/modules.dep" 2>/dev/null | cut -d: -f2)
	for d in $deps; do
		list="$d $list"
	done
	for d in $list; do
		[ -f "$d" ] && insmod "$d" 2>/dev/null
	done
	insmod "$MODDIR/$MODULE" 2>/dev/null
	return 0
}

zone=$(find_any_zone)
if [ -z "$zone" ]; then
	load_module || exit 0
	# the zones are registered while the module loads, unless the
	# sensor's probe is deferred; give that a moment
	i=0
	while [ $i -lt 20 ]; do
		zone=$(find_any_zone) && break
		sleep 0.1
		i=$((i + 1))
	done
fi

if [ -z "$zone" ]; then
	log "no SoC thermal zone; the CPU temperature is not shown"
	exit 0
fi

ln -sf "$zone/temp" "$LINK"
log "$LINK -> $zone/temp ($(cat "$zone/type"), $(cat "$zone/temp"))"
exit 0
