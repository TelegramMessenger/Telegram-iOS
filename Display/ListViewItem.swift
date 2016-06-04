import Foundation
import SwiftSignalKit

public protocol ListViewItem {
    func nodeConfiguredForWidth(async: (() -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: (ListViewItemNode, () -> Void) -> Void)
    func updateNode(async: (() -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: (ListViewItemNodeLayout, () -> Void) -> Void)
    
    var accessoryItem: ListViewAccessoryItem? { get }
    var headerAccessoryItem: ListViewAccessoryItem? { get }
    var selectable: Bool { get }
    
    func selected()
}

public extension ListViewItem {
    var accessoryItem: ListViewAccessoryItem? {
        return nil
    }
    
    var headerAccessoryItem: ListViewAccessoryItem? {
        return nil
    }
    
    var selectable: Bool {
        return false
    }
    
    func selected() {
    }
    
    func updateNode(async: (() -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: (ListViewItemNodeLayout, () -> Void) -> Void) {
        completion(ListViewItemNodeLayout(contentSize: node.contentSize, insets: node.insets), {})
    }
}
