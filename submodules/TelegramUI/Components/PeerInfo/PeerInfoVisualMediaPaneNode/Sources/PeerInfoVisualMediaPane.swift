import Foundation
import AsyncDisplayKit
import TelegramCore
import PeerInfoPaneNode

public protocol PeerInfoVisualMediaPane: PeerInfoPaneNode {
    var contentType: PeerInfoVisualMediaPaneNode.ContentType { get }
    var calendarSource: SparseMessageCalendar? { get }
    var openCurrentDate: (() -> Void)? { get set }
    var paneDidScroll: (() -> Void)? { get set }
    func updateContentType(contentType: PeerInfoVisualMediaPaneNode.ContentType)
    func currentTopTimestamp() -> Int32?
    func scrollToItem(index: Int)
    func brieflyDisableTouchActions()
    func canZoom(isZoomIn: Bool) -> Bool
    func zoom(isZoomIn: Bool)
}

extension PeerInfoVisualMediaPaneNode: PeerInfoVisualMediaPane {
    public func canZoom(isZoomIn: Bool) -> Bool {
        let levels = self.availableZoomLevels()
        return (isZoomIn ? levels.increment : levels.decrement) != nil
    }

    public func zoom(isZoomIn: Bool) {
        let levels = self.availableZoomLevels()
        guard let level = isZoomIn ? levels.increment : levels.decrement else {
            return
        }
        self.updateZoomLevel(level: level)
    }
}
