import XCTest

/// Enforces the usage rule written down in Task A8 Step 6: no Swift file in the adapter may
/// call the vendored kernel without the NSException trampoline. Swift cannot catch an
/// NSException, the kernel raises on every contract mismatch, and it is certified against one
/// OS build — so a direct call is a crash waiting for the next OS.
final class IDBackendCallGuardTests: XCTestCase {

    /// Member ACCESSES, not declarations: `private var kernelInput: …?` and
    /// `self.kernelInput = kernel.inputController` are storage, not calls, and must not be
    /// flagged. Matching on the `?.` / `!.` / `.` suffix is what separates the two.
    private static let kernelEntryPoints = ["kernelInput?.", "kernelInput!.",
                                            "kernelInteraction?.", "kernelInteraction!.",
                                            "IDUIKitBehaviorKernel(",
                                            "TGRichTextInputDecHostPreflight."]

    func test_everyKernelCallIsInsideTheExceptionGuard() throws {
        RepoLayout.assertResolved()
        let adapter = RepoLayout.inputBackend.appendingPathComponent("InputDec")
        var offenders: [String] = []
        for url in RepoLayout.swiftFiles(under: adapter) {
            let text = SwiftSourceScan.stripCommentsAndStringLiterals(try String(contentsOf: url))
            for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                guard Self.kernelEntryPoints.contains(where: { line.contains($0) }) else { continue }
                // A guarded call site names the trampoline within the same statement group; the
                // convention this enforces is that the entry point appears INSIDE the closure
                // literal passed to TGRichTextInputDecPerform*, i.e. on a line that either
                // names it or follows one within three lines.
                let window = text.split(separator: "\n", omittingEmptySubsequences: false)[
                    max(0, index - 3)...index].joined(separator: "\n")
                if !window.contains("TGRichTextInputDecPerform") {
                    offenders.append("\(url.lastPathComponent):\(index + 1)")
                }
            }
        }
        XCTAssertEqual(offenders, [],
                       "unguarded kernel call — wrap it in TGRichTextInputDecPerform")
    }

    /// ANTI-VACUITY (controller finding, task-C0-supplement.md §5): a "zero offenders" result
    /// above is indistinguishable from a scan whose patterns are typo'd and can never match
    /// anything — `kernelInput?.4` or `TGRichTextInputDecHostPreflight.z` would pass just as
    /// cleanly as the correct spellings, certifying nothing. This proves each pattern's ROOT
    /// identifier is a real, correctly-spelled symbol by checking it against the OBJECTIVE-C
    /// TARGET where the underlying classes are actually declared — not the Swift adapter this
    /// suite scans (a typo'd Swift-side literal could otherwise "agree" with itself and both
    /// tests would pass vacuously together). Mirrors the controller's own verification: `grep`
    /// for `IDUIKitBehaviorKernel` under `Sources/RichTextInputDecObjC` returns 3 hits.
    func test_theKernelEntryPointIdentifiersAreRealSymbols() throws {
        RepoLayout.assertResolved()
        let objcRoot = RepoLayout.packageRoot.appendingPathComponent("Sources/RichTextInputDecObjC")
        let objcFiles = FileManager.default.enumerator(at: objcRoot, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { ["h", "m"].contains($0.pathExtension) } ?? []
        XCTAssertFalse(objcFiles.isEmpty,
                       "no Objective-C source found under \(objcRoot.path) — the control has " +
                       "nothing to check against, which would make it pass vacuously")
        let objcText = try objcFiles.map { try String(contentsOf: $0) }.joined(separator: "\n")
        // `kernelInput`/`kernelInteraction` are the ADAPTER's own local property names — nothing
        // ObjC-side is spelled that way. Their real control is the CLASS they are typed as
        // (`IDUIKitInputControllerCapability`/`IDUIKitInteractionCapability`); `IDUIKitBehaviorKernel`
        // and `TGRichTextInputDecHostPreflight` are literal substrings of their own patterns.
        for rootIdentifier in ["IDUIKitBehaviorKernel", "IDUIKitInputControllerCapability",
                               "IDUIKitInteractionCapability", "TGRichTextInputDecHostPreflight"] {
            XCTAssertTrue(objcText.contains(rootIdentifier),
                         "\(rootIdentifier) not found under Sources/RichTextInputDecObjC — a " +
                         "kernelEntryPoints pattern built on it can never match anything, making " +
                         "test_everyKernelCallIsInsideTheExceptionGuard's zero-offenders result vacuous")
        }
    }

    /// The guard must not become vacuous by the adapter simply having no kernel calls.
    ///
    /// LEFT DISABLED, deliberately, exactly as the brief specifies (and as Task A4 did for its
    /// own boundary anti-vacuity test): the brief's intent is that this proves a genuine
    /// WITNESS call is guarded, and Task C4 is where the first witness (of the six document
    /// methods) lands. Task C0's OWN guarded calls (kernel construction in `attach(to:)`, and
    /// `kernelInput?.detach()`/`kernelInteraction?.detach()` in `detach()` — added here because
    /// Step 8's own `test_everyKernelCallIsInsideTheExceptionGuard` flags them as unguarded
    /// member ACCESSES otherwise) already make the literal substring check below pass today —
    /// confirmed by running it — but they are construction/teardown, not the witnessed
    /// read/write calls this test is written to gate on.
    ///
    /// UNCOMMENTED IN TASK C4: Step 8 routed the first real witness calls (the seven
    /// `RichTextInputTextBackend` members `IDTextEditorBackend.swift`'s own Step-8 comment
    /// lists) through `kernelInput`, each wrapped in `TGRichTextInputDecPerform*` per Step 9 —
    /// so the substring this test looks for is genuinely produced by a witness, not only by
    /// construction/teardown.
    func test_thereAreGuardedKernelCallsToCheck() throws {
        RepoLayout.assertResolved()
        let adapter = RepoLayout.inputBackend.appendingPathComponent("InputDec")
        let anyCall = try RepoLayout.swiftFiles(under: adapter).contains {
            try String(contentsOf: $0).contains("TGRichTextInputDecPerform")
        }
        XCTAssertTrue(anyCall, "no guarded kernel call found — the rule covers nothing")
    }
}
