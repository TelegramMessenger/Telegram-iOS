import XCTest

/// The vendored Objective-C module is allowed to exist from this commit onward, but only
/// in one place and only reachable from one Swift directory.
///
/// This is the counterweight to Task A4's relaxation of R8/R1/R2 in
/// `InputBackendSourceBoundaryTests.swift`: those three rules stop rejecting InputDec-shaped
/// names inside two exempt paths, and these three rules take over the job of saying where
/// InputDec-shaped *files* and *symbols* may live.
final class InputDecBoundaryTests: XCTestCase {

    /// PKG/BUILD globs `Sources/RichTextEditorUIKit/**/*.swift` ONLY. An .m or .h placed under
    /// that tree compiles under SwiftPM and is silently dropped from the Bazel app build.
    func test_objectiveCLivesOutsideTheSwiftGlob() {
        RepoLayout.assertResolved()
        let offenders = FileManager.default
            .enumerator(at: RepoLayout.uiKitSources, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { ["m", "mm", "h"].contains($0.pathExtension) } ?? []
        XCTAssertEqual(offenders.map(\.lastPathComponent), [],
                       "Objective-C under Sources/RichTextEditorUIKit is invisible to Bazel")
    }

    func test_noIDUIKitSymbolInSwiftOutsideTheAdapter() throws {
        RepoLayout.assertResolved()
        let adapter = RepoLayout.inputBackend.appendingPathComponent("InputDec").path
        var offenders: [String] = []
        for url in RepoLayout.swiftFiles(under: RepoLayout.uiKitSources) where !url.path.hasPrefix(adapter) {
            let source = SwiftSourceScan.stripCommentsAndStringLiterals(try String(contentsOf: url))
            if source.range(of: #"\bIDUIKit\w+"#, options: .regularExpression) != nil {
                offenders.append(url.lastPathComponent)
            }
        }
        XCTAssertEqual(offenders, [], "IDUIKit* symbols leaked out of InputBackend/InputDec")
    }

    func test_vendoredModuleIsPresentAndComplete() {
        RepoLayout.assertResolved()
        let root = RepoLayout.packageRoot.appendingPathComponent("Sources/RichTextInputDecObjC")
        for relative in ["Kernel/IDUIKitBehaviorKernel.m",
                         "include/Kernel/IDUIKitBehaviorKernel.h",
                         "Generated/TGRichTextInputDecContractData.m",
                         "Vendor/VENDOR.md"] {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: root.appendingPathComponent(relative).path),
                "missing vendored file \(relative)")
        }
    }
}
