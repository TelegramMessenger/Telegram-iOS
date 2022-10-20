#!/usr/bin/env python3

import sys
import plistlib

if len(sys.argv) < 3:
    print("Usage <merge|finalize> output_file [inputs]")
    sys.exit(0)

output = sys.argv[2]
action = sys.argv[1]

merged_fragments = []
seen_licenses = set()
for idx, arg in enumerate(sys.argv):
    if idx <= 2:
        continue
    with open(arg, 'rb') as f:
        input_plist = plistlib.load(f, fmt=plistlib.FMT_XML)
        if not input_plist:
            continue
        fragments = input_plist if isinstance(input_plist, list) else [input_plist]
        for fragment in fragments:
            # We only want to insert a given software license 1 time
            title = fragment.get("Title")
            if title in seen_licenses:
                continue
            seen_licenses.add(title)
            merged_fragments.append(fragment)

if action == "--finalize":
    out_plist = {
        "StringsTable": "Acknowledgements",
        "PreferenceSpecifiers": merged_fragments
    }
    with open(output, 'wb') as f:
        plistlib.dump(out_plist, f, fmt=plistlib.FMT_XML)
elif action == "--merge":
    with open(output, 'wb') as f:
        plistlib.dump(merged_fragments, f, fmt=plistlib.FMT_XML)
