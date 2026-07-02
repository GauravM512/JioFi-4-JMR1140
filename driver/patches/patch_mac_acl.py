import os

filepath = "/tmp/jiofi_custom_build/rtl8189es/os_dep/linux/ioctl_cfg80211.c"
with open(filepath, "r") as f:
    content = f.read()

old_acl_line = "wiphy->max_acl_mac_addrs = NUM_ACL;"
new_acl_line = "wiphy->max_acl_mac_addrs = 0; /* Forced to 0 to bypass wiphy_register validation failure */"

if old_acl_line in content:
    content = content.replace(old_acl_line, new_acl_line)
    print("ioctl_cfg80211.c patched to set max_acl_mac_addrs to 0 successfully!")
else:
    print("Error: Could not find max_acl_mac_addrs line in ioctl_cfg80211.c")

with open(filepath, "w") as f:
    f.write(content)
print("Patching complete!")
