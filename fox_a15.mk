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

# screen settings (1080x2340, Infinity-U cutout, rounded corners;
# Android's status bar is 80 px high on this device)
OF_SCREEN_H := 2340
OF_STATUS_H := 80
OF_STATUS_INDENT_LEFT := 48
OF_STATUS_INDENT_RIGHT := 48
OF_USE_GREEN_LED := 0
OF_HIDE_NOTCH := 1
OF_CLOCK_POS := 1
OF_ALLOW_DISABLE_NAVBAR := 0

# number of list options before scrollbar creation
OF_OPTIONS_LIST_NUM := 8

# skip decryption
OF_SKIP_FBE_DECRYPTION := 1

# others
OF_UNBIND_SDCARD_F2FS := 1
OF_QUICK_BACKUP_LIST := /boot;/efs;/vendor_efs;/nvram;/nvdata;/nvcfg;/protect_f;/protect_s;
OF_USE_DMCTL := 1
OF_ENABLE_ALL_PARTITION_TOOLS := 1
OF_NO_TREBLE_COMPATIBILITY_CHECK := 1
OF_NO_ADDITIONAL_MIUI_PROPS_CHECK := 1

# prebuilt stock kernel
OF_FORCE_PREBUILT_KERNEL := 1

# disable the flashlight (the flash LED modules are not in the recovery ramdisk)
OF_FLASHLIGHT_ENABLE := 0

# no persist partition
OF_DEVICE_WITHOUT_PERSIST := 1

# battery percent (read from /sys/class/power_supply/battery)
OF_USE_LEGACY_BATTERY_SERVICES := 1

# don't keep log history - only use for Stable releases
ifeq ($(FOX_BUILD_TYPE),Stable)
   OF_DONT_KEEP_LOG_HISTORY := 1
endif
#
