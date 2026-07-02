# JioFi 4 (Qualcomm MDM9607) Custom Driver Compilation Guide

This repository contains a custom client/STA mode driver for the Realtek `rtl8189es` wireless chipset, built for the JioFi 4 (JMR1140) mobile router.

The custom compiled driver module is stored at:
👉 **[patched/rtl8189es-custom.ko](file:///home/gaurav/jiofi/patched/rtl8189es-custom.ko)**

---

## 🔍 Critical Findings (Qualcomm Kernel Binary Alignment)

The primary reason why compilation against standard, vanilla Linux 3.18.20 kernel headers resulted in crashes/Oops on the JioFi router is that the **Qualcomm MSM kernel has custom modifications to core structs**, causing compilation offsets to mismatch.

### 1. `struct net_device` Offset Mismatch (Solved)
* **Symptom:** Kernel oops inside `register_netdevice` during `insmod`.
* **Details:** Disassembly showed the compiler was writing `netdev_ops` at offset `0x110` (272 bytes), whereas the running kernel expected it at offset `0x118` (280 bytes).
* **Cause:** The conditional block for `CONFIG_WIRELESS_EXT` pointers (`wireless_handlers` and `wireless_data`) was stripped out because the kernel config system auto-disabled it when no wireless drivers were selected built-in.
* **Resolution:** We patched `<linux/netdevice.h>` to force-include these pointers (`#if 1`), pushing `netdev_ops` to `0x118`.

### 2. `struct iw_handler_def` WEXT Offset Mismatch (Solved)
* **Symptom:** `iwconfig wlan0` resulting in user-space/kernel segmentation faults.
* **Details:** The fields `.private`, `.private_args`, etc. inside `struct iw_handler_def` are conditional on `CONFIG_WEXT_PRIV`. The running kernel had it enabled, but header preparation stripped it, shifting the offset of `get_wireless_stats` and causing pointer dereference crashes during WEXT ioctls.
* **Resolution:** We patched `<net/iw_handler.h>` to force-include these private pointers (`#if 1`) and defined `-DCONFIG_WEXT_PRIV` in the Makefile.

### 3. `struct mmc_card` Offset Mismatch (Solved)
* **Symptom:** Segmentation fault inside SDIO card detection (`dump_sdio_card_info`).
* **Cause:** Qualcomm-specific modifications inside `struct mmc_card` shifted fields.
* **Resolution:** We patched `os_dep/linux/sdio_intf.c` to completely bypass card structure dereferencing in `dump_sdio_card_info()`.

---

## 🛠️ How to Rebuild
To compile the driver from scratch, simply run:
```bash
./driver/build.sh
```
The script will download the kernel source, Bootlin cross-compilation toolchain, apply the compatibility headers patches, compile the driver, and output the binary to `patched/rtl8189es-custom.ko`.

---

## 🚀 How to Load and Verify
1. **Push the driver module to the JioFi:**
   ```powershell
   adb push H:\Downloads\rtl8189es-custom.ko /tmp/
   adb shell
   ```

2. **Unload the stock driver and load the custom one:**
   ```sh
   # 1. Unload stock driver
   rmmod rtl8189es
   
   # 2. Load our custom aligned WEXT driver
   insmod /tmp/rtl8189es-custom.ko
   ```

3. **Verify the wireless interface configuration:**
   ```sh
   iwconfig wlan0
   ```
