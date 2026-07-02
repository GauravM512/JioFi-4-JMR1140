# JioFi JMR1140 Custom Firmware & Reverse Engineering Project

This repository contains the findings, build configuration, patches, and scripts to customize the **JioFi JMR1140** (Qualcomm MDM9607 platform) mobile router. It enables permanent ADB shell access, unlocks the cell lock for other SIMs (APN profile management), and converts the device into a fully functioning Wi-Fi Extender/Repeater with custom Web UI monitoring.

---

## 📂 Repository Structure

```text
├── metadata/                  # Build database files and configurations
│   ├── config.gz              # Stock kernel configuration
│   └── rootfs.state           # Fakeroot filesystem node mode/owner database
├── firmware/                  # Official/stock binaries and flashing tools
├── patched/                   # Prebuilt final firmware files and hashes
│   └── mdm9607-sysfs-repeater-patched.ubi  # Latest ready-to-flash custom system image
├── system_patches/            # Raw templates of files modified in rootfs
│   ├── 1_adb_only/            # Permanent ADB composition configuration
│   ├── 2_adb_apn/             # ADB + unlocked cellular configuration
│   └── 3_wifi_repeater/       # Complete AP+STA Repeater implementation
├── driver/                    # Source files for compiled custom drivers
├── rootfs/                    # Extracted system root filesystem (working build dir)
├── README.md                  # Main project guide (this file)
├── REVERSE_ENGINEERING.md     # In-depth static/dynamic analysis log
├── DEVICE.md                  # Hardware & software specs sheet
└── DRIVER_BUILD.md            # Kernel module driver compilation steps
```

---

## 🛠️ Step-by-Step Build & Repack Instructions

To compile the filesystem and generate the custom UBI flashing image from the rootfs directory, follow these commands:

### Prerequisites (Debian/Ubuntu)
```bash
sudo apt update && sudo apt install -y fakeroot mtd-utils python3-venv python3-pip
```

### 1. Register Modified File Permissions
Before building the UBI image, clear old inodes and register the executable/mode bits of updated scripts using the fakeroot database:
```bash
# Clean up target inodes in the state database
sed -i -E '/ino=(405007|401143|400986),/d' metadata/rootfs.state

# Register modes and permissions
fakeroot -i metadata/rootfs.state -s metadata/rootfs.state -- sh -c '
  chmod +x rootfs/etc/init.d/start_repeater
  chmod 644 rootfs/etc/hostapd.conf
  chmod 755 rootfs/www/cgi-bin/status
'
```

### 2. Compile UBIFS Payload
Build the raw UBIFS filesystem payload containing the rootfs files:
```bash
fakeroot -i metadata/rootfs.state -s metadata/rootfs.state -- \
  /usr/sbin/mkfs.ubifs \
  -r rootfs \
  -m 2048 \
  -e 126976 \
  -c 2146 \
  -F \
  -j 8388608 \
  -x lzo \
  -o /tmp/rootfs.ubifs
```

### 3. Generate Flashing UBI Container
Package the UBIFS payload into a final UBI image with correct Qualcomm BSP container configurations:
```bash
# Create target config for ubinize
cat <<EOF > /tmp/ubinize.cfg
[sysfs_volume]
mode=ubi
image=/tmp/rootfs.ubifs
vol_id=0
vol_type=dynamic
vol_name=rootfs
vol_flags=autoresize
EOF

# Package with correct geometry and stock image sequence
/usr/sbin/ubinize -o patched/mdm9607-sysfs-patched.ubi -m 2048 -p 128KiB -s 2048 -Q 907419386 /tmp/ubinize.cfg
```

---

## ⚡ How to Flash

1. **For First-Time Installation:**
   * Rename the custom patched UBI image file `mdm9607-sysfs-patched.ubi` to **`mdm9607-sysfs.ubi`**.
   * Place the renamed image in the `firmware/` directory containing the Windows firmware upgrade tool (`Firmware Upgrade_6.x.exe`), replacing the default stock file.
   * Run the installer executable to load the image onto the device.

2. **For Updates via Fastboot (If ADB is active):**
   * Reboot the device into fastboot mode:
     ```bash
     adb reboot bootloader
     ```
   * Flash the UBI image directly to the system partition:
     ```bash
     fastboot flash system patched/mdm9607-sysfs-repeater-patched.ubi
     ```
   * Reboot the device normally:
     ```bash
     fastboot reboot
     ```

---

## 🟢 Visual LED Indicators (RSSI LED in Repeater Mode)

In Wi-Fi Repeater Mode, the **RSSI LED** indicates connection health and signal status:

* 🟢 **Solid Green**: Connected to the upstream host router with a **Strong Signal** ($\ge 70\%$).
* 🟡 **Solid Yellow/Amber**: Connected to the upstream host router with a **Medium Signal** ($35\% - 69\%$).
* 🔴 **Solid Red**: Connected to the upstream host router with a **Weak/Poor Signal** ($< 35\%$).
* 🔴 **Fast Blinking Red** (250ms interval): Upstream connection lost, scanning/reconnecting.
* 🔴 **Slow Blinking Red** (500ms interval): Booting up or waiting for configuration.

---

## 🔗 Resources, Drivers & Flasher Tools

Since the official AMTelecom OEM support pages have been delisted, you can retrieve the genuine diagnostic drivers, upgrade executables, and firmware tools from this verified community mirror:

👉 **[JMR1140 Drivers and Tools Mirror](https://spacebyte.in/drive/s/uCVx8f0br9B78IR8bZZtsels6SzexX)**

* **EDL Mode Recovery:** If the system is bricked, you can access Qualcomm Emergency Download Mode (EDL) using the serial COM port AT command interface and flash the stock `mdm9607-sysfs.ubi` reference partition image to restore functionality.
