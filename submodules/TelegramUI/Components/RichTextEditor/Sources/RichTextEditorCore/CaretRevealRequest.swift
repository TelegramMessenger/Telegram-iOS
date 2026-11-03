import CoreGraphics

/// The curves the two hosts actually pass — the chat input panel uses `.easeInOut` and `.spring`,
/// the article screen `.immediate` and a 0.4s spring.
///
/// Deliberately small. The mapping at each host is an exhaustive switch over ITS transition type, so
/// a curve some future host passes becomes a compile error there rather than a silent fallback to
/// the wrong motion.
public enum RichTextEditorAnimationCurve {
    case easeInOut
    case spring
}

/// How a host wants a change it has just asked for to be applied.
///
/// The package owns this type rather than importing `Display`: `ContainedViewLayoutTransition` and
/// `ComponentTransition` cannot cross into a package whose only dependency is `MosaicLayout`, and
/// whose targets build standalone under SwiftPM. What crosses is the description — a duration and a
/// curve — which both of the app's transition types already carry.
public enum RichTextEditorAnimation {
    case immediate
    case animated(duration: Double, curve: RichTextEditorAnimationCurve)
}

/// What a layout pass says about the caret.
///
/// The default everywhere is `.none`, and that is the point: an editor does not scroll itself to
/// follow the caret, so a pass that says nothing about it does not move it. See
/// the RichTextEditor `CLAUDE.md`, "The host decides when the caret is revealed".
public enum RichTextEditorCaretReveal {
    /// This pass is not about the caret — a theme change, a measurement, a host-driven relayout.
    case none
    /// Reveal the caret if the geometry THIS pass applies would leave it hidden.
    case ifNeeded(RichTextEditorAnimation)
}
