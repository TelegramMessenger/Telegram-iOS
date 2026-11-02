import Foundation
import CoreGraphics

/// The width the input field's placeholder may take on its line: from where the field's text starts, which the send-as
/// avatar pushes right, to where the field's buttons begin (the accessory buttons, the send button). A placeholder too
/// long for it is truncated before the buttons instead of running under them (#116).
func chatTextInputPlaceholderMaxWidth(textLeftInset: CGFloat, buttonsMinX: CGFloat) -> CGFloat {
    return max(1.0, buttonsMinX - textLeftInset)
}
