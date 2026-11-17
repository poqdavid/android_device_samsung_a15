#
# Copyright (C) 2026 The OrangeFox Recovery Project
# SPDX-License-Identifier: GPL-3.0-or-later
#

# The kernel, DTB, DTBO, recovery modules and touch firmware come from one
# stock firmware, kept as a set per One UI generation in firmware/<name>/.
# A set only works with a bootloader of the same generation: the bootloader
# builds the kernel's device tree from the installed firmware's lk and dtbo
# partitions, not from the recovery image, so with a kernel of another
# generation touch does not work. Each set is therefore a build of its own;
# pick it before lunch with
#
#     export A15_FIRMWARE=oneui6
#
# Included by BoardConfig.mk and twrp_a15.mk.

# an empty A15_FIRMWARE from the environment counts as unset
ifeq ($(strip $(A15_FIRMWARE)),)
A15_FIRMWARE := oneui7
endif
A15_FIRMWARE_DIR := $(DEVICE_PATH)/firmware/$(A15_FIRMWARE)
ifeq ($(wildcard $(A15_FIRMWARE_DIR)/firmware.mk),)
$(error A15_FIRMWARE=$(A15_FIRMWARE), but there is no $(A15_FIRMWARE_DIR)/firmware.mk)
endif
include $(A15_FIRMWARE_DIR)/firmware.mk
