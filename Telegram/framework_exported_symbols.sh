#!/bin/bash
# The symbols a framework must export: those its clients reference and it defines.
#
#   framework_exported_symbols.sh scan <defined|undefined> <archive> <output>
#       The defined external (or the undefined) symbol names of one static archive, one per line.
#       One action per archive, so an edit rescans only the archive it changed.
#   framework_exported_symbols.sh merge <output> <defined lists file> <undefined lists file>
#       The intersection of the framework's defined names and its clients' undefined names. Each
#       lists file names one `scan` output per line (see framework_exported_symbols.bzl).
set -euo pipefail

mode="$1"
shift

case "$mode" in
scan)
    kind="$1"
    archive="$2"
    output="$3"
    case "$kind" in
    defined) flags=(-g -U -j) ;;
    undefined) flags=(-u -j) ;;
    *) echo "framework_exported_symbols: unknown scan kind $kind" >&2; exit 2 ;;
    esac
    # `nm -j` prints bare names plus "archive(member):" headers and blank lines between members.
    # A scan that loses symbols cannot pass silently: a missing defined or undefined name makes
    # the client's link fail with an undefined symbol.
    { xcrun nm "${flags[@]}" "$archive" 2> /dev/null || true; } | { grep -v -e ':$' -e '^$' || true; } | sort -u > "$output"
    ;;
merge)
    output="$1"
    defined_lists="$2"
    undefined_lists="$3"
    scratch="$(mktemp -d)"
    trap 'rm -rf "$scratch"' EXIT
    { xargs cat < "$defined_lists" || true; } | sort -u > "$scratch/defined"
    { xargs cat < "$undefined_lists" || true; } | sort -u > "$scratch/undefined"
    if [ ! -s "$scratch/defined" ]; then
        echo "framework_exported_symbols: no defined symbols in the framework's archives" >&2
        exit 1
    fi
    if [ ! -s "$scratch/undefined" ]; then
        echo "framework_exported_symbols: no undefined symbols in the clients' archives" >&2
        exit 1
    fi
    comm -12 "$scratch/defined" "$scratch/undefined" > "$output"
    ;;
*)
    echo "framework_exported_symbols: unknown mode $mode" >&2
    exit 2
    ;;
esac
