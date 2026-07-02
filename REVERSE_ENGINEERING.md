# JioFi JMR1140 Firmware Reverse Engineering Log & Findings

This document aggregates the static and dynamic analysis findings for the JioFi JMR1140 (Qualcomm MDM9607 platforms). It covers the partition analysis, target boot USB compositions, hidden AT debug triggers, driver debugging, Web UI modifications, and kernel interactions.

---

## 1. Static Firmware & Layout Analysis

The JMR1140 router utilizes a Qualcomm MDM9607 SoC running embedded Linux. The NAND partition map contains several custom partitions:

* **`aboot`**: Fastboot bootloader.
* **`boot`**: Kernel boot image.
* **`modem`**: Qualcomm baseband system.
* **`system`**: Core Linux root filesystem (repacked as a UBI/UBIFS container).

### Volume Geometry
* **Minimum I/O Size**: 2048 bytes
* **Logical Erase Block (LEB)**: 126,976 bytes (124 KiB)
* **Physical Erase Block (PEB)**: 131,072 bytes (128 KiB)
* **Sub-page Size**: 2048 bytes
* **Image Sequence**: `907419386` (Important for firmware packaging compatibility).

---

## 2. ADB OEM Lock & Bypass

The firmware includes a precompiled Android ADB daemon (`adbd` in `/sbin/adbd`), but it is locked out by default under regular boot compositions.

### Analysis of USB Compositions
The USB configuration framework selects USB functions dynamically via composition scripts in `/sbin/usb/compositions/`.
On normal boot, the platform loads composition **`02e1`**:
* **Lock Condition**: ADB (`ffs`) is only started if:
  * `/sys/devices/soc:smem_db/factory_mode == 1`, or
  * `/sys/devices/soc:smem_db/debug_enable == 1`
* Otherwise, it loads RNDIS, DIAG, and Serial lines only, leaving ADB off.

### AT-Command Unlock (Non-Intrusive)
A hidden debug interface exists in the Qualcomm serial command parser (`libamt_atfwd_utils.so`).
Sending the following AT commands directly to the serial modem COM port triggers dynamic ADB activation without modification of the firmware container:
```text
AT%DBGMODE=1
AT%DBGUSBSET=1
```
The RIL daemon intercepts these commands and starts `/etc/init.d/adbd`.

### System-Level Patches for Permanent ADB
1. **USB Composition Modification (`/sbin/usb/compositions/02e1`)**:
   Modified normal-boot conditional branch logic to load `ffs` (ADB) unconditionally.
2. **Missing Shell Fix**:
   The `adbd` executable expects `/system/bin/sh` to launch shell sessions. The stock system lacks this directory structure. A build-time symlink from `/system/bin/sh` to `/bin/sh` was created to prevent immediate bootloops upon ADB shell startup.

---

## 3. Wi-Fi Extender & AP+STA Configuration

The system uses a Realtek `rtl8189es` wireless module. The stock firmware maps the backhaul priority exclusively to cellular (modem).

### System Changes to Enable Wi-Fi Extender
1. **Network Interface Decoupling**:
   Removed `wlan1` (the new local hotspot interface) from the primary bridge `bridge0` to allow separate IP range allocation.
2. **Double-Interface Routing**:
   * `wlan0`: Formed as a client interface (STA backhaul) connecting to the upstream hotspot.
   * `wlan1`: Formed as a local access point (AP) broadcasting the new SSID.
3. **DHCP Conflict & Authoritative Mode**:
   Since client devices frequently connect with cached IP configurations from parent routers, the local `dnsmasq` server on `wlan1` is started with `--dhcp-authoritative` to immediately NAK invalid IPs and speed up IP acquisition to under 0.5s.
4. **Stale hostapd Cleanups**:
   Added `ap_max_inactivity=30` and `disassoc_low_ack=1` to ensure `hostapd` immediately drops inactive stations, avoiding the 5-minute stale reconnect lockout.

---

## 4. Hardware Sensors & LED Integration

### Battery Telemetry
* The board lacks standard Android `/sys/class/power_supply/battery/` sysfs nodes.
* **Charging Interface**: Managed by the **Silergy SY6923** charger module (`/sys/class/power_supply/sy6923-charger`).
* **Voltage Acquisition**: Managed by the Qualcomm VADC (`/sys/devices/qpnp-vadc-8/vbatt`). 
  * The voltage is scaled (1/3 scale factor) by the hardware.
  * **Translation Formula**:
    $$V_{\text{actual}} = R_{\text{Result}} \times 3 / 1000 \text{ mV}$$
    * Voltages range from $3400\text{mV}$ (0%) to $4200\text{mV}$ (100%).
* **Presence detection**: Since the physical `/present` node is hardcoded to `0` by the driver, presence is detected using a voltage threshold: if $V_{\text{actual}} < 2000\text{mV}$ (2.0V), the battery is disconnected (pure USB-only power).

### LED Brightness Controls & Blink Codes
LED nodes on PMIC platforms default to low safe current ratings when incorrect out-of-range values (e.g. `255`) are written to `/sys/class/leds/<led>/brightness`. A custom utility function queries `/sys/class/leds/<led>/max_brightness` at runtime to ensure full maximum brightness is set.

In Wi-Fi Repeater Mode, the **RSSI LED** is used to convey device status:

| LED Color / Pattern | Device State |
|---------------------|--------------|
| 🟢 **Solid Green** | Connected to upstream router (Strong Signal $\ge 70\%$) |
| 🟡 **Solid Yellow/Amber** | Connected to upstream router (Medium Signal $35\% - 69\%$) |
| 🔴 **Solid Red** | Connected to upstream router (Weak Signal $< 35\%$) |
| 🔴 **Fast Blinking Red** (250ms) | Upstream connection lost / Reconnecting |
| 🔴 **Slow Blinking Red** (500ms) | Booting / Idle (Waiting for upstream configuration) |

---

## 5. Resources & Flash Tools Mirror

Because official AMTelecom links are delisted:
* **Upgrade Tools & Qualcomm Drivers**: Verified mirror at **[Spacebyte JMR1140 Drive](https://spacebyte.in/drive/s/uCVx8f0br9B78IR8bZZtsels6SzexX)**.
* **Modem Backups & EDL recovery**: 
  * **To dump/backup stock partitions**: Enable temporary ADB via serial COM AT command line injection (`AT%DBGMODE=1` & `AT%DBGUSBSET=1`), then boot the device into EDL mode by running `adb reboot edl`. You can then dump/read your partitions using QPST/QFIL or open-source QDL tools.
