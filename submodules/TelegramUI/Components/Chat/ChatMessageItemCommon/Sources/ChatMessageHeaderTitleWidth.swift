import Foundation
import UIKit

/// The widest a chat header pill's title may be (a forum's floating topic header, a peer header). The pill is the
/// title plus `chromeWidth` (icon, paddings, arrow), centred between the list's side insets, which include the side
/// topic panel and iPhone Duo's strip. The title is capped so the pill stays `margin` inside that band on every screen
/// width; a wide band keeps the fixed `maximumWidth`.
public func chatMessageHeaderTitleMaxWidth(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, chromeWidth: CGFloat, margin: CGFloat, maximumWidth: CGFloat = 320.0) -> CGFloat {
    let bandWidth = width - leftInset - rightInset
    return max(0.0, min(maximumWidth, floor(bandWidth - chromeWidth - margin * 2.0)))
}
