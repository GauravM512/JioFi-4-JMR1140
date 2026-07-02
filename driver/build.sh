#!/bin/bash
# JioFi 4 (MDM9607) Custom Driver Build Script
# This script automates downloading vanilla kernel source, setting up the cross-compilation toolchain,
# applying binary compatibility patches for Qualcomm structures, and building the custom driver.
set -euo pipefail

BUILD_DIR="/tmp/jiofi_custom_build"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "=== Downloading Toolchain ==="
if [ ! -d "toolchain" ]; then
    wget -q --show-progress -O toolchain.tar.bz2 "https://toolchains.bootlin.com/downloads/releases/toolchains/armv7-eabihf/tarballs/armv7-eabihf--glibc--stable-2020.08-1.tar.bz2"
    mkdir toolchain
    tar -xf toolchain.tar.bz2 -C toolchain --strip-components=1
    rm toolchain.tar.bz2
fi

echo "=== Downloading Kernel Source ==="
if [ ! -d "linux-3.18.20" ]; then
    wget -q --show-progress -O linux.tar.xz "https://cdn.kernel.org/pub/linux/kernel/v3.x/linux-3.18.20.tar.xz"
    tar -xf linux.tar.xz
    rm linux.tar.xz
fi

# Apply GCC compiler headers compatibility fixes
for V in {6..10}; do
    cp -f linux-3.18.20/include/linux/compiler-gcc5.h linux-3.18.20/include/linux/compiler-gcc${V}.h 2>/dev/null || true
done

echo "=== Downloading Driver Source ==="
if [ ! -d "rtl8189es" ]; then
    git clone --depth 1 "https://github.com/openlumi/rtl8189es.git"
fi

# Apply platform fixes to driver Makefile and C files
cd rtl8189es
git checkout Makefile os_dep/linux/os_intfs.c os_dep/linux/sdio_intf.c os_dep/linux/ioctl_cfg80211.c os_dep/linux/rtw_cfgvendor.c 2>/dev/null || true

# 1. Edit Makefile to target PC platform, enable WEXT, WEXT_PRIV, and CFG80211
sed -i 's/CONFIG_PLATFORM_I386_PC = n/CONFIG_PLATFORM_I386_PC = y/' Makefile
sed -i 's/EXTRA_CFLAGS += -mhard-float/# EXTRA_CFLAGS += -mhard-float/' Makefile
sed -i 's/EXTRA_CFLAGS += -mfloat-abi=hard/# EXTRA_CFLAGS += -mfloat-abi=hard/' Makefile

# Re-enable CFG80211
sed -i 's/# EXTRA_CFLAGS += -DCONFIG_IOCTL_CFG80211 -DRTW_USE_CFG80211_STA_EVENT/EXTRA_CFLAGS += -DCONFIG_IOCTL_CFG80211 -DRTW_USE_CFG80211_STA_EVENT/g' Makefile
sed -i 's/EXTRA_CFLAGS += -DCONFIG_LITTLE_ENDIAN/EXTRA_CFLAGS += -DCONFIG_LITTLE_ENDIAN -DCONFIG_WIRELESS_EXT -DCONFIG_WEXT_PRIV -DCONFIG_CONCURRENT_MODE/g' Makefile

# 2. Apply MMC SDIO card dump bypass to prevent struct mmc_card offset mismatch panic
python3 /home/gaurav/jiofi/driver/patches/apply_sdio_patch.py || true

# 3. Apply Qualcomm compatibility patches
python3 /home/gaurav/jiofi/driver/patches/apply_qualcomm_fixes.py || true
python3 /home/gaurav/jiofi/driver/patches/patch_mac_acl.py || true

cd ..

echo "=== Preparing Device Kernel Config ==="
cp -f /home/gaurav/jiofi/config.gz .
zcat config.gz > linux-3.18.20/.config
rm config.gz

# Force ARMv7 target architecture via Multiplatform config
sed -i 's/CONFIG_ARCH_MSM=y/# CONFIG_ARCH_MSM is not set/' linux-3.18.20/.config
echo "CONFIG_ARCH_MULTIPLATFORM=y" >> linux-3.18.20/.config

echo "=== Applying Qualcomm Core Structures Offset Patches ==="
# 1. Patch netdevice.h to force CONFIG_WIRELESS_EXT fields (resolves register_netdevice offset crash)
python3 -c '
filepath = "linux-3.18.20/include/linux/netdevice.h"
with open(filepath, "r") as f:
    content = f.read()
target = """#ifdef CONFIG_WIRELESS_EXT
	const struct iw_handler_def *	wireless_handlers;
	struct iw_public_data *	wireless_data;
#endif"""
replacement = """#if 1 // Force enabled for Qualcomm JMR1140 compatibility
	const struct iw_handler_def *	wireless_handlers;
	struct iw_public_data *	wireless_data;
#endif"""
if target in content:
    with open(filepath, "w") as f:
        f.write(content.replace(target, replacement))
    print("netdevice.h successfully patched!")
else:
    print("netdevice.h already patched or target not found.")
'

# 2. Patch iw_handler.h to force CONFIG_WEXT_PRIV fields (resolves iwconfig offset crash)
python3 -c '
filepath = "linux-3.18.20/include/net/iw_handler.h"
with open(filepath, "r") as f:
    content = f.read()
target = """#ifdef CONFIG_WEXT_PRIV
	__u16			num_private;
	/* Number of private arg description */
	__u16			num_private_args;
	/* Array of handlers for private ioctls
	 * Will call dev->wireless_handlers->private[ioctl - SIOCIWFIRSTPRIV]
	 */
	const iw_handler *	private;

	/* Arguments of private handler. This one is just a list, so you
	 * can put it in any order you want and should not leave holes...
	 * We will automatically export that to user space... */
	const struct iw_priv_args *	private_args;
#endif"""
replacement = """#if 1 // Force enabled for Qualcomm JMR1140 compatibility
	__u16			num_private;
	/* Number of private arg description */
	__u16			num_private_args;
	/* Array of handlers for private ioctls
	 * Will call dev->wireless_handlers->private[ioctl - SIOCIWFIRSTPRIV]
	 */
	const iw_handler *	private;

	/* Arguments of private handler. This one is just a list, so you
	 * can put it in any order you want and should not leave holes...
	 * We will automatically export that to user space... */
	const struct iw_priv_args *	private_args;
#endif"""
if target in content:
    with open(filepath, "w") as f:
        f.write(content.replace(target, replacement))
    print("iw_handler.h successfully patched!")
else:
    print("iw_handler.h already patched or target not found.")
'
# 3. Patch cfg80211.h to comment out abort_scan (resolves 4-byte struct cfg80211_ops offset shift)
cp -f /home/gaurav/jiofi/driver/Qualcomm_Headers/cfg80211.h linux-3.18.20/include/net/cfg80211.h
python3 -c '
filepath = "linux-3.18.20/include/net/cfg80211.h"
with open(filepath, "r") as f:
    content = f.read()
target = "void\t(*abort_scan)(struct wiphy *wiphy, struct wireless_dev *wdev);"
replacement = "/* void\t(*abort_scan)(struct wiphy *wiphy, struct wireless_dev *wdev); -- Commented out to align structure offsets with JioFi kernel */"
if target in content:
    with open(filepath, "w") as f:
        f.write(content.replace(target, replacement))
    print("cfg80211.h successfully patched!")
else:
    print("cfg80211.h already patched or target not found.")
'

echo "=== Preparing Kernel Headers ==="
export PATH="$BUILD_DIR/toolchain/bin:$PATH"
export ARCH=arm
export CROSS_COMPILE=arm-linux-

cd linux-3.18.20
# Pass HOSTCFLAGS="-fcommon" to bypass the multiple definition of yylloc error on modern hosts
make HOSTCFLAGS="-fcommon" olddefconfig
make HOSTCFLAGS="-fcommon" modules_prepare
cd ..

echo "=== Compiling Driver Module ==="
cd rtl8189es
find . -name "*.o" -o -name "*.ko" -o -name "*.mod.c" | xargs rm -f
make ARCH=arm CROSS_COMPILE=arm-linux- KSRC="$BUILD_DIR/linux-3.18.20" HOSTCFLAGS="-fcommon" modules
cd ..

echo "=== Saving Driver Artifact ==="
mkdir -p /home/gaurav/jiofi/patched
cp -f rtl8189es/8189es.ko /home/gaurav/jiofi/patched/rtl8189es-custom.ko
echo "Custom driver saved to: patched/rtl8189es-custom.ko"
