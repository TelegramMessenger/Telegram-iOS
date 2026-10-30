import Foundation
import UIKit
import UIKit.UIGestureRecognizerSubclass
import Display
import CoreList

/// `ListViewImpl`'s tap selection (its `touchesBegan`/`touchesMoved`/`touchesEnded`) for a CoreList of
/// `ListViewItemCoreListView` rows. A touch on a selectable row highlights it after 0.08 s unless it has moved more than
/// 4 pt; its lift, within 4 pt of where it went down, highlights it then too and tells the row's node `selected()`. The
/// list's drag ends it: the host calls `cancel()` from the list's `willBeginDragging`. A touch that lands on moving
/// content stops it and selects nothing (`CoreVirtualListView.lastTouchCaughtMovingContent`, read at the highlight and at
/// the lift): the list's drag cannot be relied on to begin before the lift there, since an ancestor's interactive pop
/// recognizer holds every pan until it fails. `ListViewItem.selected(listView:)` is not called: there is no `ListView`.
///
/// Added to the list's `scrollGestureHostView`. It recognizes only at the lift and lets every recognizer recognize
/// beside it, so it never holds the scroll pan (whose own delegate grants nothing; CoreList's guide, "the limbo gotcha").
public final class ListViewItemCoreListSelectionRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    private weak var list: CoreVirtualListView?
    private weak var touchedRow: ListViewItemCoreListView?
    private weak var highlightedNode: ListViewItemNode?
    private var touchLocation: CGPoint?
    private var highlightTimer: Foundation.Timer?

    public init(list: CoreVirtualListView) {
        self.list = list
        super.init(target: nil, action: nil)
        self.delegate = self
        self.cancelsTouchesInView = false
        self.delaysTouchesBegan = false
        self.delaysTouchesEnded = false
    }

    /// Ends a touch's selection without selecting: the list began to drag.
    public func cancel() {
        guard self.touchLocation != nil else {
            return
        }
        self.clearHighlight(animated: false)
        self.endTouch()
        if self.state == .possible {
            self.state = .failed
        }
    }

    public func clearHighlight(animated: Bool) {
        if let node = self.highlightedNode {
            self.highlightedNode = nil
            node.setHighlighted(false, at: CGPoint(), animated: animated)
        }
    }

    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard self.touchLocation == nil, touches.count == 1, let list = self.list, let location = touches.first?.location(in: list), let row = self.selectableRow(at: location, in: list) else {
            self.fail()
            return
        }
        self.touchLocation = location
        self.touchedRow = row
        let timer = Foundation.Timer(timeInterval: 0.08, repeats: false, block: { [weak self] _ in
            self?.highlightTouchedRow()
        })
        self.highlightTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let touchLocation = self.touchLocation, let list = self.list, let location = touches.first?.location(in: list) else {
            return
        }
        if self.isFar(location, from: touchLocation) {
            self.clearHighlight(animated: false)
            self.fail()
        }
    }

    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        guard let touchLocation = self.touchLocation, let row = self.touchedRow, let node = row.itemNode, let list = self.list, !list.lastTouchCaughtMovingContent else {
            self.clearHighlight(animated: false)
            self.fail()
            return
        }
        // The lift too, not only the moves: a swipe delivered as a touch-down and a far lift with no moves between
        // (synthesized input; it sent a result twice on the simulator, 2026-10-28 and 2026-10-29) is not a tap.
        if let location = touches.first?.location(in: list), self.isFar(location, from: touchLocation) {
            self.clearHighlight(animated: false)
            self.fail()
            return
        }
        self.highlightTouchedRow()
        self.endTouch()
        self.state = .ended
        node.selected()
    }

    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        self.clearHighlight(animated: false)
        self.endTouch()
        self.state = .cancelled
    }

    override public func reset() {
        super.reset()
        self.endTouch()
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    /// `ListViewImpl`'s threshold: a touch that moved more than 4 pt is not a tap.
    private func isFar(_ location: CGPoint, from touchLocation: CGPoint) -> Bool {
        let dx = location.x - touchLocation.x
        let dy = location.y - touchLocation.y
        return dx * dx + dy * dy > 4.0 * 4.0
    }

    private func fail() {
        self.clearHighlight(animated: false)
        self.endTouch()
        if self.state == .possible {
            self.state = .failed
        }
    }

    private func endTouch() {
        self.highlightTimer?.invalidate()
        self.highlightTimer = nil
        self.touchLocation = nil
    }

    private func highlightTouchedRow() {
        guard let row = self.touchedRow, let node = row.itemNode, self.highlightedNode !== node, let list = self.list, let location = self.touchLocation, !list.lastTouchCaughtMovingContent else {
            return
        }
        self.clearHighlight(animated: false)
        self.highlightedNode = node
        // In the node, which fills the row as presented (`convert` would compose the content host's model offset).
        let frame = list.presentedFrame(of: row)
        node.setHighlighted(true, at: CGPoint(x: location.x - frame.minX + node.bounds.minX, y: location.y - frame.minY + node.bounds.minY), animated: false)
    }

    /// The loaded row under `location` (in the list's coordinates, where it is on screen), if its item is selectable and
    /// its node can be selected there.
    private func selectableRow(at location: CGPoint, in list: CoreVirtualListView) -> ListViewItemCoreListView? {
        for view in list.loadedItemViews {
            guard let row = view as? ListViewItemCoreListView else {
                continue
            }
            let frame = list.presentedFrame(of: row)
            guard frame.contains(location) else {
                continue
            }
            guard row.listItem.selectable, let node = row.itemNode, node.canBeSelected else {
                return nil
            }
            // In the node, which fills the row with its bounds' origin at its content offset.
            let point = CGPoint(x: location.x - frame.minX + node.bounds.minX, y: location.y - frame.minY + node.bounds.minY)
            return node.isLayerBacked || node.visibleForSelection(at: point) ? row : nil
        }
        return nil
    }
}
