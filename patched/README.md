# JioFi JMR1140 Firmware — Patched Image Index

All images here are built from the original stock firmware (`firmware/mdm9607-sysfs.ubi`).

---

## 🗂️ Image Catalogue

### `mdm9607-sysfs-stock-repacked-v2.ubi`
- **Type:** Stock / Reference
- **SHA-256:** `b933d5a76ad5696e63caa30621a1774efb887eb6b1ceff8f4698534e79012ca3`
- **Status:** ✅ Boots confirmed
- **Changes:** None — pure stock repack used only as baseline and geometry reference.

---

### `mdm9607-sysfs-unlocked-apn.ubi`
- **Type:** Stock + APN unlock
- **SHA-256:** `291b8882255d99be05cac550943fffc0acf49af46e8708be6dd40a4bef2e1bc2`
- **Status:** ✅ Boots confirmed
- **Changes:** APN restriction removed from `mobileap_cfg.xml`

---

### `mdm9607-sysfs-adb-shelllink-v2.ubi`
- **Type:** Stock + ADB shell
- **SHA-256:** `6624fac352523664ff29266e0e48410584f3b7ee9d75a981e74934d50d62788f`
- **Status:** ✅ Boots and gives `adb shell` confirmed
- **Changes:**
  - USB composition `02e1` enables ADB
  - `/system/bin/sh → /bin/sh` symlink for `adb shell`

---

### `mdm9607-sysfs-repeater-patched.ubi` ⭐ Stable Base
- **Type:** WiFi Repeater
- **SHA-256:** `269ee149ccf092a6dd57ece8316391fa99074f73aeddce6dbf55ce21e6c835be`
- **Status:** ✅ Boots and gives `adb shell` confirmed — **used as base for all further builds**
- **Changes:**
  - WiFi Repeater mode (AP+STA via hostapd + mobileap_cfg)
  - Custom Web UI (CGI scripts: status, save, scan, reboot)
  - ADB shell enabled (`02e1` composition + `/system/bin/sh` symlink)
  - RTL8189ES WiFi module (OpenLumi-derived, supports `nl80211` client mode)

---

### `mdm9607-sysfs-adb-ssh-busybox.ubi`
- **Type:** ADB + SSH + Busybox (no repeater)
- **Based on:** `mdm9607-sysfs-repeater-patched.ubi`
- **SHA-256:** `b614ef3b4fed2580f5f2e8e25c3198d155b707bf66ff9351d45891532cbba1b7`
- **Status:** ✅ Built
- **Build script:** `system_patches/4_ssh_busybox/build_ssh_busybox_image.sh`
- **Changes over base:**
  - Dropbear SSH 2022.82 (static musl) — background-safe init (forked with `&`)
  - Busybox 1.31.0 (static musl)

---

### `mdm9607-sysfs-repeater-ssh-busybox.ubi` ⭐ Recommended
- **Type:** WiFi Repeater + SSH + Busybox + Battery LED
- **Based on:** `mdm9607-sysfs-repeater-patched.ubi`
- **SHA-256:** `b286f9e4007e6c57ec1f73b1eb2bfa1cdb439529395647d66839a0b9c164f746`
- **Status:** ✅ Built
- **Build script:** `system_patches/3_wifi_repeater/build_repeater_ssh_busybox_image.sh`
- **Changes over base:**
  - Dropbear SSH 2022.82 (static musl) — background-safe init
  - Busybox 1.31.0 (static musl)
  - Battery LED manager:
    - **Charging:** blinks N times per minute based on % (1 blink = 10%)
    - **Discharging:** Green (100–70%), Orange (70–50%), Red (50–20%), Blinking Red (20–0%)
    - **Full / Idle:** White LED

---

## 🔌 Flashing

### Via Fastboot (recommended)

Enter fastboot: hold **Power + WPS** while plugging USB (or remove battery first if LEDs don't go RED).

```powershell
# Flash any image
fastboot flash system patched/<image-name>.ubi
fastboot reboot

# Restore stock
fastboot flash system firmware/mdm9607-sysfs.ubi
fastboot reboot
```

### Via Windows Firmware Upgrade Tool (first-time / no fastboot)

> ⚠️ Follow these steps **in order** or the tool will hang on "Searching device…"

1. **Install the bundled USB driver first** — run `driver.exe` from the firmware archive. This installs the Qualcomm HS-USB QDLoader driver required by the upgrade tool.
2. **Copy the tool out of `%TEMP%\amt_temp\`** — the `.exe` is self-extracting and unpacks to a temp folder Windows can wipe on reboot. Copy it to a stable path like `C:\JioFi\amt_temp\`.
3. **Rename your image to `mdm9607-sysfs.ubi`** and place it next to the upgrade tool executable.
4. Launch the upgrade tool and follow the on-screen prompts.

---

## 📦 SSH Access (After Flashing)

Connect via SSH from your PC once the device boots:

```sh
ssh root@192.168.225.1
# No password required (blank root password on personal builds)
# Or use ADB first:
adb shell
```

Generate and push your SSH public key for passwordless login:

```sh
ssh-copy-id root@192.168.225.1
# or manually:
adb push ~/.ssh/id_rsa.pub /data/dropbear/authorized_keys
adb shell chmod 600 /data/dropbear/authorized_keys
```

---

## 🔧 ADB Without Flashing (Stock Firmware)

The stock firmware contains OEM AT handlers that can enable ADB through the router's serial COM port:

```text
AT%DBGMODE=1
AT%DBGUSBSET=1
```

These are handled by `amt_atfwd_daemon` / `libamt_atfwd_utils.so.0`. Use a serial terminal (e.g. PuTTY) on the JioFi's COM port.

---

## 🏗️ Manual Patching Guide

### Part 1: Enabling ADB

#### Step 1.1: Edit USB Composition

Open `sbin/usb/compositions/02e1` and find the default boot case (`*`) around line 139:

```diff
        * )
-           if [ $(cat /sys/devices/soc:smem_db/wdisk_mode) == "1" ]
-           then
-               run_mass_storage &
-           else
-               run_mass &
-           fi
+           if [ $(cat /sys/devices/soc:smem_db/wdisk_mode) == "1" ]
+           then
+               run_mass_storage &
+           else
+               run_nomass &
+           fi
        ;;
```

#### Step 1.2: Create ADB Shell Symlink

`adbd` looks for the shell at `/system/bin/sh`. Create a symlink inside your fakeroot session:

```sh
ln -s /bin/sh /path/to/extracted/rootfs/system/bin/sh
```

---

### Part 2: Unlocking APN Settings (Other SIM Cards)

#### Step 2.1: Unhide APN Fields in Web UI

Open `WEBSERVER/www/setting/QCMAP_LTE.html`, find the `session_level == 3` block (~line 166):

```diff
-                   document.getElementById('H_default_apn').style.display = "none";
-                   document.getElementById('Table_Apn_network').style.display = "none";
+                   document.getElementById('H_default_apn').style.display = "block";
+                   document.getElementById('Table_Apn_network').style.display = "block";
-                   document.getElementById('H_MultiAPN').style.display = "none";
-                   document.getElementById('Table_MultiAPN').style.display = "none";
+                   document.getElementById('H_MultiAPN').style.display = "block";
+                   document.getElementById('Table_MultiAPN').style.display = "block";
```

#### Step 2.2: Change Default APN

Open `etc/mobileap_cfg.xml`:

```diff
-       <APN>jionet</APN>
+       <APN>internet</APN>
```

---

## ⚠️ Critical Build Rules (Learned from Bootloops)

### 1. Always extract with `-k` (keep permissions)
```bash
ubireader_extract_files -k -o $EXTRACT_DIR $BASE_UBI
```
Without `-k`, ubireader drops UID/GID metadata. 1,439 of 1,660 system files get packaged owned by your PC user instead of `root`, causing an instant bootloop.

### 2. Never move rootfs across filesystem boundaries
Extract, patch, and repack **entirely within the same physical partition**. Moving from `/tmp` (tmpfs) to `/home` (ext4) reassigns all inode numbers, destroying the `fakeroot` permissions database.

### 3. Dropbear init must fork to background
```sh
( dropbearkey ... && dropbear ... ) &
```
The kernel has near-zero entropy on boot — synchronous `dropbearkey` blocks the entire init sequence permanently.

### 4. Patch Busybox inside fakeroot
Always `cp` + `chmod` the new Busybox inside a `fakeroot -- sh -c '...'` session so the inode is recorded as `uid=0 gid=0`.

---

## ✅ Correct Repack Geometry

| Parameter | Value |
|---|---|
| UBI Min I/O | `2048` |
| UBI PEB size | `128KiB` |
| VID header offset | `2048` |
| UBIFS LEB size | `126976` |
| UBIFS max LEB count | `2146` |
| UBIFS journal size | `8388608` |
| Image sequence | `907419386` |
| Volume name | `rootfs` |
| Volume flags | `autoresize` |
| Volume size | `42029056` |

```sh
ROOT=/path/to/extracted/rootfs
OUT=/path/to/out
STATE=/path/to/fakeroot.state

fakeroot -i "$STATE" -- /usr/sbin/mkfs.ubifs \
  -r "$ROOT" \
  -m 2048 -e 126976 -c 2146 -F -j 8388608 -x lzo \
  -o "$OUT/rootfs.ubifs"

cat > "$OUT/ubinize.cfg" <<'EOF'
[rootfs]
mode=ubi
image=/path/to/out/rootfs.ubifs
vol_id=0
vol_size=42029056
vol_type=dynamic
vol_name=rootfs
vol_flags=autoresize
EOF

/usr/sbin/ubinize \
  -o "$OUT/mdm9607-sysfs-custom.ubi" \
  -m 2048 -p 128KiB -s 2048 -Q 907419386 \
  "$OUT/ubinize.cfg"
```

---

## 🔍 Verification

```sh
.tools/ubi-venv/bin/ubireader_display_info patched/mdm9607-sysfs-repeater-patched.ubi
```

Expected fields:
```
Image Sequence Num: 907419386
Volume name: rootfs
flags: autoresize
max_leb_cnt: 2146
max_bud_bytes: 8388608
```
