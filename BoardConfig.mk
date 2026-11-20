#
# Copyright (C) 2024 The Android Open Source Project
# Copyright (C) 2024 The TWRP Open Source Project
#
# SPDX-License-Identifier: Apache-2.0
#
# Copyright (C) 2026 The OrangeFox Recovery Project
# SPDX-License-Identifier: GPL-3.0-or-later
#

DEVICE_PATH := device/samsung/a15

# Bootloader
BOARD_VENDOR := samsung
TARGET_SOC := mt6789
TARGET_BOOTLOADER_BOARD_NAME := a15
TARGET_NO_BOOTLOADER := true
TARGET_NO_RADIOIMAGE := true

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

ALLOW_MISSING_DEPENDENCIES := true

# File systems
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

# Platform
TARGET_BOARD_PLATFORM := mt6789

# Display
TARGET_SCREEN_DENSITY := 450

# Kernel
# The kernel, DTB, DTBO and every module under recovery/root/lib/modules
# come from one stock firmware (see README.md) and are replaced together.
KERNEL_DIR := $(DEVICE_PATH)/prebuilt
TARGET_PREBUILT_KERNEL := $(KERNEL_DIR)/Image.gz
TARGET_PREBUILT_DTB := $(KERNEL_DIR)/dtb
BOARD_PREBUILT_DTBOIMAGE := $(KERNEL_DIR)/recovery_dtbo
BOARD_INCLUDE_RECOVERY_DTBO := true
TARGET_KERNEL_ARCH := arm64

# Boot
BOARD_BOOT_HEADER_VERSION := 2
BOARD_KERNEL_BASE := 0x3fff8000
BOARD_KERNEL_CMDLINE := androidboot.selinux=permissive bootopt=64S3,32N2,64N2 loop.max_part=7
BOARD_KERNEL_IMAGE_NAME := Image.gz
BOARD_KERNEL_PAGESIZE := 4096
BOARD_KERNEL_OFFSET := 0x00008000
BOARD_RAMDISK_OFFSET := 0x26f08000
BOARD_KERNEL_SECOND_OFFSET := 0xc0008000
BOARD_KERNEL_TAGS_OFFSET := 0x07c88000
BOARD_DTB_OFFSET := 0x07c88000
BOARD_MKBOOTIMG_ARGS := --kernel_offset $(BOARD_KERNEL_OFFSET) --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_MKBOOTIMG_ARGS += --tags_offset $(BOARD_KERNEL_TAGS_OFFSET) --second_offset $(BOARD_KERNEL_SECOND_OFFSET)
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION) --pagesize $(BOARD_KERNEL_PAGESIZE) --board "SRPWI18B007"
BOARD_MKBOOTIMG_ARGS += --dtb $(TARGET_PREBUILT_DTB) --dtb_offset $(BOARD_DTB_OFFSET)
# Appends SEANDROIDENFORCE and the AVB hash footer to the recovery image
BOARD_CUSTOM_BOOTIMG_MK := $(DEVICE_PATH)/mkboot/bootimg.mk

# Recovery
BOARD_HAS_LARGE_FILESYSTEM := true
BOARD_HAS_NO_SELECT_BUTTON := true

# Partitions
BOARD_FLASH_BLOCK_SIZE := 262144
BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 83886080
BOARD_SYSTEMIMAGE_PARTITION_TYPE := f2fs
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs

# Dynamic Partitions
BOARD_SUPER_PARTITION_SIZE := 11744051200
BOARD_SUPER_PARTITION_GROUPS := samsung_dynamic_partitions
BOARD_SAMSUNG_DYNAMIC_PARTITIONS_SIZE := 11739856896
BOARD_SAMSUNG_DYNAMIC_PARTITIONS_PARTITION_LIST := system system_ext vendor product odm vendor_dlkm

# System as root
BOARD_ROOT_EXTRA_FOLDERS := carrier data_mirror debug_ramdisk efs linkerconfig metadata odm_dlkm oem optics postinstall prism second_stage_resources spu system_ext vendor_dlkm system_dlkm
BOARD_SUPPRESS_SECURE_ERASE := true

# Workaround for error copying vendor files to recovery ramdisk
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := f2fs
TARGET_COPY_OUT_VENDOR := vendor

AB_OTA_UPDATER := false

# Android Verified Boot
BOARD_AVB_ENABLE := true
BOARD_AVB_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_RECOVERY_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_RECOVERY_ALGORITHM := SHA256_RSA4096
BOARD_AVB_RECOVERY_ROLLBACK_INDEX := 1
BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION := 1
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 2

# Crypto
# As in the stock recovery: Android 12 and the patch level of the firmware
# the TEE files come from (set by install-tee-files.py). The TEE does not
# use these while keymint reports valid versions, which prepare_tee.sh
# takes from the installed firmware.
BOARD_USES_METADATA_PARTITION := true
PLATFORM_VERSION := 12
PLATFORM_SECURITY_PATCH := 2025-08-01
PLATFORM_VERSION_LAST_STABLE := $(PLATFORM_VERSION)
VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)
BOOT_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)

# FBE v2 with metadata encryption, decrypted with Samsung's TEEGRIS
# services (init.recovery.teegris.rc). The keymaster version is not read
# from the vendor partition: that would mount it over the recovery's /vendor.
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
TW_USE_FSCRYPT_POLICY := 2
TW_FORCE_KEYMASTER_VER := true
TW_PREPARE_DATA_MEDIA_EARLY := true

# Properties of the stock vendor the keystore services read
TARGET_VENDOR_PROP += $(DEVICE_PATH)/vendor.prop

# Keep the label of the TEE's storage on efs
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor

# PRODUCT_COPY_FILES directives.
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
DISABLE_ARTIFACT_PATH_REQUIREMENTS := true

# Kernel modules from vendor_dlkm
# The stock recovery module set has no touchscreen driver and no SoC
# temperature sensor (soc_temp_lvts.ko). These are loaded from the
# ramdisk's /lib/modules (their dependencies are in modules.dep); the touch
# drivers fall back to the installed ROM's vendor_dlkm. soc_temp_lvts.ko is
# loaded before OrangeFox starts, by cpu_temp.sh, and zt7650m_ts.ko by
# zinitix_touch.sh, so that it finds no firmware to flash.
TW_LOAD_VENDOR_MODULES := "zt7650m_ts.ko focaltech_ts_ft3418.ko soc_temp_lvts.ko"
TW_LOAD_VENDOR_BOOT_MODULES := true

# TWRP specific build flags
TW_INCLUDE_REPACKTOOLS := true
TW_INCLUDE_LIBRESETPROP := true
TW_INCLUDE_RESETPROP := true
TW_FRAMERATE := 90
TW_THEME := portrait_hdpi
RECOVERY_SDCARD_ON_DATA := true
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
# 0-255 is the panel's normal range, 256-483 is HBM
TW_BRIGHTNESS_PATH := "/sys/class/backlight/panel/brightness"
TW_MAX_BRIGHTNESS := 255
TW_DEFAULT_BRIGHTNESS := 128
TW_USE_LEGACY_BATTERY_SERVICES := true
TW_CUSTOM_BATTERY_PATH := /sys/class/power_supply/battery
# a link to the soc_max thermal zone, made by cpu_temp.sh; without
# soc_temp_lvts.ko in the ramdisk it is not made and the temperature is hidden
TW_CUSTOM_CPU_TEMP_PATH := /tmp/cpu_temp
TW_NO_REBOOT_BOOTLOADER := true
TW_HAS_DOWNLOAD_MODE := true
TW_INCLUDE_NTFS_3G := true
TW_USE_NEW_MINADBD := true
TW_EXCLUDE_DEFAULT_USB_INIT := true
TW_USE_TOOLBOX := true
TARGET_USES_MKE2FS := true
TW_NO_LEGACY_PROPS := true
TW_NO_BIND_SYSTEM := true
TW_EXCLUDE_APEX := true
TWRP_INCLUDE_LOGCAT := true
TARGET_USES_LOGD := true
TW_BACKUP_EXCLUSIONS := /data/fonts

# tap to wake
TW_NO_SCREEN_BLANK := true

# use unique serial number for device ID
TW_USE_SERIALNO_PROPERTY_FOR_DEVICE_ID := true
#
