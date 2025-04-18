import UIKit

public final class ActionSheetItemGroup {
    let items: [ActionSheetItem]
    let leadingVisibleNodeCount: CGFloat?
    
    public init(items: [ActionSheetItem], leadingVisibleNodeCount: CGFloat? = nil) {
        self.items = items
        self.leadingVisibleNodeCount = leadingVisibleNodeCount
    }
}
