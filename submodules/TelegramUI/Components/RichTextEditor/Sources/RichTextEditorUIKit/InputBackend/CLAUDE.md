# Input backends (`Sources/RichTextEditorUIKit/InputBackend`)

The `RichTextInputBackend` seam between the canvas editor and the text-input machinery behind it. The kernel and engine
the InputDec backends adapt are in `Sources/RichTextInputDecObjC/CLAUDE.md` and `Sources/RichTextInputDecUpstream/CLAUDE.md`;
shared rules are in the package `CLAUDE.md`.

## Backends and selection

- `LegacyRichTextInputBackend` is the shipping backend.
- `IDTextEditorBackend` (`InputDec/`) drives the kernel; its deviations are recorded in `InputDec/DIVERGENCES.md`.
  `RichTextInputCanvasFactory.make(_:)` is the one place a backend is chosen, from `RichTextEditorView`'s `inputBackend`
  kind: `.inputDecIfSupported` builds an `IDDocumentCanvasView` with an injected `IDTextEditorBackend` when
  `isSupported()` (iOS 17.0 floor plus the mandatory contracts; false without `TG_RICHTEXT_INPUTDEC_ENABLED`), else the
  legacy canvas. The default is `.legacy`; the chat panel passes `.inputDecIfSupported` only while Debug Settings
  `inputDecTextBackend` is on. Never build `IDDocumentCanvasView()` bare: it defaults to `LegacyRichTextInputBackend`,
  and every `.inputDec` test then passes while testing the wrong thing.
- `IDUpstreamInputBackend` (`InputDec/Upstream/`) drives the vendored engine through the same family and is outside the
  app build: the Bazel `srcs` glob excludes its directory and `Package.swift` compiles it for the test target only.
  `Tests/RichTextEditorCoreTests/SourceBoundary/InputDecUpstreamAdapterBoundaryTests.swift` pins both, and which
  requirements are implemented. Each unimplemented requirement reports a named contract violation instead of a
  plausible value, and a test drives each one. It has no production call site.
- `IDTextEditorBackendModuleProbe.swift` only proves the kernel module compiles and links (it imports
  `RichTextInputDecObjC` and calls one contract-manifest function).

## The responder hand-off has no production caller

`RichTextInputBackend` has `acquireFirstResponder()` / `relinquishFirstResponder()`, returning a
`RichTextInputResponderTransition`, because the engine's editing surface is a separate view inside the host and UIKit
shows no keyboard while the host itself holds first responder. `LegacyRichTextInputBackend` answers `.hostOwnsTheRole`
and never touches the responder chain, which keeps behaviour unchanged and makes the pair recursion-proof for a host
that routes its overrides through it.

Nothing in `Sources/` calls either method, and `DocumentCanvasView`'s responder overrides are unchanged, pinned by
`InputBackendSourceBoundaryTests.test_theResponderHandOffHasNoProductionCallSiteYet_R23`. When the canvas is wired up,
delete that test rather than working around it.
