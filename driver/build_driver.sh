#!/bin/bash
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

# Apply platform fixes to driver Makefile
cd rtl8189es
sed -i 's/CONFIG_PLATFORM_I386_PC = n/CONFIG_PLATFORM_I386_PC = y/' Makefile
sed -i 's/EXTRA_CFLAGS += -mhard-float/# EXTRA_CFLAGS += -mhard-float/' Makefile
sed -i 's/EXTRA_CFLAGS += -mfloat-abi=hard/# EXTRA_CFLAGS += -mfloat-abi=hard/' Makefile
cd ..

echo "=== Extracting Device Kernel Config ==="
# Force re-extraction of config if it wasn't customized for ARMv7
if [ ! -f "linux-3.18.20/.config" ] || ! grep -q "CONFIG_ARCH_MULTIPLATFORM=y" linux-3.18.20/.config; then
    cp /home/gaurav/jiofi/config.gz .
    zcat config.gz > linux-3.18.20/.config
    # Enable ARMv7 multiplatform to force compiler to target ARMv7
    sed -i 's/CONFIG_ARCH_MSM=y/# CONFIG_ARCH_MSM is not set/' linux-3.18.20/.config
    echo "CONFIG_ARCH_MULTIPLATFORM=y" >> linux-3.18.20/.config
    rm config.gz
fi

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
make ARCH=arm CROSS_COMPILE=arm-linux- KSRC="$BUILD_DIR/linux-3.18.20" HOSTCFLAGS="-fcommon" modules
cd ..

echo "=== Compilation Complete! ==="
mkdir -p /home/gaurav/jiofi/patched
cp -f rtl8189es/8189es.ko /home/gaurav/jiofi/patched/rtl8189es-custom.ko
echo "Custom driver saved to: patched/rtl8189es-custom.ko"
