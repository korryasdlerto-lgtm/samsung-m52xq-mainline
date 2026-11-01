# samsung-m52xq-mainline

postmarketOS + KDE Plasma Mobile on a **mainline Linux kernel** for the
**Samsung Galaxy M52 5G** (codename `m52xq`, SM-M526B / SM-M526BR,
Qualcomm Snapdragon 778G / SM7325, platform "yupik").

Not Halium, not libhybris, not the Android kernel: the phone runs a mainline
Linux 7.1.2 kernel with device drivers and fixes, and a normal Linux
userspace. Tested on one SM-M526B. Personal, unofficial project.

**Status (release "unofficial v1", 2026-11-01): a daily-usable
Linux phone** - calls, SMS, mobile data on two SIMs, Wi-Fi, Bluetooth,
GPU-accelerated UI, sound, GPS, sensors, cameras, deep sleep that wakes for
calls, SMS and Telegram messages.

## Repositories

| | |
|---|---|
| This repository | installer, rootfs overlay (scripts, services, configs), patched package recipes, device tree, documentation |
| Kernel | [sc7280-mainline-linux-m52xq](https://github.com/korryasdlerto-lgtm/sc7280-mainline-linux-m52xq), branch `master` = the kernel in v44 (7.1.2 #437), config `arch/arm64/configs/m52xq_defconfig` |
| Kernel binaries | [release v44-kernel-437](https://github.com/korryasdlerto-lgtm/sc7280-mainline-linux-m52xq/releases/tag/v44-kernel-437): boot.img of v1 (without the IPA firmware), Image, appended DTB, modules, vendor_boot, config |

## What works

| Feature | Status | Notes |
|---|---|---|
| Boot, UFS storage | works | regulator load, conservative UFS gear, error-handler deadlock fix |
| Display | works | own driver for the Samsung S6E3HAB (AMB667AN01) AMOLED panel |
| GPU (Adreno 642L) | works | freedreno, GPU-composited Plasma; GMU start/resume fixes (clock IDs, interconnect, GX_CBCR, OPP) |
| Touchscreen | works | Synaptics TCM on-cell driver |
| Wi-Fi, Bluetooth | works | WCN6750 / ath11k, Wake-on-WLAN with an APF packet filter |
| Calls, SMS, mobile data | works | both SIMs (DSDS), ModemManager patches, in-call audio over Q6 voice |
| Audio | works | loudspeaker (TFA9878), earpiece, microphones, noise suppression calibration |
| GPS | works | own raw-QRTR QMI LOC client (`tools/m52xq-gnss.py`), not through a standard location service yet |
| Sensors | works | light, proximity (screen off in calls), accelerometer (auto-rotate) through the SSC DSP (fastrpc, hexagonrpcd, patched libssc) |
| Battery, charging | works | own SM5714 fuel gauge, charger and Type-C drivers |
| Cameras | partial | see below |
| Suspend | works | wakes for calls, SMS and Telegram over Wi-Fi; drain see below |
| NFC | works | Samsung sec-nfc on i2c (boot v241 + vendor_boot v238), quick-settings tile, off by default |
| Fingerprint | no | |
| Video out over USB-C | not tested | |

### Cameras

- Kernel: sensor drivers IMX616 (front), S5KGW3 (main 64 MP), GC5035,
  FP5529 flash LED, a camera scanner (`m52xq-camscan`), CAMSS fixes, ICP (A5)
  bring-up, Venus secure mode for hardware video encoding.
- Userspace: Plasma Camera with 16 patches (`packages/plasma-camera`:
  orientation, autofocus and tap-to-focus, pinch zoom, full-resolution and RAW
  photo, JPEG quality, video with the hardware encoder), Megapixels,
  libcamera (soft ISP fixes), libmegapixels, libdng.
- Not every lens and mode works yet; details in the manual in `docs/` (section 21, appendix F).
- Hardware video encoding / decoding (Venus, vpu-2.0): the Venus driver of the
  kernel repository (`drivers/media/platform/qcom/venus`, with `secure.c` for
  the secure non-pixel buffer the m52xq firmware needs), built as modules
  (`CONFIG_VIDEO_QCOM_VENUS=m`) and installed to `/usr/lib/modules/7.1.2/extra/venus`.
  The Venus firmware is not in this repository.
- Second path, experimental: Qualcomm GPL camera driver + CamX userspace
  (`camx/`). Step 1 is done (the driver builds against our kernel and binds on
  the phone); the CamX userspace part is not started.

### Sleep and battery

- Base drain in deep sleep (s2idle) is about 37 mA, about 1 %/h, when nothing
  wakes the phone.
- With Telegram Desktop connected it is about 4 %/h: the Telegram server drops
  an idle connection about every minute and the phone wakes up (Wi-Fi WoW) to
  reconnect. Messages and calls still arrive at once.
- In sleep, SMS and messenger notifications give only the sound; the display
  stays off. Calls turn the display on.
- Helpers: `m52xq-suspend-guard` (retries a failed suspend and suspends after
  2 minutes of real idleness), `m52xq-wifi-dark` + system-sleep hooks (dark
  resume after a Wi-Fi / modem wake-up), `m52xq-notify-heal` (restarts the SMS /
  telephony daemon after a lost notification).

## Install

Requirements: unlocked bootloader, TWRP for m52xq, a microSD card with the
zips, backups of EFS, persist, modem, boot, vendor_boot and vbmeta.

- Flashable zip (1.9 GB): [postmarketos-m52xq-mainline-plasma-unofficial-v1.zip](https://drive.google.com/file/d/144tpTxWZ9abbORYdreZ5RAORVHYxRKRO/view?usp=sharing), md5 `f26412c368728f5a061da137dd3a542a`
- Video guide: <https://www.youtube.com/watch?v=Kg9ajKq3kkw>

Flash **UN1CA_3.1.0** first to get the maximum system partition size (the
installer grows `system` to 8 000 000 000 bytes and the rootfs fills it).
After LineageOS 23 the partition is 1 GB smaller, but the install still works.

TWRP steps:

```
Wipe - Format Data - yes - enter - Back - Back - Advanced Wipe - Data - Repair or Change File System - Change File System - EXT4 - Swipe to Change - Back - Back - Back - Back - Back - Install - Select Storage - Micro SD card - UN1CA_3.1.0-a5bf09f2_20260604_m52xq-sign.zip - Swipe to confirm Flash - Back - Back - Wipe - Format Data - enter - Back - Back - Advanced Wipe - Data - Repair or Change File System - Change File System - EXT4 - Swipe to Change - Back - Back - Back - Back - Back - Install - postmarketos-m52xq-mainline-plasma-unofficial-v1.zip - Swipe to confirm Flash - Reboot System
```

The installer writes boot and vendor_boot, writes the rootfs to `system` and puts
the overlay of `rootfs-overlay/` on top. The Samsung/Qualcomm device firmware is
not in the zip: the installer copies it, read-only, from the phone's own
partitions - ADSP, GPU zap shader, IPA (mobile data) and Venus from `apnhlos`,
Bluetooth firmware and sensor configs from `vendor`, the modem from `modem`, the
sensor registry from `persist`, the Bluetooth address from `EFS`. The IPA firmware
is appended to the boot ramdisk as a second (gzip) initramfs archive, because the
built-in IPA driver needs it before the rootfs is mounted. `vendor` must come from
a Samsung-based ROM (stock, UN1CA or LineageOS).

Default password (screen unlock and root): `112233`. Change the unlock
password:

```
printf "user:1111\n" | sudo chpasswd
```

### Back to Android

Video guide: <https://www.youtube.com/watch?v=0lgLbtdl4rA>

```
Wipe - Format Data - yes - enter - Back - Back - Back - Advanced Wipe - Data - Repair or Change File System - Change File System - EXT4 - Swipe to Change - Back - Back - Back - Back - Back - Install - lineage-23.2-2026-nightly-m52xq-signed.zip - Back - Back - Wipe - Format Data - enter - Reboot System
```

Stock firmware can always be restored with Odin.

## Repository layout

| Path | Content |
|---|---|
| `installer/` | `META-INF/.../update-binary` of the flashable zip (TWRP shell installer) |
| `rootfs-overlay/` | files the installer puts on the rootfs: `m52xq-*` scripts and services, system-sleep hooks, udev rules, modem/sensor/audio configs, Plasma Mobile QML. Binaries, proprietary firmware and sensor configs are not here: see `rootfs-overlay/EXCLUDED-FILES.txt` |
| `packages/` | pmaports recipes (APKBUILD + patches) of the packages we patched: spacebar, plasma-dialer, plasma-mobile, plasma-camera, megapixels, libcamera, libmegapixels, libdng, libssc, modemmanager, plasma-keyboard, kalk, qt6-qtvirtualkeyboard; plasma-mobile patches 0001…0007 (+ NFC icon 0008, not built) and plasma-nm 0001 with the cut-down build files used for the phone (see their README) |
| `pmaports-device/` | `device-samsung-m52xq` and `linux-samsung-m52xq` |
| `device-tree/vendor_boot-m52xq-v148.dts` | the device tree in vendor_boot v238 (based on the stock board DTB, with the mainline fixes) |
| `device-tree/sm7325-samsung-m52xq.dts` | early upstream-style draft, not used by the release |
| `upstream/` | bugs found here that are not specific to this phone, with ready kernel patches (`upstream/README.md`) |
| `camx/` | experimental CamX camera path: our patch to the Qualcomm GPL camera driver, the `m52xq-gdsc-reg` module, status |
| `tools/` | `repack_boot.py` (new kernel Image into boot.img, DTB tail kept), `vb_dtb.py` (new device tree into vendor_boot), `dtbo_list.py` (list/extract DTBO entries), `boot_ramdisk_append.py` / `boot_ramdisk_drop.py` (add/remove files in the boot.img ramdisk), `check-rootfs-files-paths.sh` (check before building a zip), `audit_gcc_clock_ids.py` (finds downstream/mainline clock ID mix-ups in the DT), `m52xq-gnss.py` (GPS) |
| `docs/` | the porting manual, Russian and English (`M52-mainline-porting-manual-RU.docx`, `-EN.docx`): the process, the build from scratch with commands, the boot/vendor_boot/DTBO images, a digest of the log, services and scripts, sleep, the userspace patches |

## Building

- Kernel: `make ARCH=arm64 LLVM=1 m52xq_defconfig Image` with clang/LLD 22
  (the pmbootstrap Alpine chroot); the boot image is the previous boot.img with
  the new `Image` and the appended DTB tail.
- Packages: copy a directory from `packages/` to `pmaports/temp/` and run
  `pmbootstrap build --arch aarch64 --force <name>`.

## Credits

postmarketOS and pmbootstrap, KDE Plasma Mobile, the mainline Linux developers
for Qualcomm SC7280 / QCM6490 (Fairphone 5 and others), LineageOS (device and
kernel sources used as reference), the TWRP maintainers for m52xq.

## License

Kernel code: GPL-2.0 (see the kernel repository). Patches follow the license of
the patched project. Scripts and documentation in this repository: GPL-2.0.
