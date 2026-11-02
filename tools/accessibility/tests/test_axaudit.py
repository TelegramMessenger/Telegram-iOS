import json
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import axaudit  # noqa: E402

with open(os.path.join(HERE, "fixtures", "chatlist-before.json")) as fh:
    TREE = json.load(fh)
LINES, FLAGS = axaudit.audit(TREE, (402, 874))


def flags(kind):
    return [d for k, d in FLAGS if k == kind]


class AxAuditTests(unittest.TestCase):
    def test_flags_unlabelled_buttons(self):
        f = flags("unlabelled-interactive")
        self.assertTrue(any(d.startswith("Button") and d.endswith("16,64 55x44") for d in f), f)
        self.assertTrue(any(d.startswith("Button") and d.endswith("75,57 207x44") for d in f), f)

    def test_flags_offscreen_rows(self):
        f = flags("offscreen")
        self.assertTrue(any("Chat 9" in d and d.endswith("0,1455 402x76") for d in f), f)
        self.assertTrue(any("Chat 10" in d and d.endswith("402,293 402x76") for d in f), f)

    def test_flags_duplicates(self):
        f = flags("duplicate")
        self.assertTrue(any(d.startswith("Image") and d.endswith("40,791 48x48") for d in f), f)

    def test_ignores_scroll_bars(self):
        self.assertFalse([l for l in LINES if "scroll bar" in l.lower()])
        self.assertFalse([d for _, d in FLAGS if "scroll bar" in d.lower()])

    def test_labelled_row_not_flagged(self):
        self.assertTrue(any("Chat 1 |" in l for l in LINES))
        self.assertFalse([d for _, d in FLAGS if "Chat 1 |" in d])


if __name__ == "__main__":
    unittest.main()
