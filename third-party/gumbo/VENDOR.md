# gumbo (Telegram's fork)

gumbo-parser as litehtml bundles it (`litehtml/src/gumbo`, `litehtml/gumbo-include`), taken with twidget 80dad8c
(`third-party/twidget`, pristine commit `a70b21c5a4`, identical at twidget b5878f9) and moved here on 2026-10-16.
It parses for litehtml (`//third-party/twidget:litehtml_fork`) and for the native widget runtime
(`//submodules/TelegramUI/Components/MessageWidget/WidgetRuntime`).

**This is our fork** (the user, 2026-10-16). Edit it here; nothing is pulled from upstream. Each change gets a
numbered entry under "Changes": what changed, why, and the test that pins it. `git log --follow` reaches the
pristine files through the move; every change since is `git diff a70b21c5a4 -- third-party/gumbo` read across the
rename (`git diff -M a70b21c5a4 HEAD -- third-party/twidget/LiteHTML/litehtml/src/gumbo third-party/gumbo`).

## Layout

| path | what |
|---|---|
| `src/` | gumbo's C sources and private headers (`LICENSE`: Apache 2.0; `visualc/` is not compiled) |
| `include/` | `gumbo.h`, `gumbo/tag_enum.h` |
| `tests/html5lib/` | html5lib-tests `9329e64` (MIT, `LICENSE`): `tree-construction/*.dat`, the last revision before those tests moved to WPT |
| `tests/` | the host tests, the tree dumper they share, and the html5lib harness's reader and driver (`html5lib_dat.h`) |

## Bazel targets

| target | what |
|---|---|
| `:gumbo` | `cc_library`, `-O2` in every configuration |
| `:GumboHtml5libTests` | host `cc_test`: html5lib's tree-construction cases (below) |
| `:GumboForkTests` | host `cc_test`: the changes below |
| `:tree_dump` | testonly header library: `tests/tree_dump.h`, gumbo's tree in html5lib's format |
| `:html5lib_dat` | testonly header library: `tests/html5lib_dat.h`, the `.dat` reader, skip rule and counting driver that `:GumboHtml5libTests` and WidgetRuntime's `:WidgetRuntimeBuilderHtml5libTests` share |

## Tests

`GumboHtml5libTests` runs every html5lib tree-construction case with the default options and compares the tree
in html5lib's format. As forked: 1,747 pass, 31 fail and are listed in `tests/html5lib-expected-failures.txt`
(gaps that predate the fork), 14 are skipped (scripting on, or a fragment context gumbo has no tag for). Until M1b
Task 15 the harness counted 1,746 and 32: its reader took the one case with an empty `#data`
(`tests_innerHTML_1.dat:80`) for one whose data was the rest of its block, and listed it as a failure. A listed
case that starts passing fails the test until its line is removed, so the list only shrinks. A listed case that does
not run (a typo, a skipped case) fails it too, and so does a file that cannot be read or gives no case, or a total
other than 1,792 cases in 57 files.

## Changes

Changes 1-8 landed together on 2026-10-16 so that a parse is linear in its input and bounded in memory; before them
eight input classes were quadratic (a ninth, the growing list of active formatting elements, is change 10) (4x the input took 12-20x the time; table in the commit). Each limit is a
`GumboOptions` field, `-1` for none, and its default is the widget runtime's, which litehtml (parsing with
`kGumboDefaultOptions`) shares. Within the limits nothing changed: identical html5lib verdicts, byte-identical
trees for the widget corpus and twidget's chats (336 documents), ASan clean. `tests/fork_test.cpp`
(`:GumboForkTests`) pins each one, and each was reverted on its own once to see its test fail.

1. **The tree is freed without recursion.** `destroy_node` (`src/parser.c`) keeps an explicit stack. It recursed
   once per level, so freeing a tree deeper than the thread's stack crashed: 100,000 nested `<span>`s on a
   512 KiB stack (`testDeepTreeIsFreedWithoutRecursion`; SIGBUS before).
2. **An element knows whether it is open.** `GumboElement.is_open`, kept by `open_elements_push`, `_insert_at`,
   `_remove_at`, `_remove`, `_replace_at` and `pop_current_node`, which are now the only writers of the stack
   of open elements. `is_open_element` scanned the stack, so reconstructing the active formatting elements cost
   O(depth) per entry (`testOpenElementsAreTrackedThroughTheAdoptionAgency`, html5lib `tests1.dat:18`, which
   the adoption agency's in-place replacement broke while it bypassed the helpers; and the timing class
   "reconstruction at the depth limit", ~70x a plain document without the flag).
3. **`max_tree_depth`, default 512.** A start tag that arrives while the stack holds that many elements is ignored
   as a parse error; reconstructing the active formatting elements stops there. Every scan of the stack (the
   scope checks, foster parenting, the adoption agency) is then bounded. Past the limit the tree differs from the
   spec's: the ignored tags' text lands in the deepest element, and their end tags are ignored or close an outer
   element of the same name. The widget runtime drops content deeper than 256 levels anyway (`testDepthLimit`,
   `testReconstructionStopsAtTheDepthLimit`).
4. **`max_attributes`, default 256** (widget-sandbox's `MAX_ATTRIBUTES`). `finish_attribute_name`
   (`src/tokenizer.c`) drops later attributes exactly as it drops a duplicate. The first 256 distinct survive,
   which is what dropping after deduplication keeps. The duplicate check was O(attributes) per attribute
   (`testAttributeLimit`).
5. **The Noah's Ark clause compares attribute-set hashes first.** `GumboElement.attributes_hash`, an
   order-independent sum of per-attribute hashes, is set in `add_formatting_element` (clones copy it). The full
   comparison runs only when the hashes match. It was O(attributes²) per pair of formatting elements (`testNoahsArkClause` for the
   semantics; the timing class "formatting with 256 attributes").
6. **`max_nodes`, default 100,000.** Parsing stops as at the end of the input once that many nodes exist, after
   the token in hand; `GumboOutput.stopped_at_node_limit` reports it. Reconstructing formatting elements made
   O(n²) nodes from O(n) markup (`<div><b a=N></div>` repeated: 5 M nodes from 64 KiB) (`testNodeLimit`).
7. **A fragment's document has a quirks mode.** `new_document_node` sets `GUMBO_DOCTYPE_NO_QUIRKS`; the fragment
   parser never runs the initial insertion mode that set it, so it was uninitialized memory
   (`testFragmentDocumentHasAQuirksMode`, with an allocator that fills memory).
8. **`max_errors` defaults to 0.** Every parser error copied the whole stack of open elements: 256 KiB of
   `<ul><li>` made 65,282 errors and a 277 MB peak (2.9 MB without), and at the end of a deep document one error
   per unclosed element made it quadratic. Nothing here reads the errors (`testParseErrorsAreNotRecordedByDefault`).
9. **A dropped attribute name without a value resets the tag buffer.** A duplicate name (or one past
   `max_attributes`) with no `=value` left its name in the tag buffer, because the reset sat in
   `add_duplicate_attr_error` after an early return taken when errors are not recorded (change 8 made that the
   default). The next name was appended to it: `<p disabled disabled class=c>` gave `disabled` and
   `disabledclass="c"`, `<p o o nclick=y>` gave `onclick`. `finish_attribute_name` now resets in both drop
   branches (`testDroppedNamesDoNotLeakIntoTheNextAttribute`, with errors off and on).
10. **`max_formatting_elements`, default 512.** Entries of the list of active formatting elements after its last
   marker were unbounded when distinct, and every formatting start tag walks the list twice (reconstruction's
   rewind, the Noah's Ark count). Adding one past the limit removes the earliest entry after the marker, as the
   Noah's Ark clause removes the earliest identical one. 509 `<div>`s then `<b a=N></div><div>` repeated took
   0.013 s at 64 KiB and 0.2 s at 256 KiB (39x plain), 0.78 s at 512 KiB; now linear
   (`testFormattingListLimit`, the timing class "growing list of formatting elements").
11. **A tag name read back from its source text ends where the tag name state ends it.** `gumbo_tag_from_original_text`
   (`src/tag.c`) stopped a start tag's name at space, tab, LF, FF and `/` but not CR, while the tokenizer reads a CR
   as LF (the source text is not newline-normalized), and took an end tag's name as everything between `</` and `>`.
   Both now stop at the same terminators, CR included. With CRLF line ends and an attribute on the next line
   (`<svg\r\n width=16>`) the name kept the CR: SVG case adjustment missed (`lineargradient\r`), names a client
   derives from the source kept it (`svg\r`, `my-el\r`), and the foreign-content end-tag match compares these names,
   so `</svg>` did not close the `<svg>` and the rest of the document went inside it. Likewise a line break before an
   end tag's `>` (`</g\n>`, `</g\r\n>`) left the foreign element open. Found by the widget runtime's review
   (`testTagNamesFromSourceTextEndAtCR`, `testEndTagNamesFromSourceTextEndAtWhitespace`: each tree equals the one
   without the line break).

12. **`max_total_attributes`, default -1 (no limit).** Parsing stops (as at the end of the input) once the elements
   the tree keeps hold this many attributes in all; `GumboOutput.stopped_at_attribute_limit` reports it, next to
   `stopped_at_node_limit`. Attributes are not nodes, so `max_nodes` does not bound them: `<p` + 256 attributes +
   `>` repeated grows the tree's attribute count without bound (52.5 B of transient heap per input byte, a 220 MB
   peak at 4 MiB) while its node count stays tiny. `_attribute_count` counts where the tree keeps attributes — the
   token-to-element ownership transfer (`create_element_from_token`), the reconstruction clone (`clone_node`) and
   the `<html>`/`<body>` merge (`merge_attributes`) — and is checked in the main loop exactly as `max_nodes` is,
   at a token boundary. Because `clone_node` keeps the element's attributes, the overshoot past the cap is much larger
   than `max_nodes`' (entry 6, "the token in hand"): one character that reconstructs the active formatting elements can
   clone up to `max_formatting_elements` (512) elements of up to `max_attributes` (256) attributes each before the
   check fires. A reprocessed token is handled again before the check, and one can reconstruct twice: a tag arriving
   after table text flushes the text with foster parenting (a reconstruction), and an `<a>` reprocessed in the table
   runs the adoption agency, which pops those clones, then reconstructs them again (`<div><a ...><b ...>...</div>`
   `<table>x<a>` with 508 entries makes 1,017 clones in that one iteration). So the overshoot is up to
   2 x 512 + 32 (the adoption agency's) clones. The widget runtime sets 100,000; litehtml (`kGumboDefaultOptions`)
   keeps -1 (`testTotalAttributeLimit`).
13. **`max_total_attribute_bytes`, default -1 (no limit).** Parsing stops (as at the end of the input) once the
   attribute strings the tree keeps hold this many bytes: each name and value copy, `strlen + 1` as
   `gumbo_copy_stringz` and `gumbo_string_buffer_to_string` allocate them. It **shares change 12's flag**,
   `stopped_at_attribute_limit` (a client acts the same on either). Change 12 counts attributes, but `clone_node`
   deep-copies every attribute's name and value, so a long-valued `<b>` left in the active formatting list is copied
   once per reconstruction: `<div><b a="<16 KiB>"></div>` + `<p>x</p>` x 30,000 is a 256 KB document that kept
   486 MB of copies with only `max_nodes` stopping it (the final review's probe; 113 KB of fragment markup kept
   252 MB). The bytes are counted at the same three keep sites as change 12 (`create_element_from_token`,
   `clone_node`, `merge_attributes`); the only other places that allocate attribute strings are the tokenizer and
   `adjust_{foreign,svg,mathml}_attributes`, which all work on the token before an element takes it, so the
   transfer's `strlen` counts the final name. Counted only while the limit is on (no `strlen` otherwise), and checked
   in the main loop at a token boundary like `max_nodes`. One token can therefore overshoot: the adoption agency
   clones the formatting element up to 8 times (its outer loop) and up to 3 inner nodes per iteration, and
   reconstruction clones each popped entry once, so one token copies one start tag's attribute bytes at most 9 times
   (`<a href="<3 MiB>">` + 8 `<div>` + `<a>`: the final `<a>` alone copies the 3 MiB value 8 times). On the
   two-reconstruction path in entry 12 an entry is copied at most twice, and a randomized search of 800,000 shapes
   found no token copying one value more than 8 times. The widget runtime sets 8 MiB; litehtml keeps -1
   (`testTotalAttributeBytesLimit`).

`testPathologicalInputsParseInLinearTime` holds the classes together: each at 64 KiB and 256 KiB, 4x the input in
at most 8x the time and at most 25x a plain document's (measured: at most 4.3x and 3.1x).
