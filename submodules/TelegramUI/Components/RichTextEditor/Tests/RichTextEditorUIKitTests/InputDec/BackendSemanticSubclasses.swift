#if canImport(UIKit)
import XCTest
@testable import RichTextEditorUIKit

/// The legacy run. Green from the moment the base class exists — it pins what "the same" means.
@MainActor
@available(iOS 16.0, *)
final class LegacyBackendSemanticTests: BackendSemanticContractCases {
    override class var backendKind: RichTextInputBackendKind? { .legacy }
}

/// The ID run. Skips wholesale off the certified OS band; on it, every inherited assertion must
/// produce the identical result. A divergence is a bug in the adapter or an entry in
/// DIVERGENCES.md — never a weakened base-class assertion.
@MainActor
@available(iOS 16.0, *)
final class IDBackendSemanticTests: BackendSemanticContractCases {
    override class var backendKind: RichTextInputBackendKind? { .inputDec }
}
#endif
