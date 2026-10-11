#if canImport(UIKit)
import UIKit

/// The per-paragraph layout seam, republished for `RichTextEngineEditor`.
///
/// `BlockLayoutEngine` and `makeBlockLayout` live under `Layout/`. This file republishes them rather
/// than copying anything, which is `RichTextButtonSurface.swift`'s arrangement and for the same
/// reason: another module needs the seam, and a second copy of text layout is the one thing that
/// must not exist.
@available(iOS 13.0, *)
public typealias RichTextBlockLayout = BlockLayoutEngine

/// Builds the layout the current build selects — TextKit 2 where available, the TextKit 1 back-port
/// otherwise. The choice stays `makeBlockLayout`'s, so a caller outside this module cannot pin one.
@available(iOS 13.0, *)
public func richTextMakeBlockLayout(attributedString: NSAttributedString,
                                    width: CGFloat) -> RichTextBlockLayout {
    makeBlockLayout(attributedString: attributedString, width: width)
}
#endif
