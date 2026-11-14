#
# Copyright (C) 2026 The OrangeFox Recovery Project
#
# SPDX-License-Identifier: Apache-2.0
#
# OrangeFox build vars for the Samsung Galaxy A15 (SM-A155F, a15).
#
# These are only applied when the device is selected, so export
# FOX_BUILD_DEVICE before sourcing the build environment:
#
#   export FOX_BUILD_DEVICE=a15
#   source build/envsetup.sh
#   lunch twrp_a15-eng
#   mka adbd recoveryimage
#

FDEVICE="a15"

if [ "$1" = "$FDEVICE" ] || [ "$FOX_BUILD_DEVICE" = "$FDEVICE" ]; then
	export ALLOW_MISSING_DEPENDENCIES=true
	export LC_ALL="C"
	export TW_DEFAULT_LANGUAGE="en"

	# Maintainer / versioning (bump the patch version for every release)
	export OF_MAINTAINER="poqdavid"
	export FOX_MAINTAINER_PATCH_VERSION="${FOX_MAINTAINER_PATCH_VERSION:-1}"

	# Non-Xiaomi, A-only device with a dedicated recovery partition
	export FOX_VANILLA_BUILD=1
	export OF_NO_TREBLE_COMPATIBILITY_CHECK=1
	export OF_NO_ADDITIONAL_MIUI_PROPS_CHECK=1
	export FOX_RECOVERY_SYSTEM_PARTITION="/dev/block/mapper/system"
	export FOX_RECOVERY_VENDOR_PARTITION="/dev/block/mapper/vendor"
	# bootimg.mk already appends SEANDROIDENFORCE and the AVB footer,
	# so FOX_USE_SAMSUNG_SPECIAL must stay unset.

	# Prebuilt stock kernel
	export OF_FORCE_PREBUILT_KERNEL=1

	# Screen: 1080x2340, Infinity-U cutout (Android's status bar is 80 px
	# high), rounded corners, no hardware navigation keys
	export OF_SCREEN_H=2340
	export OF_STATUS_H=80
	export OF_STATUS_INDENT_LEFT=48
	export OF_STATUS_INDENT_RIGHT=48
	export OF_HIDE_NOTCH=1
	export OF_CLOCK_POS=1
	export OF_ALLOW_DISABLE_NAVBAR=0

	# Read the battery level from sysfs (see TW_CUSTOM_BATTERY_PATH)
	export OF_USE_LEGACY_BATTERY_SERVICES=1

	# No notification LED; the flash LED driver (sm5714 + MTK flashlight
	# core) is not loaded in recovery
	export OF_USE_GREEN_LED=0
	export OF_FLASHLIGHT_ENABLE=0

	# Quick backup: boot plus the Samsung/MediaTek partitions that hold
	# IMEI and calibration data
	export OF_QUICK_BACKUP_LIST="/boot;/efs;/vendor_efs;/nvram;/nvdata;/nvcfg;/protect_f;/protect_s;"

	# Extra tools
	export FOX_USE_BASH_SHELL=1
	export FOX_ASH_IS_BASH=1
	export FOX_USE_NANO_EDITOR=1
	export FOX_USE_TAR_BINARY=1
	export FOX_USE_SED_BINARY=1
	export FOX_USE_XZ_UTILS=1
	# Samsung firmware images ship as .lz4
	export FOX_USE_LZ4_BINARY=1
	export FOX_DELETE_AROMAFM=1
fi
