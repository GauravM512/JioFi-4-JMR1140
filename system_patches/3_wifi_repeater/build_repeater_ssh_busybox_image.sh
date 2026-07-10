#!/bin/bash
# system_patches/3_wifi_repeater/build_repeater_ssh_busybox_image.sh
# ============================================================================
# Builds mdm9607-sysfs-repeater-ssh-busybox.ubi
#
# Includes:
#   - WiFi Repeater mode (hostapd, mobileap_cfg, custom Web UI, ADB)
#   - Updated Busybox 1.31.0 (static, musl)
#   - Dropbear SSH 2022.82 (static, musl, background-safe init)
#   - Battery LED manager (charging blink, discharge colour, white idle)
#
# Does NOT include:
#   - WPS Wake-on-LAN listener (personal_builds only)
#   - Battery LED manager (personal_builds only)
#   - Blank root password (set BLANK_ROOT_PASSWORD=1 to enable)
#
# Hard rules (learned from bootloop debugging):
#   1. Extract with -k (keep permissions) — without this 1439/1660 files
#      get wrong UIDs and bootloop.
#   2. Stay on the same filesystem — don't move rootfs between /tmp and /home.
#   3. Dropbear init forks to background — avoids entropy-starvation boot hang.
#   4. All patching in ONE fakeroot session sharing one state DB.
# ============================================================================

set -eu

PROJECT_ROOT=/home/gaurav/jiofi
REPEATER_PATCH="$PROJECT_ROOT/system_patches/3_wifi_repeater"
SSH_PATCH="$PROJECT_ROOT/system_patches/4_ssh_busybox"
BASE_UBI="$PROJECT_ROOT/patched/mdm9607-sysfs-repeater-patched.ubi"
OUTPUT_UBI="$PROJECT_ROOT/patched/mdm9607-sysfs-repeater-ssh-busybox.ubi"

BUILD_DIR="$PROJECT_ROOT/personal_builds/_build/repeater_ssh_busybox"
EXTRACT_DIR="$BUILD_DIR/patched_extract"
STATE_DB="$BUILD_DIR/rootfs.state"
UBIFS_OUT="$BUILD_DIR/rootfs.ubifs"
UBINIZE_CFG="$BUILD_DIR/ubinize.cfg"

EXTRACT_BIN="$PROJECT_ROOT/.tools/ubi-venv/bin/ubireader_extract_files"
BLANK_ROOT_PASSWORD="${BLANK_ROOT_PASSWORD:-0}"

# --- Sanity checks ---
[ -f "$BASE_UBI" ]    || { echo "FATAL: base UBI missing: $BASE_UBI"; exit 1; }
[ -x "$EXTRACT_BIN" ] || { echo "FATAL: ubireader missing: $EXTRACT_BIN"; exit 1; }
command -v fakeroot    >/dev/null || { echo "FATAL: fakeroot not installed"; exit 1; }
[ -f "$SSH_PATCH/binaries/busybox" ]  || { echo "FATAL: busybox binary missing"; exit 1; }
[ -f "$SSH_PATCH/binaries/dropbear" ] || { echo "FATAL: dropbear binary missing"; exit 1; }

# --- Clean old build ---
trap 'rm -f "$UBIFS_OUT" 2>/dev/null || true' EXIT
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "=== 1. Extracting base UBI with -k (keep permissions) ==="
fakeroot -s "$STATE_DB" -- \
    "$EXTRACT_BIN" -k -o "$EXTRACT_DIR" "$BASE_UBI"

ROOTFS_DIR=$(find "$EXTRACT_DIR" -mindepth 2 -maxdepth 4 -type d -name rootfs | head -n 1)
[ -n "$ROOTFS_DIR" ] || { echo "FATAL: no rootfs/ found beneath $EXTRACT_DIR"; exit 1; }
echo "Rootfs: $ROOTFS_DIR"

echo "=== 2. Applying all patches inside single fakeroot session ==="
fakeroot -i "$STATE_DB" -s "$STATE_DB" -- sh -c '
  set -e
  RD="$1"
  REPEATER_PATCH="$2"
  SSH_PATCH="$3"
  BLANK_ROOT_PASSWORD="$4"
  PROJECT_ROOT="$(dirname "$(dirname "$SSH_PATCH")")"
  # e.g. SSH_PATCH=.../system_patches/4_ssh_busybox → PROJECT_ROOT=.../jiofi

  # ── A. WiFi Repeater patches ──────────────────────────────────────────────
  # Copy repeater overlay (etc/, sbin/, usr/, www/ directories)
  cp -rfP "$REPEATER_PATCH/." "$RD/"

  # ADB shell symlink (required for adb shell to work)
  mkdir -p "$RD/system/bin"
  ln -sf /bin/sh "$RD/system/bin/sh"

  # Boot service symlinks for repeater (rc2-5)
  ln -sf ../init.d/start_repeater "$RD/etc/rc2.d/S99start_repeater"
  ln -sf ../init.d/start_repeater "$RD/etc/rc3.d/S99start_repeater"
  ln -sf ../init.d/start_repeater "$RD/etc/rc4.d/S99start_repeater"
  ln -sf ../init.d/start_repeater "$RD/etc/rc5.d/S99start_repeater"

  # Fix permissions on repeater scripts
  chmod 755 "$RD/etc/init.d/start_repeater"
  chmod 755 "$RD/etc/init.d/start_QCMAP_Web_CLIENT_le"
  chmod 755 "$RD/etc/init.d/start_QCMAP_ConnectionManager_le"
  chmod 755 "$RD/www/cgi-bin/save"
  chmod 755 "$RD/www/cgi-bin/status"
  chmod 755 "$RD/www/cgi-bin/reboot"
  chmod 755 "$RD/www/cgi-bin/scan"
  chmod 755 "$RD/sbin/usb/compositions/02e1"
  chown 0:0 "$RD/etc/init.d/start_repeater"
  chown 0:0 "$RD/etc/init.d/start_QCMAP_Web_CLIENT_le"
  chown 0:0 "$RD/etc/init.d/start_QCMAP_ConnectionManager_le"
  echo "  [+] WiFi Repeater patches applied."

  # ── B. Busybox update ────────────────────────────────────────────────────
  cp "$SSH_PATCH/binaries/busybox" "$RD/bin/busybox"
  chmod 755 "$RD/bin/busybox"
  chown 0:0 "$RD/bin/busybox"
  echo "  [+] Busybox 1.31.0 installed."

  # ── C. Dropbear SSH ──────────────────────────────────────────────────────
  cp "$SSH_PATCH/binaries/dropbear" "$RD/usr/sbin/dropbearmulti"
  chmod 755 "$RD/usr/sbin/dropbearmulti"
  chown 0:0 "$RD/usr/sbin/dropbearmulti"
  ln -sf dropbearmulti         "$RD/usr/sbin/dropbear"
  ln -sf ../sbin/dropbearmulti "$RD/usr/bin/dropbearkey"
  ln -sf ../sbin/dropbearmulti "$RD/usr/bin/dbclient"

  cp "$SSH_PATCH/etc/init.d/dropbear" "$RD/etc/init.d/dropbear"
  chmod 755 "$RD/etc/init.d/dropbear"
  chown 0:0 "$RD/etc/init.d/dropbear"
  ln -sf ../init.d/dropbear "$RD/etc/rc5.d/S60dropbear"
  echo "  [+] Dropbear SSH 2022.82 installed."

  # ── D. Battery LED manager ───────────────────────────────────────────────
  cp /home/gaurav/jiofi/personal_builds/battery_led_manager.sh "$RD/usr/bin/battery_led_manager.sh"
  chmod 755 "$RD/usr/bin/battery_led_manager.sh"
  chown 0:0 "$RD/usr/bin/battery_led_manager.sh"
  cp /home/gaurav/jiofi/personal_builds/start_battery_led "$RD/etc/init.d/start_battery_led"
  chmod 755 "$RD/etc/init.d/start_battery_led"
  chown 0:0 "$RD/etc/init.d/start_battery_led"
  ln -sf ../init.d/start_battery_led "$RD/etc/rc5.d/S98start_battery_led"
  echo "  [+] Battery LED manager installed."

  # ── E. Fixed battery CGI (correct ADC path + µV→mV conversion) ──────────
  cp "$PROJECT_ROOT/rootfs/www/cgi-bin/status" "$RD/www/cgi-bin/status"
  chmod 755 "$RD/www/cgi-bin/status"
  chown 0:0 "$RD/www/cgi-bin/status"
  echo "  [+] Fixed battery CGI installed."

  # ── F. jiofetch ──────────────────────────────────────────────────────────
  cp "$PROJECT_ROOT/personal_builds/jiofetch" "$RD/usr/bin/jiofetch"
  chmod 755 "$RD/usr/bin/jiofetch"
  chown 0:0 "$RD/usr/bin/jiofetch"
  echo "  [+] jiofetch installed."

  # ── G. sy6923 charger fix (PRESENT=0 boot bug) ───────────────────────────
  cp "$PROJECT_ROOT/personal_builds/fix_charger" "$RD/etc/init.d/fix_charger"
  chmod 755 "$RD/etc/init.d/fix_charger"
  chown 0:0 "$RD/etc/init.d/fix_charger"
  ln -sf ../init.d/fix_charger "$RD/etc/rc5.d/S01fix_charger"
  echo "  [+] sy6923 charger fix installed."

  # ── D. Optional: blank root password for SSH login ───────────────────────
  if [ "$BLANK_ROOT_PASSWORD" = "1" ]; then
    sed -i "s/^root:[^:]*:/root::/" "$RD/etc/shadow"
    echo "  [+] Root password blanked."
  fi
' _ "$ROOTFS_DIR" "$REPEATER_PATCH" "$SSH_PATCH" "$BLANK_ROOT_PASSWORD"

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
