#if canImport(UIKit)
import RichTextInputDecObjC

/// Forces both build systems to actually compile and link the vendored Objective-C module.
/// Without a Swift import, Bazel would happily accept a broken `objc_library` that nothing
/// depends on, and the divergence would only surface at Stage C.
enum IDTextEditorBackendModuleProbe {
    static var isContractManifestLinkable: Bool { TGRichTextInputDecContractManifest() != nil }
}

/// USAGE RULE for every later task in this plan:
///
/// No Swift code in InputBackend/InputDec/ may call a kernel method directly. Every call —
/// kernel construction, every `kernelInput`/`kernelInteraction` witness, every preflight —
/// goes through `TGRichTextInputDecPerform` / `…PerformReturningObject`, and a caught
/// exception becomes a thrown `RichTextInputBackendAttachmentError.privateRuntimeFailure`
/// (at attach) or a logged no-op that returns the witness's documented "absent" value
/// (afterwards). `IDUIKitInputControllerCapability.activeController` raises on ANY call after
/// detach, so the post-detach path is the common case, not the exotic one.
///
/// `IDBackendCallGuardTests` (Task C0 Step 9) greps this directory and fails on a direct call.
enum IDTextEditorBackendKernelCallPolicy {}
#endif
