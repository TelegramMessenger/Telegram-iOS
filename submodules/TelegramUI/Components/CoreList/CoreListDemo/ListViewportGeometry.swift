import UIKit

struct ListViewportGeometry: Equatable {
    var size: CGSize
    var insets: UIEdgeInsets

    var contentWidth: CGFloat {
        max(0, size.width - insets.left - insets.right)
    }

    var minimumOffset: CGFloat { -insets.top }

    func maximumOffset(contentBottom: CGFloat) -> CGFloat {
        contentBottom + insets.bottom - size.height
    }
}
