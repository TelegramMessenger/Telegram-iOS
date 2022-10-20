#!/usr/bin/env python3
from __future__ import print_function

import json
import optparse
import os
import struct
import sys
import headermap_tool
import tempfile

# The data structure that LLVM uses is { mappings: { name: path } }

def main():
    """ Helper program for headermap rule"""
    output_path = sys.argv[1]
    json_path = sys.argv[2]

    if len(sys.argv) == 3:
        headermap_tool.action_write("write", [json_path, output_path])
        return

    # We write an intermediate JSON file, which represents the trans hmap
    fd, merge_file = tempfile.mkstemp()
    with open(json_path, "r") as f:
        input_data = json.load(f)
        # For every additional headermap, read it in and merge
        for path in sys.argv[3:]:
            add_hmap = headermap_tool.HeaderMap.frompath(path)
            for mapping in add_hmap.mappings:
                input_data["mappings"][mapping[0]] = mapping[1]

        with open(merge_file, "w") as f:
            json.dump(input_data, f, indent=2)

        headermap_tool.action_write("write", [merge_file, output_path])

if __name__ == '__main__':
    main()
