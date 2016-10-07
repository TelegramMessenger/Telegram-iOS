import Foundation
import SwiftSignalKit

public enum ListViewItemUpdateAnimation {
    case None
    case System(duration: Double)
}

public protocol ListViewItem {
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> Void) -> Void)
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void)
    
    var accessoryItem: ListViewAccessoryItem? { get }
    var headerAccessoryItem: ListViewAccessoryItem? { get }
    var floatingAccessoryItem: ListViewAccessoryItem? { get }
    var selectable: Bool { get }
    
    func selected(listView: ListView)
}

public extension ListViewItem {
    var accessoryItem: ListViewAccessoryItem? {
        return nil
    }
    
    var headerAccessoryItem: ListViewAccessoryItem? {
        return nil
    }
    
    var floatingAccessoryItem: ListViewAccessoryItem? {
        return nil
    }
    
    var selectable: Bool {
        return false
    }
    
    func selected(listView: ListView) {
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        completion(ListViewItemNodeLayout(contentSize: node.contentSize, insets: node.insets), {})
    }
}
