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

public final class ListViewItemApply {
    public let timestamp: Double?
    public private(set) var invertOffsetDirection: Bool = false

    public init(timestamp: Double? = nil) {
        self.timestamp = timestamp
    }

    public func setInvertOffsetDirection() {
        self.invertOffsetDirection = true
    }
}

public protocol ListViewItem: AnyObject {
    /// Everything a *neighbor* is permitted to know about this item.
    ///
    /// Load-bearing: a descriptor must encode everything a neighbor reads. Backends relayout a row
    /// exactly when this value changes on either side, so a fact omitted here goes stale on screen.
    /// Recover payloads with `AnyEquatable.base(_:)`, passing a facet protocol.
    ///
    /// Use `AnyEquatable.noNeighborInfluence` for items whose neighbors read nothing about them.
    var neighborDescriptor: AnyEquatable { get }

    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void)
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void)
    
    var accessoryItem: ListViewAccessoryItem? { get }
    var headerAccessoryItem: ListViewAccessoryItem? { get }
    var selectable: Bool { get }
    var approximateHeight: CGFloat { get }
    var pinToEdgeWithInset: Bool { get }
    
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
    
    var pinToEdgeWithInset: Bool {
        return false
    }
    
    func selected(listView: ListView) {
    }
    
    func performSecondaryAction(listView: ListView) {
    }
}
