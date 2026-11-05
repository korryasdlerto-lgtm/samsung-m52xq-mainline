# Changes from unofficial v1 to unofficial v2

Audience: users of the port and developers who want to know what changed and why.

| | v1 (2026-11-01) | v2 (2026-11-05) |
|---|---|---|
| Kernel | 7.1.2 #437 (boot v249) | 7.1.13 #442 (boot v254) |
| Device tree | downstream-style DTB (vendor_boot v238) | DTB built from the upstream-style `sm7325-samsung-m52xq.dts` plus local nodes (vendor_boot local-v34) |
| dtbo | left as it was | replaced by `dtbo-frag` (one harmless fragment; ABL needs it for this DTB) |
| Zip | `...-unofficial-v1.zip` | `...-unofficial-v2-50.zip`, md5 `ce6903082a6632d9ff209262dd317748` |

A clean install is required: Format Data as described in the README.

## Kernel

- Updated from 7.1.2 to the 7.1.13 stable release.
- `sm5714_fg`: accepts the ADC node as `vadc` or `adc`. With the upstream DT node name the driver silently used the chip temperature instead of the battery NTC, and AFC charging jumped between 9 V and 5 V every few seconds. Now the battery temperature is real and 9 V is stable.
- `sm5714_typec`: interrupts during suspend are deferred until resume, like `fusb302` does, so the I2C bus is not touched while it is asleep.
- `s3fwrn5` (NFC): the I2C driver enables an optional `pvdd` supply before driving EN. This also went to upstream with a binding change.
- `ath11k` AHB: driver removal fixed for a device that failed to start or was never registered, so `modprobe -r ath11k_ahb` (the real Wi-Fi off) works.

## Device tree

The DTB now comes from the file that is being upstreamed, so the phone runs what reviewers read. Differences that matter on the phone:

- **Touchscreen dead zones:** regulators S1b, S7b and S8b are raised to stock minimums (1.872, 0.972, 1.272 V). They feed the LDOs of the touch rail.
- **UFS:** VCC L7b is fixed at 2.952 V; it defaulted to 2.4 V and gave UFS errors.
- **Sensors:** L12c is always on at 1.8 V; unpowered sensors crashed the ADSP (`bus recovery fatal`).
- **Bluetooth:** correct RFA supplies (`vddrfa1p2` = S8b, `vddrfa2p2` = S1c); error `0xfc00` at start is gone.
- **microSD:** SD pin configuration and card-detect pin added.
- **NFC:** interrupt is edge-rising, and the power rail is a switched regulator used by the driver.
- **Memory map:** the region for Samsung `removed` memory was corrected, CDSP memory dropped (no CDSP firmware path is used), camera carveout corrected. The `video@8ad00000` overlap with ADSP memory from the v1 upstream patch is gone.
- **Display:** framebuffer node kept simple for the bootloader splash.

## Calls and audio

- **ADSP crash on speaker/earpiece switching, fixed.** The audio DSP crashed (`EX:audio_process`, `AfeDy...`/`EF00`) on the 3rd or 4th voice session of one call. It happened on 17.10, 23.10, 04.11 and three times on 05.11, always a few milliseconds after the calibration data was sent. Without calibration there was no crash, but the volume was wrong. The cause is the Samsung module `0x10001001` in the voice calibration: the 10 records of this module are removed from `m52xq_voice_cal_{handset,speaker}_48k.bin`, the other 45 are kept. Test: 9 sessions in one call, no crash, normal volume. The 8k/16k/headset/Bluetooth files are unchanged.
- **Ringtone silence after a while, fixed.** `pulseaudio.desktop` loaded `module-x11-xsmp`, which ended PulseAudio together with Xwayland; `kde-telephony-daemon` kept a dead canberra context and calls rang silently. PulseAudio autostart is hidden now and PulseAudio has its own user service, `m52xq-pulseaudio.service`. Before that it was autospawned inside `m52xq-call-screen-wake`, so restarting that service killed the sound.
- **Random silent speaker, worked around.** The TFA9878 amplifier is set up over I2C (GPI DMA 900000) when the speaker opens; on `Event without a pending descriptor` it stays silent while the PCM runs. New service `m52xq-tfa-guard` watches the kernel log and re-opens the sink. The root cause in the GPI/I2C path is not found yet. The logic was tested on a playing sound; a real failure on a ringtone has not happened since it was installed.

## Incoming calls

- **GSM:** `m52xq-call-screen-wake` now reacts to the ringtone of `kde-telephony-daemon`: it switches the display on, starts `plasma-dialer` if needed and raises its window with a KWin script (`m52xq-raise-dialer.js`). Before, the phone showed only a notification on an unlocked screen, and a dialer running in the background stayed minimised.
- **Telegram:** a Telegram sound still playing after 2 s is treated as a ringtone and the call window is raised (`m52xq-raise-telegram.js`). KWin refuses Telegram's own activation while locked; the window is on top after unlocking. It cannot appear over the lock screen.

## Wi-Fi and Bluetooth

- **Wi-Fi really turns off.** In v1 the tile used rfkill, and with rfkill the WPSS firmware never sleeps (~110 mA overnight). Now off unloads `ath11k_ahb` and WPSS is shut down; on re-initialises WCN6750 through the Bluetooth driver and loads the driver back (`m52xq-wifi-hw`, `m52xq-wifi-soft`, `m52xq-wpss-restart`, about 20 s).
- **Settings page, fixed.** The Wi-Fi switch in Settings had an endless on/off loop: upstream uses `onCheckedChanged` + `handler.enableWireless()`, which also fires on state changes (hundreds of `radio-control` calls). The page inside `kcm_mobile_wifi.so` was replaced: `onToggled`, and the same `m52xq-wifi-soft` as the tile. See `packages/plasma-nm/`. After replacing this file on a running system, delete `~/.cache/plasma-settings/qmlcache`.
- **Messages after a wake-up, fixed.** NetworkManager took Wi-Fi down on every resume ("belatedly take down Wake-on-LAN devices"): deauth, then 7-8 s to reconnect, and pushes were lost until TCP retried, up to 3-4 minutes. New sleep hook `m52xq-nm-keep-wifi.sh` disarms WoWLAN before NetworkManager handles the resume and arms it again 3 s later. Telegram message now arrives about 1.3 s after the wake-up.
- **Bluetooth after Wi-Fi off/on, fixed.** Restarting WPSS re-probes the Bluetooth controller, which came back unconfigured without an address. `m52xq-wpss-restart` now sets the address again. It also finds WPSS by name instead of assuming `remoteproc0`.

## NFC

- Polling only with the screen on (`m52xq-nfc-poll`, started by `m52xq-nfc-power`), with reliable start: the chip must answer, otherwise power cycle. Before, about 70 IRQ/s while polling and an unreliable start after the tile.
- `m52xq-nfc status` reads the saved state, because the chip is off while the screen is off.

## Charging, USB, boot

- AFC 9 V stable (see kernel).
- USB role restore finds the role switch by pattern on both device tree naming schemes; USB runtime PM rules cover both names.
- `m52xq-depmod-firstboot` rebuilds the module index once. In v2 an ordering cycle with udev was fixed: it caused a userdata timeout on every boot.
- Virtual camera service fixed (it had no execute permission in v1) and finds nodes on both `soc` and `soc@0`.
- GPS state is restored after a reboot.

## Interface

- Reboot menu and SIM manager follow the system language: Russian, Korean, Japanese, Simplified Chinese, Hindi, Arabic, otherwise English. Titles stay in English. Messages from the SIM script itself are still English.
- Installer banner shortened, dtbo line added to the summary.

## Sleep

Measured on v2 with the raw fuel gauge counter:

- Wi-Fi, NFC, Bluetooth off: about 24 mA.
- Wi-Fi on: about 48 mA while asleep, about 91 mA on average, because network packets wake the phone (interrupt `ce2`) and each wake-up costs about 25 s awake.

## Known issues in v2

- Outgoing SMS were rejected by the network on both SIMs during the last test, with zero balance (`RP cause 28` and `96`). Not yet confirmed on a SIM with credit. Incoming SMS work.
- Mobile data reconnected about every 30 s on a SIM with zero balance on GSM (`modem-no-carrier`). Not yet checked with credit.
- Once in a day WPSS crash-looped at Wi-Fi on (`ccpm_mhi.c:397:mhi_issue_request Failed`); it could not be reproduced. In that state, switching Wi-Fi off hangs in `modprobe -r` and a reboot is needed: `m52xq-wifi-hw` does not guard against it yet.
- USB networking did not come up after one boot and after one sleep; a reboot helped.
- No sound or notification for an SMS while the Messages app is open (behaviour of the app).
- Telegram ringtone may start 3-4 s late.
- Browser video is software decoded; 10-bit HEVC does not decode on Venus.
- Fingerprint reader and VoLTE do not work.
- The zip still contains Wi-Fi firmware, `board-2.bin` and Adreno firmware; everything else is copied from the phone.
