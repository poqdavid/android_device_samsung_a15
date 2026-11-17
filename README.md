## OrangeFox Recovery device tree for the Samsung Galaxy A15 (MediaTek)

The Galaxy A15 (SM-A155F - codenamed _"a15"_) is an entry-level smartphone from Samsung.

It was announced and released in December 2023.

This tree is for the 4G model only. The Galaxy A15 5G (SM-A156x, _"a15x"_) uses a different chipset and kernel.

## Device specifications

| Feature                        | Specification                                                                             |
| -----------------------------: | :---------------------------------------------------------------------------------------- |
| Chipset                        | MediaTek Helio G99 (MT6789, 6 nm)                                                         |
| CPU                            | Octa-core (2x2.2 GHz Cortex-A76 & 6x2.0 GHz Cortex-A55)                                   |
| GPU                            | Mali-G57 MC2                                                                              |
| Memory                         | 4GB / 6GB / 8GB RAM                                                                       |
| Shipped OS                     | Android 14 (One UI 6.0)                                                                   |
| Storage                        | 128GB / 256GB                                                                             |
| SIM                            | Nano-SIM or Nano-SIM + Nano-SIM                                                           |
| MicroSD                        | microSDXC (uses shared SIM slot)                                                          |
| Battery                        | 5000 mAh (non-removable), 25W fast charge                                                 |
| Dimensions                     | 160.1 x 76.8 x 8.4 mm (6.30 x 3.02 x 0.33 in)                                             |
| Display                        | 6.5 inches, 1080 x 2340, 19.5:9 ratio, Super AMOLED, 90Hz                                 |

## Device picture

<img src="https://fdn2.gsmarena.com/vv/bigpic/samsung-galaxy-a15-lte-.jpg" width="45%"/>

---
# Which build
Each OrangeFox build is for one One UI generation (its file names end in the set's name, such as `oneui7`), and only works fully, touch included, on a phone whose bootloader is of that generation. The 4th character from the end of the bootloader version tells which. `adb shell getprop ro.boot.bootloader` shows it; on stock firmware it is also the end of the build number (Settings > About phone > Software information).

| Build | Bootloader | Example |
| :---- | :--------- | :------ |
| `oneui7` | One UI 7 (Android 15), letter `C` | A155FXXU7**C**YK1 |

# Flashing
## Flashing with an installed custom recovery (OrangeFox/TWRP):
    * Download the OrangeFox zip installer file
    * Reboot your device to your custom recovery
    * Flash the OrangeFox zip installer (there will be an automatic reboot to OrangeFox after flashing)

##  Flashing with Odin - only if there is no installed custom recovery:
    * Ensure that your bootloader is unlocked
    * Download the OrangeFox "tar" file
    * Open Odin and untick "Auto Reboot"
    * Reboot the device to download mode
    * Flash the "tar" file to the "AP" slot in Odin
    * Reboot to recovery, using the relevant hardware key combination (hold Volume Up + Power with a USB cable connected)
    * Flash the OrangeFox zip installer from a MicroSD card, USB-OTG or with ADB sideload

## Decryption
	* /data (FBE v2 with metadata encryption) is decrypted with Samsung's own TEE services, with or without a PIN, password or pattern
	* The keys are bound to the Android version and patch levels. OrangeFox reports the installed firmware's values to the TEE, so it decrypts on any stock firmware date
	* The TEE keeps the EFS partition in use until every user is decrypted. To restore an EFS backup after skipping the password prompt, first run `setprop vendor.recovery.tee_stop 1` in the terminal

## Issues
	* Settings are stored in the cache partition, so wiping cache resets them
	* Decryption needs a readable installed system and vendor. If the TEE cannot start (for example after wiping them), or OrangeFox does not get past decrypting /data within 40 seconds, it restarts itself with decryption off for that boot: /data shows as not mountable, and the logs are saved to `/cache/Fox/tee`
	* The flashlight is not supported
	* On a bootloader of another One UI generation than the build's, touch does not work; `/tmp/recovery.log` then says which build this is and which bootloader the phone has

---
## Building

This tree is for the fox_12.1 manifest. `A15_FIRMWARE` picks the firmware set to build (see below); without it, the build is `oneui7`.

    . build/envsetup.sh
    export A15_FIRMWARE=oneui7
    lunch twrp_a15-eng
    mka adbd recoveryimage

To build another set in the same `out` directory, run `mka installclean` first.

## Firmware sets

The bootloader builds the kernel's device tree from the installed firmware's `lk` and `dtbo` partitions, not from the recovery image, so the recovery's kernel and modules have to come from a firmware of the same One UI generation as the installed bootloader. The tree keeps one set per generation in `firmware/<set>`:

| Set | Firmware | Kernel | Bootloaders |
| :-- | :------- | :----- | :---------- |
| `oneui7` | A155FXXS7CYG4 | 5.10.226-android12-9-31117096 | `C` |

Each set has the kernel, DTB and DTBO (`prebuilt/`) and the modules in `recovery/root/lib/modules`, taken unmodified from the stock recovery of its firmware, and `firmware.mk` with the firmware version, the board name of that stock image and the OS letters of the bootloaders it is for. The touchscreen drivers (`zt7650m_ts.ko`, `focaltech_ts_ft3418.ko`), `tuihw-inf.ko` and the touch firmware (`recovery/root/vendor/firmware`) come from `vendor_dlkm` and `vendor` of the same firmware. A set must always be replaced as a whole, from one firmware. Everything else in the tree is shared by all sets.

The CPU temperature needs the SoC temperature sensor driver, `soc_temp_lvts.ko`, also from `vendor_dlkm` of the same firmware, which the stock recovery does not load. `cpu_temp.sh` loads it from the set's `lib/modules` before OrangeFox starts; without it there, the temperature is hidden.

To refresh a set, or to add one, use the [builder](https://github.com/poqdavid/orangefox-a15-builder)'s tools on a rooted phone running that stock firmware:

    tools/pull-vendor-files.sh vendor-files --recovery
    tools/extract-prebuilts.py --recovery vendor-files/recovery.img --vendor-files vendor-files \
        --tree device/samsung/a15 --firmware oneui7

## Prebuilt TEE files

At boot, `prepare_tee.sh` takes the TEE from the installed firmware: the trusted apps, and the TEE daemons, the keymint, fkeymaster, gatekeeper and weaver (hermesd) services, the gatekeeper modules and their libraries listed in `recovery/root/vendor/etc/tee-files.list`. So they always match the firmware, SM-A155F or SM-A155M, of any date and One UI generation, and are shared by all firmware sets.

The copies in `recovery/root/vendor` are the fallback for anything the installed firmware lacks. They come unmodified from one stock firmware; `tee-files.txt` lists them with their checksums, that firmware and its patch levels. To refresh them and the list, pull the files from a rooted phone and install them with the [builder](https://github.com/poqdavid/orangefox-a15-builder)'s tools; this also sets `PLATFORM_SECURITY_PATCH`:

    tools/pull-tee-files.py tee-files
    tools/install-tee-files.py tee-files.zip --tree device/samsung/a15

---
### Thanks to
@[devhunter1](https://github.com/devhunter1)
For the TWRP tree on which this one is based ([TeamWin/android_device_samsung_a15](https://github.com/TeamWin/android_device_samsung_a15))

@[mylove90](https://github.com/mylove90) and Mohamed Saad
For their fixes to that tree

The OrangeFox trees for the Galaxy [A33 5G](https://gitlab.com/OrangeFox/device/a33x) and [A23 5G](https://gitlab.com/OrangeFox/device/a23xq)
For the layout and scripts this tree follows

@[G3R03XP](https://github.com/G3R03XP) and @[kkdemergencia](https://github.com/kkdemergencia) for testing the builds and this would not have been possible without them

### Kernel sources
The recovery uses the stock kernel. Samsung publishes its source for the SM-A155F at [opensource.samsung.com](https://opensource.samsung.com); a buildable copy is available at [https://github.com/poqdavid/android_kernel_samsung_sma155f](https://github.com/poqdavid/android_kernel_samsung_sma155f)

---
## Copyright

```
#
# Copyright (C) 2024 The TWRP Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#  *  Copyright (C) 2026 The OrangeFox Recovery Project
#  *
#  * This program is free software: you can redistribute it and/or modify
#  * it under the terms of the GNU General Public License as published by
#  * the Free Software Foundation, either version 3 of the License, or
#  * (at your option) any later version.
#  *
#  * This program is distributed in the hope that it will be useful,
#  * but WITHOUT ANY WARRANTY; without even the implied warranty of
#  * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  * GNU General Public License for more details.
#  *
#  * You should have received a copy of the GNU General Public License
#  * along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
```
