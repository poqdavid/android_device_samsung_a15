#
# Copyright (C) 2026 The OrangeFox Recovery Project
# SPDX-License-Identifier: GPL-3.0-or-later
#

# Firmware set oneui7, written by extract-prebuilts.py from the stock
# firmware A155FXXS7CYG4: the kernel, DTB, DTBO and modules of its
# recovery image, and the vendor_dlkm modules and touch firmware the
# recovery adds to them. Kernel 5.10.226-android12-9-31117096.
# Built with A15_FIRMWARE=oneui7 (see ../firmware.mk).
A15_FIRMWARE_BUILD := A155FXXS7CYG4
# the board name in the header of the stock recovery image
A15_BOARD_NAME := SRPWI18B007
# The OS letters of the bootloaders this set is for: the 4th character from
# the end of ro.boot.bootloader (C in A155FXXS7CYG4). runatboot.sh warns
# when the phone's is another one.
A15_FIRMWARE_OS := C
