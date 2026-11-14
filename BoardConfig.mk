#
# Copyright (C) 2024 The Android Open Source Project
# Copyright (C) 2026 The OrangeFox Recovery Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/samsung/a15

# For building with minimal manifest
ALLOW_MISSING_DEPENDENCIES := true

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := cortex-a76

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv7-a-neon
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a55
TARGET_USES_64_BIT_BINDER := true

TARGET_CPU_SMP := true

# Bootloader
BOARD_VENDOR := samsung
TARGET_BOOTLOADER_BOARD_NAME := a15
TARGET_NO_BOOTLOADER := true
TARGET_NO_RADIOIMAGE := true

# Platform
TARGET_BOARD_PLATFORM := mt6789

# Display
TARGET_SCREEN_DENSITY := 450

# Kernel (prebuilt kernel, DTB and DTBO taken from a stock SM-A155F recovery
# image; the modules in recovery/root must come from the same image)
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
TARGET_PREBUILT_DTB := $(DEVICE_PATH)/prebuilt/dtb.img
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilt/dtbo.img
BOARD_INCLUDE_RECOVERY_DTBO := true
BOARD_KERNEL_IMAGE_NAME := Image
BOARD_KERNEL_CMDLINE := androidboot.selinux=permissive bootopt=64S3,32N2,64N2 loop.max_part=7

# Recovery image layout (stock header v2 recovery image)
BOARD_KERNEL_BASE := 0x3fff8000
BOARD_NAME := SRPWI18B003
BOARD_PAGE_SIZE := 4096
BOARD_KERNEL_OFFSET := 0x00008000
BOARD_RAMDISK_OFFSET := 0x26f08000
BOARD_SECOND_OFFSET := 0xc0008000
BOARD_TAGS_OFFSET := 0x07c88000
BOARD_HEADER_VERSION := 2
BOARD_DTB_OFFSET := 0x07c88000
BOARD_MKBOOTIMG_ARGS := --board $(BOARD_NAME) --pagesize $(BOARD_PAGE_SIZE) --kernel_offset $(BOARD_KERNEL_OFFSET) --ramdisk_offset $(BOARD_RAMDISK_OFFSET) --second_offset $(BOARD_SECOND_OFFSET) --tags_offset $(BOARD_TAGS_OFFSET) --header_version $(BOARD_HEADER_VERSION) --dtb_offset $(BOARD_DTB_OFFSET) --dtb $(TARGET_PREBUILT_DTB)
# Appends SEANDROIDENFORCE and the AVB hash footer to the recovery image
BOARD_CUSTOM_BOOTIMG_MK := $(DEVICE_PATH)/bootimg.mk

# Partitions
BOARD_FLASH_BLOCK_SIZE := 262144
BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 83886080
BOARD_HAS_LARGE_FILESYSTEM := true
BOARD_SYSTEMIMAGE_PARTITION_TYPE := f2fs
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := f2fs
TARGET_COPY_OUT_VENDOR := vendor
BOARD_USES_METADATA_PARTITION := true

# Dynamic partitions
BOARD_SUPER_PARTITION_SIZE := 11744051200
BOARD_SUPER_PARTITION_GROUPS := samsung_dynamic_partitions
BOARD_SAMSUNG_DYNAMIC_PARTITIONS_PARTITION_LIST := system vendor product odm vendor_dlkm system_ext
BOARD_SAMSUNG_DYNAMIC_PARTITIONS_SIZE := 11739856896

# PRODUCT_COPY_FILES directives
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
DISABLE_ARTIFACT_PATH_REQUIREMENTS := true

# System as root
BOARD_ROOT_EXTRA_FOLDERS := carrier data_mirror debug_ramdisk efs linkerconfig metadata odm_dlkm oem optics postinstall prism second_stage_resources spu system_ext vendor_dlkm system_dlkm
BOARD_SUPPRESS_SECURE_ERASE := true

# Recovery
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
AB_OTA_UPDATER := false
BOARD_HAS_NO_SELECT_BUTTON := true

# Verified Boot
BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 2
BOARD_AVB_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_RECOVERY_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_RECOVERY_ALGORITHM := SHA256_RSA4096
BOARD_AVB_RECOVERY_ROLLBACK_INDEX := 1
BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION := 1

# Security patch level / version (keeps anti-rollback checks happy)
PLATFORM_SECURITY_PATCH := 2099-12-31
VENDOR_SECURITY_PATCH := 2099-12-31
PLATFORM_VERSION := 12

# Crypto
# Samsung keeps the FBE keys in TEEGRIS (tzdev), so /data cannot be decrypted.
# Internal storage is only readable between Format Data and the next Android
# boot; otherwise use MicroSD, OTG or ADB sideload.
TW_INCLUDE_CRYPTO := false
TW_INCLUDE_CRYPTO_FBE := false
TW_INCLUDE_FBE_METADATA_DECRYPT := false

# Kernel modules
# The stock recovery module set has no touchscreen driver. The recovery loads
# the Zinitix ZT7650M / FocalTech FT3418 drivers itself: first from the
# ramdisk's /lib/modules (needs the drivers, their dependencies and matching
# modules.dep entries there), then from the installed ROM's vendor_dlkm.
TW_LOAD_VENDOR_MODULES := "zt7650m_ts.ko focaltech_ts_ft3418.ko"
TW_LOAD_VENDOR_BOOT_MODULES := true

# TWRP configuration
TW_THEME := portrait_hdpi
TW_FRAMERATE := 90
RECOVERY_SDCARD_ON_DATA := true
TW_EXCLUDE_APEX := true
TW_NO_SCREEN_BLANK := true

# Backlight: drivers/gpu/drm/samsung/panel registers "panel" with a 0-255
# normal range; 256-483 is HBM, so cap the slider at 255.
TW_BRIGHTNESS_PATH := "/sys/class/backlight/panel/brightness"
TW_MAX_BRIGHTNESS := 255
TW_DEFAULT_BRIGHTNESS := 128

# Battery: sec-battery exposes capacity/status directly in sysfs
TW_USE_LEGACY_BATTERY_SERVICES := true
TW_CUSTOM_BATTERY_PATH := /sys/class/power_supply/battery

# The thermal modules are not loaded in recovery, so every zone reads 0
TW_NO_CPU_TEMP := true

# Samsung: no fastboot bootloader, Download mode instead
TW_NO_REBOOT_BOOTLOADER := true
TW_HAS_DOWNLOAD_MODE := true

# USB is configured by init.recovery.usb.rc (Samsung VID/PID)
TW_EXCLUDE_DEFAULT_USB_INIT := true
TW_USE_NEW_MINADBD := true

TW_INCLUDE_NTFS_3G := true
TW_INCLUDE_LPTOOLS := true
# Ships magiskboot (used by multidisabler); the repack UI itself is A/B only
TW_INCLUDE_REPACKTOOLS := true
TW_INCLUDE_RESETPROP := true
TW_INCLUDE_LIBRESETPROP := true
TW_USE_TOOLBOX := true
TARGET_USES_MKE2FS := true
TW_NO_LEGACY_PROPS := true
TW_NO_BIND_SYSTEM := true
TW_USE_MODEL_HARDWARE_ID_FOR_DEVICE_ID := true
TW_BACKUP_EXCLUSIONS := /data/fonts

# Debug
TWRP_INCLUDE_LOGCAT := true
TARGET_USES_LOGD := true

# OrangeFox: the FOX_/OF_ build vars live in vendorsetup.sh and are only
# exported when FOX_BUILD_DEVICE is set before sourcing build/envsetup.sh.
# Without them the build still succeeds but the UI ignores the cutout and
# the screen size, so refuse to configure in that case.
ifneq ($(wildcard bootable/recovery/orangefox.mk bootable/recovery/orangefox_defaults.go),)
ifeq ($(strip $(OF_SCREEN_H)),)
$(error OrangeFox build vars for a15 are not set. Run "export FOX_BUILD_DEVICE=a15" before "source build/envsetup.sh")
endif
endif
