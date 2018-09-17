import Foundation
#if os(macOS)
import SwiftSignalKitMac
#else
import SwiftSignalKit
#endif

public enum ListViewItemUpdateAnimation {
    case None
    case System(duration: Double)
    
    public var isAnimated: Bool {
        if case .None = self {
            return false
        } else {
            return true
        }
    }
}

public struct ListViewItemConfigureNodeFlags: OptionSet {
    public var rawValue: Int32
    
    public init() {
        self.rawValue = 0
    }
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let preferSynchronousResourceLoading = ListViewItemConfigureNodeFlags(rawValue: 1 << 0)
}

public protocol ListViewItem {
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void)
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void)
    
    var accessoryItem: ListViewAccessoryItem? { get }
    var headerAccessoryItem: ListViewAccessoryItem? { get }
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
    
    var selectable: Bool {
        return false
    }
    
    func selected(listView: ListView) {
    }
}
