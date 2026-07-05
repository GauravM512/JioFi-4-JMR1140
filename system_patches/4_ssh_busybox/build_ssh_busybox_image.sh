#!/bin/bash
# system_patches/4_ssh_busybox/build_ssh_busybox_image.sh
# ============================================================================
# Builds mdm9607-sysfs-adb-ssh-busybox.ubi from the verified patched base.
# Adds: Updated Busybox 1.31.0 + Dropbear SSH 2022.82 + ADB (already in base)
# Does NOT include: personal WPS listener, battery LED, root password blanking
#
# Hard rules (from personal_builds/README.md):
#   1. Always pass -k to ubireader_extract_files (preserves Android UIDs).
#   2. Never copy/move files across physical filesystem boundaries.
#   3. Dropbear init MUST run in background (&) to avoid entropy boot hang.
# ============================================================================

set -eu

PROJECT_ROOT=/home/gaurav/jiofi
PATCH_DIR="$PROJECT_ROOT/system_patches/4_ssh_busybox"
BASE_UBI="$PROJECT_ROOT/patched/mdm9607-sysfs-repeater-patched.ubi"
OUTPUT_UBI="$PROJECT_ROOT/patched/mdm9607-sysfs-adb-ssh-busybox.ubi"

BUILD_DIR="$PROJECT_ROOT/personal_builds/_build/ssh_busybox"
EXTRACT_DIR="$BUILD_DIR/patched_extract"
STATE_DB="$BUILD_DIR/rootfs.state"
UBIFS_OUT="$BUILD_DIR/rootfs.ubifs"
UBINIZE_CFG="$BUILD_DIR/ubinize.cfg"

EXTRACT_BIN="$PROJECT_ROOT/.tools/ubi-venv/bin/ubireader_extract_files"

# --- Sanity checks ---
[ -f "$BASE_UBI" ]    || { echo "FATAL: base UBI missing: $BASE_UBI"; exit 1; }
[ -x "$EXTRACT_BIN" ] || { echo "FATAL: ubireader missing"; exit 1; }
command -v fakeroot    >/dev/null || { echo "FATAL: fakeroot missing"; exit 1; }
[ -f "$PATCH_DIR/binaries/busybox" ]  || { echo "FATAL: busybox binary missing"; exit 1; }
[ -f "$PATCH_DIR/binaries/dropbear" ] || { echo "FATAL: dropbear binary missing"; exit 1; }

# --- Clean ---
trap 'rm -f "$UBIFS_OUT" 2>/dev/null || true' EXIT
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "=== 1. Extracting base UBI with -k (keep permissions) ==="
fakeroot -s "$STATE_DB" -- \
    "$EXTRACT_BIN" -k -o "$EXTRACT_DIR" "$BASE_UBI"

ROOTFS_DIR=$(find "$EXTRACT_DIR" -mindepth 2 -maxdepth 4 -type d -name rootfs | head -n 1)
[ -n "$ROOTFS_DIR" ] || { echo "FATAL: no rootfs/ found"; exit 1; }
echo "Rootfs: $ROOTFS_DIR"

echo "=== 2. Applying patches inside single fakeroot session ==="
fakeroot -i "$STATE_DB" -s "$STATE_DB" -- sh -c '
  set -e
  RD="$1"
  PATCH="$2"

  # -- Busybox (replaces stock binary, same path, same name) --
  cp "$PATCH/binaries/busybox" "$RD/bin/busybox"
  chmod 755 "$RD/bin/busybox"
  chown 0:0 "$RD/bin/busybox"

  # -- Dropbear multi-binary --
  cp "$PATCH/binaries/dropbear" "$RD/usr/sbin/dropbearmulti"
  chmod 755 "$RD/usr/sbin/dropbearmulti"
  chown 0:0 "$RD/usr/sbin/dropbearmulti"
  ln -sf dropbearmulti         "$RD/usr/sbin/dropbear"
  ln -sf ../sbin/dropbearmulti "$RD/usr/bin/dropbearkey"
  ln -sf ../sbin/dropbearmulti "$RD/usr/bin/dbclient"

  # -- Dropbear init script (background-safe, see README) --
  cp "$PATCH/etc/init.d/dropbear" "$RD/etc/init.d/dropbear"
  chmod 755 "$RD/etc/init.d/dropbear"
  chown 0:0 "$RD/etc/init.d/dropbear"
  ln -sf ../init.d/dropbear "$RD/etc/rc5.d/S60dropbear"

  echo "  [+] busybox, dropbear, init script applied."
' _ "$ROOTFS_DIR" "$PATCH_DIR"

echo "=== 3. Compiling UBIFS ==="
fakeroot -i "$STATE_DB" -s "$STATE_DB" -- \
    /usr/sbin/mkfs.ubifs \
    -r "$ROOTFS_DIR" -m 2048 -e 126976 -c 2146 -F -j 8388608 -x lzo \
    -o "$UBIFS_OUT"

echo "=== 4. Packing UBI container ==="
cat > "$UBINIZE_CFG" <<EOF
[rootfs]
mode=ubi
image=$UBIFS_OUT
vol_id=0
vol_size=42029056
vol_type=dynamic
vol_name=rootfs
vol_flags=autoresize
EOF

/usr/sbin/ubinize \
    -o "$OUTPUT_UBI" -m 2048 -p 128KiB -s 2048 -Q 907419386 \
    "$UBINIZE_CFG"

trap - EXIT

echo "============================================================================"
echo "SUCCESS"
ls -lh "$OUTPUT_UBI"
sha256sum "$OUTPUT_UBI"
echo "============================================================================"
echo "Flash: fastboot flash system $OUTPUT_UBI"
