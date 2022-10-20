#!/bin/sh

# Convert standard input to a C char array, write to a file, then create an
# MD5 sum of that file and append said MD5 sum as char array to the file.

[ -n "$1" ] || exit 1

# Filter out whitespace, empty lines, and comments.
sanitize() {
    sed 's/^[[:space:]]*//; /^$/d; /^\/\//d'
}

# Convert stdin to a \0-terminated char array.
dump() {
    echo "static const char $1[] = {"
    od -v -A n -t x1 | sed 's/[[:space:]]*\([[:alnum:]]\{2\}\)/0x\1, /g'
    echo '0x00 };'
}

# Print MD5 hash w/o newline character to not embed the character in the array.
hash() {
    # md5sum is not standard, so try different platform-specific alternatives.
    { md5sum "$1" || md5 -q "$1" || digest -a md5 "$1"; } 2>/dev/null |
        cut -b -32 | tr -d '\n\r'
}

trap 'rm -f "$1.temp"' EXIT

sanitize | tee "$1.temp" |
    dump 'x264_opencl_source' > "$1"

hash "$1.temp" |
    dump 'x264_opencl_source_hash' >> "$1"
