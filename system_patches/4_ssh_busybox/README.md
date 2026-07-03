# 🐚 JioFi 4 (MDM9607) Dropbear SSH & Updated Busybox Patch

This patch contains prebuilt statically compiled binaries for **Dropbear SSH** and **Busybox** built specifically for the JMR1140 router's EABI5 ARMv7l architecture. The Dropbear binary is statically compiled against `musl-libc` to ensure full compatibility with the old Linux `3.18.20` kernel without trigger version warnings.

---

## 📂 Included Components

1. **`binaries/busybox`** (Static Busybox version `1.31.0` compiled with `musl-libc`)
2. **`binaries/dropbear`** (Static Dropbear SSH multi-binary version `2022.82` compiled with `musl-libc`, only **418 KB**)
3. **`etc/init.d/dropbear`** (Init boot startup service configured to store keys persistently in `/data/dropbear` and PID file to `/tmp/dropbear.pid`)

---

## ⚡ Installation Instructions

### Method 1: Applying directly to a custom UBI Firmware Repack
If you are compiling a custom system firmware image, copy these files into your extracted rootfs:

1. **Copy the binaries and init script:**
   ```bash
   # Copy dropbear multi-binary and create symlinks
   cp binaries/dropbear /tmp/extracted_rootfs/rootfs/usr/sbin/dropbearmulti
   chmod 755 /tmp/extracted_rootfs/rootfs/usr/sbin/dropbearmulti
   ln -sf dropbearmulti /tmp/extracted_rootfs/rootfs/usr/sbin/dropbear
   ln -sf ../sbin/dropbearmulti /tmp/extracted_rootfs/rootfs/usr/bin/dropbearkey
   ln -sf ../sbin/dropbearmulti /tmp/extracted_rootfs/rootfs/usr/bin/dbclient

   # Copy updated busybox binary
   cp binaries/busybox /tmp/extracted_rootfs/rootfs/bin/busybox
   chmod 755 /tmp/extracted_rootfs/rootfs/bin/busybox

   # Copy Dropbear init service script
   cp etc/init.d/dropbear /tmp/extracted_rootfs/rootfs/etc/init.d/dropbear
   chmod 755 /tmp/extracted_rootfs/rootfs/etc/init.d/dropbear
   ```

2. **Register the SSH daemon to run on boot:**
   ```bash
   cd /tmp/extracted_rootfs/rootfs/etc
   ln -sf ../init.d/dropbear rc5.d/S60dropbear
   ```

3. **Unlock root password (Allow blank passwords):**
   Open `/tmp/extracted_rootfs/rootfs/etc/shadow` in a text editor, locate the `root` user line, and clear the password hash (the field between the first and second colons). Change:
   ```text
   root:*:17351:0:99999:7:::
   ```
   to:
   ```text
   root::17351:0:99999:7:::
   ```

4. **Rebuild the UBI image** using `mkfs.ubifs` and `ubinize` (refer to the main [system_patches/README.md](../README.md)).

---

### Method 2: Installing live via ADB (No Flashing Required)
If you already have ADB shell access and want to install SSH and updated Busybox directly onto the running device:

1. **Unlock root password on the running device:**
   ```bash
   adb shell "sed -i 's/^root:[^:]*:/root::/' /etc/shadow"
   ```

2. **Push the binaries and scripts:**
   ```bash
   # Push updated Busybox
   adb push binaries/busybox /bin/busybox
   adb shell chmod +x /bin/busybox

   # Push Dropbear SSH multi-binary and setup symlinks
   adb push binaries/dropbear /usr/sbin/dropbearmulti
   adb shell chmod +x /usr/sbin/dropbearmulti
   adb shell ln -sf dropbearmulti /usr/sbin/dropbear
   adb shell ln -sf ../sbin/dropbearmulti /usr/bin/dropbearkey
   adb shell ln -sf ../sbin/dropbearmulti /usr/bin/dbclient

   # Push init daemon scripts
   adb push etc/init.d/dropbear /etc/init.d/dropbear
   adb shell chmod +x /etc/init.d/dropbear
   ```

3. **Reboot the device:**
   ```bash
   adb reboot
   ```
   Once rebooted, the Dropbear daemon will start automatically on port 22.

---

## 🐚 SSH Connection
Connect from your PC using:
```bash
ssh root@192.168.1.103
```
*(Press **Enter** when prompted for a password!)*
