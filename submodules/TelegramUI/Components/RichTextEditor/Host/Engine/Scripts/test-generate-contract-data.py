#!/usr/bin/env python3
"""Non-vacuous check of the class renames: decode the emitted bytes and inspect the manifest."""
import json, re, subprocess, sys, tempfile, pathlib

SRC = "PrivateUIKit/Contracts/UIKitBehaviorContracts-iOS26.5.json"
LAYOUT = "TGRichTextInputDecLayoutController"
WITNESS = "TGRichTextInputDecCanvasABIWitness"

def decoded(path):
    text = pathlib.Path(path).read_text()
    body = text.split("TGRichTextInputDecContractBytes[] = {", 1)[1].split("};", 1)[0]
    data = bytes(int(b, 16) for b in re.findall(r"0x([0-9a-f]{2})", body))
    return json.loads(data.decode("utf-8"))

def main():
    out = pathlib.Path(tempfile.mkdtemp()) / "TGRichTextInputDecContractData.m"
    subprocess.run(["Scripts/generate-contract-data.py", SRC, str(out)], check=True)
    m = decoded(out)

    rows = [r for cap in m["capabilities"].values() for r in cap["members"]]
    assert len(rows) == 127, "capability member count changed: %d" % len(rows)
    assert [r for r in rows if r["class"] == LAYOUT].__len__() == 47, "47 incomingCallbacks rows"
    assert [r for r in rows if r["class"] == WITNESS].__len__() == 3, "3 canvas rows"
    for bad in ("IDRichTextLayoutController", "IDBlockTextView"):
        assert not [r for r in rows if r["class"] == bad], "un-renamed row: " + bad
    assert m["referenceOnly"] == {}, "referenceOnly must be emptied, not deleted"
    assert "referenceOnly" in m, "the key itself must survive (manifest parser demands it)"
    assert len(m["forbidden"]) == 8, "the forbidden deny-list must travel intact"
    assert m["runtime"] == {"osVersion": "26.5", "osBuild": "23F73"}

    # Reproducibility: two runs must be byte-identical.
    out2 = pathlib.Path(tempfile.mkdtemp()) / "again.m"
    subprocess.run(["Scripts/generate-contract-data.py", SRC, str(out2)], check=True)
    assert out.read_bytes() == out2.read_bytes(), "codegen is not deterministic"
    print("contract codegen OK")

if __name__ == "__main__":
    main()
