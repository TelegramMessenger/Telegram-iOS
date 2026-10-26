#if canImport(UIKit)
import RichTextInputDecObjC
import XCTest

/// This suite is the ONLY non-vacuous check that the class renames landed. Text greps over the
/// generated `.m` cannot serve: the payload is emitted as `0x49, 0x44, …`, so a grep for an
/// upstream class name is satisfied whether or not any rename happened. Everything here runs
/// against the PARSED manifest.
///
/// It is also the first thing in either build system that COMPILES the vendored Objective-C.
/// Tasks A4 and A5 both shipped green gates while `Sources/RichTextInputDecObjC/` was in no
/// target's sources at all: SwiftPM silently ignores an undeclared directory under `Sources/`
/// (no diagnostic, not even at a forced manifest re-evaluation) and `BUILD`'s globs are
/// target-scoped. So a green run of THIS suite is the first evidence that the snapshot builds.
final class ContractManifestTests: XCTestCase {
    func test_manifestParsesFromCompiledInBytes() {
        let manifest = TGRichTextInputDecContractManifest()
        XCTAssertNotNil(manifest, "the compiled-in contract data failed to parse")
    }

    func test_manifestRecordsTheCertifiedOSBand() throws {
        let manifest = try XCTUnwrap(TGRichTextInputDecContractManifest())
        XCTAssertEqual(manifest.osVersion, "26.5")
        XCTAssertEqual(manifest.osBuild, "23F73")
    }

    /// THE load-bearing test of the vendoring. `IDUIKitCapabilityResolver.evaluateContract:`
    /// looks each member's class up with NSClassFromString and rejects the whole capability when
    /// it is nil; `incomingCallbacks` is mandatory. If the codegen renamed on the wrong key
    /// (the JSON spells it "class", not "className"), these 47 rows still say
    /// IDRichTextLayoutController, that class does not exist in this binary, and
    /// isSupported() can never return true — with no build error anywhere.
    func test_everyIncomingCallbackRowNamesTheVendoredLayoutController() throws {
        let manifest = try XCTUnwrap(TGRichTextInputDecContractManifest())
        let incoming = try XCTUnwrap(manifest.capabilities["incomingCallbacks"])
        XCTAssertEqual(incoming.members.count, 47)
        for member in incoming.members {
            XCTAssertEqual(member.className, "TGRichTextInputDecLayoutController",
                           "row \(member.identifier) was not renamed")
        }
    }

    /// The three canvas-hosted rows: inputController.keyboardDeletePreflight,
    /// autoscrollEntry.start, autoscrollEntry.cancel.
    func test_theThreeCanvasRowsNameTheABIWitness() throws {
        let manifest = try XCTUnwrap(TGRichTextInputDecContractManifest())
        var renamed: [String] = []
        for (_, capability) in manifest.capabilities {
            for member in capability.members where member.className == "TGRichTextInputDecCanvasABIWitness" {
                renamed.append(member.identifier)
            }
        }
        XCTAssertEqual(Set(renamed), ["inputController.keyboardDeletePreflight",
                                      "autoscrollEntry.start", "autoscrollEntry.cancel"])
    }

    /// No upstream class name may survive anywhere in the shipped manifest.
    func test_noUpstreamClassNameSurvivesAnywhere() throws {
        let manifest = try XCTUnwrap(TGRichTextInputDecContractManifest())
        for (name, capability) in manifest.capabilities {
            for member in capability.members {
                XCTAssertNotEqual(member.className, "IDRichTextLayoutController", "\(name)")
                XCTAssertNotEqual(member.className, "IDBlockTextView", "\(name)")
            }
        }
    }

    /// `referenceOnly` is EMPTIED, not deleted: `manifestWithData:error:` runs
    /// IDUIKitDictionaryHasExactKeys over {schema, runtime, capabilities, referenceOnly,
    /// forbidden} (IDUIKitRuntimeContract.m:667-678), so deleting the key fails the parse
    /// outright — `test_manifestParsesFromCompiledInBytes` would go red first.
    /// `forbidden` DOES travel: it is a deny-list, and it is the only machine-checkable
    /// statement that the reference backend's surfaces are not used.
    func test_referenceOnlyIsEmptyAndTheForbiddenDenyListIsIntact() throws {
        let manifest = try XCTUnwrap(TGRichTextInputDecContractManifest())
        XCTAssertEqual(manifest.referenceOnly.count, 0,
                       "the 53 referenceOnly rows belong to the excluded reference backend")
        XCTAssertEqual(manifest.forbiddenSymbols.count, 8)
        for symbol in ["_UITextLayoutControllerBase", "_UITextKit2LayoutController",
                       "_UITextLayoutCanvasView", "_UITextLayoutCanvasViewController",
                       "layoutControllerWithTextView:textContainer:",
                       "initWithTextView:textContainer:", "_canvasViewForTextContainer:",
                       "_setCanvasView:forTextContainer:"] {
            XCTAssertTrue(manifest.forbiddenSymbols.contains(symbol), "missing deny-list entry \(symbol)")
        }
    }

    func test_mandatoryCapabilitiesArePresent() throws {
        let manifest = try XCTUnwrap(TGRichTextInputDecContractManifest())
        for name in ["inputController", "typingAttributes", "incomingCallbacks"] {
            XCTAssertNotNil(manifest.capabilities[name], "missing mandatory capability \(name)")
        }
    }
}
#endif
