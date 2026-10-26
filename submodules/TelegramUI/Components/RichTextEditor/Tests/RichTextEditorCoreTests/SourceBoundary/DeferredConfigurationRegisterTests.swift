import XCTest

/// Global Constraints 7 and 8 of the first-shippable-milestone plan, enforced mechanically rather
/// than by convention.
///
/// Accept-and-store is the one member category permitted to answer a host call without doing
/// anything, so it is also the one category that could hide a genuine lie. Two rules keep it honest:
/// every such member lives in ONE file, and every one names the rung that will consume it. **A
/// member that cannot name a consuming rung is not configuration** — it belongs in answer-or-trap or
/// perform-or-trap instead.
///
/// Both rules are checked here because neither is visible at a call site. A `quoteStyle` setter that
/// silently discards its value looks identical to one whose value R7 will read; the marker is what
/// distinguishes them, and a test is what keeps the marker from rotting.
final class DeferredConfigurationRegisterTests: XCTestCase {

    private static let registerPath =
        "Sources/RichTextEngineEditor/RichTextEngineEditorView+DeferredConfiguration.swift"

    /// Every accept-and-store member, by the name a caller uses.
    private static let acceptAndStoreMembers = [
        "quoteStyle", "codeStyle", "mediaBlockStyle", "quoteCollapseIcons",
        "detailsChevronImage", "renderMetrics", "configureSelectionHandleView",
        "registerFormulaRenderer", "registerButtonIconProvider",
        "registerEmojiViewProvider", "registerMediaViewProvider",
        "registerChecklistMarkerViewProvider", "canPasteMedia", "onPasteMedia",
        "plainTextFragmentTransformer", "contextMenuItemsProvider",
        "onRequestTableStructuralMenu", "onRequestMediaControl",
    ]

    // `RepoLayout.packageRoot` already exists in this directory and is FOUR hops up; do not
    // re-derive it.
    private func source(at relativePath: String) throws -> String {
        try String(contentsOf: RepoLayout.packageRoot.appendingPathComponent(relativePath),
                   encoding: .utf8)
    }

    /// The half of the file that declares the MEMBERS, i.e. everything from the extension onward.
    ///
    /// Scanning the whole file does not work, and failing to notice that is how this test was wrong
    /// on its first run: `DeferredConfiguration`'s stored properties share their names with the
    /// extension's computed ones and appear FIRST, so a naive search matched the struct every time.
    /// The file's own doc comment also contains the literal string `// CONSUMED BY: R<n>` while
    /// explaining the rule, which made the first member pass against prose rather than a marker.
    private func memberSection(of register: String) throws -> String {
        guard let extensionStart = register.range(of: "extension RichTextEngineEditorView {") else {
            throw XCTSkip("the register has no `extension RichTextEngineEditorView` to scan")
        }
        return String(register[extensionStart.upperBound...])
    }

    func test_everyAcceptAndStoreMemberNamesTheRungThatWillConsumeIt() throws {
        let register = try memberSection(of: try source(at: Self.registerPath))
        for member in Self.acceptAndStoreMembers {
            // Match the DECLARATION, not an incidental mention inside the struct's storage.
            let declaration = register.range(of: "public var \(member)")
                ?? register.range(of: "public func \(member)")
            guard let declaration else {
                return XCTFail("\(member) is not declared in the register")
            }
            let preamble = String(register[register.startIndex..<declaration.lowerBound])
            // Two spellings, one rule: a member names the rung that will consume it, whether it
            // was deferred there from the start or RE-deferred there after a rung declined it.
            let consumed = preamble.range(of: "// CONSUMED BY: R", options: .backwards)
            let redeferred = preamble.range(of: "// RE-DEFERRED TO: R", options: .backwards)
            let marker: Range<String.Index>?
            switch (consumed, redeferred) {
            case let (c?, r?): marker = c.lowerBound > r.lowerBound ? c : r
            case let (c?, nil): marker = c
            case let (nil, r?): marker = r
            case (nil, nil): marker = nil
            }
            guard let marker else {
                return XCTFail("\(member) has no `// CONSUMED BY: R<n>` or `// RE-DEFERRED TO: R<n>` marker before it")
            }
            // The marker must belong to THIS member: nothing between it and the declaration may
            // itself be a declaration, or one member's marker would vouch for the next.
            let between = String(preamble[marker.upperBound...])
            XCTAssertFalse(between.contains("public var ") || between.contains("public func "),
                           "\(member)'s nearest CONSUMED BY marker belongs to an earlier member")
        }
    }

    func test_noAcceptAndStoreMemberIsDeclaredOutsideTheRegister() throws {
        let root = RepoLayout.packageRoot.appendingPathComponent("Sources/RichTextEngineEditor")
        let files = try FileManager.default.contentsOfDirectory(atPath: root.path)
            .filter { $0.hasSuffix(".swift") }
            .filter { !$0.hasSuffix("+DeferredConfiguration.swift") }
        XCTAssertFalse(files.isEmpty, "found no sibling sources to check — the scan is vacuous")
        for file in files {
            let text = try String(contentsOf: root.appendingPathComponent(file), encoding: .utf8)
            for member in Self.acceptAndStoreMembers {
                XCTAssertFalse(
                    text.contains("public var \(member)") || text.contains("public func \(member)"),
                    "\(member) is declared in \(file); accept-and-store members live only in the register")
            }
        }
    }
}
