import Foundation
import UIKit
import SwiftSignalKit

public enum ListViewItemUpdateAnimation {
    case None
    case System(duration: Double, transition: ControlledTransition)
    case Crossfade
    
    public var isAnimated: Bool {
        if case .None = self {
            return false
        } else {
            return true
        }
    }
    
    public var animator: ControlledTransitionAnimator {
        switch self {
        case .None:
            return ControlledTransition.LegacyAnimator(duration: 0.0, curve: .linear)
        case let .System(_, transition):
            return transition.animator
        case .Crossfade:
            return ControlledTransition.LegacyAnimator(duration: 0.0, curve: .linear)
        }
    }
    
    public var transition: ContainedViewLayoutTransition {
        switch self {
        case .None, .Crossfade:
            return .immediate
        case let .System(_, transition):
            return transition.legacyAnimator.transition
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

public struct ListViewItemApply {
    public let isOnScreen: Bool
    public let timestamp: Double?
    
    public init(isOnScreen: Bool, timestamp: Double? = nil) {
        self.isOnScreen = isOnScreen
        self.timestamp = timestamp
    }
}

public protocol ListViewItem {
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void)
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void)
    
    var accessoryItem: ListViewAccessoryItem? { get }
    var headerAccessoryItem: ListViewAccessoryItem? { get }
    var selectable: Bool { get }
    var approximateHeight: CGFloat { get }
    
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
    
    var approximateHeight: CGFloat {
        return 44.0
    }
    
    func selected(listView: ListView) {
    }
}
