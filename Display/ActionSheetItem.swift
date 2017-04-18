import Foundation

public protocol ActionSheetItem {
    func node() -> ActionSheetItemNode
    func updateNode(_ node: ActionSheetItemNode) -> Void
}
