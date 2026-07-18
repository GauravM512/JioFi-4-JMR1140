# 🐚 JioFi 4 (MDM9607) Static Busybox Patches

This patch contains prebuilt statically compiled binaries for **Busybox** built specifically for the JioFi JMR1140 router's EABI5 ARMv7l architecture.

These binaries are statically compiled against `musl-libc` to ensure full compatibility with the old Linux `3.18.20` kernel without library version or compiler mismatch warnings.

---

## 📂 Version Options

We provide two versions of Busybox for you to choose from depending on your compatibility needs:

1. **Busybox v1.31.0** (located at [binaries/1.31.0/busybox](file:///home/gaurav/jiofi/system_patches/5_busybox/binaries/1.31.0/busybox))
   * **Size:** 1.10 MB
   * **Note:** Very stable, widely tested compatibility build used in dropbear integration.
2. **Busybox v1.38.0** (located at [binaries/1.38.0/busybox](file:///home/gaurav/jiofi/system_patches/5_busybox/binaries/1.38.0/busybox))
   * **Size:** 1.37 MB
   * **Note:** The latest stable compilation containing the newest features and applets.

---

## ⚡ Installation Instructions

### Method 1: Applying directly to a custom UBI Firmware Repack
If you are compiling a custom system firmware image, choose your preferred version and copy it into your extracted rootfs:

1. **Copy the chosen binary and set permissions (replace `<version>` with `1.31.0` or `1.38.0`):**
   ```bash
   # Copy updated busybox binary (e.g. for 1.38.0)
   cp binaries/<version>/busybox /tmp/extracted_rootfs/rootfs/bin/busybox
   chmod 755 /tmp/extracted_rootfs/rootfs/bin/busybox
   chown 0:0 /tmp/extracted_rootfs/rootfs/bin/busybox
   ```

2. **Rebuild the UBI image** using `mkfs.ubifs` and `ubinize` (refer to the main [system_patches/README.md](../README.md)).

---

### Method 2: Installing live via ADB (No Flashing Required)
If you already have ADB shell access and want to update Busybox directly onto the running device:

1. **Mount the rootfs as read-write:**
   ```bash
   adb shell mount -o remount,rw /
   ```

2. **Push the chosen binary and update permissions (replace `<version>` with `1.31.0` or `1.38.0`):**
   ```bash
   # Push updated Busybox
   adb push binaries/<version>/busybox /bin/busybox
   adb shell chmod 755 /bin/busybox
   adb shell chown 0:0 /bin/busybox
   ```

3. **Verify the installation:**
   ```bash
   adb shell busybox
   ```
