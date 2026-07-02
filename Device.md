# JioFi JMR1140 Hardware & Software Specification

## Device Information

| Property | Value |
|----------|-------|
| Model | JioFi JMR1140 |
| Platform | Qualcomm Technologies MDM9607 CDP |
| SoC | Qualcomm MDM9607 |
| Hardware ID | Qualcomm Technologies, Inc. MDM9307 |
| CPU Architecture | ARMv7-A (32-bit) |
| CPU | ARM Cortex-A7 |
| CPU Cores | 1 |
| Maximum Frequency | 1.3056 GHz |
| Linux Architecture | armv7l |
| Bootloader | Qualcomm Aboot (Fastboot) |
| Kernel | Linux 3.18.x |
| Qualcomm BSP | LNX.LE.2.0.2-61406-9x15 |

---

# CPU

```
Processor       : ARMv7 Processor rev 5 (v7l)
CPU implementer : ARM (0x41)
CPU part        : 0xC07 (Cortex-A7)
CPU revision    : r5p0
```

### Features

- Thumb / Thumb-2
- NEON
- VFPv3
- VFPv4
- LPAE
- Integer Divide
- EDSP

---

# Memory

## RAM

| Item | Value |
|------|------:|
| Installed | 256 MB DDR |
| Available to Linux | ~170 MB |
| Reserved | ~80 MB |

Reserved memory is primarily allocated for:

- Modem + ADSP
- CNSS Debug
- External Image
- Kernel/CMA

---

## NAND Flash

| Item | Value |
|------|------:|
| Type | Raw NAND |
| Capacity | 256 MB |
| Filesystem | UBIFS |

---

# Partition Layout

| Partition | Purpose |
|-----------|---------|
| sbl | Secondary Bootloader |
| mibib | Qualcomm Boot Configuration |
| efs2 | Calibration / NV Data |
| tz | TrustZone |
| rpm | Resource Power Manager |
| nandcal | NAND Calibration |
| amt1 | AMT Data |
| aboot | Android Bootloader (Fastboot) |
| boot | Linux Kernel |
| modem | Modem Firmware |
| misc | Miscellaneous |
| recovery | Recovery Kernel |
| recoveryfs | Recovery Filesystem |
| sec | Security |
| system | Root Filesystem |
| userdata | User Data |

---

# UBI Volumes

| UBI Device | Volume | Purpose |
|------------|--------|---------|
| ubi0 | rootfs | Root Filesystem |
| ubi1 | modem | Modem Firmware |
| ubi2 | usrfs | User Data |

Filesystem

- UBIFS

---

# Networking

## Cellular

Supported LTE Bands

- Band 3 (1800 MHz)
- Band 5 (850 MHz)
- Band 40 (2300 MHz)

---

## Wi-Fi

### Hardware

- Realtek RTL8189ES

> **Note:** The firmware in this repository may use a custom-built Wi-Fi driver.

### Supported Standards

- IEEE 802.11b
- IEEE 802.11g
- IEEE 802.11n (2.4 GHz)

### Wireless Modes

- Station (Client)
- Access Point (AP)

---

# USB

Supported Functions

- ADB
- RNDIS
- ECM

---

# External Interfaces

- Micro USB 2.0
- Nano SIM
- Micro SD (up to 32 GB)

---

# Battery

| Property | Value |
|----------|-------|
| Capacity | 2600 mAh |
| Charging Voltage | 4.35 V |

Estimated Runtime

- 7–8 Hours
- Up to 480 Hours Standby

---

# Software

| Property | Value |
|----------|-------|
| Operating System | Embedded Linux |
| Kernel | Linux 3.18.x |
| Root Filesystem | UBIFS |
| Bootloader | Qualcomm Fastboot |
| BSP | Qualcomm LNX.LE.2.0.x |

---

# Summary

| Component | Specification |
|-----------|--------------|
| SoC | Qualcomm MDM9607 |
| CPU | ARM Cortex-A7 @ 1.3 GHz |
| RAM | 256 MB DDR |
| Flash | 256 MB NAND |
| Wi-Fi | IEEE 802.11b/g/n (2.4 GHz) |
| LTE | Bands 3 / 5 / 40 |
| Kernel | Linux 3.18.x |
| Filesystem | UBIFS |
| USB | ADB, RNDIS, ECM |
| Battery | 2600 mAh |
| Max Wi-Fi Clients | 31 |