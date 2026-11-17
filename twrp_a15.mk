#
# Copyright (C) 2024 The Android Open Source Project
# Copyright (C) 2024 The TWRP Open Source Project
#
# SPDX-License-Identifier: Apache-2.0
#
# Copyright (C) 2026 The OrangeFox Recovery Project
# SPDX-License-Identifier: GPL-3.0-or-later
#

# Release name
PRODUCT_RELEASE_NAME := a15

# Default device path for tree
DEVICE_PATH := device/samsung/$(PRODUCT_RELEASE_NAME)

# Inherit device configuration
$(call inherit-product, $(DEVICE_PATH)/device.mk)

# Inherit fox flags
$(call inherit-product-if-exists, $(DEVICE_PATH)/fox_a15.mk)

# Inherit some common TWRP stuff.
$(call inherit-product, vendor/twrp/config/common.mk)

PRODUCT_COPY_FILES += $(call find-copy-subdir-files,*,$(DEVICE_PATH)/recovery/root,recovery/root)

# The firmware set's recovery modules and touch firmware, and what it is for,
# so runatboot.sh can tell when the bootloader is of another One UI generation
include $(DEVICE_PATH)/firmware/firmware.mk
PRODUCT_COPY_FILES += $(call find-copy-subdir-files,*,$(A15_FIRMWARE_DIR)/recovery/root,recovery/root)
PRODUCT_VENDOR_PROPERTIES += \
    ro.vendor.a15.firmware=$(A15_FIRMWARE) \
    ro.vendor.a15.firmware.build=$(A15_FIRMWARE_BUILD) \
    ro.vendor.a15.firmware.os=$(A15_FIRMWARE_OS)

## Device identifier. This must come after all inclusions
PRODUCT_NAME := twrp_$(PRODUCT_RELEASE_NAME)
PRODUCT_DEVICE := $(PRODUCT_RELEASE_NAME)
PRODUCT_MODEL := SM-A155F
PRODUCT_BRAND := samsung
PRODUCT_MANUFACTURER := samsung
PRODUCT_GMS_CLIENTID_BASE := android-samsung
#
