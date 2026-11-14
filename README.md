# OrangeFox device tree for the Samsung Galaxy A15 (SM-A155F)

| Device          | Samsung Galaxy A15 (4G)                                   |
|-----------------|-----------------------------------------------------------|
| Codename        | a15                                                       |
| Models          | SM-A155F                                                  |
| SoC             | MediaTek Helio G99 (MT6789)                               |
| CPU             | 2x Cortex-A76 @ 2.2 GHz + 6x Cortex-A55 @ 2.0 GHz         |
| GPU             | Mali-G57 MC2                                              |
| Display         | 6.5" Super AMOLED, 1080 x 2340, 90 Hz, Infinity-U cutout  |
| Storage         | UFS 2.2                                                   |
| Shipped Android | 14 (One UI 6.0)                                           |
| Partitions      | A-only, dynamic (super), dedicated recovery partition     |

Not for the Galaxy A15 5G (SM-A156x, `a15x`): different SoC, kernel and modules.

## Building

This tree targets the `fox_12.1` manifest.

```bash
mkdir -p ~/OrangeFox && cd ~/OrangeFox
git clone https://gitlab.com/OrangeFox/sync.git
cd sync
./orangefox_sync.sh --branch 12.1 --path ~/OrangeFox/fox_12.1

cd ~/OrangeFox/fox_12.1
git clone <this repo> -b fox_12.1 device/samsung/a15

export FOX_BUILD_DEVICE=a15
source build/envsetup.sh
lunch twrp_a15-eng
mka adbd recoveryimage
```

`FOX_BUILD_DEVICE` has to be exported before `build/envsetup.sh` is sourced,
otherwise `vendorsetup.sh` skips the OrangeFox build vars and `BoardConfig.mk`
stops the build.

The output is `out/target/product/a15/OrangeFox-*.img` and the matching zip.
The image already carries `SEANDROIDENFORCE` and an AVB hash footer
(see `bootimg.mk`).

## Installing

Samsung has no fastboot, so the first install is done with Odin:

1. Unlock the bootloader (OEM unlocking).
2. Put the image in a tar (`tar -H ustar -cf OrangeFox.tar recovery.img`)
   and flash it in Odin's AP slot with Auto Reboot unticked. If the phone
   then refuses to boot recovery with a verification error, also flash a
   `vbmeta` with verification disabled.
3. Reboot straight into recovery: hold Volume Up + Power with a USB cable
   connected.
4. Keep OrangeFox installed: boot must not be the stock image when Android
   starts, otherwise Samsung's install-recovery service restores the stock
   recovery. Root (Magisk/KernelSU), flash a custom kernel, or run
   `multidisabler` from the OrangeFox terminal.

Later updates can be installed from OrangeFox itself (zip or image).

## Known limitations

- No /data decryption: Samsung keeps the FBE keys in TEEGRIS. Internal
  storage is only readable between Format Data and the next Android boot,
  which encrypts it again; use MicroSD, USB OTG or ADB sideload.
- OrangeFox settings, themes and the recovery password are stored under
  /sdcard/Fox, so they only persist while internal storage is readable.
- Touch needs a stock-based ROM: the touchscreen drivers depend on
  `tuihw-inf.ko`, which is not in the recovery ramdisk yet, so they are
  loaded from the installed ROM's `vendor_dlkm`. With an empty or non-stock
  `super`, use OrangeFox's hardware-key navigation (volume and power keys)
  or adb.
- No flashlight: the flash LED driver is not loaded in recovery.
- No CPU temperature: the thermal modules are not loaded in recovery.

## Prebuilts

`prebuilt/kernel`, `prebuilt/dtb.img`, `prebuilt/dtbo.img` and the modules in
`recovery/root/lib/modules` come from one stock SM-A155F recovery image
(Android 14 firmware, kernel `5.10.198-android12-9-28575149`). The touch
drivers in `recovery/root/vendor/lib/modules` come from the same firmware.
Replace them together, from one firmware: the kernel only accepts modules
whose symbol versions match it.

## Credits

- [TeamWin](https://github.com/TeamWin/android_device_samsung_a15) and
  devhunter1 for the original TWRP tree, and mylove90 and Mohamed Saad for
  their fixes to it
- The [OrangeFox Recovery Project](https://gitlab.com/OrangeFox)
