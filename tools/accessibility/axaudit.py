#!/usr/bin/env python3
"""Audit an AXe `describe-ui` dump.

Usage: axaudit.py <tree.json> [--screen WxH]

Prints one line per meaningful element (`type | label | value | traits | frame`),
then `FLAG <kind> <element>` lines. Always exits 0.
Flag kinds: unlabelled-interactive, offscreen, zero-size, duplicate, bare-image,
bare-text-in-control.
"""
import json
import sys

CONTAINERS = {"Group", "ScrollArea", "Application"}
INTERACTIVE = {"Button", "Link", "Switch", "Slider", "TextField", "SecureTextField",
               "SearchField", "Tab", "TabBar", "Toggle", "Stepper", "Cell",
               "SegmentedControl", "Picker", "MenuItem", "Checkbox", "RadioButton"}


def is_scroll_bar(n):
    s = "%s %s" % (n.get("AXLabel") or "", n.get("AXValue") or "")
    return "scroll bar" in s.lower() or "0 pages" in s.lower()


def txt(v):
    return (v or "").strip() if isinstance(v, str) else ""


def meaningful(n):
    return bool(txt(n.get("AXLabel")) or txt(n.get("AXValue"))) or n.get("type") not in CONTAINERS


def fmt_frame(f):
    def g(k):
        v = f.get(k, 0)
        return ("%g" % round(v, 1))
    return "%s,%s %sx%s" % (g("x"), g("y"), g("width"), g("height"))


def describe(n):
    traits = n.get("traits") or []
    if isinstance(traits, str):
        traits = [traits]
    one = lambda s: txt(s).replace("\n", "\\n")
    return " | ".join([n.get("type") or "?", one(n.get("AXLabel")), one(n.get("AXValue")),
                       ",".join(str(t) for t in traits), fmt_frame(n.get("frame") or {})])


def walk(nodes, parent_ctl, out):
    for n in nodes:
        if is_scroll_bar(n):
            continue
        ctl = parent_ctl
        if meaningful(n):
            out.append((n, parent_ctl))
        if n.get("type") in INTERACTIVE:
            ctl = n
        walk(n.get("children") or [], ctl, out)


def audit(tree, screen=None):
    roots = tree if isinstance(tree, list) else [tree]
    if screen is None:
        f = (roots[0].get("frame") or {}) if roots else {}
        screen = (f.get("width", 0), f.get("height", 0))
    sw, sh = screen
    out = []
    walk(roots, None, out)
    lines, flags, seen = [], [], set()
    for n, ctl in out:
        d = describe(n)
        lines.append(d)
        f = n.get("frame") or {}
        x, y, w, h = (f.get(k, 0) for k in ("x", "y", "width", "height"))
        t = n.get("type")
        labelled = bool(txt(n.get("AXLabel")) or txt(n.get("AXValue")))
        if t in INTERACTIVE and not labelled:
            flags.append(("unlabelled-interactive", d))
        if t == "Image" and not labelled:
            flags.append(("bare-image", d))
        if t == "StaticText" and ctl is not None and not txt(ctl.get("AXLabel")):
            flags.append(("bare-text-in-control", d))
        if w <= 0 or h <= 0:
            flags.append(("zero-size", d))
        elif sw and sh and (x >= sw or y >= sh or x + w <= 0 or y + h <= 0):
            flags.append(("offscreen", d))
        key = (t, txt(n.get("AXLabel")), txt(n.get("AXValue")), x, y, w, h)
        if key in seen:
            flags.append(("duplicate", d))
        seen.add(key)
    return lines, flags


def main(argv):
    args = argv[1:]
    screen = None
    if "--screen" in args:
        i = args.index("--screen")
        w, h = args[i + 1].lower().split("x")
        screen = (float(w), float(h))
        del args[i:i + 2]
    if not args:
        print(__doc__)
        return 0
    with open(args[0]) as fh:
        tree = json.load(fh)
    lines, flags = audit(tree, screen)
    print("\n".join(lines))
    for kind, d in flags:
        print("FLAG %s %s" % (kind, d))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
