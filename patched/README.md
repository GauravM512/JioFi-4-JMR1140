# JioFi JMR1140 Patched Firmware

This directory contains bootable UBI firmware images for the
**JioFi JMR1140** (Qualcomm MDM9607) router, plus a custom Realtek
Wi-Fi driver and the AP+STA repeater helpers. Every UBI image here was
built with the corrected **v2 repacking geometry** (image sequence
`907419386`, see [Correct Repack Recipe](#correct-repack-recipe));
earlier repack attempts with mismatched sub-page sizes bootlooped
the device before this geometry was pinned down.

---

## Working Images (most recent first)

### `mdm9607-sysfs-repeater-patched.ubi`
* **Purpose:** Full Wi-Fi repeater / extender with permanent ADB shell.
* **Tested:** Boots, exposes `adb shell`, broadcasts a local hotspot,
  connects to an upstream Wi-Fi AP through the custom STA-capable
  `rtl8189es` driver.
* **Layered on top of:** `mdm9607-sysfs-adb-shelllink-v2.ubi` +
  OpenLumi `rtl8189es.ko` + `start_repeater` init script +
  `hostapd.conf`.

### `mdm9607-sysfs-unlocked-apn.ubi`
* **Purpose:** Carrier-lock bypass + permanent ADB shell.
* **Default APN:** `internet` (generic, not `jionet`).
* **Web UI:** `Default APN` and `Multiple APN` tables unhidden under
  `session_level == 3` (administrator login).

### `mdm9607-sysfs-adb-shelllink-v2.ubi`
* **Purpose:** Stock firmware with a permanent root ADB shell — **no
  other modifications**.
* **Use this when:** You want a minimal, well-understood base that
  you can layer further customisations on top of.

### `mdm9607-sysfs-stock-repacked-v2.ubi`
* **Purpose:** Zero-edit stock repack, used to validate the v2
  repacking geometry before layering any of the patches above.
* **Use this when:** Sanity-checking the build pipeline, or as a
  known-good rollback.

---

## Repeater Image Changes

`mdm9607-sysfs-repeater-patched.ubi` combines every patch in
`mdm9607-sysfs-adb-shelllink-v2.ubi` plus the repeater subsystem:

* `/usr/lib/modules/3.18.20/kernel/drivers/net/rtl8192cd/rtl8189es.ko`
  — replaced with the OpenLumi-derived client / STA-capable module
  (see [`../../DRIVER_BUILD.md`](../../DRIVER_BUILD.md) for build
  prerequisites). The custom module is loaded with power management
  disabled (`rtw_power_mgnt=0`, `rtw_ips_mode=0`).
* `/etc/init.d/start_repeater` — launches the AP+STA repeater on
  boot (driven by the standalone script in this folder).
* `/etc/hostapd.conf` — local hotspot config (`ssid=JioFi_Repeater`,
  WPA2-PSK, default passphrase `12345678`; mirrors this folder's
  `hostapd.conf`).
* `/etc/mobileap_cfg.xml` —
  `<WlanMode>AP-STA</WlanMode>` and
  `<MobileAPSTABridgeEnable>1</MobileAPSTABridgeEnable>`.
* `start_QCMAP_ConnectionManager_le` and
  `start_QCMAP_Web_CLIENT_le` — neutered (stubbed to `/bin/true`)
  so QCMAP does not fight the repeater for the radio interface.
* `uiapp` daemon — neutered to free up the LED class nodes for the
  repeater status indicator.

After flashing:

```sh
# 1. Confirm ADB shell is up:
adb shell

# 2. Configure upstream Wi-Fi credentials:
cat > /etc/wpa_supplicant.conf <<'EOF'
ctrl_interface=/var/run/wpa_supplicant
network={
    ssid="YOUR_UPSTREAM_SSID"
    psk="YOUR_UPSTREAM_PASSWORD"
    key_mgmt=WPA-PSK
}
EOF

# 3. The repeater is already running; SSID "JioFi_Repeater"
#    should be visible. Browse http://192.168.224.1/ for the
#    repeater Web UI.
```

LED behaviour of the upstream STA connection is encoded directly in
the `start_repeater` background loop:

| LED | State |
|-----|-------|
| Solid Green | RSSI ≥ 70 % |
| Solid Amber | RSSI 35 – 69 % |
| Solid Red | RSSI < 35 % |
| Fast blink Red (250 ms) | Reconnecting / lost upstream |
| Slow blink Red (500 ms) | Booting / waiting for config |

---

## Repeater Status

* **Status:** **Working** on stock JMR1140 hardware.
* **Driver note:** The OEM `rtl8189es.ko` is an AP-only build.
  Forcing `opmode=8` (`IW_MODE_INFRA`) on it silently reverts to
  master mode with `Undefined state... using AP mode as default`.
  The repeater image replaces it with the OpenLumi-derived module
  that has working `nl80211` client-mode support.

---

## Helpers

### `start_repeater.sh`
A standalone copy of the same script that lives at
`/etc/init.d/start_repeater` inside the repeater image. Useful as a
reference and for running the repeater manually under `adb shell`
without rebooting into the image.

### `hostapd.conf`
The local-hotspot configuration consumed both by
`start_repeater.sh` and by the on-device `start_repeater` init
script. Defaults: `ssid=JioFi_Repeater`, `channel=1`, `hw_mode=g`,
`wpa=2`, `wpa_passphrase=12345678`. Edit this file before a manual
run if you want a different SSID or passphrase.

---

## ADB Without Flashing

The firmware contains OEM AT handlers for:

```text
AT%DBGMODE=1
AT%DBGUSBSET=1
```

Those commands are handled by `amt_atfwd_daemon` /
`libamt_atfwd_utils.so.0` and can enable ADB on stock firmware
through the router AT/serial COM port without flashing any of these
images.

---

## Correct Repack Recipe

The first stock repack bootlooped because the UBIFS geometry was
wrong. The working recipe (used by `mdm9607-sysfs-stock-repacked-v2.ubi`
and every downstream image) uses:

* UBI min I/O: `2048`
* UBI PEB size: `128KiB`
* VID header offset: `2048`
* UBIFS LEB size: `126976`
* Image sequence: `907419386`
* Volume name: `rootfs`
* Volume flags: `autoresize`
* UBI total blocks: `327`
* UBI data blocks: `325`
* UBIFS `max_leb_cnt`: `2146`
* UBIFS journal: `8388608`
* UBIFS flag: `Space fixup`

Build commands:

```sh
ROOT=/path/to/extracted/rootfs
OUT=/path/to/out
STATE=/path/to/fakeroot.state

fakeroot -i "$STATE" -- /usr/sbin/mkfs.ubifs \
  -r "$ROOT" \
  -m 2048 -e 126976 -c 2146 -F -j 8388608 -x lzo \
  -o "$OUT/rootfs.ubifs"

cat > "$OUT/ubinize.cfg" <<'EOF'
[sysfs_volume]
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

When using the config above, replace `/path/to/out/rootfs.ubifs`
with the real absolute path. `ubinize` does not expand shell
variables inside the config file.

---

## Verification Commands

```sh
.tools/ubi-venv/bin/ubireader_display_info patched/mdm9607-sysfs-stock-repacked-v2.ubi
sha256sum -c patched/SHA256SUMS
```

Expected `ubireader` fields:

```text
Total Block Count: 327
Data Block Count: 325
Image Sequence Num: 907419386
PEB Range: 2 - 326
reserved_pebs: 331
flags: autoresize
UBIFS flags: Space fixup
leb_cnt: 325
log_lebs: 5
max_bud_bytes: 8388608
max_leb_cnt: 2146
```

---

## Flashing

Restore stock:

```sh
fastboot flash system firmware/mdm9607-sysfs.ubi
fastboot reboot
```

Flash the repeater image:

```sh
fastboot flash system patched/mdm9607-sysfs-repeater-patched.ubi
fastboot reboot
```

If the device is not yet in fastboot, hold the **Power + WPS**
buttons simultaneously while connecting the USB cable (or remove
the battery first and run purely on USB power if the LEDs do not
turn RED). For first-time flashes you can also rename the `.ubi`
to `mdm9607-sysfs.ubi`, drop it into `firmware/` next to the
Windows `Firmware Upgrade_6.x.exe` tool, and run that installer.

---

## Manual Patching Guide

If you are repacking the firmware yourself, here are the
step-by-step file edits needed to enable ADB and SIM unlocking
independently.

### Part 1: Enabling ADB

To enable ADB, you need to modify the USB composition script to
initialize the ADB interface during normal boot, and create a
symlink for the shell.

#### Step 1.1: Edit USB Composition

Open `sbin/usb/compositions/02e1` on the extracted rootfs and locate
the default boot option case (`*`) around line 139:

```diff
        * )
-           # Enable WiFi disk mode in normal boot.
-           if [ $(cat /sys/devices/soc:smem_db/wdisk_mode) == "1" ]
-           then
-               run_mass_storage &
-           else
-               run_mass &
-           fi
+           # Enable ADB in normal boot while preserving WiFi disk mode.
+           if [ $(cat /sys/devices/soc:smem_db/wdisk_mode) == "1" ]
+           then
+               run_mass_storage &
+           else
+               run_nomass &
+           fi
        ;;
```

#### Step 1.2: Create ADB Shell Symlink

Qualcomm's `adbd` looks for the shell executable at `/system/bin/sh`.
In standard Yocto, the shell is located at `/bin/sh`. You must
create a symlink to bridge this. *Within your fakeroot extraction
session*, run:

```sh
ln -s /bin/sh /path/to/extracted/rootfs/system/bin/sh
```

### Part 2: Enabling Other SIM Cards (Unhiding APN Settings)

By default the JMR1140 is carrier-locked to Jio. The lock is enforced
in the Web UI and config files by hiding APN editing and forcing
`jionet`; the modem itself is typically already unlocked.

#### Step 2.1: Unhide APN Fields in Web UI

Open `WEBSERVER/www/setting/QCMAP_LTE.html` on the extracted rootfs
and locate the `session_level == 3` (user login level) code block
around line 166:

```diff
                    //Default APN
-                   document.getElementById('H_default_apn').style.display = "none";
-                   document.getElementById('Table_Apn_network').style.display = "none";
+                   document.getElementById('H_default_apn').style.display = "block";
+                   document.getElementById('Table_Apn_network').style.display = "block";
                    //Multiple APN
-                   document.getElementById('H_MultiAPN').style.display = "none";
-                   document.getElementById('Table_MultiAPN').style.display = "none";
+                   document.getElementById('H_MultiAPN').style.display = "block";
+                   document.getElementById('Table_MultiAPN').style.display = "block";
```

#### Step 2.2: Change Default APN to Generic

Open `etc/mobileap_cfg.xml` on the extracted rootfs and change the
default APN from Jio's to the generic APN used by other carriers:

```diff
        <APN4NetworkAttach>1</APN4NetworkAttach>
-       <APN>jionet</APN>
+       <APN>internet</APN>
```

Once flashed, you can insert another SIM card, log into the Web UI,
and manually configure any carrier APN via the newly visible LTE
settings page.
