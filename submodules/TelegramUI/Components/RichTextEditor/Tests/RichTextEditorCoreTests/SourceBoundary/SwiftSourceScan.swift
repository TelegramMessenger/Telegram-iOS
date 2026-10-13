import Foundation

/// Pure-text helpers the source-boundary suite uses to reason about Swift source without compiling it.
/// Deliberately naive (no real Swift parser) — good enough to find banned identifiers and function
/// bodies, NOT a substitute for the compiler. `stripCommentsAndStringLiterals` exists because this
/// codebase's own comments densely name the forbidden things (e.g. `+UITextInput.swift:262` explains
/// the `.zero` policy in prose), so a naive substring search over raw source is nearly all false
/// positives.
enum SwiftSourceScan {

    /// Removes `//` line comments, `/* */` block comments (nesting-aware, since Swift allows nested
    /// block comments), and `"…"` / `"""…"""` string literal contents — replacing their interiors with
    /// spaces so line/column positions in the surrounding source are preserved (a caller can still
    /// reason about line numbers from the stripped text).
    static func stripCommentsAndStringLiterals(_ source: String) -> String {
        var result = String()
        result.reserveCapacity(source.count)

        enum Mode {
            case normal
            case lineComment
            case blockComment(depth: Int)
            case stringLiteral(triple: Bool)
        }

        var mode: Mode = .normal
        let chars = Array(source)
        var i = 0
        let n = chars.count

        func emitBlank(_ c: Character) {
            result.append(c == "\n" ? "\n" : " ")
        }

        while i < n {
            let c = chars[i]
            switch mode {
            case .normal:
                if c == "/", i + 1 < n, chars[i + 1] == "/" {
                    mode = .lineComment
                    result.append(" "); result.append(" ")
                    i += 2
                    continue
                }
                if c == "/", i + 1 < n, chars[i + 1] == "*" {
                    mode = .blockComment(depth: 1)
                    result.append(" "); result.append(" ")
                    i += 2
                    continue
                }
                if c == "\"", i + 2 < n, chars[i + 1] == "\"", chars[i + 2] == "\"" {
                    mode = .stringLiteral(triple: true)
                    result.append("\""); result.append("\""); result.append("\"")
                    i += 3
                    continue
                }
                if c == "\"" {
                    mode = .stringLiteral(triple: false)
                    result.append("\"")
                    i += 1
                    continue
                }
                result.append(c)
                i += 1
            case .lineComment:
                if c == "\n" {
                    mode = .normal
                    result.append("\n")
                } else {
                    emitBlank(c)
                }
                i += 1
            case .blockComment(let depth):
                if c == "/", i + 1 < n, chars[i + 1] == "*" {
                    mode = .blockComment(depth: depth + 1)
                    emitBlank(c); emitBlank(chars[i + 1])
                    i += 2
                    continue
                }
                if c == "*", i + 1 < n, chars[i + 1] == "/" {
                    if depth <= 1 {
                        mode = .normal
                    } else {
                        mode = .blockComment(depth: depth - 1)
                    }
                    emitBlank(c); emitBlank(chars[i + 1])
                    i += 2
                    continue
                }
                emitBlank(c)
                i += 1
            case .stringLiteral(let triple):
                if c == "\\", i + 1 < n {
                    // Escape sequence: blank both characters, whatever the second one is.
                    emitBlank(c); emitBlank(chars[i + 1])
                    i += 2
                    continue
                }
                if triple {
                    if c == "\"", i + 2 < n, chars[i + 1] == "\"", chars[i + 2] == "\"" {
                        mode = .normal
                        result.append("\""); result.append("\""); result.append("\"")
                        i += 3
                        continue
                    }
                } else if c == "\"" {
                    mode = .normal
                    result.append("\"")
                    i += 1
                    continue
                } else if c == "\n" {
                    // An unterminated single-line string literal: bail back to normal at the newline
                    // rather than swallowing the rest of the file.
                    mode = .normal
                    result.append("\n")
                    i += 1
                    continue
                }
                emitBlank(c)
                i += 1
            }
        }
        return result
    }

    /// The assignment operator this file's write scans recognise: `=`, or one of Swift's compound
    /// assignment operators, NOT followed by another `=`.
    ///
    /// **The trailing `(?!=)` is a fix, not a flourish** (Task 40b fix round 1). It used to be
    /// `[^=]`, which requires a character AFTER the operator and therefore could not match a write
    /// whose right-hand side is on the NEXT LINE — and this codebase wraps aggressively at ~100
    /// columns, so `markedRange =`⏎`computeRange()` read as zero matches. That is the worst possible
    /// failure for a rule whose whole job is finding writes: in a file with no other match it leaves
    /// no dictionary key at all, i.e. a silent green. A lookahead matches at end-of-line and still
    /// rejects `==`, because the name must be immediately followed by `\s*<op>`, so there is only one
    /// alignment to try.
    ///
    /// The compound set is explicit rather than a character class, and each excluded neighbour was
    /// checked: `!=`, `<=`, `>=`, `==` cannot match (their first character is not in the set and the
    /// bare `=` branch would have to match that character instead), and a name used as an OPERAND
    /// (`x = anchor + 1`, `head ?? 0`) cannot match either, because after the operator the pattern
    /// demands `=` and finds a space.
    private static let assignmentOperator = #"\s*(?:[-+*/%&|^]|<<|>>|\?\?)?=(?!=)"#

    /// Counts WRITES to any of `names` in `source` (which should already be passed through
    /// `stripCommentsAndStringLiterals`). A write is an assignment to the bare name, to
    /// `self.<name>`, or to the name as an element of a destructuring tuple, at a position that is
    /// not a `.`-qualified member of some other object and not a `let`/`var` DECLARATION.
    ///
    /// This is R7's `test_exactlyOneWritableSelectionAuthority` scan, and it is the durable fix that
    /// the old `test_selectionWriteSiteBaseline_R7_doesNotRegress` deferred. D19's raw grep —
    /// `(^|[^.[:alnum:]_])(self\.)?(anchor|head)[[:space:]]*=[^=]` — cannot tell `anchor = 0` from
    /// `guard let anchor = map.anchor(…)`, so the old ratchet excluded two whole FILES by name and
    /// its own note recorded that as debt. Rejecting a candidate whose immediately preceding token is
    /// a `let`/`var` keyword is strictly narrower: a genuine write inside one of those files is now
    /// caught, where a filename exclusion could never see it.
    ///
    /// Counts SITES, not lines: `a = nil; b = nil` is two, and `(a, b) = (1, 2)` is two.
    ///
    /// # WHAT THIS CANNOT SEE — the complete list, so nobody credits the rule with more
    ///
    /// Four of these were measured by Task 40b's reviewer against the landed scan; two were fixed in
    /// the fix round and two are documented gaps. A fifth was added by Task 42's reviewer. **A future implementer who needs one closed should
    /// close it with a construction (plant the shape, watch the gate redden), not with a rewrite.**
    ///
    ///  1. **A `let`/`var` DECLARATION, including a type-scope stored property** (`var anchor = 0`).
    ///     Deliberate, and not a hole in practice: a re-introduced canvas-side store is caught
    ///     exactly, at runtime, by `SelectionAuthorityTests`' `Mirror` over a live
    ///     `DocumentCanvasView`. A text scan that tried to separate a type-scope stored property from
    ///     a local binding would need a real parser, and the wrong guess in either direction is worse
    ///     than the runtime check that already exists.
    ///  2. **A `.`-qualified write through another object** (`someView.markedRange = nil`). The
    ///     leading `[^.\w]` excludes it, exactly as D19's grep always did, because another object's
    ///     `.anchor` is not this rule's subject. For the SELECTION half this is closed by the
    ///     compiler (the projections are get-only); for the composition half it is open until Task 41
    ///     moves that state, and `test_theWriteDoorsIntoBackendOwnedInputStateAreEnumerated` closes the one
    ///     concrete instance that matters — the `canonicalSelectionStorage` downcast.
    ///  3. **A write reached through a computed alias or a function** (`selectionBox.pointee = …`).
    ///     Out of scope for any name-based scan.
    ///  4. **Multi-line tuple destructuring**, where the closing `)` and the `=` are on different
    ///     lines. The single-line form IS caught (see below); the scan is line-at-a-time, so a
    ///     wrapped one is not. Fixing it needs a statement joiner, which is a parser.
    ///  5. **A write to a MEMBER of a guarded name** (`floatingCursorPoint.y += delta`,
    ///     `markedRange?.location = 0`). Added TASK 42 FIX ROUND 1, review Minor 1, after that task's
    ///     own boundary comment credited the scan with catching exactly this shape. It does not: the
    ///     pattern requires the assignment operator to follow the NAME (modulo an optional `?`), and
    ///     here `.y` sits in between. Note this is NOT gap 2 — the qualification is on the RIGHT of
    ///     the guarded name, not the left, so the name really is this rule's subject and the write
    ///     really does mutate the guarded value. Deliberately left open: matching `NAME(\.\w+|\?)*`
    ///     before the operator would also start matching `a.b.c = …` chains whose head merely shares a
    ///     name, and the runtime `Mirror` checks in
    ///     `SelectionAuthorityTests`/`MarkedStateAuthorityTests`/`FloatingCursorStateAuthorityTests`
    ///     already catch the DECLARATION that any such write would need.
    ///
    /// FIXED in the fix round, listed because the shapes look like gaps and are not:
    ///  * **A wrapped right-hand side** (`anchor =`⏎`compute()`) — see `assignmentOperator`.
    ///  * **Compound assignment** (`anchor += 1`, `compositionUndoSnapshot? += [b]`) — same.
    ///  * **Single-line tuple destructuring** (`(anchor, head) = (1, 2)`) — the second scan below.
    ///    Unreachable for `anchor`/`head` today (get-only), reachable for the four composition names,
    ///    which is precisely the half Task 41 will be editing.
    ///
    /// # THE ONE RESIDUAL FALSE POSITIVE, which is the correct direction to err
    ///
    /// A LOCAL `var` that is declared and then reassigned — `var anchor = 0` … `anchor = 5` — has its
    /// reassignment reported as an offender: the declaration is skipped by rule 1, but the second
    /// line has no `let`/`var` before it and is indistinguishable from a write to the real property.
    /// `TableBlockBox.swift` already carries eight `let anchor = …` table-span bindings, so one of
    /// them becoming a reassigned `var` is a plausible future spurious red. **Do not read such a red
    /// as proof of a second authority — check the file first.** The fix is to rename the local (the
    /// precedent is `LegacyRichTextInputBackend+Mutation.swift`'s `currentAnchor`/`currentHead`), not
    /// to widen this scan: over-reporting a local is cheap, and under-reporting a real write is the
    /// failure this whole rule exists to prevent.
    static func inputStateWriteCount(in source: String, to names: [String]) -> Int {
        guard !names.isEmpty else { return 0 }
        let alternatives = names.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        // Group 1 = an optional `self.`; group 2 = the name itself (its range is what the
        // declaration check looks backwards from). The optional `?` admits `x? += y` on an Optional.
        let pattern = #"(?:^|[^.\w])(self\.)?("# + alternatives + #")\??"# + assignmentOperator
        // A destructuring assignment: a parenthesised list, with no nested parens, followed by an
        // assignment. Each guarded name INSIDE the list is one write site.
        let tuplePattern = #"\(([^()]*)\)"# + assignmentOperator
        let bareName = #"(?:^|[^.\w])("# + alternatives + #")(?![\w])"#
        guard let re = try? NSRegularExpression(pattern: pattern),
              let tupleRe = try? NSRegularExpression(pattern: tuplePattern),
              let bareRe = try? NSRegularExpression(pattern: bareName) else { return 0 }
        let declaration = try? NSRegularExpression(pattern: #"\b(let|var)\s*$"#)

        func isDeclaration(_ ns: NSString, nameStart: Int) -> Bool {
            guard let declaration else { return false }
            let prefix = ns.substring(to: nameStart)
            let prefixNS = prefix as NSString
            return declaration.firstMatch(in: prefix,
                                          range: NSRange(location: 0, length: prefixNS.length)) != nil
        }

        var total = 0
        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let text = String(line)
            let ns = text as NSString
            let whole = NSRange(location: 0, length: ns.length)
            for m in re.matches(in: text, range: whole) {
                // `self.x = …` is unambiguously a write; only a bare name can be a declaration.
                if m.range(at: 1).location != NSNotFound { total += 1; continue }
                if isDeclaration(ns, nameStart: m.range(at: 2).location) { continue }
                total += 1
            }
            // Destructuring. `let (a, b) = (anchor, head)` is not matched: the parenthesised group
            // holding the names is the one on the RIGHT, and it is not followed by an assignment.
            for m in tupleRe.matches(in: text, range: whole) {
                guard let inner = Range(m.range(at: 1), in: text) else { continue }
                if isDeclaration(ns, nameStart: m.range.location) { continue }   // `let (anchor, head) = …`
                let list = String(text[inner])
                let listNS = list as NSString
                total += bareRe.numberOfMatches(in: list,
                                                range: NSRange(location: 0, length: listNS.length))
            }
        }
        return total
    }

    /// Counts CALL SITES of any of `names` in `source` (already comment-stripped) — an occurrence of
    /// `name(` that is not a `func name(` DECLARATION and not a protocol requirement. Used by the
    /// boundary rules that give an enumerated-caller-set claim teeth: a doc comment saying "seven
    /// callers, read the contract before adding an eighth" is a wish; the same sentence with an exact
    /// per-file count behind it costs an eighth caller one edit to a constant, which is what "a
    /// decision, not a detail" is supposed to feel like.
    ///
    /// Counts SITES: two calls on one line is two. `.`-qualified receivers ARE counted here (unlike
    /// the write scan), because `target.inputBackend.setCanonicalAnchor(…)` is exactly as much a
    /// caller as the unqualified form — the subject is the callee, not the receiver.
    static func callSiteCount(in source: String, to names: [String]) -> Int {
        guard !names.isEmpty else { return 0 }
        let alternatives = names.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        guard let re = try? NSRegularExpression(
            pattern: #"(?<!\bfunc\s)(?<![\w])("# + alternatives + #")\s*\("#) else { return 0 }
        let ns = source as NSString
        return re.numberOfMatches(in: source, range: NSRange(location: 0, length: ns.length))
    }

    /// Counts CONSTRUCTION SITES of any of `names` — `Name(` **and** `Name.init(`, which
    /// `callSiteCount` cannot see because the `.` sits between the identifier and the paren.
    ///
    /// **This exists because `callSiteCount` was used for a construction rule and was EVADED.** Task
    /// 43 added `test_theTokenizerHasExactlyOneConstructionSite` on top of `callSiteCount`; Task 43's
    /// reviewer planted a live second construction site spelled `DocumentTokenizer.init(canvas:)` and
    /// the rule stayed GREEN. Worse, the same commit recommended that exact spelling as a mutation in
    /// a neighbouring test's doc comment, so the form a reader was pointed at was the invisible one.
    ///
    /// **IT IS STILL NOT A COMPLETE NET, AND MUST NOT BE SOLD AS ONE.** All five spellings below
    /// COMPILE (verified by planting them in a canvas file and building for the simulator, Task 43
    /// fix round 1) and only the first two match this pattern:
    ///
    /// | # | spelling | this scan | `identifierMentionCount` |
    /// | - | --- | --- | --- |
    /// | A | `Name(canvas: x)` | ✅ | ✅ 1 |
    /// | B | `Name.init(canvas: x)` | ✅ | ✅ 1 |
    /// | C | `[x].map(Name.init)` — bare metatype member, no paren after the name | ❌ | ✅ 1 |
    /// | D | `typealias T = Name` then `T(canvas: x)` | ❌ | ✅ 1, at the `typealias` |
    /// | E | `let m: Name.Type = Name.self; m.init(canvas: x)` | ❌ | ✅ 2, at the binding |
    ///
    /// So a construction rule wanting a real net pairs this with an EXACT `identifierMentionCount`
    /// allowance — every spelling leaves at least one identifier mention somewhere, even when the
    /// construction itself names nothing. That is the same two-rule shape R7b already uses for the
    /// backend stores (a precise named rule for the actionable message, a blunt mention cap for
    /// completeness).
    static func constructionSiteCount(in source: String, to names: [String]) -> Int {
        guard !names.isEmpty else { return 0 }
        let alternatives = names.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        guard let re = try? NSRegularExpression(
            pattern: #"(?<!\bfunc\s)(?<![\w])("# + alternatives + #")(?:\s*\.\s*init)?\s*\("#)
        else { return 0 }
        let ns = source as NSString
        return re.numberOfMatches(in: source, range: NSRange(location: 0, length: ns.length))
    }

    /// Counts every mention of any of `names` as an identifier in `source` (already comment-stripped),
    /// **including `.`-qualified ones**. Deliberately blunt: used for names that must not appear
    /// OUTSIDE their owning directory at all, where any mention — a read, a write, a downcast target —
    /// is the violation.
    ///
    /// **The lookbehind is `(?<![\w])`, NOT `(?<![\w.])`, and that difference is the whole point.**
    /// The shape this exists to catch is
    /// `(inputBackend as? LegacyRichTextInputBackend)?.canonicalSelectionStorage = …` — a
    /// `.`-qualified write, which is precisely what the write scan's `[^.\w]` prefix cannot see.
    /// Excluding a preceding `.` here would make this rule blind to its only subject.
    static func identifierMentionCount(in source: String, to names: [String]) -> Int {
        guard !names.isEmpty else { return 0 }
        let alternatives = names.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        guard let re = try? NSRegularExpression(pattern: #"(?<![\w])("# + alternatives + #")(?![\w])"#)
        else { return 0 }
        let ns = source as NSString
        return re.numberOfMatches(in: source, range: NSRange(location: 0, length: ns.length))
    }

    /// Brace-balanced extraction of every top-level `func` in `source` (which should already be passed
    /// through `stripCommentsAndStringLiterals`, so braces inside comments/strings can't unbalance the
    /// scan). Returns each function's name, 1-based line number of the `func` keyword, and the text
    /// between its outermost `{ }` (exclusive of the braces themselves).
    static func functionBodies(in source: String) -> [(name: String, line: Int, body: String)] {
        var results: [(name: String, line: Int, body: String)] = []
        let chars = Array(source)
        let n = chars.count

        // Precompute line number for any character index.
        var lineStarts: [Int] = [0]
        for (idx, c) in chars.enumerated() where c == "\n" {
            lineStarts.append(idx + 1)
        }
        func lineNumber(atIndex idx: Int) -> Int {
            var lo = 0, hi = lineStarts.count - 1, ans = 0
            while lo <= hi {
                let mid = (lo + hi) / 2
                if lineStarts[mid] <= idx { ans = mid; lo = mid + 1 } else { hi = mid - 1 }
            }
            return ans + 1
        }

        let funcPattern = try! NSRegularExpression(pattern: #"\bfunc\s+([A-Za-z_][A-Za-z0-9_]*)\s*[<(]"#)
        let nsSource = source as NSString
        let matches = funcPattern.matches(in: source, range: NSRange(location: 0, length: nsSource.length))

        for match in matches {
            guard let nameRange = Range(match.range(at: 1), in: source) else { continue }
            let name = String(source[nameRange])
            let funcKeywordIndex = match.range.location

            // Find the opening '(' of the parameter list, skipping a possible generic parameter list
            // `<...>` first.
            var i = match.range.location + match.range.length - 1
            if chars[i] == "<" {
                var depth = 1
                i += 1
                while i < n, depth > 0 {
                    if chars[i] == "<" { depth += 1 }
                    if chars[i] == ">" { depth -= 1 }
                    i += 1
                }
                // advance to the next '('
                while i < n, chars[i] != "(" { i += 1 }
            }
            guard i < n, chars[i] == "(" else { continue }

            // Balance the parameter-list parens.
            var parenDepth = 1
            i += 1
            while i < n, parenDepth > 0 {
                if chars[i] == "(" { parenDepth += 1 }
                if chars[i] == ")" { parenDepth -= 1 }
                i += 1
            }

            // Skip everything up to the first top-level '{' or ';'/newline-terminated protocol
            // requirement (no body — e.g. a protocol's `func foo()` with no braces). Also must not
            // cross another `func` keyword, which would mean this one has no body (a protocol
            // requirement).
            var braceIndex: Int? = nil
            var j = i
            while j < n {
                if chars[j] == "{" { braceIndex = j; break }
                // A statement terminator or the start of another declaration before any '{' means
                // this `func` has no body (protocol requirement, or a `->` return type not yet
                // reached — keep scanning through those).
                if chars[j] == "\n" {
                    // Peek ahead (skipping whitespace) — if the next non-whitespace token isn't part
                    // of a return-type/where-clause continuation, stop looking for a brace on this
                    // line. We conservatively keep scanning until EOF or a clearly unrelated keyword.
                }
                j += 1
            }
            guard let openBrace = braceIndex else { continue }

            var depth = 1
            var k = openBrace + 1
            while k < n, depth > 0 {
                if chars[k] == "{" { depth += 1 }
                if chars[k] == "}" { depth -= 1 }
                k += 1
            }
            let closeBrace = k - 1
            guard closeBrace > openBrace else { continue }

            let bodyRange = (openBrace + 1)..<closeBrace
            let body = String(chars[bodyRange])
            results.append((name: name, line: lineNumber(atIndex: funcKeywordIndex), body: body))
        }
        return results
    }

    /// Returns the union of member (func/var) names declared directly inside any of the named
    /// `protocols` in the file at `url`. Used by later boundary rules to check that a conformer only
    /// touches members a specific protocol actually vends.
    static func protocolMemberNames(in url: URL, protocols: [String]) -> Set<String> {
        guard let raw = try? String(contentsOf: url) else { return [] }
        let source = stripCommentsAndStringLiterals(raw)
        let chars = Array(source)
        let n = chars.count
        var names: Set<String> = []

        for protocolName in protocols {
            let pattern = "\\bprotocol\\s+" + NSRegularExpression.escapedPattern(for: protocolName) + #"\b[^{]*\{"#
            guard let re = try? NSRegularExpression(pattern: pattern) else { continue }
            let nsSource = source as NSString
            guard let match = re.firstMatch(in: source, range: NSRange(location: 0, length: nsSource.length)) else { continue }
            let openBrace = match.range.location + match.range.length - 1
            guard openBrace < n, chars[openBrace] == "{" else { continue }

            var depth = 1
            var k = openBrace + 1
            while k < n, depth > 0 {
                if chars[k] == "{" { depth += 1 }
                if chars[k] == "}" { depth -= 1 }
                k += 1
            }
            let body = String(chars[(openBrace + 1)..<max(openBrace + 1, k - 1)])

            let memberPattern = try! NSRegularExpression(
                pattern: #"\b(?:func|var|let)\s+([A-Za-z_][A-Za-z0-9_]*)"#)
            let nsBody = body as NSString
            for m in memberPattern.matches(in: body, range: NSRange(location: 0, length: nsBody.length)) {
                if let r = Range(m.range(at: 1), in: body) {
                    names.insert(String(body[r]))
                }
            }
        }
        return names
    }
}
