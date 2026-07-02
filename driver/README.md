# JioFi 4 (MDM9607) Custom Wifi Driver Build

This folder contains the custom Realtek `rtl8189es` driver built for the JioFi 4 (JMR1140) mobile router to enable Client/STA mode.

## Directory Structure
- [rtl8189es/](file:///home/gaurav/jiofi/driver/rtl8189es): The fully patched driver source repository.
- [patches/](file:///home/gaurav/jiofi/driver/patches): Reference copies of python scripts used to apply patches.
- [Qualcomm_Headers/](file:///home/gaurav/jiofi/driver/Qualcomm_Headers): The official Qualcomm `msm-3.18` wireless headers used for compilation.
- [build_driver.sh](file:///home/gaurav/jiofi/driver/build_driver.sh): The compilation script to trigger a clean build.

---

## 🛠️ Compilation and Setup Instructions

To compile the driver from scratch:
1. Ensure the bootlin toolchain and kernel sources are set up under `/tmp/jiofi_custom_build/`.
2. Run the build script:
   ```bash
   ./build_driver.sh
   ```
3. The successfully compiled driver will be saved at:
   👉 [patched/rtl8189es-custom.ko](file:///home/gaurav/jiofi/patched/rtl8189es-custom.ko)

---

## 📖 Architecture & Design Decisions

### 1. Legacy WEXT vs cfg80211
The stock JioFi wireless driver (`rtl8189es.ko`) does **not** link against or use the modern `cfg80211` wireless subsystem. Instead, it is configured as a legacy Wireless Extensions (`wext`) driver. 
By disabling `CONFIG_IOCTL_CFG80211` in our custom driver:
* We completely bypass the kernel's `wiphy` registration code path.
* We avoid all complex structural offset mismatches (e.g. `struct wiphy` size differences) that caused segmentation faults during `wiphy_register()`.
* The driver registers the network interface directly with the kernel's standard `register_netdev()` routine.

### 2. MMC/SDIO Subsystem Offset Bypass
Because the Qualcomm kernel has internal modifications to the MMC structure `struct mmc_card`, dereferencing it causes kernel oops. We patched `os_dep/linux/sdio_intf.c` to bypass `dump_sdio_card_info()`, preventing oops when the SDIO card registers.

---

## 🔍 History of Segmentation Faults and Fixes

| Phase | Root Cause | Symptom | Resolution |
| :--- | :--- | :--- | :--- |
| **Phase 1** | Mainline `cfg80211` structure offset mismatch vs Qualcomm kernel. | Segmentation fault in `memcpy` inside `wiphy_register()`. | Replaced mainline `cfg80211.h` with official Qualcomm `msm-3.18` headers. |
| **Phase 2** | Preprocessor compiler check mismatch in `cfg80211_rtw_del_station` and `vendor_event_alloc`. | Compilation failures. | Patched signatures to match Qualcomm's custom definitions. |
| **Phase 3** | Qualcomm `wiphy_register` MAC ACL validation check mismatch. | Warning traceback at `/net/wireless/core.c:530` returning `-EINVAL`. | Patched `wiphy->max_acl_mac_addrs` to `0` unconditionally. |
| **Phase 4** | Qualcomm `struct wiphy` size mismatch caused by customized `struct device`. | Segmentation fault in `memcpy` (writing to NULL dest). | Disabled `CONFIG_IOCTL_CFG80211` in Makefile to compile as WEXT-only (matching stock architecture). |
