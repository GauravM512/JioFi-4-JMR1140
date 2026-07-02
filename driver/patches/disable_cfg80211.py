import os

# 1. Patch Makefile to disable CONFIG_IOCTL_CFG80211
makefile_path = "/tmp/jiofi_custom_build/rtl8189es/Makefile"
with open(makefile_path, "r") as f:
    lines = f.readlines()

patched = False
for idx, line in enumerate(lines):
    # We find the line in the CONFIG_PLATFORM_I386_PC block
    if "CONFIG_PLATFORM_I386_PC" in line:
        print(f"Found platform PC block near line {idx}")
    if idx >= 1285 and idx <= 1305:
        if "-DCONFIG_IOCTL_CFG80211" in line:
            lines[idx] = line.replace("EXTRA_CFLAGS += -DCONFIG_IOCTL_CFG80211 -DRTW_USE_CFG80211_STA_EVENT", "# EXTRA_CFLAGS += -DCONFIG_IOCTL_CFG80211 -DRTW_USE_CFG80211_STA_EVENT")
            print(f"Commented out CONFIG_IOCTL_CFG80211 at line {idx+1}")
            patched = True

with open(makefile_path, "w") as f:
    f.writelines(lines)

if patched:
    print("Makefile successfully patched to disable CFG80211!")
else:
    print("Warning: Could not patch Makefile!")
