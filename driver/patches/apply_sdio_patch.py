import os

filepath = "/tmp/jiofi_custom_build/rtl8189es/os_dep/linux/sdio_intf.c"
with open(filepath, "r") as f:
    content = f.read()

# 1. Bypass dump_sdio_card_info to prevent oops
old_dump_start = "void dump_sdio_card_info(void *sel, struct dvobj_priv *dvobj)"
# Let's find this function and empty its body!
start_idx = content.find(old_dump_start)
if start_idx != -1:
    # Find the matching closing brace of the function
    # The function body starts at '{'
    brace_start = content.find('{', start_idx)
    # We find the matching '}' by tracking depth
    depth = 0
    end_idx = -1
    for idx in range(brace_start, len(content)):
        if content[idx] == '{':
            depth += 1
        elif content[idx] == '}':
            depth -= 1
            if depth == 0:
                end_idx = idx
                break
    if end_idx != -1:
        new_dump_func = """void dump_sdio_card_info(void *sel, struct dvobj_priv *dvobj)
{
	/* Bypassed to prevent kernel oops from struct mmc_card offset mismatch */
	RTW_PRINT_SEL(sel, "dump_sdio_card_info bypassed\\n");
}"""
        content = content[:start_idx] + new_dump_func + content[end_idx + 1:]
        print("dump_sdio_card_info patched successfully!")
    else:
        print("Error: Could not find closing brace for dump_sdio_card_info")
else:
    print("Error: Could not find dump_sdio_card_info definition")

with open(filepath, "w") as f:
    f.write(content)
print("SDIO patching complete!")
