import XCTest

/// A source guard, not a behaviour test — because the thing it defends against is a call site that
/// does not exist yet, and no behaviour test can catch that.
///
/// The anti-pattern: read `ChatTextInputState.inputText` (a DERIVED flat projection), mutate the copy,
/// and reconstruct a state from it. That round-trip goes through `chatInputContent(from:)`, which
/// cannot express a heading, list, quote, table or medium — so changing a few characters retypes every
/// block in the composer as a body paragraph. It shipped as two user-visible bugs before the
/// structural `replacingFlatRange` replaced the composer's writers.
///
/// If this fails on a file you just edited: you want `ChatTextInputState.replacingFlatRange(_:with:)`.
final class ComposerFlatRebuildGuardTests: XCTestCase {
    private static let scannedFiles = [
        "MentionChatInputContextPanelNode",
        "HashtagChatInputContextPanelNode",
        "CommandChatInputContextPanelNode",
        "CommandMenuChatInputContextPanelNode",
        "EmojisChatInputContextPanelNode",
        "ChatTextInputPanelNode"
    ]

    /// The one site carrying the shape but deliberately not converted, named rather than silently
    /// excluded — a guard that hides a hole is worse than no guard.
    ///
    /// `ChatTextInputPanelNode.toggleQuoteCollapse` converts a `.block` quote range into a
    /// `.collapsedBlock` placeholder and back. That is block-level surgery (the structural equivalent is
    /// flipping `ChatInputBlockQuote.collapsed`), not a text replace-range, so `replacingFlatRange`
    /// cannot express it.
    ///
    /// **It is also unreachable with structured content, so it flattens nothing in practice** (verified
    /// 2026-08-18, after an earlier version of this comment claimed otherwise). The closure is only ever
    /// invoked by the LEGACY `ChatInputTextNode`, from its `QuoteBackgroundView`; on the native node it
    /// is a stored property nothing calls, because the editor has its own `collapseQuoteRun` /
    /// `expandCollapsedQuote`. By the time a composer holds a heading it has latched to native, so the
    /// legacy path cannot be carrying structure to lose. Left exempt rather than converted: the shape is
    /// still here for the guard to see, and converting dead code earns nothing.
    private static let knownUnconvertedSites: Set<String> = [
        "ChatTextInputPanelNode.swift:toggleQuoteCollapse"
    ]

    private func source(named name: String) throws -> String {
        let url = try XCTUnwrap(Bundle(for: type(of: self)).url(forResource: name, withExtension: "swift"),
                                "\(name).swift is missing from the test bundle — check the BUILD `data` wiring")
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Every site matching the anti-pattern, keyed by the enclosing declaration so an exemption names a
    /// FUNCTION rather than a line number that drifts with every unrelated edit above it.
    ///
    /// ONE scanner, read by both tests below. Two copies of one scan is how an exemption ends up
    /// matching in the checker and not in the staleness check.
    private func offendingSites() throws -> [(site: String, line: Int)] {
        // A declaration is a `func`/`var`, or a closure assigned to a property (`x.onFoo = {`) — the
        // latter is how the panel installs most of its callbacks.
        let declarationPatterns = [
            #"(?:func|var) ([A-Za-z_][A-Za-z0-9_]*)"#,
            #"\.([A-Za-z_][A-Za-z0-9_]*) = \{"#
        ]
        var result: [(site: String, line: Int)] = []
        for name in Self.scannedFiles {
            let lines = try self.source(named: name).components(separatedBy: "\n")
            var declaration = "<top level>"
            for (index, line) in lines.enumerated() {
                for pattern in declarationPatterns {
                    guard let match = line.range(of: pattern, options: .regularExpression) else {
                        continue
                    }
                    let text = String(line[match])
                    if let captured = text.range(of: #"[A-Za-z_][A-Za-z0-9_]*(?= = \{)|(?<=func |var )[A-Za-z_][A-Za-z0-9_]*"#,
                                                 options: .regularExpression) {
                        declaration = String(text[captured])
                    }
                }
                // The tell is taking a MUTABLE copy of a live state's derived text. Read-only uses of
                // `.inputText` (length, substring, entity generation) are fine and stay.
                let mutatesDerivedText = line.contains("NSMutableAttributedString(attributedString:")
                    && line.contains(".inputText")
                let copiesDerivedText = line.contains(".inputText.mutableCopy()")
                if mutatesDerivedText || copiesDerivedText {
                    result.append((site: "\(name).swift:\(declaration)", line: index + 1))
                }
            }
        }
        return result
    }

    /// The scan is only meaningful if the files actually reached the bundle. Without this, a broken
    /// `data` wiring would make the guard vacuously green — the worst possible failure for a guard.
    func test_everyScannedFileIsPresent() throws {
        for name in Self.scannedFiles {
            XCTAssertFalse(try self.source(named: name).isEmpty, "\(name).swift is empty")
        }
    }

    func test_noComposerSiteRebuildsStateFromAMutatedInputText() throws {
        let offenders = try self.offendingSites()
            .filter { !Self.knownUnconvertedSites.contains($0.site) }
            .map { "\($0.site) (line \($0.line))" }
        XCTAssertEqual(offenders, [], """
            A composer site mutates a copy of the derived `inputText` and will reconstruct state from \
            it, flattening every heading / list / quote / table in the composer. \
            Use ChatTextInputState.replacingFlatRange(_:with:) instead.
            """)
    }

    /// Every exemption must still MATCH something. Otherwise a converted (or renamed) site leaves a
    /// stale entry behind that would silently absorb a genuinely new offender in the same function.
    func test_everyKnownExemptionStillMatchesASite() throws {
        let found = Set(try self.offendingSites().map(\.site))
        XCTAssertEqual(Self.knownUnconvertedSites.subtracting(found), [],
                       "a known-unconverted site no longer matches — delete its exemption")
    }
}
