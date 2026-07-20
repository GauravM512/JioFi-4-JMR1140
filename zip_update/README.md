# Master Guide: JioFi Web Firmware Update Architecture & Custom ZIP Packaging

## 1. Overview & Hardware Architecture

This guide explains the inner workings of the **JioFi Web Firmware Update Engine** for devices running the **Qualcomm MDM9607 platform** (AMTelecom **AR5800RJ** / JioFi 4 JMR1140 hardware revision). 

The JioFi update engine validates packages through **Model Matching (`AR5800RJ`)**, **`build.prop` Inspection**, and **Qualcomm Android Recovery (`update-binary`)**.

---

## 2. End-to-End Execution Pipeline

```
[ 1. Web Panel Upload ]
   ├── User selects ZIP file in Web UI (Firmware Update)
   ├── Web server saves upload payload to: /data/upgrade/update.zip
   └── Web CGI / daemon sets recovery command:
       echo --update_package=/data/upgrade/update.zip > /cache/recovery/command

[ 2. Reboot & Recovery Handshake ]
   ├── Web daemon executes: sys_reboot recovery
   ├── Qualcomm Bootloader (appsboot.mbn) detects recovery command
   └── Boots into Recovery Kernel & RAMDISK

[ 3. Recovery Validation & Extraction (/usr/bin/recovery) ]
   ├── Recovery opens /data/upgrade/update.zip
   ├── Unzips system/build.prop to temporary directory
   ├── Reads ro.product.model property
   ├── Compares ro.product.model ("AR5800RJ") against hardware model ("AR5800RJ")
   └── If match succeeds -> Runs /META-INF/com/google/android/update-binary

[ 4. Low-Level Flashing (updater-script) ]
   ├── Mounts physical UBIFS NAND flash volume (/dev/ubi2_0 -> /system)
   ├── Extracts system files to /system/bin/ (busybox) and /system/usr/bin/ (jiofetch)
   ├── Sets executable permissions (chmod 0755)
   ├── Unmounts /system safely
   └── Clears recovery command & reboots router into normal operating system
```

---

## 3. The 4 Essential Rules for Custom JioFi Update ZIPs

To ensure a custom update ZIP installs successfully via the JioFi Web Panel, it must follow these 4 mandatory principles:

### Rule 1: Correct Hardware Model Identification (`AR5800RJ`)
* The JioFi recovery binary checks `system/build.prop` inside the ZIP.
* `system/build.prop` **must** include:
  ```ini
  ro.product.model=AR5800RJ
  ro.build.version.incremental=907419386
  ```
* ❌ *If set to `JMR1140` or incorrect string*, recovery aborts with:
  `I:model name missmatch (JMR1140) : (AR5800RJ) -> Installation aborted.`

---

### Rule 2: Explicit UBIFS Flash Partition Mounting
* When recovery boots, the physical `/system` NAND flash partition (`/dev/ubi2_0`) is **NOT mounted** by default.
* Your `updater-script` **must explicitly mount `/dev/ubi2_0`** before copying files:
  ```edify
  ui_print("Mounting system partition...");
  mount("ubifs", "UBI", "system", "/system");
  run_program("/bin/mount", "-t", "ubifs", "/dev/ubi2_0", "/system");

  ui_print("Extracting files...");
  package_extract_dir("bin", "/system/bin");
  package_extract_dir("usr", "/system/usr");

  ui_print("Unmounting system partition...");
  unmount("/system");
  ```
* ❌ *Without mounting*, files are extracted into the temporary RAMDISK and wiped upon reboot!

---

### Rule 3: Single-Copy Clean Path Structure (`system_patches` Layout)
* In JioFi embedded Linux rootfs layout (matching `system_patches/`):
  * **Busybox** is installed at `/system/bin/busybox`
  * **jiofetch** is installed at `/system/usr/bin/jiofetch`
* Single copies keep update packages lightweight (~877 KB - 1.0 MB).

---

### Rule 4: Standard Recovery Zip Layout
Your custom ZIP package must follow this exact root structure:

```text
jiofi_custom_update.zip
├── bin/
│   └── busybox                     # Busybox 1.38.0 binary
├── usr/
│   └── bin/
│       └── jiofetch                # jiofetch script from personal_builds/
├── system/
│   └── build.prop                  # Model declaration (ro.product.model=AR5800RJ)
├── compatibility.txt               # AR5800RJ:0:00000000
└── META-INF/
    └── com/
        └── google/
            └── android/
                ├── update-binary    # Qualcomm ARM 32-bit recovery installer
                └── updater-script   # Edify installation script
```

---

## 4. Available Update Packages

The `zip_update/` folder contains the following packages:

* 📄 **[jiofi_jiofetch_update.zip](file:///home/gaurav/jiofi/zip_update/jiofi_jiofetch_update.zip)** (877 KB)
  *(Original working update ZIP containing Busybox 1.38.0 and jiofetch)*

* 🔧 **[jiofi_adb_enabler.zip](file:///home/gaurav/jiofi/zip_update/jiofi_adb_enabler.zip)** (95 KB)
  *(ADB enabler — patches USB composition to start `adbd` on every boot. Gives persistent ADB shell access without any other changes.)*


---

## 5. How to Flash via Web Panel

1. Open your router's Web Control Panel (`http://192.168.225.1/`).
2. Navigate to **Firmware Update**.
3. Select your desired update `.zip`.
4. Click **Upgrade**.
5. When the router reboots, open terminal and test:
   ```bash
   adb shell busybox | head -n 2
   adb shell jiofetch
   ```
