#!/usr/bin/env python3
"""Convert a .wasm module into a C++ source defining a byte array.

Used by the :reference_core_embedded_src genrule so the reference call core
ships inside the binary instead of being loaded from disk.

Usage: wasm_to_source.py INPUT.wasm OUTPUT.cpp
"""
import sys


def main():
    if len(sys.argv) != 3:
        sys.stderr.write("usage: wasm_to_source.py INPUT.wasm OUTPUT.cpp\n")
        return 2
    with open(sys.argv[1], "rb") as handle:
        data = handle.read()
    # Guard against silently embedding a truncated or non-wasm artifact:
    # every wasm module starts with the "\0asm" magic and a 4-byte version.
    if len(data) < 8 or data[:4] != b"\x00asm":
        sys.stderr.write("error: %s is not a wasm module\n" % sys.argv[1])
        return 1
    out = [
        '#include "v2wasm/EmbeddedCoreModule.h"\n',
        "\n",
        "namespace tgcalls {\n",
        "namespace v2wasm {\n",
        "\n",
        "extern const uint8_t kReferenceCoreWasm[] = {\n",
    ]
    for offset in range(0, len(data), 16):
        chunk = data[offset:offset + 16]
        out.append("    " + "".join("0x%02x," % byte for byte in chunk) + "\n")
    out.append("};\n")
    out.append("extern const size_t kReferenceCoreWasmSize = %d;\n" % len(data))
    out.append("\n")
    out.append("} // namespace v2wasm\n")
    out.append("} // namespace tgcalls\n")
    with open(sys.argv[2], "w") as handle:
        handle.write("".join(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
