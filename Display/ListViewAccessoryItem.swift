import Foundation

public protocol ListViewAccessoryItem {
    func isEqualToItem(other: ListViewAccessoryItem) -> Bool
    func node() -> ListViewAccessoryItemNode
}
