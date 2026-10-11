#if canImport(UIKit)
import ObjectiveC
import RichTextInputDecObjC
import UIKit
import XCTest

final class CanvasABIWitnessTests: XCTestCase {
    func test_witnessClassResolvesUnderTheRenamedManifestName() {
        XCTAssertNotNil(NSClassFromString("TGRichTextInputDecCanvasABIWitness"))
    }

    func test_witnessImplementsTheThreeCanvasRowsDirectly() {
        let cls: AnyClass = TGRichTextInputDecCanvasABIWitness.self
        var count: UInt32 = 0
        let methods = class_copyMethodList(cls, &count)
        defer { free(methods) }
        let names = (0..<Int(count)).map { String(cString: sel_getName(method_getName(methods![$0]))) }
        for selector in ["keyboardInputShouldDelete:", "startAutoscroll:", "cancelAutoscroll"] {
            XCTAssertTrue(names.contains(selector),
                          "\(selector) must be implemented on the witness itself, not inherited")
        }
    }

    /// The resolver-level proof the two tests above don't give: not just that the witness class
    /// exists and implements the three selectors (by name), but that the REAL
    /// `IDUIKitCapabilityResolver` — the same code `isSupported()` will eventually call — accepts
    /// them, i.e. the runtime type encodings the compiler emitted for these three methods match
    /// what the compiled-in manifest asserts. This is the check that would have caught the
    /// controller supplement's finding on its own: the brief's own Step-4 snippet declared
    /// `startAutoscroll:` returning BOOL, but the manifest's row says returnType "v" (void) —
    /// a signature that compiles fine and looks plausible, then fails exactly this evaluation.
    func test_resolverAcceptsTheAutoscrollEntryCapability() throws {
        let manifest = try XCTUnwrap(TGRichTextInputDecContractManifest())
        let contract = try XCTUnwrap(manifest.capabilities["autoscrollEntry"])
        let resolver = IDUIKitCapabilityResolver.system()
        let result = resolver.evaluateContract(contract)
        XCTAssertTrue(result.isAccepted, "mismatches: \(result.mismatches)")
    }
}
#endif
