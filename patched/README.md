# JioFi JMR1140 Firmware Notes

## Working Images

- `mdm9607-sysfs-stock-repacked-v2.ubi`
  - Zero-edit stock repack.
  - Confirmed by device test: boots.

- `mdm9607-sysfs-adb-shelllink-v2.ubi`
  - Confirmed by device test: boots and gives `adb shell`.
  - Changes: normal `02e1` USB composition enables ADB, and
    `/system/bin/sh -> /bin/sh` is present.

- `mdm9607-sysfs-adb-extender-v1.ubi`
  - New extender test image.
  - Based on the working ADB fallback rootfs.
  - Keeps ADB shell.
  - Enables AP+STA defaults for Wi-Fi extender testing.

Older files without `v2` are kept only for comparison. Do not use them first.

## Extender Image Changes

`mdm9607-sysfs-adb-extender-v1.ubi` changes:

- `/etc/mobileap_cfg.xml`
  - `<WlanMode>AP-STA</WlanMode>`
  - `<MobileAPSTABridgeEnable>1</MobileAPSTABridgeEnable>`
  - Backhaul priority changed to `wlan`, then `wwan`, then `usb_cradle`.

- `/WEBSERVER/www/QCMAP.html`
  - Adds visible `WiFi Extender` menu item under Settings.
  - Adds `#wlan` hash loader.

- `/WEBSERVER/www/QCMAP_WLAN.html`
  - Direct browsing now redirects to `QCMAP.html#wlan`.
  - Use: `http://192.168.225.1/QCMAP.html#wlan`

- `/usr/bin/jiofi-set-sta`
  - ADB helper to configure upstream Wi-Fi SSID/password.

After flashing and booting:

```sh
adb shell
jiofi-set-sta "UPSTREAM_SSID" "UPSTREAM_PASSWORD"
```

For open upstream Wi-Fi:

```sh
jiofi-set-sta "UPSTREAM_SSID"
```

Then open:

```text
http://192.168.225.1/QCMAP.html#wlan
```

The hidden Qualcomm WLAN page can set AP-STA mode and STA DHCP/static mode. It
does not provide a friendly scan/select upstream SSID UI, so use
`jiofi-set-sta` for upstream credentials.

## ADB Without Flashing

The firmware contains OEM AT handlers for:

```text
AT%DBGMODE=1
AT%DBGUSBSET=1
```

Those commands are handled by `amt_atfwd_daemon` /
`libamt_atfwd_utils.so.0` and can enable ADB on stock firmware through the
router AT/serial COM port.

## Correct Repack Recipe

The first stock repack bootlooped because the UBIFS geometry was wrong. The
working recipe is:

- UBI min I/O: `2048`
- UBI PEB size: `128KiB`
- VID header offset: `2048`
- UBIFS LEB size: `126976`
- Image sequence: `907419386`
- Volume name: `rootfs`
- Volume flags: `autoresize`
- UBI total blocks: `327`
- UBI data blocks: `325`
- UBIFS `max_leb_cnt`: `2146`
- UBIFS journal: `8388608`
- UBIFS flag: `Space fixup`

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

When using the config above, replace `/path/to/out/rootfs.ubifs` with the real
absolute path. `ubinize` does not expand `$OUT` inside the config file.

## Verification Commands

```sh
.tools/ubi-venv/bin/ubireader_display_info patched/mdm9607-sysfs-adb-extender-v1.ubi
.tools/ubi-venv/bin/ubireader_display_info /tmp/jiofi_extender_repack/build/rootfs.ubifs
sha256sum -c patched/SHA256SUMS
```

Expected important fields:

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

## Flashing

Restore stock:

```powershell
fastboot flash system firmware\mdm9607-sysfs.ubi
fastboot reboot
```

Flash extender image:

```powershell
fastboot flash system patched\mdm9607-sysfs-adb-extender-v1.ubi
fastboot reboot
```

## Extender Status

*   **Status:** **Unsupported** at the driver level.
*   **Root Cause:** While Qualcomm's QCMAP framework supports `AP-STA` mode, the stock Realtek Wi-Fi kernel module ([rtl8189es.ko](file:///tmp/jiofi_extender_repack/extract/907419386/rootfs/usr/lib/modules/3.18.20/kernel/drivers/net/rtl8192cd/rtl8189es.ko)) was compiled by the OEM without `CONFIG_CLIENT_MODE` support. Any attempt to force client mode (`opmode=8` / `IW_MODE_INFRA`) triggers `Undefined state... using AP mode as default` and reverts to AP mode (`IW_MODE_MASTER`).

---

## Patched UBI Images

- **`mdm9607-sysfs-unlocked-apn.ubi`**
  - **Description:** SIM unlock and ADB image. Keeps ADB access, but reverts AP-STA settings and unhides Web UI APN settings.
  - **Default APN:** `internet` (generic).

---

## Manual Patching Guide

If you are repacking the firmware yourself, here are the step-by-step file edits needed to enable ADB and SIM Unlocking independently.

### Part 1: Enabling ADB
To enable ADB, you need to modify the USB composition script to initialize the ADB interface during normal boot, and create a symlink for the shell.

#### Step 1.1: Edit USB Composition
Open [sbin/usb/compositions/02e1](file:///tmp/jiofi_unlock_repack/rootfs/sbin/usb/compositions/02e1) and locate the default boot option case (`*`) around line 139:

```diff
 		* )
-			# Enable WiFi disk mode in normal boot.
-			if [ $(cat /sys/devices/soc:smem_db/wdisk_mode) == "1" ]
-			then
-				run_mass_storage &
-			else
-				run_mass &
-			fi
+			# Enable ADB in normal boot while preserving WiFi disk mode.
+			if [ $(cat /sys/devices/soc:smem_db/wdisk_mode) == "1" ]
+			then
+				run_mass_storage &
+			else
+				run_nomass &
+			fi
 			;;
```

#### Step 1.2: Create ADB Shell Symlink
Qualcomm's `adbd` looks for the shell executable at `/system/bin/sh`. In standard Yocto, the shell is located at `/bin/sh`. You must create a symlink to bridge this.
*Within your fakeroot extraction session*, run:
```sh
ln -s /bin/sh /path/to/extracted/rootfs/system/bin/sh
```

---

### Part 2: Enabling Other SIM Cards (Unhiding APN Settings)
By default, the JMR1140 is carrier-locked to Jio. However, the modem itself is typically unlocked; the lock is enforced in the user interface and config files by hiding APN editing and forcing `jionet`.

#### Step 2.1: Unhide APN Fields in Web UI
Open [WEBSERVER/www/setting/QCMAP_LTE.html](file:///tmp/jiofi_unlock_repack/rootfs/WEBSERVER/www/setting/QCMAP_LTE.html) and locate the `session_level == 3` (user login level) code block around line 166:

```diff
 					//Default APN
-					document.getElementById('H_default_apn').style.display = "none";
-					document.getElementById('Table_Apn_network').style.display = "none";
+					document.getElementById('H_default_apn').style.display = "block";
+					document.getElementById('Table_Apn_network').style.display = "block";
 					//Multiple APN
-					document.getElementById('H_MultiAPN').style.display = "none";
-					document.getElementById('Table_MultiAPN').style.display = "none";
+					document.getElementById('H_MultiAPN').style.display = "block";
+					document.getElementById('Table_MultiAPN').style.display = "block";
```

#### Step 2.2: Change Default APN to Generic
Open [etc/mobileap_cfg.xml](file:///tmp/jiofi_unlock_repack/rootfs/etc/mobileap_cfg.xml) and change the default APN from Jio's to the generic APN used by other carriers:

```diff
 			<APN4NetworkAttach>1</APN4NetworkAttach>
-			<APN>jionet</APN>
+			<APN>internet</APN>
```
Once flashed, you can insert another SIM card, log into the Web UI, and manually configure any carrier APN via the newly visible LTE settings page.
