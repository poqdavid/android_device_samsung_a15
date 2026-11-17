#
# Copyright (C) 2026 The OrangeFox Recovery Project
# SPDX-License-Identifier: GPL-3.0-or-later
#

# Firmware set oneui6, written by extract-prebuilts.py from the stock
# firmware A155MUBS6BYE1: the kernel, DTB, DTBO and modules of its
# recovery image, and the vendor_dlkm modules and touch firmware the
# recovery adds to them. Kernel 5.10.205-android12-9-28575149.
# Built with A15_FIRMWARE=oneui6 (see ../firmware.mk).
A15_FIRMWARE_BUILD := A155MUBS6BYE1
# the board name in the header of the stock recovery image
A15_BOARD_NAME := SRPWJ11A006
# The OS letters of the bootloaders this set is for: the 4th character from
# the end of ro.boot.bootloader (B in A155MUBS6BYE1). runatboot.sh warns
# when the phone's is another one.
A15_FIRMWARE_OS := B
