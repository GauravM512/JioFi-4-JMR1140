# JioFi JMR1140 Custom Firmware Project

> **Unlock your JioFi 4.** A maintained, documented fork of the Qualcomm-MDM9607 firmware for the **JioFi JMR1140** mobile hotspot. Adds **permanent ADB shell**, **any-carrier SIM support**, and a working **Wi-Fi Extender / Repeater** mode — all while keeping stock LTE behaviour and the original Web UI.

---

## What This Project Does

The **JioFi JMR1140** is a small battery-powered mobile Wi-Fi hotspot sold by Reliance Jio in India. Out of the box it is intentionally limited:

| Out of the box | After flashing |
|---|---|
| Only Jio SIMs work; the APN field is hidden in the Web UI | **Any carrier's SIM** works (Airtel, Vi, BSNL, …) and the APN is exposed under the administrator login |
| No general-purpose debug shell over USB | **Permanent root ADB shell** on every boot |
| The radio can only broadcast Wi-Fi to other devices; it cannot connect *to* an upstream Wi-Fi network as a client | Acts as a **Wi-Fi Extender / Repeater** — connects *to* an upstream Wi-Fi router as a client, then rebroadcasts a fresh local hotspot (`JioFi_Repeater`) |
| Stock LTE bands (3, 5, 40), Web UI, hardware behaviour | **Identical LTE bands, Web UI look, and hardware behaviour** — the patches only add features, never remove them |

This repository contains the recovery image, the source patches, the repacking recipe, the custom Realtek Wi-Fi driver, and the full reverse-engineering notes that explain *why* each change had to be made the way it did.

For full hardware / software specifications, see **[`Device.md`](Device.md)**.

---

## 🧭 Choose Your Goal

Pick the path that matches what you want from the device. Every image below is **pre-built and verified** — you do not need to compile anything.

| I want to … | Flash this image | Read first |
|---|---|---|
| Get a permanent **root ADB shell** over USB (no other changes) | [`patched/mdm9607-sysfs-adb-shelllink-v2.ubi`](patched/README.md#mdm9607-sysfs-adb-shelllink-v2ubi) | [`patched/README.md`](patched/README.md) |
| **Use any carrier's SIM** (Airtel, Vi, BSNL, …) *and* get root ADB | [`patched/mdm9607-sysfs-unlocked-apn.ubi`](patched/README.md#mdm9607-sysfs-unlocked-apnubi) | The APN-carrier section of [`patched/README.md`](patched/README.md) |
| **Turn the JioFi into a Wi-Fi Extender/Repeater** *and* keep root ADB | [`patched/mdm9607-sysfs-repeater-patched.ubi`](patched/README.md#mdm9607-sysfs-repeater-patchedubi) | The full repeater write-up in [`patched/README.md`](patched/README.md) |

Each image's SHA-256, what changes are baked in, and what to expect after flashing are documented in **[`patched/patch.md`](patched/patch.md)**.

---

## ⚡ Quick Start — Flash a Pre-Built Image

### What you'll need

* The JioFi JMR1140 itself (battery removed is fine — it runs from USB alone).
* A micro-USB cable.
* Either a **Windows PC** *or* `adb` + `fastboot` installed on Linux/macOS.
* The **community-mirrored firmware upgrade tool** + USB driver. The official AMTelecom support download pages are delisted, so the verified replacement is at 👉 **[JMR1140 Drivers and Flasher Tools Mirror](https://spacebyte.in/drive/s/uCVx8f0br9B78IR8bZZtsels6SzexX)**.

### Option A — Windows tool (recommended for first-time install / no ADB yet)

This is the simplest path: no ADB, no Linux, no terminal.

1. **Install the USB driver (`driver.exe`) from the mirror first.** The upgrade tool cannot even *see* the JioFi on the USB port until this is installed. If you skip this step, the tool just hangs on *"Searching device…"* forever.
2. **Run the upgrade tool (`Firmware Upgrade_6.x.exe`).** It is a self-extracting archive that unpacks itself to a folder named **`amt_temp` inside Windows `%TEMP%`** and runs from there.
   **Copy the `amt_temp` folder to a stable location** (e.g. `C:\JioFi\amt_temp\`) *before* doing anything else — Windows can wipe `%TEMP%` at any reboot, including while you're mid-flash, which bricks the device.
3. **Rename your chosen `.ubi` to `mdm9607-sysfs.ubi`** and place it inside the copied `amt_temp` folder. The tool only flashes a file with that exact name sitting in its own folder.
4. **Put the JioFi into recovery mode.** Power it off, then **hold the Power + WPS buttons simultaneously while plugging the USB cable** into your PC. The LEDs turn RED once the bootloader is up. (If the device isn't detected, remove the battery entirely and retry — the JMR1140 runs from USB alone.)
5. **Run `FirmwareUpgrade.exe` from the copied folder** and follow the prompts.

> These three Windows-tool prerequisites mirror the canonical blockquote in **[`patched/README.md` — Flashing section](patched/README.md#flashing)**; if anything has changed since this guide was written, the canonical version is the source of truth.

### Option B — `fastboot` (for updates once ADB works)

Use this *after* the device has been flashed at least once with a shell-enabled image, or once you have activated ADB over the serial COM port (`AT%DBGMODE=1`, see [`REVERSE_ENGINEERING.md`](REVERSE_ENGINEERING.md)).

```sh
# 1. Drop into fastboot:
adb reboot bootloader

# 2. Flash the chosen image to the system partition:
fastboot flash system patched/mdm9607-sysfs-repeater-patched.ubi

# 3. Reboot:
fastboot reboot
```

> **Roll back to stock any time:** `fastboot flash system firmware/mdm9607-sysfs.ubi && fastboot reboot`.

For full per-image flashing notes, the v2 repack geometry, and the verification commands, see **[`patched/README.md`](patched/README.md)**.

---

## 🛠️ Build from Source

If you want to customise a patch, change the default APN, swap in your own Wi-Fi driver, or just see how the firmware is repacked, the **full step-by-step build walkthrough** lives in **[`system_patches/README.md`](system_patches/README.md)** — start there. It covers unpacking the stock rootfs with `ubi-reader`, applying one of three patch options (`1_adb_only/`, `2_adb_apn/`, or `3_wifi_repeater/`), the missing `/system/bin/sh` symlink, fakeroot mode tracking, and the v2 `mkfs.ubifs` + `ubinize` geometry.

For the **custom Realtek `rtl8189es` driver source / build chain** (the OpenLumi-derived STA-capable replacement for the OEM AP-only driver) and the three Qualcomm-specific kernel-offset patches that make the module load on the JMR1140's modified Linux 3.18.20 kernel, see **[`DRIVER_BUILD.md`](DRIVER_BUILD.md)**.

---

## 🟢 LED Indicators in Repeater Mode

When the `repeater-patched` image is running, the RSSI LED reflects the **upstream Wi-Fi** connection quality:

| LED Color / Pattern | Meaning |
|---|---|
| 🟢 **Solid Green** | Strong signal (**RSSI ≥ 70 %**) |
| 🟡 **Solid Yellow/Amber** | Medium signal (**35 % ≤ RSSI < 70 %**) |
| 🔴 **Solid Red** | Weak signal (**RSSI < 35 %**) |
| 🔴 **Fast Blinking Red** (250 ms) | Upstream lost — reconnecting |
| 🔴 **Slow Blinking Red** (500 ms) | Booting / waiting for config |

The colour logic lives in the `start_repeater` background loop; see [`patched/README.md`](patched/README.md) for the full implementation.

---

## 📚 Documentation Index

Each document below covers one specific audience and topic — start from the one that matches your goal.

| Document | Who it's for | What it covers |
|---|---|---|
| **[`patched/README.md`](patched/README.md)** | End-user & flasher | Per-image catalogue, v2 repack recipe, flashing walkthrough, Windows-tool prerequisites (driver + `%TEMP%\amt_temp\`), verification commands. **Read this before flashing.** |
| **[`patched/patch.md`](patched/patch.md)** | End-user & flasher | Per-file catalogue of everything in `patched/`, with SHA-256 hashes and a description of what changed in each. |
| **[`system_patches/README.md`](system_patches/README.md)** | Builder / developer | From-source walkthrough: extract stock firmware, apply a patch option, repack with `mkfs.ubifs` + `ubinize`. |
| **[`Device.md`](Device.md)** | Anyone preparing to flash | Hardware & software specifications — MDM9607 SoC, ARM Cortex-A7 @ 1.3 GHz, 256 MB DDR, 256 MB raw NAND, UBI volumes, supported LTE bands (3/5/40), external interfaces (Micro USB + Nano SIM + Micro SD), battery 2 600 mAh. |
| **[`DRIVER_BUILD.md`](DRIVER_BUILD.md)** | Driver / kernel developer | Custom `rtl8189es` driver: why a custom build is required, the three Qualcomm kernel-offset corrections, how to rebuild, how to `insmod` and validate. |
| **[`REVERSE_ENGINEERING.md`](REVERSE_ENGINEERING.md)** | Researcher / curious reader | Static + dynamic analysis log: USB composition internals, AT-command ADB unlock, AP+STA double-interface routing, battery/LED telemetry reverse engineering, EDL recovery. |

---

## ❓ Frequently Asked Questions

* **Will this void my warranty?** Yes — flashing custom firmware is not supported by Reliance Jio. The stock firmware is preserved at [`firmware/mdm9607-sysfs.ubi`](firmware/mdm9607-sysfs.ubi) so you can revert at any time.
* **Can I unlock ADB without flashing anything?** Yes — the OEM firmware has undocumented AT handlers (`AT%DBGMODE=1`, `AT%DBGUSBSET=1`) that dynamically activate ADB over the serial COM port. See **[`REVERSE_ENGINEERING.md` § 2](REVERSE_ENGINEERING.md#2-adb-oem-lock--bypass)** for the details.
* **Where do I get the firmware upgrade tool?** The official AMTelecom download pages are delisted. Community mirror: 👉 **[JMR1140 Drivers and Flasher Tools](https://drive.google.com/drive/u/0/folders/1wrLRm-8vgX0-f2AJqPw5cUjbzf2T43mI)**.

---

## ⚖️ Disclaimer

Custom firmware is unofficial, not supported by Reliance Jio, and may have unintended effects on your device's LTE connection, battery telemetry, or warranty status. **Back up your stock partitions** (via EDL — see above) before flashing, and verify each image's SHA-256 against [`patched/patch.md`](patched/patch.md) before writing it to the device.
