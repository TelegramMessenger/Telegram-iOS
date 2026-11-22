import XCTest

/// A member the host can set and the editor never reads is a lie with a getter, and a geometry
/// constant nothing reads is a decision that never took effect.
///
/// Four defects in the R7-details increment were exactly this: the details chevron's tap,
/// `DetailsShape.titleBodyGap`, Tab in a title, and `tapBelowAddsTrailingParagraph` — the last one
/// stored, defaulted `false` where legacy defaults `true`, and read by nothing, so the one host that
/// wanted it lost it twice over.
///
/// `DeferredConfigurationRegisterTests` enforces something adjacent and useful — that such a member
/// NAMES the rung that will consume it — but it cannot catch these. Its member list is a
/// hand-maintained literal and it scans ONE file, so the host knobs in `+ComposerHost.swift` were
/// never in its scope at all. This one DISCOVERS members instead of listing them.
///
/// **What it does not prove.** A reader is a mention, not a call. `detailsChevron(at:)` had a reader
/// — a test — for the whole rung in which nothing in the app invoked it. The honest claim here is
/// "declared and never read", not "declared and never used"; catching the second needs a call-graph
/// check, which is recorded in the spec's §6 rather than implied by this test's name.
final class HostConfigurationConsumerTests: XCTestCase {

    private static let engineSources = "Sources/RichTextEngineEditor"

    private static let configurationFiles = [
        "RichTextEngineEditorView+DeferredConfiguration.swift",
        "RichTextEngineEditorView+ComposerHost.swift",
    ]

    /// Members with no consumer in `Sources/` ON PURPOSE. Every entry needs a REASON — an exemption
    /// without one is the omission this test exists to find, one level up.
    private static let writeOnlyByDesign: [String: String] = [
        "formulaRenderer":
            "R9-formulas. `insertFormula(latex:)` still traps, so there is no formula for a renderer "
            + "to draw yet. The register's `CONSUMED BY: R9` marker is the other half of this: that "
            + "one says a rung is named, this one says a reader exists — and until the rung lands "
            + "the honest answer is an exemption rather than a reader that does nothing.",
        "buttonIconProvider":
            "R9-buttons. `insertButtonRow()` and `makeSelectionInlineButton()` both trap, so no "
            + "button exists to ask for an icon. Same split as `formulaRenderer` above.",
        "syntaxHighlighter":
            "R9-syntax-highlighting, NOT YET. Master's code-block highlighting reached the shared "
            + "`RichTextEditor` protocol in the 2026-09-15 merge and both hosts register a "
            + "highlighter at construction, so the ENGINE editor must accept one — it just does not "
            + "colour code yet, and a block renders plain, which is what a host registering nothing "
            + "already gets in either editor. Storing it is honest; a reader that discarded the "
            + "tokens would not be.",
    ]

    // MARK: - The two rules

    func test_everyHostConfigurableMemberIsReadSomewhere() throws {
        let sources = try engineSourceFiles()
        var unread: [String] = []
        for file in Self.configurationFiles {
            let path = "\(Self.engineSources)/\(file)"
            for member in try declaredNames(in: path, pattern: #"public var (\w+)"#) {
                if let reason = Self.writeOnlyByDesign[member] {
                    XCTAssertFalse(reason.isEmpty, "\(member)'s exemption needs a reason")
                    continue
                }
                if !isRead(member, in: sources, declaredIn: path) { unread.append("\(member) (\(file))") }
            }
        }
        XCTAssertEqual(unread, [], "settable by a host, read by nothing in Sources/")
    }

    func test_everyShapeGeometryConstantIsReadSomewhere() throws {
        let sources = try engineSourceFiles()
        var unread: [String] = []
        let path = "\(Self.engineSources)/EngineBlockRole.swift"
        for constant in try declaredNames(in: path, pattern: #"public static let (\w+): CGFloat"#) {
            if !isRead(constant, in: sources, declaredIn: path) { unread.append(constant) }
        }
        XCTAssertEqual(unread, [], "declared on a shape, read by nothing in Sources/")
    }

    /// The instrument has to be able to find something, or a green run means nothing: a name that is
    /// declared and read nowhere must be reported.
    func test_theScanCanFindAnUnreadMember() throws {
        let sources = try engineSourceFiles()
        XCTAssertFalse(isRead("aMemberNoOneDeclaredOrRead", in: sources,
                              declaredIn: "\(Self.engineSources)/EngineBlockRole.swift"))
    }

    func test_theScanFindsMembersAtAll() throws {
        let members = try declaredNames(in: "\(Self.engineSources)/RichTextEngineEditorView+ComposerHost.swift",
                                        pattern: #"public var (\w+)"#)
        XCTAssertGreaterThan(members.count, 10, "the composer-host knobs are in scope")
        XCTAssertTrue(members.contains("tapBelowAddsTrailingParagraph"),
                      "the member whose absence of a consumer motivated this test")
    }

    // MARK: - Mechanics

    private func engineSourceFiles() throws -> [String: String] {
        let root = RepoLayout.packageRoot.appendingPathComponent(Self.engineSources)
        var files: [String: String] = [:]
        for name in try FileManager.default.contentsOfDirectory(atPath: root.path) where name.hasSuffix(".swift") {
            files["\(Self.engineSources)/\(name)"] =
                try String(contentsOf: root.appendingPathComponent(name), encoding: .utf8)
        }
        XCTAssertFalse(files.isEmpty, "found no engine sources — the scan would be vacuous")
        return files
    }

    private func declaredNames(in relativePath: String, pattern: String) throws -> [String] {
        let source = try String(contentsOf: RepoLayout.packageRoot.appendingPathComponent(relativePath),
                                encoding: .utf8)
        let regex = try NSRegularExpression(pattern: pattern)
        let whole = NSRange(source.startIndex..., in: source)
        return regex.matches(in: source, range: whole).compactMap { match in
            Range(match.range(at: 1), in: source).map { String(source[$0]) }
        }
    }

    /// Read = mentioned in a file OTHER than the one declaring it. The declaring file always mentions
    /// its own member (the declaration, and for a computed property its accessors), so counting that
    /// would make every member look read. A member used only inside its own file is rare enough to
    /// belong in the exemption list with a reason rather than to weaken the rule.
    private func isRead(_ name: String, in sources: [String: String], declaredIn path: String) -> Bool {
        sources.contains { file, contents in file != path && contents.contains(name) }
    }
}
