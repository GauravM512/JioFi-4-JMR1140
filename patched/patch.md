# JioFi JMR1140 Patched Firmware & Custom Driver Guide

This directory holds every verified, bootable artefact produced by
the **JioFi JMR1140** (Qualcomm MDM9607) custom-firmware project.
All UBI images here are built against the corrected **v2 repacking
geometry** (image sequence `907419386`, see
[`README.md`](README.md#correct-repack-recipe)).

---

## File Index

| File | Purpose | Tested on device |
|------|---------|------------------|
| [`mdm9607-sysfs-repeater-patched.ubi`](#4-full-repeater-adb--openlumi-wi-fi-driver--ap-sta) | Full Wi-Fi repeater / extender + permanent ADB | ✅ |
| [`mdm9607-sysfs-unlocked-apn.ubi`](#3-sim-unlocked--adb-enabled-airtelvietc) | Carrier unlock (generic APN) + permanent ADB | ✅ |
| [`mdm9607-sysfs-adb-shelllink-v2.ubi`](#2-root-adb-shell-enabled-recommended-base) | Stock firmware + permanent ADB shell only | ✅ |
| [`mdm9607-sysfs-stock-repacked-v2.ubi`](#1-stock-repacked-safe-reference) | Stock repack (sanity check, no edits) | ✅ |
| [`rtl8189es-custom.ko`](#rtl8189es-customko) | OpenLumi-derived `rtl8189es` driver module | ✅ |
| [`start_repeater.sh`](#start_repeatersh) | Standalone copy of the repeater init script | ✅ |
| [`hostapd.conf`](#hostapdconf) | Standalone copy of the local hotspot config | ✅ |
| [`SHA256SUMS`](#sha256sums) | SHA-256 manifest of the bootable UBI images | n/a |
| [`README.md`](README.md) | Build / repack recipe and manual patching guide | n/a |
| [`patch.md`](patch.md) | This file — per-file catalogue | n/a |

Image hierarchy (least → most features):

```
mdm9607-sysfs-stock-repacked-v2.ubi
        ⊂ mdm9607-sysfs-adb-shelllink-v2.ubi
                ⊂ mdm9607-sysfs-unlocked-apn.ubi
                        ⊂ mdm9607-sysfs-repeater-patched.ubi
```

---

## Bootable UBI Images

### 1. Stock Repacked (Safe Reference)

* **Filename:**
  [`mdm9607-sysfs-stock-repacked-v2.ubi`](mdm9607-sysfs-stock-repacked-v2.ubi)
* **SHA-256:**
  `b933d5a76ad5696e63caa30621a1774efb887eb6b1ceff8f4698534e79012ca3`
* **Description:** A zero-modification, clean rebuild of the stock
  system filesystem. Use this to verify that the host build
  environment and the `v2` UBI geometry are stable on your hardware
  before adding modifications.

### 2. Root ADB Shell Enabled (Recommended Base)

* **Filename:**
  [`mdm9607-sysfs-adb-shelllink-v2.ubi`](mdm9607-sysfs-adb-shelllink-v2.ubi)
* **SHA-256:**
  `6624fac352523664ff29266e0e48410584f3b7ee9d75a981e74934d50d62788f`
* **Description:** Permanently enables a root ADB shell.
  * **Edits:** Patches the default `02e1` USB composition to load the
    `run_nomass` configuration, which attaches the ADB gadget on a
    normal boot.
  * **Symlink:** Creates the missing `/system/bin/sh → /bin/sh` so
    `adbd` does not fail with *"sh not found"* when starting a shell
    session.
* **Use this as:** The base image when you want a known-good device
  with `adb shell` and want to layer further customisations over SSH
  or ADB without re-flashing the system partition.

### 3. SIM Unlocked & ADB Enabled (Airtel/Vi/etc.)

* **Filename:**
  [`mdm9607-sysfs-unlocked-apn.ubi`](mdm9607-sysfs-unlocked-apn.ubi)
* **SHA-256:**
  `291b8882255d99be05cac550943fffc0acf49af46e8708be6dd40a4bef2e1bc2`
* **Description:** Bypasses the Jio carrier lock and keeps the
  permanent ADB shell from the previous image.
  * **Web UI patch:** Replaces `display: none` with `display: block`
    in the `session_level == 3` block of
    `WEBSERVER/www/setting/QCMAP_LTE.html`. After logging in as
    `administrator`, the previously hidden **Default APN** and
    **Multiple APN** configuration tables become visible.
  * **APN default:** Replaces `<APN>jionet</APN>` with
    `<APN>internet</APN>` in `etc/mobileap_cfg.xml`.
* **Purpose:** Drop in any other carrier's SIM (Airtel, Vi, BSNL, …)
  and configure the matching APN from the Web UI without further
  in-place edits.

### 4. Full Repeater (ADB + OpenLumi Wi-Fi Driver + AP-STA)

* **Filename:**
  [`mdm9607-sysfs-repeater-patched.ubi`](mdm9607-sysfs-repeater-patched.ubi)
* **SHA-256:**
  `269ee149ccf092a6dd57ece8316391fa99074f73aeddce6dbf55ce21e6c835be`
* **Description:** The end-user image. Combines every patch in
  `adb-shelllink-v2` plus:
  * OpenLumi-derived `rtl8189es.ko` STA-capable driver installed
    at `/usr/lib/modules/3.18.20/kernel/drivers/net/rtl8192cd/`.
    Custom build details are in
    [`../../DRIVER_BUILD.md`](../../DRIVER_BUILD.md). The module is
    loaded with power management disabled (`rtw_power_mgnt=0`,
    `rtw_ips_mode=0`).
  * `/etc/init.d/start_repeater` — brings up `wlan0` (STA backhaul)
    + `wlan1` (routed AP broadcast on `192.168.224.1`) + a
    dedicated `dnsmasq` (range `.20`–`.60`, `--dhcp-authoritative`)
    + NAT masquerade. Two background loops run alongside:
    an RSSI LED colouriser (green ≥ 70 %, amber 35–69 %, red < 35 %)
    and a suspend/resume watchdog that re-initialises the
    `rtw_*` interfaces if a long sleep is detected.
  * `/etc/hostapd.conf` — defaults: SSID `JioFi_Repeater`,
    channel 1, WPA2-PSK passphrase `12345678`.
  * `/etc/mobileap_cfg.xml` — `<WlanMode>AP-STA</WlanMode>` and
    `<MobileAPSTABridgeEnable>1</MobileAPSTABridgeEnable>`.
  * `start_QCMAP_ConnectionManager_le` and
    `start_QCMAP_Web_CLIENT_le` neutered (stubbed to `/bin/true`)
    so QCMAP does not fight the repeater for the radio interface.
  * `uiapp` daemon neutered to free up the LED class nodes for the
    repeater status indicator.
* **Use this as:** The end-user image. After flashing, configure the
  upstream Wi-Fi credentials in `/etc/wpa_supplicant.conf` and
  browse `http://192.168.224.1/` for the repeater's Web UI.

---

## Standalone Files

### `rtl8189es-custom.ko`

* **SHA-256:**
  `1cafec642ef52c73447b60b4c7a2ca852e2d3b855263ff5146744ec66a958727`
* **Purpose:** The compiled kernel module for the OpenLumi
  STA-capable `rtl8189es` driver.
* **When you need it:** The custom module is already baked into the
  `repeater-patched` image, so you **do not** need to `insmod` it
  there. Only load it manually if you are running a stock or
  `adb-shelllink` image and want to test client mode without
  re-flashing.
* **Why a custom build is needed:** The stock OEM `rtl8189es.ko` was
  compiled without `CONFIG_CLIENT_MODE`. Forcing `opmode=8` /
  `IW_MODE_INFRA` on it silently reverts to master/AP mode with
  `Undefined state... using AP mode as default`. The OpenLumi-derived
  module has working `nl80211` client-mode operations, and the
  patch notes in [`../../DRIVER_BUILD.md`](../../DRIVER_BUILD.md)
  explain the three Qualcomm-specific struct-offset corrections
  (`struct net_device`, `struct iw_handler_def`, `struct mmc_card`)
  that make the module actually load on the JMR1140 kernel.

### `start_repeater.sh`

* **SHA-256:**
  `b723deb007f8692eb7a299b991046d5516954870eb1c070110fabb5e48e5a9a2`
* **Purpose:** A standalone copy of the same script that lives at
  `/etc/init.d/start_repeater` inside the `repeater-patched` image.
  Useful when you want to launch the repeater by hand on a stock or
  `adb-shelllink` image (after `insmod` of the custom driver), or
  as a reference for adjustments before re-flashing.
* **Notes:** Reads upstream credentials from
  `/etc/wpa_supplicant.conf` (or `/data/wpa_supplicant.conf` when
  present), the local hotspot config from `/data/hostapd.conf` or
  `/etc/hostapd.conf`, and writes leases to
  `/tmp/dnsmasq_wlan1.leases` (PID at `/tmp/dnsmasq_wlan1.pid`).
  The full boot-time variant with the RSSI LED colouriser and
  suspend/resume watchdog lives at
  [`system_patches/3_wifi_repeater/etc/init.d/start_repeater`](../../system_patches/3_wifi_repeater/etc/init.d/start_repeater).

### `hostapd.conf`

* **SHA-256:**
  `bd2f8659dc52d89a727fa261fcb924759cacc366f1cad3c29603f568b432c491`
* **Purpose:** The `hostapd` configuration consumed both by the
  on-device `start_repeater` (via `/etc/hostapd.conf` or
  `/data/hostapd.conf`) and by any manual hostapd invocation from
  `start_repeater.sh`.
* **Defaults:** `ssid=JioFi_Repeater`, `channel=1`, `hw_mode=g`,
  `wpa=2`, `wpa_passphrase=12345678`. Edit before use if you need a
  different SSID or passphrase. The boot-time copy in the repeater
  image adds `ap_max_inactivity=30` and `disassoc_low_ack=1` to
  kick inactive clients promptly.

### `SHA256SUMS`

A flat SHA-256 manifest of the UBI images plus the `.ko` driver
module, intended as a verification aid. **The manifest was
generated against older builds and is currently out of sync with
the files in this directory** — for example, the
`rtl8189es-custom.ko` was rebuilt and its hash changed.

Regenerate it from the repository root:

```sh
( cd patched && sha256sum mdm9607-sysfs-*.ubi rtl8189es-custom.ko ) \
  > patched/SHA256SUMS
```

Then verify with:

```sh
sha256sum -c patched/SHA256SUMS
```

> Use the per-file SHAs in the sections above for a verified check
> independent of `SHA256SUMS` while the manifest is being
> regenerated.

---

## Loading and Testing the Custom Driver on a Non-Repeater Image

This section only applies if you want to validate client mode
without re-flashing. Because `CONFIG_MODULE_SIG` is disabled in
the JMR1140 kernel, the module loads without any key signing.

```sh
# 1. Stop the QCMAP Connection Manager (which owns the radio):
/etc/init.d/start_QCMAP_ConnectionManager_le stop

# 2. Unload the stock AP-only driver:
rmmod rtl8189es

# 3. Load the custom driver with power management off:
insmod /path/to/rtl8189es-custom.ko rtw_power_mgnt=0 rtw_ips_mode=0

# 4. Bring the wireless interface up and validate client mode:
ifconfig wlan0 up
iw dev wlan0 set type managed      # must NOT silently revert
```

If `iw dev wlan0 set type managed` succeeds and `iw dev wlan0`
still shows `type managed`, the custom driver is active. To make
the change permanent on a non-repeater image, back up the original
and copy `rtl8189es-custom.ko` over
`/usr/lib/modules/3.18.20/kernel/drivers/net/rtl8192cd/rtl8189es.ko`.

---

## ⚡ Flashing Instructions

### Method 1: `fastboot` (recommended for updates)

1. With the device powered on, drop into fastboot:

   ```sh
   adb reboot bootloader
   ```

2. Flash the chosen image to the `system` partition:

   ```sh
   # End-user image (ADB + Wi-Fi repeater):
   fastboot flash system patched/mdm9607-sysfs-repeater-patched.ubi

   # Carrier unlock only:
   fastboot flash system patched/mdm9607-sysfs-unlocked-apn.ubi

   # ADB shell only:
   fastboot flash system patched/mdm9607-sysfs-adb-shelllink-v2.ubi
   ```

3. Reboot:

   ```sh
   fastboot reboot
   ```

### Method 2: First-time Flash (no ADB yet)

1. Power the device off.
2. Hold **Power + WPS** simultaneously and connect the USB cable
   to your PC. The LEDs turn RED once the bootloader is active.
   If the PC does not detect the device, remove the battery and
   retry on pure USB power — the JMR1140 runs from USB alone.
3. Use `fastboot flash system …` as in Method 1, **or** rename
   the chosen `.ubi` to `mdm9607-sysfs.ubi`, drop it into
   `firmware/`, and run the Windows `Firmware Upgrade_6.x.exe`
   installer to flash via the OEM tool.

   > **⚠️ Windows-tool prerequisites — do these *in order*
   > before launching `Firmware Upgrade_6.x.exe`**
   >
   > 1. **Install the bundled USB driver first.** The same
   >    archive contains `driver.exe` — the Qualcomm HS-USB
   >    QDLoader driver. Run `driver.exe` *before* anything
   >    else: without it, `Firmware Upgrade_6.x.exe` cannot
   >    enumerate the JioFi on its USB port and refuses to
   >    start (it just sits on "Searching device…" until you
   >    kill it).
   > 2. **Copy the tool out of `%TEMP%\amt_temp\` to a
   >    stable location.** `Firmware Upgrade_6.x.exe` is a
   >    self-extracting archive that unpacks itself to a
   >    folder literally named `amt_temp` inside Windows
   >    `%TEMP%` and runs from there. Windows can wipe
   >    `%TEMP%` at any reboot — including while you're
   >    mid-flash — so copy the extracted `amt_temp`
   >    folder (e.g. `C:\JioFi\amt_temp\`) before
   >    launching the upgrade tool.
   > 3. **Rename the image to the exact expected name.**
   >    The upgrade tool only flashes a file literally
   >    named `mdm9607-sysfs.ubi` sitting next to its own
   >    executable, so the renamed image must already be
   >    in the extracted folder when you launch the tool.
