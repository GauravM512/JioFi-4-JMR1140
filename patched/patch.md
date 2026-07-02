# JioFi JMR1140 Patched Firmware & Custom Driver Guide

This directory contains verified, bootable system firmware (`rootfs`) UBI images and a custom-compiled Wi-Fi kernel driver for the JioFi 4 (JMR1140) router. All files here utilize the corrected **v2 repacking geometry**, preventing the device bootloops caused by legacy v1 repacks.

---

## 📦 Patched Files Directory

### 1. Stock Repacked (Safe Reference)
*   **Filename:** [mdm9607-sysfs-stock-repacked-v2.ubi](file:///home/gaurav/jiofi/patched/mdm9607-sysfs-stock-repacked-v2.ubi)
*   **SHA256:** `b933d5a76ad5696e63caa30621a1774efb887eb6b1ceff8f4698534e79012ca3`
*   **Description:** A zero-modification, clean rebuild of the stock system filesystem. Use this to verify that the build environment and geometry are 100% stable on your hardware without adding modifications.

### 2. Root ADB Shell Enabled (Recommended Base)
*   **Filename:** [mdm9607-sysfs-adb-shelllink-v2.ubi](file:///home/gaurav/jiofi/patched/mdm9607-sysfs-adb-shelllink-v2.ubi)
*   **SHA256:** `6624fac352523664ff29266e0e48410584f3b7ee9d75a981e74934d50d62788f`
*   **Description:** Enables a root ADB shell.
    *   **Edits:** Modifies the default `02e1` USB composition to load the `run_nomass` configuration (enabling ADB gadget) on normal boot.
    *   **Symlink:** Creates the missing `/system/bin/sh` symlink pointing to `/bin/sh` to prevent `adb shell` from failing with a "sh not found" error.

### 3. SIM Unlocked & ADB Enable (Airtel/Vi/etc.)
*   **Filename:** [mdm9607-sysfs-unlocked-apn.ubi](file:///home/gaurav/jiofi/patched/mdm9607-sysfs-unlocked-apn.ubi)
*   **SHA256:** `291b8882255d99be05cac550943fffc0acf49af46e8708be6dd40a4bef2e1bc2`
*   **Description:** Bypasses carrier locks and enables ADB.
    *   **Web UI Patch:** Comments out display-hiding directives in `/WEBSERVER/www/setting/QCMAP_LTE.html`. Logging in as `administrator` exposes the previously hidden **Default APN** and **Multiple APN** configuration tables.
    *   **APN Default:** Replaces the default `jionet` APN with the generic APN `internet` in `/etc/mobileap_cfg.xml`.
    *   **Purpose:** Allows inserting other carriers' SIM cards (like Airtel/Vi) and manually configuring their respective APNs.

### 4. Custom OpenLumi Wi-Fi Driver
*   **Filename:** [rtl8189es-custom.ko](file:///home/gaurav/jiofi/patched/rtl8189es-custom.ko)
*   **SHA256:** `a2a8397862d0e98914ac12d17c8c4e230dc2d73a2788d2e9c938f8690ab26cc7`
*   **Description:** A custom-compiled driver built using the OpenLumi `rtl8189es` driver source code, cross-compiled against your JioFi's specific `3.18.20` kernel layout.
    *   **Purpose:** Replaces the stock AP-only driver with a module that fully supports standard Linux client (STA) mode and `nl80211` command sets, enabling wireless repeater/extender functionality.

---

## ⚡ Loading and Testing the Custom Driver

Since `CONFIG_MODULE_SIG` is disabled in the JioFi kernel, you can load the custom driver directly using `insmod` without modifying the boot partition. 

### Step 1: Boot ADB Firmware
Ensure you are running an ADB-enabled firmware on the router (e.g. `mdm9607-sysfs-adb-shelllink-v2.ubi`).

### Step 2: Push and Load the Driver
Open your PC terminal and run:
```powershell
# 1. Push the compiled driver to the JioFi tmp folder:
adb push patched\rtl8189es-custom.ko /tmp/

# 2. Open ADB shell:
adb shell
```

Inside the **ADB shell**, run:
```sh
# 3. Stop the Qualcomm QCMAP Connection Manager (which manages the stock driver):
/etc/init.d/start_QCMAP_ConnectionManager_le stop

# 4. Unload the stock driver module:
rmmod rtl8189es

# 5. Load the custom driver module:
insmod /tmp/rtl8189es-custom.ko

# 6. Bring the wireless interface UP:
ifconfig wlan0 up
```

### Step 3: Scan and Connect to Upstream Wi-Fi
Inside the **ADB shell**, test the client connection:
```sh
# 1. Check if scanning works (should return nearby networks):
iwlist wlan0 scan

# 2. Write client credentials config:
cat > /tmp/wpa.conf <<'EOF'
ctrl_interface=/var/run/wpa_supplicant
network={
    ssid="YOUR_HOME_WIFI_SSID"
    psk="YOUR_WIFI_PASSWORD"
}
EOF

# 3. Connect to the Wi-Fi using the custom driver's stable nl80211 handler:
wpa_supplicant -Dnl80211 -iwlan0 -c/tmp/wpa.conf -B

# 4. Fetch an IP address from your home router:
udhcpc -i wlan0

# 5. Verify internet connection:
ping -I wlan0 8.8.8.8
```

Once connection works, you can permanently replace `/usr/lib/modules/3.18.20/kernel/drivers/net/rtl8192cd/rtl8189es.ko` with this custom driver file, disable QCMAP, and script the startup bridge.

---

## ⚡ Flashing Instructions

To flash any of the patched images, boot the router into fastboot mode and flash the `system` partition:

### Step 1: Boot into Fastboot/Bootloader Mode
1. Remove the battery and connect the router to a PC via a USB cable.
2. Press and hold the internal reset button using a paperclip or SIM ejector pin.
3. While holding the button, plug the USB cable into your PC.
4. Release the button when the display LEDs turn **RED** (indicating bootloader mode).

### Step 2: Flash the Image
Run the following commands in your PC terminal (replace the filename with your chosen patch):

```powershell
# 1. Check if the device is connected:
fastboot devices

# 2. Flash the UBI image to the system partition:
fastboot flash system patched\mdm9607-sysfs-unlocked-apn.ubi

# 3. Reboot the device:
fastboot reboot
```
