# CamX camera path (experimental, stopped after step 1)

A second camera path next to the mainline CAMSS one: the Qualcomm GPL
kernel camera driver plus the Qualcomm CamX userspace, the way the camera
works on Qualcomm Linux for QCM6490 (same "kodiak"/yupik family as SM7325).

The mainline CAMSS camera (Plasma Camera / Megapixels) stays the default
and works without any of this.

## Step 1 - done: the kernel driver builds and binds

- Source: <https://github.com/qualcomm-linux/camera-driver> (GPL-2.0),
  `CAMERA_ARCH=qcm6490`, built out of tree against our 7.1.2 kernel:

  ```
  make -C <kernel> ARCH=arm64 LLVM=1 M=<camera-driver> \
       CAMERA_KERNEL_ROOT=<camera-driver> KERNEL_ROOT=<kernel> \
       CAMERA_ARCH=qcm6490 KCFLAGS="-Wno-error=format-truncation" modules
  ```

- `qualcomm-camera-driver-m52xq.patch` (against upstream 578c3ec):
  - `camera_main.c`: no `qcom,camera_kt` container node in our DT, register
    our own platform device;
  - `cam_soc_util.c`: OPP tables optional;
  - `cam_soc_icc.c`: `of_icc_get()` on the child axi-port node;
  - `cam_mem_mgr.c`: cache dir initialisation fix.
- `m52xq-gdsc-reg/`: small module that provides the camera GDSCs as the
  downstream-style `qcom,gdsc` regulators the driver expects (mainline has no
  driver for them).
- Result: `camera_qcm6490.ko` loads and the whole camera_kt driver binds on
  the phone (test device tree, not in the release).

## Next steps (not done)

1. OPP tables for the camera nodes in the device tree.
2. A glibc (Ubuntu) chroot with the Qualcomm CamX userspace (camx-kodiak).
   CamX is binary-only (Qualcomm license, Qualcomm chips only); it is
   downloaded by the user from Qualcomm, never redistributed here.
3. Samsung sensor modules and tuning files: copied from the phone's own
   vendor partition at install time, never published.
4. A switch between the mainline CAMSS camera and CamX (both must not be
   loaded at the same time).
