# samsung-m52xq-mainline

Work-in-progress mainline Linux kernel port for the **Samsung Galaxy M52 5G**
(codename `m52xq`, model `SM-M526B`/`SM-M526BR`), targeting a real
**postmarketOS** installation running a genuine upstream Linux kernel —
not a downstream Android kernel, not Halium/libhybris.

**Status: early research / build-environment stage. Nothing has been
tested on real hardware yet.** This repository documents what has been
found and built so far, honestly, including known gaps and TODOs. It is
not a working port.

## Why this exists

Most Linux-on-Android efforts for this class of device (and the parallel
effort for this exact phone, see [Related work](#related-work) below) use
Halium/Droidian-style approaches: run a real Linux distro alongside the
original Android vendor stack, bridging to it via `libhybris` for GPU,
sensors, radio, etc. That gets you a usable phone quickly, but you inherit
every quirk and bug of the vendor's Android build forever.

This repository is the opposite approach: get the Samsung M52 5G booting
on a **real, unmodified mainline Linux kernel**, talking to hardware
through upstream, in-tree drivers only. No vendor blobs beyond the
handful of `remoteproc` firmware binaries (modem, WiFi co-processor, DSP)
that even fully mainline devices still need. If it works, you get a
genuinely maintainable, long-term-supportable Linux phone — but getting
there requires each piece of hardware to already have (or gain) upstream
kernel support.

## Hardware

| | |
|---|---|
| Device | Samsung Galaxy M52 5G |
| Codename | `m52xq` (`samsung-m52xq` in postmarketOS naming) |
| Models | SM-M526B, SM-M526BR |
| SoC | Qualcomm Snapdragon 778G 5G (**SM7325**) |
| Qualcomm internal platform codename | **"yupik"** — confirmed directly from this device's own vendor kernel boot log (`subsys-pil-tz soc:qcom,ipa_fws: yupik_ipa_fws: ...`), not inferred |
| CPU | Kryo 670 (octa-core) |
| GPU | Adreno 642L (Adreno 660-class) |
| Display | 1080×2400, Novatek NT36672E panel driver IC |
| RAM / Storage | 8 GB / 128 GB |
| Charger IC | Silicon Mitus SM5714 (fuel gauge + charger) |
| Direct-charge IC | PCA9468 |
| Auxiliary PMIC | Qualcomm PM8008 |
| Fingerprint sensor | ET523 |
| Audio codec | Qualcomm WCD938x (Bolero subsystem, TX/RX/VA macros) |
| Touchscreen | Synaptics or STM, varies by board revision |
| WiFi | Qualcomm QCA (chip generation not yet confirmed to be mainline-compatible) |

All of the above (except the SoC/platform codename, which is public
Qualcomm/Linaro terminology) was extracted from the real downstream device
tree source shipped in
[`LineageOS/android_kernel_samsung_sm7325`](https://github.com/LineageOS/android_kernel_samsung_sm7325)
(branch `lineage-23.2`,
`arch/arm64/boot/dts/samsung/m52/m52xq/m52xq_eur_open_w00_r05.dts`), cross-
referenced against
[`LineageOS/android_device_samsung_m52xq`](https://github.com/LineageOS/android_device_samsung_m52xq)
and
[`LineageOS/android_device_samsung_sm7325-common`](https://github.com/LineageOS/android_device_samsung_sm7325-common)
for board config (`BOARD_NAME := SRPUF17B001`) and the kernel module list.

## Why SM7325 has any hope of a mainline port at all

Qualcomm's SM7325/SC7280/QCM6490 are the same silicon platform family
("yupik"). Crucially, the **Fairphone 5** (QCM6490) already has real,
merged, working mainline kernel support —
[`arch/arm64/boot/dts/qcom/qcm6490-fairphone-fp5.dts`](https://github.com/torvalds/linux/blob/master/arch/arm64/boot/dts/qcom/qcm6490-fairphone-fp5.dts)
lives directly in `torvalds/linux`, not a fork. Its own history shows it
was bootstrapped from the pre-existing SC7280 support (a ChromeOS
platform), by splitting out the ChromeOS-specific TrustZone assumptions
into `sc7280-chrome-common.dtsi` so it could boot on a normal
(non-ChromeOS) board.

There is also live evidence of upstream interest specifically in SM7325:
the very same `qcm6490-fairphone-fp5.dts` file contains, as of this
writing, a TODO referencing an in-flight mailing list patch that adds
`"qcom,sm7325-lpass-tx-macro"` as an explicit compatible string
(see [lore.kernel.org/linux-arm-msm/20260526-sc7280-tx-macro-v1-0-1aad6900fec0@fairphone.com](https://lore.kernel.org/linux-arm-msm/20260526-sc7280-tx-macro-v1-0-1aad6900fec0@fairphone.com/t/)) —
i.e. SM7325-specific compatibility is actively being added upstream, not
purely assumed identical to QCM6490.

This repository uses [`sc7280-mainline/linux`](https://github.com/sc7280-mainline/linux)
(a maintained mainline-kernel fork tracking SC7280/SM7325/QCM6490
devices, which already carries the Fairphone 5 support) as the base for
all kernel work, rather than starting from vanilla `torvalds/linux`.

**No existing mainline work specifically targeting `m52xq`/SM7325 was
found anywhere** (checked: postmarketOS wiki, postmarketOS pmaports
GitLab, general web search, GitHub search for related author profiles).
One community member (`19atlas`) has a postmarketOS wiki device page for
this exact phone, but it explicitly targets a **downstream** kernel
(LineageOS `lineage-22` branch) and is marked "not tested" / "does not
boot" for every single feature — it is not related to this mainline
effort, and does not currently work either way.

## What's in this repository

```
device-tree/
  sm7325-samsung-m52xq.dts   — draft mainline device tree, heavily annotated
                                with TODOs and known-wrong sections. See
                                "Current state" below before touching this.
pmaports-device/
  device-samsung-m52xq/      — postmarketOS device package (deviceinfo +
                                APKBUILD), created via `pmbootstrap aportgen`
  linux-samsung-m52xq/       — postmarketOS kernel package APKBUILD,
                                pointing at sc7280-mainline/linux + this
                                repo's device tree + a Fairphone-5-derived
                                defconfig as a starting kernel config
docs/
  RESEARCH-LOG-RU.md         — the full, chronological research log (in
                                Russian) this port was developed from —
                                every command run, every dead end, every
                                source checked, with timestamps. Kept
                                as-is for traceability rather than
                                translated/cleaned up.
```

## Current state of `device-tree/sm7325-samsung-m52xq.dts`

Starting point: a copy of `qcm6490-fairphone-fp5.dts`, then trimmed and
partially adapted. **It compiles cleanly** with `dtc` (verified with
`make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- qcom/sm7325-samsung-m52xq.dtb`
against the `sc7280-mainline/linux` tree) — but "compiles" only means the
syntax and node references are internally consistent, **not** that it
describes this phone's real hardware correctly. Concretely, per component:

| Component | Status |
|---|---|
| GPU (Adreno a660) | Same silicon as FP5; zap-shader firmware path updated to a device-specific path, but the actual `.mbn` firmware blob for this device still needs sourcing |
| Display panel (Novatek NT36672E) | Mainline driver **exists** (`drivers/gpu/drm/panel/panel-novatek-nt36672e.c`) — DTS panel node is currently a placeholder still referencing FP5's Raydium panel compatible string, needs replacing with real GPIOs/supplies from the downstream DTS |
| Audio codec (WCD938x) | Mainline driver **exists** (`sound/soc/codecs/wcd938x.c`, `wcd938x-sdw.c`) — entire audio-codec DT node currently **commented out** in the draft (its supporting pinctrl/regulator/SWR sections were trimmed and not yet reintroduced) |
| Touchscreen (Synaptics/STM) | RMI4 mainline driver exists (`drivers/input/rmi4/`, `syna,rmi4-i2c`/`syna,rmi4-spi`) but protocol compatibility with this specific board's chip/firmware is **unconfirmed** — Samsung sometimes runs a vendor protocol on top of Synaptics silicon. STM alternative (`stmfts.c`) similarly unconfirmed. **Not included in the draft at all yet.** |
| Charger (SM5714 + PCA9468 direct-charge) | **No mainline driver exists** (checked `drivers/power/`, `drivers/iio/` in this kernel tree) — this is a real blocker for battery charge management specifically. Charging *hardware detection* alone might still work via generic power-supply framework fallbacks, but active charge control will not, without writing a driver from scratch. |
| PMIC regulators (voltage tables) | Copied verbatim from Fairphone 5's `pm7325`/`pm8350c` regulator voltage ranges. **Almost certainly wrong for this board** — different phone, different regulator wiring. This is flagged as one of the highest-risk unverified areas (wrong voltage on the wrong rail is how you damage hardware), and is exactly why this has not been tested on real hardware. |
| WiFi | Deliberately **not enabled** (`status` left commented out) pending confirmation of which physical WiFi chip this board revision uses and whether it's the same mainline-supported class as Fairphone 5's, or the closed-source `qca_cld3_wlan.ko`-requiring chip already confirmed present in the parallel Halium/Droidian port of this exact device (see below) |
| Fingerprint (ET523) | No mainline driver; deliberately out of scope for a first boot attempt |
| Camera (`cci0`/`cci1`) | Entirely removed from the draft — FP5's camera sensors (Sony IMX858, Samsung S5KJN1) are certainly not what's on this phone; needs its own investigation later |
| Vibrator | FP5's `awinic,aw86927` node removed; real chip on this phone not yet identified |
| UFS storage | `status = "okay"` only, GPIO/supply values not yet cross-checked against downstream DTS |

**Bottom line: do not attempt to boot this DTS on real hardware as-is.**
The regulator voltage tables in particular are unverified guesses copied
from a different board.

## Build environment notes

- Kernel builds natively on `aarch64` hardware just fine if you have one
  handy — this repository's own kernel source (`sc7280-mainline/linux`)
  cross-compiled fine on an x86_64 host too, using a standard
  `aarch64-linux-gnu-gcc` toolchain (Debian/Ubuntu package
  `gcc-aarch64-linux-gnu`).
- `sc7280-mainline/linux` ships a ready-made `arch/arm64/configs/fp5_defconfig`
  — that's the config this repo's kernel package currently uses as a
  starting point (it's the closest known-working config for this
  platform family; `make dtbs` for a full `dtbs` target will also build
  hundreds of unrelated Windows-on-ARM laptop device trees that happen to
  live in the same `arch/arm64/boot/dts/qcom/` directory — build the
  specific target instead, e.g. `make qcom/sm7325-samsung-m52xq.dtb`).
- `postmarketOS`'s `pmaports` repository moved from `gitlab.com` to a
  self-hosted `gitlab.postmarketos.org` in 2024 — make sure `pmbootstrap`
  and any cached clones point at the new host.
- `pmbootstrap` (the postmarketOS build tool) requires Python 3.9+; on an
  older host (this one only had 3.8), running it inside a
  `python:3.11-slim` Docker container with `--privileged` (needed for the
  chroot/mount operations `pmbootstrap` performs) worked cleanly. Mount
  `~/.config` as a volume too, not just the `work` directory — the config
  file (`~/.config/pmbootstrap_v3.cfg`) is written there and is lost
  between container runs otherwise.
- `pmbootstrap aportgen` package-name argument for a new device must use a
  hyphen (`device-samsung-m52xq`), not a slash (`device/samsung-m52xq`) —
  a slash creates a broken nested directory.

## Related work

This is one of two parallel, independent approaches to running Linux on
this specific phone, developed by the same person around the same time:

- **Halium 13 + Plasma Mobile** (downstream Android kernel + libhybris
  bridge) — already boots to a working desktop with real GPU
  acceleration, working SSH/USB networking, and a fully-booting Android
  container (used only for its HAL/vendor blob bridge, not as a user-
  facing OS). Several genuinely working fixes and root-caused bugs from
  that project are documented in its own separate repository. The two
  approaches share zero code but occasionally share hardware-identification
  findings (e.g. the a660 GPU zap-shader quirk, the SM5714/PCA9468 charger
  identification, the `qca_cld3_wlan.ko` closed-source WiFi driver
  requirement) discovered independently in each.

## License

Device tree and pmaports package files: same license as their respective
upstream templates (`BSD-3-Clause` for the device tree, following
`qcm6490-fairphone-fp5.dts`'s own header; postmarketOS pmaports packages
are typically `MIT`, matching the `aportgen`-generated `APKBUILD` headers).
Research log: no specific license asserted, provided as-is for reference.
