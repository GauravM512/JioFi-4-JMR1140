# JioFi 4 (MDM9607) System Firmware Patches

This directory contains system patches for the JioFi JMR1140 router (Qualcomm MDM9607). Depending on what you want to achieve, follow one of the three options below to build your custom firmware.

---

## 🛠️ Step 1: Unpack the Stock Firmware
Before applying any patch, extract the UBIFS root filesystem from your stock system image:

```bash
# Setup virtual environment and install ubi-reader
python3 -m venv /tmp/ubi-venv
/tmp/ubi-venv/bin/pip install ubi-reader

# Extract files (preserves permissions, ownership, and symlinks)
/tmp/ubi-venv/bin/ubireader_extract_files -o /tmp/extracted_rootfs mdm9607-sysfs.ubi
```
The root filesystem will be extracted to `/tmp/extracted_rootfs/rootfs/`. Keep this terminal window open.

---

## ⚡ Choose Your Patch Option

### Option A: I want Root ADB Shell Access only
*(Keeps the stock firmware completely original, but enables a Root ADB console over USB)*

1. **Apply the USB Composition patch:**
   ```bash
   cp -rf 1_adb_only/* /tmp/extracted_rootfs/rootfs/
   ```
2. **Create the ADB Shell symlink (required for shell capability):**
   ```bash
   mkdir -p /tmp/extracted_rootfs/rootfs/system/bin
   ln -sf /bin/sh /tmp/extracted_rootfs/rootfs/system/bin/sh
   ```
3. Proceed directly to **Step 3 (Rebuild & Flash)**.

---

### Option B: I want ADB Access + Carrier APN Unlock
*(Enables root ADB access and unlocks cellular configurations to use SIM cards from other carriers like Airtel, Vi, BSNL, etc.)*

1. **Apply the USB and MobileAP configuration patches:**
   ```bash
   cp -rf 2_adb_apn/* /tmp/extracted_rootfs/rootfs/
   ```
2. **Create the ADB Shell symlink (required for shell capability):**
   ```bash
   mkdir -p /tmp/extracted_rootfs/rootfs/system/bin
   ln -sf /bin/sh /tmp/extracted_rootfs/rootfs/system/bin/sh
   ```
3. Proceed directly to **Step 3 (Rebuild & Flash)**.

---

### Option C: I want the full Dual-WLAN Wi-Fi Repeater
*(Turns the JioFi into a standalone travel router. Connects to an upstream Wi-Fi source on `wlan0` and broadcasts a custom local hotspot on `wlan1`. Includes a Web UI dashboard at `http://192.168.225.1` and dynamic signal strength LEDs.)*

1. **Apply the Repeater firmware, module drivers, and Web UI files:**
   ```bash
   cp -rf 3_wifi_repeater/* /tmp/extracted_rootfs/rootfs/
   ```
2. **Create the ADB Shell symlink (required for shell capability):**
   ```bash
   mkdir -p /tmp/extracted_rootfs/rootfs/system/bin
   ln -sf /bin/sh /tmp/extracted_rootfs/rootfs/system/bin/sh
   ```
3. **Register the Repeater service to run automatically on system boot:**
   ```bash
   cd /tmp/extracted_rootfs/rootfs/etc
   ln -sf ../init.d/start_repeater rc2.d/S99start_repeater
   ln -sf ../init.d/start_repeater rc3.d/S99start_repeater
   ln -sf ../init.d/start_repeater rc4.d/S99start_repeater
   ln -sf ../init.d/start_repeater rc5.d/S99start_repeater
   ```
4. Proceed to **Step 3 (Rebuild & Flash)**.

---

## 🛠️ Step 3: Rebuild the UBI Image
Once you have applied your chosen option, follow these commands to compile the files back into a flashable UBI binary:

```bash
# 1. Compile the UBIFS rootfs image (fakeroot is required to maintain system permissions)
fakeroot -- /usr/sbin/mkfs.ubifs \
  -r /tmp/extracted_rootfs/rootfs \
  -m 2048 -e 126976 -c 2146 -F -j 8388608 -x lzo \
  -o /tmp/rootfs.ubifs
```

Create a file named `/tmp/ubinize.cfg` with the following configuration:
```ini
[rootfs]
mode=ubi
image=/tmp/rootfs.ubifs
vol_id=0
vol_size=41267200
vol_type=dynamic
vol_name=rootfs
vol_flags=autoresize
```

Build the final flashable `.ubi` image file:
```bash
/usr/sbin/ubinize \
  -o /tmp/mdm9607-sysfs-custom.ubi \
  -m 2048 -p 128KiB -s 2048 -Q 907419386 \
  /tmp/ubinize.cfg
```

---

## ⚡ Flashing Your Patched Firmware

Choose one of the two methods below to flash your custom firmware:

### Method 1: Using the Stock Firmware Upgrade Utility (Recommended for First-Time Setup)
If you are flashing your device for the first time or do not have Fastboot/ADB drivers set up, you can use the stock Windows firmware upgrade executable (`.exe`):

1. Locate the directory containing the stock firmware flashing tool (and its matching executable) on your PC.
2. Inside that directory, locate the original stock system UBI file (typically named `mdm9607-sysfs.ubi`).
3. Rename your newly built custom image (`mdm9607-sysfs-custom.ubi`) to match the exact filename of the stock image (e.g. rename it to `mdm9607-sysfs.ubi`).
4. Replace the original stock file in the utility's directory with your renamed custom file.
5. Run the firmware upgrade `.exe` utility to flash the patched firmware onto your device.

---

### Method 2: Using Fastboot Directly (For Subsequent Updates)
If you already have root ADB shell access and Fastboot tools installed on your PC:

1. **Reboot the JioFi into Fastboot mode:**
   ```bash
   adb reboot bootloader
   ```
2. **Flash the custom system image file:**
   ```bash
   fastboot flash system /tmp/mdm9607-sysfs-custom.ubi
   ```
3. **Reboot the router:**
   ```bash
   fastboot reboot
   ```