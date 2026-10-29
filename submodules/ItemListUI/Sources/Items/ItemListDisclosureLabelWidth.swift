import Foundation
import CoreGraphics

/// The width a disclosure row's trailing value (label) is laid out in, after its title.
///
/// `labelRightInset` is where the value ends (it is right-aligned there, before the disclosure arrow). By default the
/// value keeps the row's legacy reserve after the title (16pt before an arrow, 34pt without one). A row that names a
/// `minimumSpacing` keeps exactly that much between its title and a plain text value instead (badge styles and an
/// icon peer add nothing to it), so a long localized title and a short value can share the line.
func itemListDisclosureLabelConstrainedWidth(width: CGFloat, rightInset: CGFloat, labelRightInset: CGFloat, leftInset: CGFloat, titleWidth: CGFloat, hasIconPeer: Bool, minimumSpacing: CGFloat?) -> CGFloat {
    if let minimumSpacing {
        return width - labelRightInset - leftInset - titleWidth - minimumSpacing
    }
    var result = width - rightInset - leftInset - 40.0 - titleWidth - 10.0
    if hasIconPeer {
        result -= 6.0
    }
    return result
}
