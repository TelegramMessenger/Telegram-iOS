import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import Display

public enum ChatHistoryNodeHistoryState: Equatable {
    case loading
    case loaded(isEmpty: Bool)
}

public enum ChatHistoryNodeLoadState: Equatable {
    public enum EmptyType: Equatable {
        case generic
        case joined
        case clearedHistory
    }
    
    case loading
    case empty(EmptyType)
    case messages
}

public protocol ChatHistoryNode: class {
    var historyState: ValuePromise<ChatHistoryNodeHistoryState> { get }
    var preloadPages: Bool { get set }
    
    var loadState: ChatHistoryNodeLoadState? { get }
    func setLoadStateUpdated(_ f: @escaping (ChatHistoryNodeLoadState, Bool) -> Void)
    
    func messageInCurrentHistoryView(_ id: MessageId) -> Message?
    func updateLayout(transition: ContainedViewLayoutTransition, updateSizeAndInsets: ListViewUpdateSizeAndInsets)
    func forEachItemNode(_ f: (ASDisplayNode) -> Void)
    func disconnect()
    func scrollToEndOfHistory()
}
