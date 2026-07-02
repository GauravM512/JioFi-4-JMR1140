import os

# 2. Patch rtw_cfgvendor.c (vendor_event_alloc)
v_path = "/tmp/jiofi_custom_build/rtl8189es/os_dep/linux/rtw_cfgvendor.c"
with open(v_path, "r") as f:
    v_content = f.read()

# Replace using tabs
old_v_block = "#if (LINUX_VERSION_CODE < KERNEL_VERSION(4, 1, 0))\n\tskb = cfg80211_vendor_event_alloc(wiphy, len, event_id, gfp);\n#else\n\tskb = cfg80211_vendor_event_alloc(wiphy, wdev, len, event_id, gfp);\n#endif"
new_v_block = "#if defined(SUPPORT_WDEV_CFG80211_VENDOR_EVENT_ALLOC)\n\tskb = cfg80211_vendor_event_alloc(wiphy, wdev, len, event_id, gfp);\n#elif (LINUX_VERSION_CODE < KERNEL_VERSION(4, 1, 0))\n\tskb = cfg80211_vendor_event_alloc(wiphy, len, event_id, gfp);\n#else\n\tskb = cfg80211_vendor_event_alloc(wiphy, wdev, len, event_id, gfp);\n#endif"

occ = v_content.count(old_v_block)
print(f"Found {occ} occurrences of vendor_event_alloc block in rtw_cfgvendor.c")
if occ > 0:
    v_content = v_content.replace(old_v_block, new_v_block)
    print("rtw_cfgvendor.c blocks patched!")
else:
    # If count is 0, let's try line-by-line replacement or check formatting
    print("Trying fallback replacement for rtw_cfgvendor.c...")
    # Let's replace any instance of:
    # cfg80211_vendor_event_alloc(wiphy, len, event_id, gfp)
    # with conditional macro or just:
    # cfg80211_vendor_event_alloc(wiphy, NULL, len, event_id, gfp) under SUPPORT_WDEV_CFG80211_VENDOR_EVENT_ALLOC
    v_content = v_content.replace(
        "cfg80211_vendor_event_alloc(wiphy, len, event_id, gfp)",
        "cfg80211_vendor_event_alloc(wiphy, wdev, len, event_id, gfp)"
    )
    print("Applied fallback replacement!")

with open(v_path, "w") as f:
    f.write(v_content)

print("Patcher complete!")
