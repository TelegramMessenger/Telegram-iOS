#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// The prompt shown in a container's empty SECOND line.
///
/// A placeholder is not content, so it cannot live in the engine block: it would be selectable,
/// editable, and would read back as the field's value. It is drawn as a view over the line instead —
/// the same answer the body placeholder and the hosted emoji already use.
internal final class SecondaryPlaceholderLabel: UILabel {}

@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    /// Reconciles a placeholder against every EMPTY second line.
    ///
    /// Without one the field is invisible: the row is reserved (measured — an empty author line is
    /// 22pt where a filled one is 20), but an empty line inside a pill is indistinguishable from the
    /// pill's own padding, so the field exists and cannot be found. That is precisely how this was
    /// reported: "I don't see any author field".
    internal func syncSecondaryPlaceholders() {
        var live: Set<BlockID> = []
        for (index, role) in currentRoles.enumerated() {
            guard let kind = role.secondaryKind, flatLength(ofRoleAt: index) == 0 else { continue }
            let frame = engine.id_frameForBlock(at: UInt(index))
            guard !frame.isNull, frame.width > 0, frame.height > 0 else { continue }

            let id = role.blockID
            live.insert(id)
            let label: SecondaryPlaceholderLabel
            if let existing = secondaryPlaceholderLabels[id] {
                label = existing
            } else {
                let fresh = SecondaryPlaceholderLabel()
                fresh.isUserInteractionEnabled = false   // decorative — never intercept a tap
                // Into the engine's CONTENT space, like every other hosted view here, so it rides
                // the scroll instead of staying pinned to the field.
                engine.addSubview(fresh)
                secondaryPlaceholderLabels[id] = fresh
                label = fresh
            }
            label.text = Self.placeholderText(for: kind)
            label.font = Self.placeholderFont(for: kind, styleSheet: bridge.styleSheet)
            label.textAlignment = (kind == .pullQuoteAuthor || kind == .mediaCaption) ? .center : .natural
            label.textColor = composerHostState.theme.placeholder
            // Inset to the line's own text inset. The frame is the whole block, but the text inside
            // it is indented — by the quote's bar-to-text gap, or by the code band's padding — so a
            // placeholder drawn on the raw frame sits to the LEFT of everything it stands in for.
            label.frame = frame.inset(by: Self.textInset(
                for: kind, styleSheet: bridge.styleSheet,
                pullQuotePadding: deferredConfiguration.pullQuoteStyle.horizontalPadding,
                contentIndent: role.contentIndent(styleSheet: bridge.styleSheet)))
        }

        for (id, label) in secondaryPlaceholderLabels where !live.contains(id) {
            secondaryPlaceholderLabels[id] = nil
            label.removeFromSuperview()
        }
    }

    /// The horizontal inset the line's own text carries, mirrored so the prompt lands on it.
    private static func textInset(for kind: SecondaryRegionKind, styleSheet: StyleSheet,
                                  pullQuotePadding: CGFloat, contentIndent: CGFloat) -> UIEdgeInsets {
        let quoted = contentIndent
        switch kind {
        case .blockQuoteAuthor:
            // The line's ancestry includes its own quote, so `depth` is already one at top level (16pt).
            return UIEdgeInsets(top: 0.0, left: quoted, bottom: 0.0, right: 0.0)
        case .codeLanguage:
            let inset = styleSheet.codeHorizontalInset
            return UIEdgeInsets(top: 0.0, left: inset + quoted, bottom: 0.0, right: inset)
        case .pullQuoteAuthor:
            // Centred within the pill's padding, like the line itself.
            return UIEdgeInsets(top: 0.0, left: pullQuotePadding + quoted, bottom: 0.0, right: pullQuotePadding)
        case .mediaCaption:
            return UIEdgeInsets(top: 0.0, left: quoted, bottom: 0.0, right: 0.0)
        case .detailsTitle:
            // The title's own glyph indent clears the chevron, on top of the enclosing containers'.
            // Its details contributes nothing to `quoted` (§3.4), so this is the whole of it.
            return UIEdgeInsets(top: 0.0, left: quoted + DetailsShape.titleGlyphIndent, bottom: 0.0, right: 0.0)
        }
    }

    /// Legacy's default for a details title (`RichTextEditorPlaceholders.detailsTitle`), so the two
    /// editors prompt with the same word.
    private static let detailsTitlePlaceholderText = "Title"

    /// What each line prompts with. The author's is the legacy canvas's own string, so the two
    /// editors say the same thing.
    private static func placeholderText(for kind: SecondaryRegionKind) -> String {
        switch kind {
        case .pullQuoteAuthor, .blockQuoteAuthor: return quoteAuthorPlaceholderText
        case .codeLanguage: return "Language"
        case .mediaCaption: return mediaCaptionPlaceholderText
        case .detailsTitle: return detailsTitlePlaceholderText
        }
    }

    /// Matched to the line's own rendering, so the prompt sits exactly where the text will.
    private static func placeholderFont(for kind: SecondaryRegionKind,
                                        styleSheet: StyleSheet) -> UIFont {
        switch kind {
        case .pullQuoteAuthor, .blockQuoteAuthor:
            let base = UIFont.systemFont(ofSize: styleSheet.metrics.caption.size)
            let emphasis: UIFontDescriptor.SymbolicTraits =
                kind == .pullQuoteAuthor ? [.traitBold, .traitItalic] : [.traitBold]
            let traits = base.fontDescriptor.symbolicTraits.union(emphasis)
            guard let descriptor = base.fontDescriptor.withSymbolicTraits(traits) else { return base }
            return UIFont(descriptor: descriptor, size: base.pointSize)
        case .codeLanguage:
            return UIFont.systemFont(ofSize: styleSheet.metrics.body.size, weight: .semibold)
        case .mediaCaption:
            return styleSheet.font(for: .caption, attributes: .plain)
        case .detailsTitle:
            // Body, like the line itself: a title is ordinary text, not a caption or a field label.
            return styleSheet.font(for: .body, attributes: .plain)
        }
    }
}
#endif
