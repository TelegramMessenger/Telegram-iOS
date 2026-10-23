import Foundation
import UIKit
import Display

/// The horizontal metrics of an undo overlay's panel: `panelX` in the container, the rest in the panel.
struct UndoOverlayHorizontalLayout: Equatable {
    /// Added on each side of the band between the safe insets; also the extra gap the text keeps before the button.
    var sideMargin: CGFloat
    var panelX: CGFloat
    var panelWidth: CGFloat
    /// The title's and text's maximum width, starting at `leadingInset`.
    var textMaxWidth: CGFloat
}

func undoOverlayHorizontalLayout(width: CGFloat, safeInsets: UIEdgeInsets, intrinsicInsets: UIEdgeInsets, margin: CGFloat, leadingInset: CGFloat, trailingInset: CGFloat, buttonWidth: CGFloat?, isNarrow: Bool) -> UndoOverlayHorizontalLayout {
    // The presenting context's left inset widens the margin on both sides, less iPhone Duo's side strip (the
    // difference of the side safe insets). A chat hands its children its history list's side insets, which hold the
    // safe insets with left and right swapped, so its left inset is the strip, which `safeInsets` already keep clear
    // of; counting it again left no width for the text. With equal side insets this is `margin + intrinsicInsets.left`.
    let strip = abs(safeInsets.right - safeInsets.left)
    let sideMargin = margin + max(0.0, intrinsicInsets.left - strip)

    let buttonMinX: CGFloat
    if let buttonWidth {
        buttonMinX = width - safeInsets.right - trailingInset - buttonWidth - sideMargin * 2.0
    } else {
        buttonMinX = width - safeInsets.right - trailingInset
    }
    let textMaxWidth = buttonMinX - 8.0 - leadingInset - safeInsets.left - sideMargin

    var panelWidth = width - sideMargin * 2.0 - safeInsets.left - safeInsets.right
    if isNarrow {
        panelWidth = 210.0
    }
    // Centered in the band between the side safe insets (iPhone Duo's side strip); with equal insets this is
    // the full width's center.
    let panelX = floorToScreenPixels(safeInsets.left + (width - safeInsets.left - safeInsets.right - panelWidth) / 2.0)

    return UndoOverlayHorizontalLayout(sideMargin: sideMargin, panelX: panelX, panelWidth: panelWidth, textMaxWidth: textMaxWidth)
}
