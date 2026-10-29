import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import ComponentFlow
import ComponentDisplayAdapters
import CoreList
import CoreListComponentHost

/// A `ListViewItem` as a CoreList row, for a list that moves from `ListViewImpl` to `CoreVirtualListView` with its rows as
/// they are (the chat's inline bot results). The node is built and updated through the item's own
/// `nodeConfiguredForParams` / `updateNode`, synchronously, as the chat history's CoreList backend hosts message items
/// (its `CoreListNodeHostView`, which also carries the chat's headers and rotation; this carries neither).
///
/// `content` is the host's value for the row (its entry): a reused row is laid out again exactly when it, the
/// neighbours or the side insets changed. The side insets reach the node as layout params, as `ListViewImpl` passes
/// them, so a row's own background still spans the list's width.
public final class ListViewItemCoreListItem: CoreListItem {
    public let identity: AnyHashable
    public let content: AnyEquatable
    public let listItem: ListViewItem
    public let neighbors: ListViewItemNeighbors
    public let leftInset: CGFloat
    public let rightInset: CGFloat

    public init(identity: AnyHashable, content: AnyEquatable, listItem: ListViewItem, neighbors: ListViewItemNeighbors, leftInset: CGFloat, rightInset: CGFloat) {
        self.identity = identity
        self.content = content
        self.listItem = listItem
        self.neighbors = neighbors
        self.leftInset = leftInset
        self.rightInset = rightInset
    }

    public func view() -> UIView & CoreListItemView {
        return ListViewItemCoreListView(item: self)
    }

    public func isEqual(to other: CoreListItem) -> Bool {
        guard let other = other as? ListViewItemCoreListItem else {
            return false
        }
        return self.identity == other.identity && self.content == other.content && self.neighbors == other.neighbors && self.leftInset == other.leftInset && self.rightInset == other.rightInset
    }

    public func apply(to view: UIView & CoreListItemView, transition: CoreListTransition) {
        (view as? ListViewItemCoreListView)?.setItem(self, transition: transition)
    }
}

/// Hosts a `ListViewItemNode` in a CoreList row. CoreList owns this view's frame; the node fills it.
public final class ListViewItemCoreListView: UIView, CoreListItemView {
    public private(set) var listItem: ListViewItem
    public private(set) var itemNode: ListViewItemNode?
    private var neighbors: ListViewItemNeighbors
    private var leftInset: CGFloat
    private var rightInset: CGFloat
    private var lastWidth: CGFloat = -1.0
    private var lastHeight: CGFloat = 0.0
    private var contentDirty = true
    /// The enclosing pass's transition, for the layout that follows (`setItem`, then `update(width:transition:)`).
    private var pendingTransition: CoreListTransition = .immediate
    /// The last rect from CoreList, held so a node built after it still gets it.
    private var visibleRect: CGRect?

    public var onContentDidChange: ((_ animated: Bool) -> Void)?

    init(item: ListViewItemCoreListItem) {
        self.listItem = item.listItem
        self.neighbors = item.neighbors
        self.leftInset = item.leftInset
        self.rightInset = item.rightInset
        super.init(frame: CGRect())
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    func setItem(_ item: ListViewItemCoreListItem, transition: CoreListTransition) {
        self.listItem = item.listItem
        self.neighbors = item.neighbors
        self.leftInset = item.leftInset
        self.rightInset = item.rightInset
        self.pendingTransition = transition
        self.contentDirty = true
    }

    public func update(width: CGFloat, transition: CoreListTransition) -> CGFloat {
        self.pendingTransition = transition
        if self.itemNode == nil || self.contentDirty || abs(width - self.lastWidth) > 0.5 {
            self.rebuild(width: width)
        }
        if let itemNode = self.itemNode {
            // A backstop for the passes that do not rebuild; it no-ops when `rebuild` installed this frame.
            let frame = CGRect(x: 0.0, y: 0.0, width: width, height: self.lastHeight)
            transition.setFrame(view: itemNode.view, frame: frame)
            itemNode.frame = frame
        }
        return self.lastHeight
    }

    public func visibleRectUpdated(_ visibleRect: CGRect?) {
        self.visibleRect = visibleRect
        self.applyVisibility()
    }

    /// `ListViewImpl`'s formula: the visible part's overlap with the node's content box (the row less its insets), over
    /// that box's height. Assigned only on change: the property's observers can do real work (a widget preview starts).
    private func applyVisibility() {
        guard let itemNode = self.itemNode else {
            return
        }
        var visibility: ListViewItemNodeVisibility = .none
        if let rect = self.visibleRect {
            let contentTop = itemNode.insets.top
            let contentBottom = self.lastHeight - itemNode.insets.bottom
            let contentHeight = contentBottom - contentTop
            var fraction: CGFloat = 0.0
            if contentHeight > 0.0 {
                fraction = max(0.0, min(rect.maxY, contentBottom) - max(rect.minY, contentTop)) / contentHeight
            }
            visibility = .visible(fraction, rect)
        }
        if itemNode.visibility != visibility {
            itemNode.visibility = visibility
        }
    }

    private func rebuild(width: CGFloat) {
        let params = ListViewItemLayoutParams(width: width, leftInset: self.leftInset, rightInset: self.rightInset, availableHeight: .greatestFiniteMagnitude, isStandalone: false)
        if let itemNode = self.itemNode {
            // The pass's transition as the item's own update animation; an immediate one is `.None`, so the item takes
            // none of its animated paths (`ListViewItemUpdateAnimation.isAnimated` is true for any `.System`).
            let animation: ListViewItemUpdateAnimation
            switch ComponentTransition(self.pendingTransition).containedViewLayoutTransition {
            case .immediate:
                animation = .None
            case let .animated(duration, curve):
                animation = .System(duration: duration, transition: ControlledTransition(duration: duration, curve: curve, interactive: false))
            }
            var layoutAndApply: (ListViewItemNodeLayout, (ListViewItemApply) -> Void)?
            self.listItem.updateNode(async: { f in f() }, node: { itemNode }, params: params, neighbors: self.neighbors, animation: animation, completion: { layout, apply in
                layoutAndApply = (layout, apply)
            })
            if let (layout, apply) = layoutAndApply {
                let height = layout.contentSize.height + layout.insets.top + layout.insets.bottom
                // As `ListViewImpl` stamps them, before the apply; under `hostOwnsFrame` they no longer resize the node,
                // so its box is set here, through the pass's transition.
                itemNode.contentSize = layout.contentSize
                itemNode.insets = layout.insets
                let frame = CGRect(x: 0.0, y: 0.0, width: width, height: height)
                self.pendingTransition.setFrame(view: itemNode.view, frame: frame)
                itemNode.frame = frame
                let contentOffsetY = -layout.insets.top
                if abs(itemNode.bounds.origin.y - contentOffsetY) > CGFloat.ulpOfOne {
                    itemNode.bounds.origin.y = contentOffsetY
                }
                apply(ListViewItemApply())
                itemNode.apparentHeight = height
                self.lastHeight = height
            }
        } else {
            var resolvedNode: ListViewItemNode?
            var applyClosure: (() -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void))?
            self.listItem.nodeConfiguredForParams(async: { f in f() }, params: params, synchronousLoads: false, neighbors: self.neighbors, completion: { node, apply in
                resolvedNode = node
                applyClosure = apply
            })
            if let node = resolvedNode {
                if let applyClosure {
                    let (_, apply) = applyClosure()
                    apply(ListViewItemApply())
                }
                let height = node.contentSize.height + node.insets.top + node.insets.bottom
                node.apparentHeight = height
                // Claimed after the build, whose own `contentSize`/`insets` writes give the node its first box.
                node.hostOwnsFrame = true
                self.itemNode = node
                self.addSubview(node.view)
                self.lastHeight = height
            } else {
                // Every item hosted here completes on the main queue inline (`Queue.async` runs at once when current).
                assertionFailure("\(type(of: self.listItem)) built no node synchronously")
                self.lastHeight = 0.0
            }
        }
        self.lastWidth = width
        self.contentDirty = false
        // A relayout can change the insets the fraction divides by, and a new node has none yet.
        self.applyVisibility()
    }
}
