import Foundation
import Postbox
import SwiftSignalKit
import Display

public enum ChatHistoryNodeHistoryState: Equatable {
    case loading
    case loaded(isEmpty: Bool)
    
    public static func ==(lhs: ChatHistoryNodeHistoryState, rhs: ChatHistoryNodeHistoryState) -> Bool {
        switch lhs {
            case .loading:
                if case .loading = rhs {
                    return true
                } else {
                    return false
                }
            case let .loaded(isEmpty):
                if case .loaded(isEmpty) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public protocol ChatHistoryNode: class {
    var historyState: ValuePromise<ChatHistoryNodeHistoryState> { get }
    var preloadPages: Bool { get set }
    
    func messageInCurrentHistoryView(_ id: MessageId) -> Message?
    func updateLayout(transition: ContainedViewLayoutTransition, updateSizeAndInsets: ListViewUpdateSizeAndInsets)
    func forEachItemNode(_ f: (ASDisplayNode) -> Void)
}
