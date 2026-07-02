import os

filepath = "/tmp/jiofi_custom_build/rtl8189es/os_dep/linux/os_intfs.c"
with open(filepath, "r") as f:
    content = f.read()

old_net_ns_block = """#if defined(CONFIG_NET_NS)
	dev_net_set(ndev, wiphy_net(adapter_to_wiphy(adapter)));
#endif"""

new_net_ns_block = """#if defined(CONFIG_NET_NS) && defined(CONFIG_IOCTL_CFG80211)
	dev_net_set(ndev, wiphy_net(adapter_to_wiphy(adapter)));
#endif"""

if old_net_ns_block in content:
    content = content.replace(old_net_ns_block, new_net_ns_block)
    print("os_intfs.c net namespace block patched successfully!")
else:
    print("Warning: Could not find CONFIG_NET_NS block in os_intfs.c")

with open(filepath, "w") as f:
    f.write(content)
print("Patching complete!")
