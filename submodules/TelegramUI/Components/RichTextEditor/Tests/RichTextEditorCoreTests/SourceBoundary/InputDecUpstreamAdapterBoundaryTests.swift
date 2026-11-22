import XCTest

/// **PRODUCTION MUST NOT MOVE — pinned mechanically, not by convention.**
///
/// Phase 1 of the InputDec port took the ported engine out of the shipped app entirely, and verified
/// it two ways: `bazel query 'somepath(//Telegram:Telegram, //…:RichTextInputDecUpstream)'` returns
/// `INFO: Empty results`, and `nm` over the app binary finds **0** `IDBlockTextView` symbols, down
/// from 299. The reason is not tidiness: `IDBlockTextView.m` has a `+load` that runs before `main()`
/// on every launch for every user, resolves a private UIKit protocol by name, and `@throw`s an
/// UNCAUGHT `NSException` if that fails. Nothing pre-`main` can guard it and no feature flag can turn
/// it off.
///
/// Phase 2 added an adapter that must `import RichTextInputDecUpstream`; phase 3 added a third file
/// to it (`IDUpstreamInputBackend+Responder.swift`). It therefore lives in a
/// directory that Bazel's `RichTextEditorUIKit` glob EXCLUDES, while SwiftPM's same-named target
/// (test-only here — Bazel builds the app) carries the dependency and compiles it.
///
/// **That divergence is exactly the shape this repo has been bitten by** — "a file missing from a
/// target's `srcs` silently does not exist" — so it gets a rule instead of a comment. The four
/// assertions below are each one half of the arrangement; if any single one is edited away, the
/// arrangement stops being what its comments say it is:
///
///  1. the Bazel exclude is present, and names the adapter directory;
///  2. the Bazel target still has NO `deps` edge to `:RichTextInputDecUpstream`;
///  3. the SwiftPM target DOES depend on it (otherwise the adapter is compiled by nothing at all,
///     and "excluded from the app build" would quietly mean "excluded from every build");
///  4. the excluded directory actually holds Swift files (anti-vacuity), and nothing OUTSIDE it
///     names the adapter type — which is what keeps the app build compiling with those files absent.
final class InputDecUpstreamAdapterBoundaryTests: XCTestCase {

    /// The one place the adapter's location is spelled. Every assertion below is derived from it.
    private static let adapterDirectory = "Sources/RichTextEditorUIKit/InputBackend/InputDec/Upstream"

    private static let upstreamModule = "RichTextInputDecUpstream"

    /// The modules that exist ONLY as SwiftPM targets, deliberately (Global Constraint 7). Both
    /// import `RichTextInputDecUpstream` unconditionally, so a Bazel target for either is a Bazel
    /// path for the ported engine into the shipped app. See rule 5 below.
    private static let modulesWithNoBazelTarget = ["RichTextInputDecHost", "RichTextEngineEditor"]

    /// Every `name = "…"` in a comment-stripped Starlark file. Naive on purpose, same reasoning as
    /// `richTextEditorUIKitBazelBlock()`: answering "is a target with this name declared here" does
    /// not need a Starlark parser, and `test_theTargetNameScanFindsPlantedTargets` exercises it
    /// against planted fixtures so it cannot rot into a rule that matches nothing.
    /// Every name declared by a `.target(` in a SwiftPM manifest — the first `name:` argument after
    /// each `.target(`. `.testTarget(` does not contain the literal `.target(`, so test targets are
    /// not collected; a `.target(name:condition:)` DEPENDENCY reference is, which only ever adds
    /// names and so cannot make the assertions above pass when a declaration is missing.
    private static func swiftPMTargetNames(in text: String) -> Set<String> {
        var names: Set<String> = []
        var remainder = Substring(text)
        while let marker = remainder.range(of: ".target(") {
            let tail = remainder[marker.upperBound...]
            if let nameMarker = tail.range(of: "name: \""),
               let closing = tail[nameMarker.upperBound...].firstIndex(of: "\"") {
                names.insert(String(tail[nameMarker.upperBound..<closing]))
            }
            remainder = tail
        }
        return names
    }

    private static func targetNames(in text: String) -> Set<String> {
        var names: Set<String> = []
        var remainder = Substring(text)
        while let marker = remainder.range(of: "name = \"") {
            let tail = remainder[marker.upperBound...]
            if let closing = tail.firstIndex(of: "\"") {
                names.insert(String(tail[..<closing]))
            }
            remainder = remainder[marker.upperBound...]
        }
        return names
    }

    private func buildFile() throws -> String {
        RepoLayout.assertResolved()
        return try String(contentsOf: RepoLayout.packageRoot.appendingPathComponent("BUILD"))
    }

    private func packageFile() throws -> String {
        RepoLayout.assertResolved()
        return try String(contentsOf: RepoLayout.packageRoot.appendingPathComponent("Package.swift"))
    }

    /// The `swift_library(name = "RichTextEditorUIKit", … )` block, from its `swift_library(` line to
    /// the first `)` at column zero. Naive on purpose — the same reasoning as `SwiftSourceScan`'s: a
    /// real Starlark parser is not needed to answer "does this block contain this string", and the
    /// non-vacuity assertions below fail loudly if the extraction ever stops finding the block.
    ///
    /// **Comments are stripped first**, for the same reason `SwiftSourceScan` strips them: this
    /// repo's BUILD files explain their invariants in prose that names the very things these rules
    /// forbid (`BUILD`'s deps comment opens "NO EDGE TO :RichTextInputDecUpstream"), so a rule reading
    /// raw text is a rule reading documentation. It also removes a real hazard from the backward walk
    /// below — a `swift_library(` inside a comment.
    private func richTextEditorUIKitBazelBlock() throws -> String {
        let text = Self.stripStarlarkComments(try buildFile())
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let nameIndex = lines.firstIndex(where: {
            $0.contains("name = \"RichTextEditorUIKit\"")
        }) else {
            XCTFail("no swift_library named RichTextEditorUIKit in BUILD")
            return ""
        }
        var start = nameIndex
        while start > 0, !lines[start].hasPrefix("swift_library(") { start -= 1 }
        var end = nameIndex
        while end < lines.count, lines[end] != ")" { end += 1 }
        return lines[start...min(end, lines.count - 1)].joined(separator: "\n")
    }

    /// 1 — the exclude exists and names the adapter directory.
    func test_theBazelGlobExcludesTheUpstreamAdapterDirectory() throws {
        let block = try richTextEditorUIKitBazelBlock()
        XCTAssertTrue(block.contains("swift_library("),
                      "the block extraction found nothing — every assertion here would be vacuous")
        XCTAssertTrue(block.contains("exclude = ["),
                      "BUILD's RichTextEditorUIKit srcs glob has no exclude list; the adapter under "
                      + "\(Self.adapterDirectory) would be compiled into the app, which puts "
                      + "IDBlockTextView's pre-main +load back in every launch")
        XCTAssertTrue(block.contains("\"\(Self.adapterDirectory)/**/*.swift\""),
                      "the exclude no longer names \(Self.adapterDirectory)")
    }

    /// 2 — the app-build dependency edge is still absent.
    ///
    /// **THIS IS THE ONE RULE STANDING BETWEEN THE REPO AND A PRE-`main` `+load` IN EVERY LAUNCH**, so
    /// its detection is a pure function over text (`depsListMentionsPortedEngine(in:)`) that
    /// `test_theDepsRuleCatchesBothLabelForms` exercises against planted fixtures. The first version
    /// of this rule searched for the literal `":RichTextInputDecUpstream"` — with the opening quote
    /// adjacent to the colon — and therefore matched only the SHORT label form. A fully-qualified
    /// label, `"//submodules/TelegramUI/Components/RichTextEditor:RichTextInputDecUpstream"`, would
    /// have added the forbidden edge and passed. That is not a theoretical spelling: the same `deps`
    /// list already writes `"//submodules/AppBundle"` and `"//submodules/MosaicLayout:MosaicLayout"`,
    /// so the repo's own convention is the form that walked straight through the guard.
    func test_theBazelTargetHasNoDependencyOnThePortedEngine() throws {
        let block = try richTextEditorUIKitBazelBlock()
        // Anti-vacuity: the extraction must actually be looking at a populated deps list, or a `nil`
        // result below would mean "found nothing to read" rather than "found no edge".
        let deps = try XCTUnwrap(Self.depsList(in: block),
                                 "BUILD's RichTextEditorUIKit has no readable deps list")
        XCTAssertTrue(deps.contains("RichTextEditorCore") && deps.contains("MosaicLayout"),
                      "the deps slice does not contain the entries it is known to have — the "
                      + "extraction is broken and this rule would pass vacuously: \(deps)")
        XCTAssertFalse(Self.depsListMentionsPortedEngine(in: block),
                       "BUILD's RichTextEditorUIKit now depends on \(Self.upstreamModule). That puts "
                       + "the ported engine in the shipped app and runs IDBlockTextView's pre-main "
                       + "+load on every launch. If that is intended, it is a decision to record, not "
                       + "a line to add: see the note in BUILD's deps.")
    }

    /// The positive half of rule 2, and the reason rule 2 is written as a pure function.
    ///
    /// Fixtures spell `example()`, never `func test_…`, per this suite's own R14 convention (a
    /// synthetic fixture with an XCTest-shaped name inflates grep-based test counts).
    ///
    /// The two non-detections are as load-bearing as the two detections. Bazel `deps` lists in this
    /// repo carry prose that NAMES the forbidden target — `BUILD`'s own deps comment opens "NO EDGE TO
    /// :RichTextInputDecUpstream, DELIBERATELY" — so a rule that searched raw text would be red on the
    /// very file it is protecting, and the natural "fix" for that is to re-anchor the search on a
    /// quote, which is exactly the hole this test exists to close. Stripping `#` comments is what lets
    /// the search be unanchored.
    func test_theDepsRuleCatchesBothLabelForms() {
        func example(_ depsBody: String) -> String {
            """
            swift_library(
                name = "RichTextEditorUIKit",
                srcs = glob(["Sources/**/*.swift"]),
                deps = [
            \(depsBody)
                ],
                visibility = ["//visibility:public"],
            )
            """
        }

        // DETECTED — the short label form.
        XCTAssertTrue(Self.depsListMentionsPortedEngine(
            in: example("        \":RichTextInputDecUpstream\",")))

        // DETECTED — THE F1 CASE: the fully-qualified form, which the first version of this rule
        // could not see, spelled exactly the way the neighbouring MosaicLayout entry is spelled.
        XCTAssertTrue(Self.depsListMentionsPortedEngine(in: example(
            "        \"//submodules/TelegramUI/Components/RichTextEditor:RichTextInputDecUpstream\",")))

        // DETECTED — a single-quoted label, which Starlark also accepts.
        XCTAssertTrue(Self.depsListMentionsPortedEngine(
            in: example("        '//submodules/TelegramUI/Components/RichTextEditor:RichTextInputDecUpstream',")))

        // NOT DETECTED — a clean deps list.
        XCTAssertFalse(Self.depsListMentionsPortedEngine(in: example(
            "        \":RichTextEditorCore\",\n        \"//submodules/MosaicLayout:MosaicLayout\",")))

        // NOT DETECTED — the target named only in PROSE inside deps. This is the real BUILD's shape.
        XCTAssertFalse(Self.depsListMentionsPortedEngine(in: example(
            "        # NO EDGE TO :RichTextInputDecUpstream, DELIBERATELY.\n        \":RichTextEditorCore\",")))

        // NOT DETECTED — named AFTER the deps list closes. The slice must end at its own `]`.
        XCTAssertFalse(Self.depsListMentionsPortedEngine(in: """
            swift_library(
                name = "RichTextEditorUIKit",
                deps = [
                    ":RichTextEditorCore",
                ],
                data = ["//x:RichTextInputDecUpstream"],
            )
            """))
    }

    /// Starlark comment stripping: everything from an unquoted `#` to end of line becomes spaces, so
    /// line structure (and therefore every other rule in this file) is preserved. Naive on the same
    /// terms as `SwiftSourceScan.stripCommentsAndStringLiterals` — enough to tell code from prose,
    /// not a Starlark parser.
    static func stripStarlarkComments(_ source: String) -> String {
        var out = ""
        out.reserveCapacity(source.count)
        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            var quote: Character? = nil
            var escaped = false
            var cut = line.endIndex
            var index = line.startIndex
            while index < line.endIndex {
                let character = line[index]
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if let open = quote {
                    if character == open { quote = nil }
                } else if character == "\"" || character == "'" {
                    quote = character
                } else if character == "#" {
                    cut = index
                    break
                }
                index = line.index(after: index)
            }
            out += line[line.startIndex..<cut]
            out += "\n"
        }
        return out
    }

    /// The `deps = [ … ]` body of `block`, comments stripped, bounded at its OWN closing bracket.
    static func depsList(in block: String) -> String? {
        let code = stripStarlarkComments(block)
        guard let start = code.range(of: "deps = [") else { return nil }
        var depth = 1
        var index = start.upperBound
        while index < code.endIndex {
            let character = code[index]
            if character == "[" { depth += 1 }
            if character == "]" {
                depth -= 1
                if depth == 0 { return String(code[start.upperBound..<index]) }
            }
            index = code.index(after: index)
        }
        return nil
    }

    /// **UNANCHORED on purpose.** Any mention of the module name inside the comment-stripped deps
    /// body is an edge, whatever label form spells it. Anchoring on a quote is what let the
    /// fully-qualified form through.
    static func depsListMentionsPortedEngine(in block: String) -> Bool {
        guard let deps = depsList(in: block) else { return false }
        return deps.contains(upstreamModule)
    }

    /// 3 — SwiftPM does carry the edge, so the adapter is compiled by SOMETHING.
    func test_theSwiftPMTargetDoesDependOnThePortedEngine() throws {
        let text = try packageFile()
        guard let targetRange = text.range(of: "name: \"RichTextEditorUIKit\", dependencies: [") else {
            return XCTFail("Package.swift no longer declares RichTextEditorUIKit the way this rule reads it")
        }
        let tail = String(text[targetRange.upperBound...])
        guard let closing = tail.range(of: "]") else {
            return XCTFail("could not find the end of RichTextEditorUIKit's dependency list")
        }
        let dependencies = String(tail[..<closing.lowerBound])
        XCTAssertTrue(dependencies.contains("\"\(Self.upstreamModule)\""),
                      "Package.swift's RichTextEditorUIKit no longer depends on \(Self.upstreamModule). "
                      + "Combined with the Bazel exclude, the adapter would be compiled by NOTHING — "
                      + "the exact 'a file absent from a target's srcs does not exist' failure this "
                      + "rule exists for. Its tests would still pass, because the test target has its "
                      + "own edge.")
    }

    /// 5 — **the two engine-editor modules have NO Bazel target at all.**
    ///
    /// Rules 1-4 pin `RichTextEditorUIKit`'s own arrangement, which is the only way the ported
    /// engine could reach the app *through that target*. It is not the only way it could reach the
    /// app. `RichTextInputDecHost` and `RichTextEngineEditor` both `import
    /// RichTextInputDecUpstream` unconditionally — they exist to drive it — and both are SwiftPM
    /// targets with no Bazel counterpart. The moment either one gains a `swift_library` /
    /// `objc_library` in this BUILD file, the engine is linkable into the shipped app again and
    /// `IDBlockTextView.m`'s `+load` runs before `main()` on every launch for every user, throwing
    /// an uncaught `NSException` on four separate resolution paths. Nothing pre-`main` can guard it
    /// and no feature flag can turn it off.
    ///
    /// Adding a target here would not fail any other rule in this file: rule 2 only reads
    /// `RichTextEditorUIKit`'s own `deps`, and a brand-new target's `deps` are nowhere in its scope.
    /// So this rule reads the BUILD file's target NAMES directly. It is deliberately about
    /// EXISTENCE, not about edges — a target with no dependents today is one `deps` line away from
    /// being in the app, and that line would be reviewed as a one-word change.
    ///
    /// Both names are checked against a comment-stripped BUILD file, for the same reason rule 2 is:
    /// `Package.swift` and `BUILD` both explain this arrangement in prose that names these very
    /// modules.
    /// Every `.m` under the port that declares a `+load`, by port-relative path.
    ///
    /// A helper rather than inline logic so the scan itself can be gate-tested against a fixture
    /// (`test_theLoadScanFindsAPlantedLoadMethod`). A scan that finds no files also finds no
    /// `+load`, and would pass this file's real assertion while proving nothing.
    private func loadMethodOffenders(under root: URL) throws -> [String] {
        guard let walker = FileManager.default.enumerator(atPath: root.path) else { return [] }
        var offenders: [String] = []
        for case let path as String in walker where path.hasSuffix(".m") {
            guard !path.hasPrefix("Generated/") else { continue }
            let text = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            if text.contains("+ (void)load") { offenders.append(path) }
        }
        return offenders.sorted()
    }

    /// THE INVARIANT THAT REPLACED "these modules may have no Bazel target".
    ///
    /// Until 2026-08-28 this file asserted that neither engine-editor module could appear in
    /// `BUILD`, because `IDBlockTextView.m`'s `+load` ran before `main()` and could `@throw`
    /// uncaught — linking the engine would have crashed every launch for every user. That
    /// assertion was a PROXY for the real requirement: the engine must not run code before
    /// `main()`.
    ///
    /// Upstream `442f395` moved the keyboard-input install into the initializer's `@try`, so the
    /// proxy is obsolete and the modules are now legitimately linked. This checks the real thing
    /// directly. A re-port that reintroduced a `+load` would put uncatchable pre-`main()` code back
    /// into the shipped binary, and this is what would notice.
    func test_thePortContainsNoLoadMethod() throws {
        let root = RepoLayout.packageRoot.appendingPathComponent("Sources/\(Self.upstreamModule)")
        let offenders = try loadMethodOffenders(under: root)
        XCTAssertEqual(offenders, [],
                       "the ported engine declares +load in: \(offenders). That code runs before "
                       + "main() and cannot be gated by any runtime flag, so it must not exist in a "
                       + "module the app links. Move the work into an initializer, as 442f395 did.")
    }

    /// The scan's own positive control — see `loadMethodOffenders(under:)`.
    func test_theLoadScanFindsAPlantedLoadMethod() throws {
        let fixture = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LoadScanFixture-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: fixture, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: fixture) }
        try "@implementation X\n+ (void)load { }\n@end\n"
            .write(to: fixture.appendingPathComponent("Planted.m"), atomically: true, encoding: .utf8)
        try "@implementation Y\n@end\n"
            .write(to: fixture.appendingPathComponent("Clean.m"), atomically: true, encoding: .utf8)
        XCTAssertEqual(try loadMethodOffenders(under: fixture), ["Planted.m"],
                       "the +load scan cannot see a planted +load, so the rule above proves nothing")
    }

    /// The engine-editor modules are now expected to BE Bazel targets — the inverse of what this
    /// file asserted before `442f395`. Kept as an explicit assertion rather than deleted, so that
    /// losing the edge again is a failure rather than a silent return to an untested state.
    func test_theEngineEditorModulesAreBazelTargets() throws {
        let text = Self.stripStarlarkComments(try buildFile())
        let names = Self.targetNames(in: text)
        // Anti-vacuity: the extraction must find the targets BUILD is known to declare, or the
        // assertions below would be checking an empty set.
        XCTAssertTrue(names.contains("RichTextEditorCore") && names.contains("RichTextEditorUIKit")
                      && names.contains(Self.upstreamModule),
                      "the target-name extraction did not find the targets BUILD is known to "
                      + "declare — this rule would pass vacuously: \(names.sorted())")
        for module in Self.modulesWithNoBazelTarget {
            XCTAssertTrue(names.contains(module),
                          "BUILD no longer declares a target named \(module). The engine editor "
                          + "reaches the app through these targets; without them the Debug Settings "
                          + "flag selects a backend that is not in the binary.")
        }
    }

    func test_theEngineEditorModulesAreStillSwiftPMTargets() throws {
        let names = Self.swiftPMTargetNames(in: try packageFile())
        // Anti-vacuity: the extraction must find the targets the package is known to declare.
        XCTAssertTrue(names.contains("RichTextEditorCore") && names.contains("RichTextEditorUIKit"),
                      "the .target( scan did not find the targets Package.swift is known to declare "
                      + "— this rule would pass vacuously: \(names.sorted())")
        for module in Self.modulesWithNoBazelTarget {
            XCTAssertTrue(names.contains(module),
                          "Package.swift no longer declares a target named \(module); with no Bazel "
                          + "target either, it would be compiled by nothing at all")
        }
    }

    /// The positive half of rule 5, so the name extraction is a pure function with a planted
    /// control. Fixtures spell `example()`, never `func test_…`, per this suite's R14 convention.
    ///
    /// The two non-detections matter as much as the detections: a `name = ` inside a *nested* rule
    /// argument list is still a target name for this purpose (Starlark has no nesting that matters
    /// here), but a name that merely appears in prose must not count, or the rule would be red on
    /// the very file it protects.
    func test_theTargetNameScanFindsPlantedTargets() {
        let planted = """
            swift_library(
                name = "RichTextEditorUIKit",
                srcs = ["a.swift"],
            )

            objc_library(
                name = "RichTextInputDecHost",
                srcs = ["b.m"],
            )
            """
        let names = Self.targetNames(in: planted)
        XCTAssertTrue(names.contains("RichTextEditorUIKit"))
        XCTAssertTrue(names.contains("RichTextInputDecHost"),
                      "the scan missed a planted objc_library — rule 5 would not detect the real one")
        XCTAssertFalse(names.contains("RichTextEngineEditor"))

        // A module named only in prose is not a target. `stripStarlarkComments` removes it before
        // the scan ever runs; this pins that the scan itself does not match bare mentions either.
        let prose = "# name = \"RichTextEngineEditor\" must never appear as a target\nsrcs = []"
        XCTAssertFalse(Self.targetNames(in: Self.stripStarlarkComments(prose)).contains("RichTextEngineEditor"))
    }

    /// 4a — anti-vacuity: the excluded directory holds real Swift.
    func test_theExcludedDirectoryHoldsTheAdapter() {
        RepoLayout.assertResolved()
        let directory = RepoLayout.packageRoot.appendingPathComponent(Self.adapterDirectory)
        let files = RepoLayout.swiftFiles(under: directory).map(\.lastPathComponent).sorted()
        XCTAssertEqual(files, ["IDUpstreamInputBackend+Responder.swift",
                               "IDUpstreamInputBackend+Unwitnessed.swift",
                               "IDUpstreamInputBackend.swift"],
                       "the excluded directory's contents changed; every assertion in this file is "
                       + "about what lives there, so the change wants a look: \(files)")
    }

    /// 4b — nothing outside the excluded directory names the adapter. This is what makes the app
    /// build compile with those files simply absent: a reference from an included file would be an
    /// `unresolved identifier` under Bazel and compile fine under SwiftPM, i.e. a break visible only
    /// in the app build.
    func test_nothingOutsideTheExcludedDirectoryNamesTheAdapter() throws {
        RepoLayout.assertResolved()
        let excluded = RepoLayout.packageRoot.appendingPathComponent(Self.adapterDirectory).path
        var offenders: [String] = []
        for url in RepoLayout.swiftFiles(under: RepoLayout.uiKitSources)
        where !url.path.hasPrefix(excluded) {
            let text = SwiftSourceScan.stripCommentsAndStringLiterals(try String(contentsOf: url))
            if SwiftSourceScan.identifierMentionCount(in: text, to: ["IDUpstreamInputBackend"]) > 0 {
                offenders.append(url.lastPathComponent)
            }
            if text.contains("import \(Self.upstreamModule)") {
                offenders.append("\(url.lastPathComponent) (imports \(Self.upstreamModule))")
            }
        }
        XCTAssertEqual(offenders, [],
                       "these files are in the APP build and reach for the excluded adapter or its "
                       + "module — the app build would fail to compile: \(offenders)")
    }

    /// 5 — **PHASE 2 CONSUMES NONE OF THE 54 CLIENT-SIDE REQUIREMENTS, as a property of the SOURCE.**
    ///
    /// `IDUpstreamInputBackendTests.test_theAdapterConsumesNoClientSideRequirement` asserts the same
    /// thing at runtime, by driving a full attach/type/detach cycle against six recording fakes and
    /// requiring their shared log to stay empty. That is the better evidence for what the adapter
    /// DOES — but it is not a complete net, and the gap is measurable rather than theoretical: the
    /// six fakes carry **31** `log.record` sites across **47** protocol members, so 16 client members
    /// — `RichTextInputLifecycleClient.editPolicy` among them — can be read without leaving an entry.
    ///
    /// ```
    /// $ grep -roh 'log\.record' Tests/…/Fakes/FakeInput{Document,Geometry,Annotation,Presentation,Lifecycle,Command}Client.swift | wc -l
    /// 31          # 5 / 8 / 2 / 5 / 9 / 2
    /// ```
    ///
    /// **This number was written as 33 in the first draft and it was wrong** — the ninth instance in
    /// this programme of a count asserted without re-deriving it. `grep -c 'log.record'` leaves `.`
    /// unescaped and counts LINES, so two prose lines were folded in. The `-oh` form above counts
    /// occurrences of the literal. The conclusion is unchanged and slightly stronger: 31 of 47 is a
    /// bigger blind spot than 33 of 47, so the static rule below is more necessary, not less.
    ///
    /// This half closes that gap from the other side. The adapter cannot consume a client requirement
    /// it never names, and the six accessor names are the ONLY way through `RichTextInputHost` to
    /// reach one. Together the two rules say: not on any path a test walked, and not on any path at
    /// all.
    func test_theAdapterNamesNoClientSideRequirement() throws {
        RepoLayout.assertResolved()
        let directory = RepoLayout.packageRoot.appendingPathComponent(Self.adapterDirectory)
        let clientAccessors = ["documentClient", "geometryClient", "annotationClient",
                               "presentationClient", "lifecycleClient", "commandClient"]
        let clientProtocols = ["RichTextInputDocumentClient", "RichTextInputGeometryClient",
                               "RichTextInputAnnotationClient", "RichTextInputPresentationClient",
                               "RichTextInputLifecycleClient", "RichTextInputCommandClient"]
        var offenders: [String] = []
        let files = RepoLayout.swiftFiles(under: directory)
        XCTAssertFalse(files.isEmpty, "no adapter sources found — this rule would pass vacuously")
        for url in files {
            let text = SwiftSourceScan.stripCommentsAndStringLiterals(try String(contentsOf: url))
            for name in clientAccessors + clientProtocols
            where SwiftSourceScan.identifierMentionCount(in: text, to: [name]) > 0 {
                offenders.append("\(url.lastPathComponent): \(name)")
            }
        }
        XCTAssertEqual(offenders, [],
                       "the phase-2 adapter reaches a client-side requirement: \(offenders). Phase 2 "
                       + "implements a subset of the BACKEND-side requirements and consumes NONE of the "
                       + "54 client-side ones — the InputDec host owns its own drawing, selection "
                       + "chrome and geometry until phase 8.")
    }

    // MARK: - 6 (PHASE 3b) — the implemented/unwitnessed partition is DERIVED, not restated

    /// **THE ONE PLACE THE COUNTS LIVE** (phase 3 review, Minor 7) **and the mechanical reconciliation
    /// of the unwitnessed enumeration to the member list** (Minor 9). Both findings have the same
    /// answer, which is why they are one rule.
    ///
    /// # Minor 7 — a count restated in five places
    ///
    /// The implemented/unimplemented split used to appear as a per-protocol table in
    /// `IDUpstreamInputBackend+Unwitnessed.swift`'s header, again in `IDUpstreamInputBackend.swift`'s
    /// header, again in the runtime message EVERY unimplemented member emits ("29 of 87 requirements
    /// are"), and again inside a TEST'S NAME (`test_allFiftyEightUnimplementedRequirementsReport`) —
    /// against this repo's own rule-15 note that *"a count restated in three places is how four
    /// consecutive tasks on this branch each lost a fix round"*. Every one of those moves each phase.
    /// They are gone; this rule derives them from the source, and prose that needs a number cites this
    /// rule.
    ///
    /// # Minor 9 — nothing mechanically reconciled the two lists
    ///
    /// `IDUpstreamInputBackendTests`' enumeration and `+Unwitnessed.swift`'s member list were both
    /// hand-maintained, and `XCTAssertEqual(count, 60)` cannot catch a dropped member paired with a
    /// duplicated one. The partition below is computed from the declarations themselves, so a member
    /// that is in NEITHER half (added to the protocol and forgotten) and a member in BOTH (implemented
    /// while a stale unwitnessed stub survives — which would report a contract violation on a member
    /// that works, or shadow one that does not) are each a named failure.
    ///
    /// **Signatures, not bare names.** A scan keyed on names collapses the six `UITextInput` overloads
    /// (`position(from:offset:)` vs `position(from:in:offset:)`, `characterRange(at:)` vs
    /// `characterRange(byExtending:in:)`, …) and reported 83/29/55 with a spurious overlap when phase 3
    /// first tried it. The extractor below builds Swift's own `name(label:label:)` spelling.
    func test_everyDeclaredRequirementIsEitherImplementedOrLoud() throws {
        RepoLayout.assertResolved()

        let contract = RepoLayout.inputBackend.appendingPathComponent("RichTextInputBackend.swift")
        let declared = try Self.protocolSignatures(
            in: contract,
            protocols: ["RichTextInputTextBackend", "RichTextKeyInputBackend",
                        "RichTextInputResponderBackend", "RichTextInputInteractionBackend",
                        "RichTextInputCheckingBackend", "RichTextInputBackend"])
        XCTAssertFalse(declared.isEmpty, "no protocol members parsed — this rule would pass VACUOUSLY")

        let directory = RepoLayout.packageRoot.appendingPathComponent(Self.adapterDirectory)
        var declaringFiles: [String: [String]] = [:]
        for url in RepoLayout.swiftFiles(under: directory) {
            for signature in try Self.declaredSignatures(in: url) {
                declaringFiles[signature, default: []].append(url.lastPathComponent)
            }
        }

        let unwitnessedFile = "IDUpstreamInputBackend+Unwitnessed.swift"
        var implemented: [String] = []
        var unwitnessed: [String] = []
        var missing: [String] = []
        var ambiguous: [String] = []
        for signature in declared.sorted() {
            let files = declaringFiles[signature] ?? []
            switch files.count {
            case 0: missing.append(signature)
            case 1: (files[0] == unwitnessedFile ? { unwitnessed.append(signature) }
                                                 : { implemented.append(signature) })()
            default: ambiguous.append("\(signature) declared in \(files.sorted())")
            }
        }

        XCTAssertEqual(missing, [],
                       "these requirements are declared on the contract and appear in NEITHER half of "
                       + "the adapter — the compiler catches this only because the adapter conforms, "
                       + "so if you see it here the scan has broken: \(missing)")
        XCTAssertEqual(ambiguous, [],
                       "a requirement is declared TWICE in the adapter. If one of the two is a stale "
                       + "+Unwitnessed.swift stub, it either reports a contract violation on a member "
                       + "that works or shadows one that does not: \(ambiguous)")

        // THE NUMBERS. Phase 3b took the declared count from 87 to 89 (the responder hand-off pair)
        // and the implemented count from 29 to 31; the 58 unwitnessed did not move, because a member
        // that lets the host stop having a responder transition gives the adapter nothing honest to
        // say about one it should not be having (see `responderLifecycleReason`).
        XCTAssertEqual(declared.count, 89, "the contract's member count moved")
        XCTAssertEqual(implemented.count, 31, "the implemented count moved: \(implemented)")
        XCTAssertEqual(unwitnessed.count, 58, "the unwitnessed count moved: \(unwitnessed)")
        XCTAssertEqual(implemented.count + unwitnessed.count, declared.count)
    }

    /// The runtime enumeration in `IDUpstreamInputBackendTests` must call EVERY unwitnessed member —
    /// the half `XCTAssertEqual(count, 60)` cannot check, because a dropped member paired with a
    /// duplicated one leaves the count intact.
    ///
    /// # FIX ROUND 1 — this rule shipped with two holes of its own, and one of them was measured
    ///
    /// A guard added to close a gap had a gap. Both are closed here, and `uncoveredNames(_:in:)` is
    /// factored out so `test_theEnumerationCoverageScanActuallyDetects` can drive THE SAME code
    /// against synthetic fixtures rather than a second, drifting copy of it.
    ///
    ///  1. **It scanned the whole test FILE, not the enumeration.** Five unwitnessed names were
    ///     satisfied from outside it — `position` (from unrelated setup lines) and all four
    ///     `notifying…` brackets (from `test_theNotifyingBracketsStillRunTheirBody`, which is the one
    ///     family `+Unwitnessed.swift` singles out as NOT no-op'ing). Deleting any of those five from
    ///     the enumeration left the rule green: exactly the defect it was written to catch. The scan
    ///     is now sliced to the enumeration function's own balanced body.
    ///  2. **`contains` had no trailing boundary**, so a longer sibling satisfied a shorter name:
    ///     `isComposing` by `isComposingPrediction`, `notifyingSelectionChange` by
    ///     `notifyingSelectionChangeIgnoringCoalescing`. The match now requires the next character
    ///     after the name to be a non-identifier one.
    ///
    /// Matched on the member NAME rather than the full signature, because the enumeration's call sites
    /// spell arguments rather than labels (`backend.position(from: position, in: .right, offset: 1)`).
    /// That is weaker than the signature-level partition above and is stated rather than glossed: it
    /// would not notice one overload of a name being called twice while its sibling was dropped. It
    /// does notice a whole member disappearing, which is the failure this closes.
    func test_theRuntimeEnumerationCallsEveryUnwitnessedRequirement() throws {
        RepoLayout.assertResolved()
        // Intersected with the CONTRACT's own declarations, not taken from the file wholesale: the
        // file also declares its private `unwitnessed(_:_:)` helper, which is not a requirement and
        // has no call site in the enumeration by design.
        let contract = RepoLayout.inputBackend.appendingPathComponent("RichTextInputBackend.swift")
        let declared = try Self.protocolSignatures(
            in: contract,
            protocols: ["RichTextInputTextBackend", "RichTextKeyInputBackend",
                        "RichTextInputResponderBackend", "RichTextInputInteractionBackend",
                        "RichTextInputCheckingBackend", "RichTextInputBackend"])
        let directory = RepoLayout.packageRoot.appendingPathComponent(Self.adapterDirectory)
        let unwitnessedURL = directory.appendingPathComponent("IDUpstreamInputBackend+Unwitnessed.swift")
        let names = Set(try Self.declaredSignatures(in: unwitnessedURL)
            .intersection(declared)
            .map { String($0.prefix(while: { $0 != "(" })) })
        XCTAssertGreaterThan(names.count, 50,
                             "only \(names.count) unwitnessed member names parsed — vacuous")

        let suite = RepoLayout.packageRoot.appendingPathComponent(
            "Tests/RichTextEditorUIKitTests/InputDec/Upstream/IDUpstreamInputBackendTests.swift")
        let file = SwiftSourceScan.stripCommentsAndStringLiterals(try String(contentsOf: suite))
        let enumeration = Self.balancedBodyOfFunction(named: Self.enumerationTestName, in: file)
        let body = try XCTUnwrap(enumeration,
                                 "could not find `\(Self.enumerationTestName)`'s body in "
                                 + "IDUpstreamInputBackendTests.swift — the enumeration was renamed, "
                                 + "and this rule must be repointed rather than left scanning nothing")
        // Anti-vacuity for the SLICE itself: the whole file is ~3× the enumeration, so a slice that
        // silently collapsed to the empty string, or that quietly grew back to the whole file, would
        // make this rule either always-red or as weak as the version being fixed.
        XCTAssertGreaterThan(body.count, 3_000, "the enumeration slice is implausibly short")
        XCTAssertLessThan(body.count, file.count / 2, "the enumeration slice is the whole file again")

        let uncalled = Self.uncoveredNames(names, in: body).sorted()
        XCTAssertEqual(uncalled, [],
                       "these unwitnessed requirements are never driven by the runtime enumeration, "
                       + "so nothing proves they report rather than answering plausibly: \(uncalled)")
    }

    /// The name of the enumeration this rule reconciles against. One spelling, so a rename is one
    /// edit and the `XCTUnwrap` above turns a missed rename into a named failure rather than silence.
    private static let enumerationTestName = "test_everyUnimplementedRequirementReports"

    /// Which of `names` is NOT called as `backend.<name>` in `body`, with an identifier boundary so a
    /// longer sibling cannot satisfy a shorter name. Pure, so the self-test below drives this exact
    /// code.
    static func uncoveredNames(_ names: Set<String>, in body: String) -> [String] {
        names.filter { name in
            let needle = "backend." + name
            var searchStart = body.startIndex
            while let found = body.range(of: needle, range: searchStart..<body.endIndex) {
                let next = found.upperBound
                if next == body.endIndex { return false }
                let character = body[next]
                if !(character.isLetter || character.isNumber || character == "_") { return false }
                searchStart = next
            }
            return true
        }
    }

    /// The balanced body of `func <name>(` in already-stripped Swift, or `nil`.
    static func balancedBodyOfFunction(named name: String, in stripped: String) -> String? {
        guard let declaration = stripped.range(of: "func " + name + "(") else { return nil }
        guard let open = stripped[declaration.upperBound...].firstIndex(of: "{") else { return nil }
        var depth = 0
        var index = open
        while index < stripped.endIndex {
            if stripped[index] == "{" { depth += 1 }
            if stripped[index] == "}" {
                depth -= 1
                if depth == 0 { return String(stripped[stripped.index(after: open)..<index]) }
            }
            index = stripped.index(after: index)
        }
        return nil
    }

    /// **THE NEGATIVE HALF of the rule above** — it is a guard that was shipped unable to fail, so it
    /// does not get to be trusted on its author's word a second time. Both fix-round holes and the
    /// original defect are driven through the SAME `uncoveredNames(_:in:)` the rule uses.
    ///
    /// Fixtures spell `example()`, never `func test_…`, per this suite's R14 convention (a synthetic
    /// fixture spelling an XCTest-shaped name inflates any grep-based count taken over the real tree).
    func test_theEnumerationCoverageScanActuallyDetects() {
        let names: Set<String> = ["unmarkText", "isComposing", "isComposingPrediction",
                                  "notifyingSelectionChange", "notifyingSelectionChangeIgnoringCoalescing"]

        // Must NOT fire: every name genuinely called.
        let complete = """
        backend.unmarkText()
        _ = backend.isComposing
        _ = backend.isComposingPrediction
        backend.notifyingSelectionChange {}
        backend.notifyingSelectionChangeIgnoringCoalescing {}
        """
        XCTAssertEqual(Self.uncoveredNames(names, in: complete).sorted(), [])

        // THE ORIGINAL DEFECT — a member dropped from the enumeration.
        XCTAssertEqual(
            Self.uncoveredNames(names, in: complete.replacingOccurrences(
                of: "backend.unmarkText()\n", with: "")).sorted(),
            ["unmarkText"],
            "a dropped enumeration entry must be named — this is the failure Minor 9 was about")

        // HOLE (2) — a longer sibling must not satisfy a shorter name.
        let onlyTheLongOnes = """
        backend.unmarkText()
        _ = backend.isComposingPrediction
        backend.notifyingSelectionChangeIgnoringCoalescing {}
        """
        XCTAssertEqual(Self.uncoveredNames(names, in: onlyTheLongOnes).sorted(),
                       ["isComposing", "notifyingSelectionChange"],
                       "`contains` with no trailing boundary let isComposingPrediction stand in for "
                       + "isComposing, and the coalescing variant for its base — both must be caught")

        // HOLE (1) — the slice. A call OUTSIDE the enumeration must not satisfy the rule, which is
        // enforced by scanning the function's own body; here that is the slicer's own check.
        let file = """
        func example() {
            backend.unmarkText()
        }
        func exampleElsewhere() {
            backend.isComposing
        }
        """
        let sliced = Self.balancedBodyOfFunction(named: "example", in: file)
        XCTAssertNotNil(sliced)
        XCTAssertEqual(Self.uncoveredNames(["unmarkText", "isComposing"], in: sliced ?? "").sorted(),
                       ["isComposing"],
                       "the slice must stop at the enumeration's own closing brace — a call in a "
                       + "SIBLING test is exactly how five names were satisfied from outside it")
        XCTAssertNil(Self.balancedBodyOfFunction(named: "exampleMissing", in: file),
                     "a renamed enumeration must be nil, not an empty body that covers nothing")
    }

    // MARK: - Signature extraction

    /// `name(label:label:)` for a `func`, bare `name` for a `var` — Swift's own spelling, so the six
    /// `UITextInput` overloads stay distinct.
    private static func signature(name: String, parameters: String?) -> String {
        guard let parameters else { return name }
        var labels: [String] = []
        var depth = 0
        var current = ""
        func flush() {
            let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            current = ""
            guard !trimmed.isEmpty else { return }
            // Everything before the first top-level `:` is `label name`, `name`, or `_ name`.
            var head = trimmed
            var innerDepth = 0
            for (offset, character) in trimmed.enumerated() {
                if "([<".contains(character) { innerDepth += 1 }
                else if ")]>".contains(character) { innerDepth -= 1 }
                else if character == ":", innerDepth == 0 {
                    head = String(trimmed.prefix(offset)); break
                }
            }
            let tokens = head.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" })
            labels.append(tokens.first.map(String.init) ?? "_")
        }
        for character in parameters {
            if "([<".contains(character) { depth += 1 }
            if ")]>".contains(character) { depth -= 1 }
            if character == ",", depth == 0 { flush(); continue }
            current.append(character)
        }
        flush()
        return "\(name)(\(labels.map { "\($0):" }.joined()))"
    }

    /// Every `func`/`var` declared directly inside the named protocols' bodies.
    private static func protocolSignatures(in url: URL, protocols: [String]) throws -> Set<String> {
        let source = SwiftSourceScan.stripCommentsAndStringLiterals(try String(contentsOf: url))
        var found: Set<String> = []
        for name in protocols {
            guard let bodyStart = source.range(of: "protocol \(name)")?.upperBound,
                  let open = source[bodyStart...].firstIndex(of: "{") else { continue }
            var depth = 0
            var index = open
            var close = open
            while index < source.endIndex {
                if source[index] == "{" { depth += 1 }
                if source[index] == "}" { depth -= 1; if depth == 0 { close = index; break } }
                index = source.index(after: index)
            }
            found.formUnion(declarations(in: String(source[source.index(after: open)..<close])))
        }
        return found
    }

    private static func declaredSignatures(in url: URL) throws -> Set<String> {
        declarations(in: SwiftSourceScan.stripCommentsAndStringLiterals(try String(contentsOf: url)))
    }

    /// Declarations in already-stripped Swift. Deliberately depth-agnostic: a nested type that
    /// declared the SAME signature would surface as an `ambiguous` failure above rather than being
    /// silently absorbed, which is the safe direction.
    private static func declarations(in stripped: String) -> Set<String> {
        var found: Set<String> = []
        var index = stripped.startIndex
        while index < stripped.endIndex {
            let isFunc = stripped[index...].hasPrefix("func ")
            let isVar = stripped[index...].hasPrefix("var ")
            guard isFunc || isVar else { index = stripped.index(after: index); continue }
            // `func`/`var` must start a token, not end an identifier (`overfunc `).
            if index > stripped.startIndex {
                let previous = stripped[stripped.index(before: index)]
                if previous.isLetter || previous.isNumber || previous == "_" {
                    index = stripped.index(after: index); continue
                }
            }
            var cursor = stripped.index(index, offsetBy: isFunc ? 5 : 4)
            while cursor < stripped.endIndex, stripped[cursor] == " " {
                cursor = stripped.index(after: cursor)
            }
            let name = String(stripped[cursor...].prefix { $0.isLetter || $0.isNumber || $0 == "_" })
            guard !name.isEmpty else { index = stripped.index(after: index); continue }
            cursor = stripped.index(cursor, offsetBy: name.count)
            if isVar {
                found.insert(name)
                index = cursor
                continue
            }
            // Skip a generic parameter list, then capture the balanced parameter list.
            while cursor < stripped.endIndex, stripped[cursor] == " " {
                cursor = stripped.index(after: cursor)
            }
            if cursor < stripped.endIndex, stripped[cursor] == "<" {
                var depth = 0
                while cursor < stripped.endIndex {
                    if stripped[cursor] == "<" { depth += 1 }
                    if stripped[cursor] == ">" { depth -= 1; if depth == 0 { break } }
                    cursor = stripped.index(after: cursor)
                }
                cursor = stripped.index(after: cursor)
            }
            guard cursor < stripped.endIndex, stripped[cursor] == "(" else {
                index = cursor; continue
            }
            let open = cursor
            var depth = 0
            while cursor < stripped.endIndex {
                if stripped[cursor] == "(" { depth += 1 }
                if stripped[cursor] == ")" { depth -= 1; if depth == 0 { break } }
                cursor = stripped.index(after: cursor)
            }
            guard cursor < stripped.endIndex else { break }
            found.insert(signature(name: name,
                                   parameters: String(stripped[stripped.index(after: open)..<cursor])))
            index = cursor
        }
        return found
    }
}
