import Foundation
import UIKit

/// The narrowest gift cell a phone's wide Gifts grid lays out. A cell scales its sticker with its width, but the
/// sender's avatar in its top-left corner keeps 20pt, so below this the sticker runs into the avatar.
public let peerInfoGiftsMinimumItemWidth: CGFloat = 110.0

/// The number of gifts per row in the profile's Gifts grid, for a pane of `size` whose cells sit `itemsSideInset` in
/// from each side, `spacing` apart. A wide or landscape pane takes 4 per row on a tablet and 5 on a phone, other panes
/// 3. On a phone the wide row drops columns, down to 3, while its cells would be narrower than
/// `peerInfoGiftsMinimumItemWidth`: iPhone Duo's narrow wide panes (unfolded beside the chat list, folded landscape)
/// and 320pt-wide phones in landscape. Other phones and tablets keep today's count.
public func peerInfoGiftsItemsInRow(size: CGSize, itemsSideInset: CGFloat, spacing: CGFloat, isTablet: Bool) -> Int {
    if size.width > size.height || size.width > 480.0 {
        if isTablet {
            return 4
        }
        var itemsInRow = 5
        while itemsInRow > 3 && (size.width - itemsSideInset * 2.0 - spacing * CGFloat(itemsInRow - 1)) / CGFloat(itemsInRow) < peerInfoGiftsMinimumItemWidth {
            itemsInRow -= 1
        }
        return itemsInRow
    } else {
        return 3
    }
}
