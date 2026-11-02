# Upstream candidates

Bugs found while porting the Samsung Galaxy M52 5G (SM7325) that are not
specific to this phone, and changes worth offering to the upstream projects.
On 2026-11-02 four kernel patches and one libdng patch were sent (see the
**sent** rows; archive: https://lore.kernel.org/all/?q=f:korryasdlerto).
The `kernel/` and `other/` folders hold exactly the versions that were sent.

Status words: **ready** = patch prepared, only a rebase onto the maintainer's
tree and a Signed-off-by are missing; **RFC** = changes intended behaviour,
send as RFC and discuss first; **report** = describe to the project, no patch
from us; **done upstream** = fixed upstream independently (we confirmed the
same bug); **sent** = mailed to the maintainers, waiting for review;
**not upstreamable** = checked against linux-next, the change only makes sense
for this board or a vendor devicetree.

## Linux kernel

| # | Area | Problem | Status | File |
|---|---|---|---|---|
| 1 | soc: qcom: pmic_glink_altmode | `%pOFn` used with a `struct fwnode_handle *`: the "missing reg property" error path oopses in `fwnode_get_name()` instead of printing. Hit with a vendor DT that has an extra `qcom,pmic-glink` node without `reg`. Fix: `%pfwP`. | **sent** 2026-11-02 to linux-arm-msm, Message-Id `20261102003324.340577-1-korryasdlerto@gmail.com` | `kernel/0001-…` |
| 2 | usb: typec: ucsi (glink, huawei_gaokun) | Same `%pOFn` / fwnode bug, copied into both drivers. Not hit by us, found by searching the tree. | **sent** 2026-11-02 to linux-usb, Message-Id `20261102003508.341309-1-korryasdlerto@gmail.com` (with `Fixes: c6165ed2f425` and `Fixes: 00327d7f2c8c`) | `kernel/0002-…` |
| 3 | scsi: ufs: core | Error handler does nothing while `hba->ufs_device_wlun` is NULL (before the first successful probe), so a link failure during the first probe is never recovered. Removing the check needs NULL guards in `ufshcd_rpm_get_sync()/ufshcd_rpm_put()`, `ufshcd_err_handling_prepare()` and `ufshcd_recover_pm_error()` (the three crashes we hit). | **sent** as RFC 2026-11-02 to linux-scsi, Message-Id `20261102003607.341651-1-korryasdlerto@gmail.com` | `kernel/0003-…` |
| 4 | scsi: ufs: core | Deadlock: `ufshcd_err_handling_prepare()` quiesces the tag set, then `ufshcd_verify_dev_init()` → `blk_execute_rq()` on the pseudo SCSI device waits forever. | done upstream (unquiesce of the pseudo sdev queue); we carry the backport | — |
| 5 | regulator: qcom-rpmh | A fixed voltage that is not on the regulator's step grid (e.g. LDO7 3.3 V on a 1.504 V + 8 mV grid) makes registration fail with -ENOTRECOVERABLE (-131), so consumers wait for their supply forever. We snap to the nearest step (`rpmh_regulator_snap_unreachable_fixed_uV()`). Arguably a DT error, but the downstream vendor DTs do this. | **not upstreamable** (checked 2026-11-02): the cause is the wrong value in the vendor DT; a mainline DTS just uses a voltage on the grid | `qcom-rpmh-regulator.c` in the kernel repository |
| 6 | iommu: arm-smmu-qcom | `qcom_adreno_smmu_set_ttbr0_cfg()` writes the context bank without holding a runtime PM reference on the SMMU; while the SMMU is runtime-suspended the write is lost and the GPU faults later. We take `pm_runtime_resume_and_get()` around the write. | **done upstream**: linux-next (next-20261030) already wraps the write in `pm_runtime_resume_and_get()` | `arm-smmu-qcom.c` in the kernel repository |
| 7 | iommu: arm-smmu-qcom | `qcom_adreno_smmu_init_context()` dereferences `dev_get_drvdata(dev)` without a NULL check; if the GPU's default domain is set up before the GPU driver has bound, the kernel crashes in a boot loop. Only reproduced with `fw_devlink=permissive`. | **not upstreamable** (checked 2026-11-02): only reachable with the debug option `fw_devlink=permissive` plus our IDENTITY default-domain workaround | `arm-smmu-qcom.c` |
| 8 | phy: qcom-qmp-ufs | sc7280 uses the `sm8150_ufsphy_hs_g4_pcs` overlay, which sets `PLL_CNTL`, timer and gear-band values that the SM7325 (yupik) downstream table does not set. Changing it did not fix our link problem; note only. | report | — |
| 9 | ufs: qcom | Downstream applies the HSG4 CFGREADY sampling erratum workaround (QCTDD06985523, `ufs_qcom_bypass_cfgready_signal()`); mainline does not. Not proven to matter on our board. | report | — |
| 10 | drm/msm a6xx | Stale RPMh votes after suspend, GMU restart after resume. | posted upstream by others ("drm/msm/a6xx: Fix stale rpmh votes after suspend", June 2026); we found the same defect independently | — |
| 11 | ath11k | `ATH11K_FLAG_REGISTERED` set unconditionally in the FW_READY handler. | done upstream (e517e207300e) | — |
| 20 | media: i2c: imx258 | The binding documents `reset-gpios` (XCLR), but the driver never requests it; on boards with XCLR on a GPIO the sensor stays in reset or is released before its supplies and INCK are up, and does not answer on I2C. Patch: request the GPIO as optional, release XCLR 2 ms after power-on, wait 12 ms before the first I2C access. Ultra-wide camera of the M52. | **sent** 2026-11-02 to linux-media, Message-Id `20261102004724.346475-1-korryasdlerto@gmail.com` | `kernel/0004-…` |

### Sending a kernel patch

```
git am upstream/kernel/0001-*.patch          # on top of the maintainer's tree / linux-next
git commit --amend -s                        # adds your Signed-off-by (Developer's Certificate of Origin)
scripts/checkpatch.pl -g HEAD
scripts/get_maintainer.pl -f drivers/soc/qcom/pmic_glink_altmode.c
git send-email --to=<maintainers> --cc=<lists> -1
```

The Signed-off-by is the sender's statement under the Developer's Certificate
of Origin, added with `git am -s` / `git commit -s` by whoever sends the patch
(the sent copies in `kernel/` carry it). The kernel accepts a known
identity (a consistent public name), not necessarily a legal name.

## KDE / Plasma Mobile

| # | Project | Problem | Status | Our patch |
|---|---|---|---|---|
| 12 | KNotifications (KF6) | If the notification server does not answer once (D-Bus NoReply, e.g. plasmashell busy right after a resume), the process keeps the server capabilities empty: every later notification is sent without actions, so tapping it does nothing. Restarting the application fixes it. | report | workaround `rootfs-overlay/usr/local/bin/m52xq-notify-heal` |
| 13 | Spacebar | A chat that is open in a window in the background (or behind the lock screen) keeps notifications for that number disabled: an incoming SMS then has no sound and no notification, is stored as read, and its time is replaced by the receive time. | report + MR | workaround `rootfs-overlay/usr/lib/systemd/system-sleep/m52xq-spacebar-sleep.sh` |
| 14 | Spacebar | Dual SIM (several modems): receive on all modems, choose the SIM for sending, show the SIM per message, delivery reports. | MR (feature) | `packages/spacebar/spacebar-0002…0005` |
| 15 | plasma-dialer | Notifications of incoming and missed calls have no default action, a tap opens nothing. | MR prepared (rebased onto master 78af3a0, where the call screen is the separate `org.kde.plasma.callscreen`; not compiled yet); needs an invent.kde.org account | `other/plasma-dialer-0001-…` (master), `packages/plasma-dialer/plasma-dialer-0004-default-open-action.patch` (old release, in use) |
| 16 | plasma-dialer | Dual SIM, DTMF key tones, add-contact button. | MR (feature) | `packages/plasma-dialer/plasma-dialer-0001…0007` |
| 17 | Plasma Mobile shell | Dual SIM signal indicators and data-SIM mark. | MR (feature) | `packages/plasma-mobile/` |

## Megapixels

| # | Project | Problem | Status | Our patch |
|---|---|---|---|---|
| 21 | libdng | `libdng_repack()` writes the rows without the source line padding, but the scanline loop still advances by the padded stride from `libdng_set_stride()`: with qcom-camss (RAW10 lines aligned to 16 bytes) every row shifts by another 12 bytes and the DNG is smeared. Use the packed row length when the data was repacked. | **sent** 2026-11-02 by e-mail to the author (Martijn Braam), Message-Id `20261102005001.347577-1-korryasdlerto@gmail.com` | `other/libdng-0001-…` |
| 22 | libmegapixels | Our `bytes_per_width % 16` padding is tuned for qcom-camss on this board; upstream takes the stride from the driver's `bytesperline`. | not upstreamable | `packages/libmegapixels/` |

Also checked on 2026-11-02 and dropped: plasma-keyboard (the option name
`PLASMA_KEYBOARD_SOUNDS_ENABLED` is consistent on master, no bug) and
kirigami ColumnView empty slide animation (fixed upstream: `ContentItem::animateX()`
now returns early via `qFuzzyCompare` / `finishAnimation()`).

## ModemManager

| # | Problem | Status | Our patch |
|---|---|---|---|
| 18 | Qualcomm QRTR modems with two SIMs (DSDS): only the primary subscription is exposed. Our patches add a second modem object for SIM 2, a data-SIM choice and non-fatal SIM 2 attach. | MR (feature, needs rework for upstream style) | `packages/modemmanager/0100…0103` |

## postmarketOS

| # | Problem | Status |
|---|---|---|
| 19 | initramfs `setup_log()` uses process substitution `exec > >(tee …)`, which exits with status 2 under the initramfs shell and kills init (August 2026). Check whether current pmaports still has it. | to check |
