import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import ChatPresentationInterfaceState
import AccountContext
import TelegramCore

public enum ChatHistoryNodeLoadState: Equatable {
    public enum EmptyType: Equatable {
        case generic
        case joined
        case clearedHistory
        case topic
        case botInfo
    }

    case loading(Bool)
    case empty(EmptyType)
    case messages
}

public protocol ChatHistoryNode: AnyObject {
    var historyState: ValuePromise<ChatHistoryNodeHistoryState> { get }
    var preloadPages: Bool { get set }

    var loadState: ChatHistoryNodeLoadState? { get }
    func setLoadStateUpdated(_ f: @escaping (ChatHistoryNodeLoadState, Bool) -> Void)

    func messageInCurrentHistoryView(_ id: EngineMessage.Id) -> EngineMessage?
    func updateLayout(transition: ContainedViewLayoutTransition, updateSizeAndInsets: ListViewUpdateSizeAndInsets)
    func forEachItemNode(_ f: (ASDisplayNode) -> Void)
    func disconnect()
    func scrollToEndOfHistory()
}
