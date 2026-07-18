# 🛠️ JioFi 4 (MDM9607) Compilation Guide

This guide documents how to compile custom statically linked binaries for the JioFi JMR1140 (Qualcomm MDM9607 platform, ARM Cortex-A7 CPU, `armv7l` architecture running Linux kernel `3.18.20`).

Since the stock firmware uses a very old kernel and custom environment, compiling custom programs requires a statically linked `musl-libc` toolchain to guarantee compatibility and prevent library version mismatch errors.

---

## 📦 1. The Cross-Compilation Toolchain

To compile binaries that run flawlessly on the JioFi 4, use the **Bootlin Musl Toolchain** for `armv7-eabihf` (ARMv7, Hard Float EABI, Musl libc).

* **Download URL:** `https://toolchains.bootlin.com/downloads/releases/toolchains/armv7-eabihf/tarballs/armv7-eabihf--musl--stable-2024.05-1.tar.xz`
* **Target Architecture:** ARMv7-A (Cortex-A7)
* **Compiler Prefix:** `arm-linux-` (Buildroot creates symlinks mapping `arm-linux-*` to `arm-buildroot-linux-musleabihf-*`)

### Toolchain Setup
To set up the toolchain on a Linux host (e.g., Ubuntu/Debian):

```bash
# 1. Download the toolchain package
curl -L -o /tmp/musl-toolchain.tar.xz "https://toolchains.bootlin.com/downloads/releases/toolchains/armv7-eabihf/tarballs/armv7-eabihf--musl--stable-2024.05-1.tar.xz"

# 2. Create the target folder and extract
mkdir -p /tmp/musl-toolchain
tar -xf /tmp/musl-toolchain.tar.xz -C /tmp/musl-toolchain --strip-components=1

# 3. Add to PATH
export PATH="/tmp/musl-toolchain/bin:$PATH"
```

---

## 🐚 2. Compiling Busybox (v1.38.0 or newer)

Busybox provides lightweight Unix utilities. Here is how to compile a custom updated version statically:

```bash
# 1. Download and extract Busybox source
curl -L -o /tmp/busybox-1.38.0.tar.bz2 "https://busybox.net/downloads/busybox-1.38.0.tar.bz2"
tar -xf /tmp/busybox-1.38.0.tar.bz2 -C /tmp
cd /tmp/busybox-1.38.0

# 2. Setup default config using the toolchain
make ARCH=arm CROSS_COMPILE=arm-linux- defconfig

# 3. Edit config to enable static building
# This ensures that no shared libraries are loaded at runtime
sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
sed -i 's/CONFIG_CROSS_COMPILER_PREFIX=""/CONFIG_CROSS_COMPILER_PREFIX="arm-linux-"/' .config

# 4. Compile the binary
make ARCH=arm CROSS_COMPILE=arm-linux- -j$(nproc)

# 5. Verify the compiled binary
file busybox
arm-linux-readelf -h busybox
```

---

## 🔒 3. Compiling Dropbear SSH

Dropbear is a lightweight SSH server. To compile it statically against the musl-libc toolchain:

```bash
# 1. Download and extract Dropbear source
curl -L -o /tmp/dropbear-2022.82.tar.bz2 "https://matt.ucc.asn.au/dropbear/releases/dropbear-2022.82.tar.bz2"
tar -xf /tmp/dropbear-2022.82.tar.bz2 -C /tmp
cd /tmp/dropbear-2022.82

# 2. Configure for static musl build
# --disable-harden prevents gcc from compiling with dynamic PIE (Position Independent Executables) flags
./configure --host=arm-linux \
            --disable-zlib \
            --disable-syslog \
            --disable-harden \
            CC=arm-linux-gcc \
            CFLAGS="-static" \
            LDFLAGS="-static"

# 3. Compile the multi-call binary containing SSH server, client, and keys tool
make MULTI=1 PROGRAMS="dropbear dropbearkey dbclient" -j$(nproc)

# 4. Verify Dropbear multi-call binary
file dropbearmulti
arm-linux-readelf -h dropbearmulti
```

---

## 💡 Key Tips for Compiling Custom Programs

1. **Always link statically (`-static`):** The target system's dynamic libraries might be outdated, missing, or incompatible. Linking statically ensures all dependencies are packed inside the binary.
2. **Use `-disable-harden` (for Dropbear/Autotools):** If building Autotools-based software, compilation scripts might automatically inject dynamic hardening flags (such as `-Wl,-pie`, `-z relro`). Always override or disable them to ensure true static linking.
3. **Strip your binaries:** Use `arm-linux-strip <binary>` to remove debugging symbols and significantly decrease the binary size (crucial for JioFi's limited 256MB flash space).
