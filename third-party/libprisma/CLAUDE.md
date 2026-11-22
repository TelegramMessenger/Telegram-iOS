# libprisma — agent notes

## `SyntaxHighlighterTests` and the recursion bound

The `brightscript` grammar in the shipped `grammars.dat` has a token cycle. Without a bound, highlighting such a block
recurses `tokenize()`/`matchGrammar()` until the process dies of a stack overflow, a remote DoS because a code block is
highlighted on receipt. `SyntaxHighlighter::kMaxTokenizeDepth` (128; ~1.1 KiB of stack per level) caps it and degrades
to plain text at the cap. Don't pull upstream `TelegramMessenger/libprisma` as a substitute for the cap: as of its HEAD `07ff1fcc` it has no
bound and its regenerated `grammars.dat` still ships the cycle.

`//third-party/libprisma:SyntaxHighlighterTests` pins the bound. It is a host `cc_test` (root `CLAUDE.md`, "Running
tests") that compiles only libprisma's pure-C++ core (not `Syntaxer.mm`, which needs UIKit) plus header-only
`boost_regex`, and loads the real shipped `grammars.dat` (passed via the target's
`args = ["$(location Resources/grammars.dat)"]`). Run it with
`./build-input/bazel-9.2.0-darwin-arm64 test //third-party/libprisma:SyntaxHighlighterTests --test_output=all`.
