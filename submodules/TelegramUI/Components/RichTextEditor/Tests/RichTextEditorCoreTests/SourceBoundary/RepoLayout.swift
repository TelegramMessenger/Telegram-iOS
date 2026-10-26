import Foundation
import XCTest

enum RepoLayout {
    /// …/Tests/RichTextEditorCoreTests/SourceBoundary/RepoLayout.swift → package root: 4 hops up.
    static let packageRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // SourceBoundary
        .deletingLastPathComponent()   // RichTextEditorCoreTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // package root

    static var uiKitSources: URL { packageRoot.appendingPathComponent("Sources/RichTextEditorUIKit") }
    static var inputBackend: URL { uiKitSources.appendingPathComponent("InputBackend") }

    /// `T/InputBackend/` — the contract-suite test files (Tasks 22a-22i) AND, since `swiftFiles(under:)`
    /// below is a RECURSIVE `FileManager.enumerator` (has been since 22c), everything under its
    /// `Fakes/` subdirectory and the `Routers/` subdirectory Task 24 is about to create. (CORRECTED
    /// task-23 fix round 1, review Minor 7 — a prior version of this comment, and the `uiKitTestsSupport`
    /// one below, both claimed `Fakes/`/`Routers/` were excluded from the DECLARATION walk; that was
    /// only ever true of R10's discovery scope before this fix round widened it — see
    /// `InputBackendSourceBoundaryTests.swift`'s R10 doc comment — never of this recursive path itself.)
    /// Added for R10 (Task 22c fix round 2): a `BackendContractCases` subclass must never name a
    /// concrete backend outside `makeBackend()`.
    static var uiKitTestsInputBackend: URL {
        packageRoot.appendingPathComponent("Tests/RichTextEditorUIKitTests/InputBackend")
    }

    /// `T/Support/` — where `SpyRichTextInputBackend` (Task 23) lives. Added so R10's DISCOVERY (which,
    /// unlike the declaration walk above, is NOT recursive over the whole test tree by default — it only
    /// scans whatever `URL` it is explicitly pointed at) can be widened past `Sources/`-only for BOTH
    /// protocols (see that rule's own doc comment, "TASK 23"/"FIX ROUND 1" paragraphs) without also
    /// picking up `T/InputBackend/Fakes/`'s `FakeInputHost`/`IncompatibleFakeHost` HOST conformers —
    /// those are already governed by R11's own, differently-masked mechanism (masked on
    /// `func makeHost(`, not `func makeBackend()`), and scanning `Fakes/` for `RichTextInputHost` would
    /// make R10 fail on `BackendContractCases.swift` itself (its `makeHost(log:)` legitimately
    /// constructs `FakeInputHost(log: log)` outside `makeBackend()`). R10's discovery separately scans
    /// `uiKitTestsInputBackend` (above) for `RichTextInputBackend` ALONE — the half that carries no such
    /// risk — to close the `Fakes/`/`Routers/`/`T/InputBackend/`-root gap without this one.
    static var uiKitTestsSupport: URL {
        packageRoot.appendingPathComponent("Tests/RichTextEditorUIKitTests/Support")
    }

    /// `T/InputBackend/Routers/` — the router-test directory Task 24 creates. Added for R14: no test
    /// file in here may read `.inputBackend.` directly (that proves the spy works, not that the canvas
    /// routes to it — Task 23's own settled `beginningOfDocument` fix is the exact defect this guards).
    static var uiKitTestsRouters: URL {
        uiKitTestsInputBackend.appendingPathComponent("Routers")
    }

    /// FAIL, never skip. A skip here is a vacuous pass — exactly the failure mode a boundary gate
    /// must not have.
    static func assertResolved(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: packageRoot.appendingPathComponent("Package.swift").path),
            "source-boundary tests could not resolve the package root; got \(packageRoot.path)",
            file: file, line: line)
    }

    static func swiftFiles(under dir: URL) -> [URL] {
        guard let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else { return [] }
        return e.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }.sorted { $0.path < $1.path }
    }
}
