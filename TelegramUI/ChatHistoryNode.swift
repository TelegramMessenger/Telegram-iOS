import Foundation
import Postbox
import SwiftSignalKit
import Display

public protocol ChatHistoryNode: class {
    var historyReady: Promise<Bool> { get }
    var preloadPages: Bool { get set }
    
    func messageInCurrentHistoryView(_ id: MessageId) -> Message?
    func updateLayout(transition: ContainedViewLayoutTransition, updateSizeAndInsets: ListViewUpdateSizeAndInsets)
    func forEachItemNode(_ f: @noescape(ASDisplayNode) -> Void)
}
