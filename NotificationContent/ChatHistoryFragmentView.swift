import Foundation
import Display
import TelegramCore
import TelegramUI
import Postbox
import SwiftSignalKit

private let accountCache = Atomic<[AccountRecordId: Account]>(value: [:])

private struct ChatHistoryFragmentEntry: Comparable, Identifiable {
    let message: Message
    let read: Bool
    
    var stableId: UInt32 {
        return self.message.stableId
    }
}

private func==(lhs: ChatHistoryFragmentEntry, rhs: ChatHistoryFragmentEntry) -> Bool {
    if MessageIndex(lhs.message) == MessageIndex(rhs.message) && lhs.message.flags == rhs.message.flags {
        if lhs.message.media.count != rhs.message.media.count {
            return false
        }
        if lhs.read != rhs.read {
            return false
        }
        for i in 0 ..< lhs.message.media.count {
            if !lhs.message.media[i].isEqual(rhs.message.media[i]) {
                return false
            }
        }
        return true
    } else {
        return false
    }
}

private func <(lhs: ChatHistoryFragmentEntry, rhs: ChatHistoryFragmentEntry) -> Bool {
    return MessageIndex(lhs.message) < MessageIndex(rhs.message)
}

private final class ChatHistoryFragmentDisplayItem {
    fileprivate let item: ListViewItem
    fileprivate var node: ListViewItemNode?
    
    init(item: ListViewItem) {
        self.item = item
    }
    
    init(item: ListViewItem, node: ListViewItemNode?) {
        self.item = item
        self.node = node
    }
}

final class ChatHistoryFragmentView: UIView {
    private let sizeUpdated: (CGSize) -> Void
    
    private var layoutWidth: CGFloat?
    private var displayItems: [ChatHistoryFragmentDisplayItem] = []
    
    private let disposable = MetaDisposable()
    
    let account = Promise<Account>()
    
    init(peerId: PeerId, width: CGFloat, sizeUpdated: @escaping (CGSize) -> Void) {
        self.sizeUpdated = sizeUpdated
        self.layoutWidth = width
        
        super.init(frame: CGRect())
        
        /*let appBundleIdentifier = Bundle.main.bundleIdentifier!
        guard let lastDotRange = appBundleIdentifier.range(of: ".", options: [.backwards]) else {
            return
        }
        
        let appGroupName = "group.\(appBundleIdentifier.substring(to: lastDotRange.lowerBound))"
        let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
        
        guard let appGroupUrl = maybeAppGroupUrl else {
            return
        }
        
        let accountPromise = self.account
        
        let accountId = currentAccountId(appGroupPath: appGroupUrl.path, testingEnvironment: false)
        
        let authorizedAccount: Signal<Account, NoError>
        let cachedAccount = accountCache.with { dict -> Account? in
            if let account = dict[accountId] {
                return account
            } else {
                return nil
            }
        }
        if let cachedAccount = cachedAccount {
            authorizedAccount = .single(cachedAccount)
        } else {
            authorizedAccount = accountWithId(accountId, appGroupPath: appGroupUrl.path, logger: .named("notification-content"), testingEnvironment: false) |> mapToSignal { account -> Signal<Account, NoError> in
                switch account {
                    case .left:
                        return .complete()
                    case let .right(authorizedAccount):
                        setupAccount(authorizedAccount)
                        let _ = accountCache.modify { dict in
                            var dict = dict
                            dict[accountId] = authorizedAccount
                            return dict
                        }
                        return .single(authorizedAccount)
                }
            }
        }
        
        let view = authorizedAccount
            |> take(1)
            |> mapToSignal { account -> Signal<(Account, MessageHistoryView, ViewUpdateType), NoError> in
                accountPromise.set(.single(account))
                account.stateManager.reset()
                account.shouldBeServiceTaskMaster.set(.single(.now))
                let view = account.viewTracker.aroundMessageHistoryViewForPeerId(peerId, index: MessageIndex.upperBound(peerId: peerId), count: 20, anchorIndex: MessageIndex.upperBound(peerId: peerId), fixedCombinedReadStates: nil, tagMask: nil)
                    |> map { view, updateType, _ -> (Account, MessageHistoryView, ViewUpdateType) in
                        return (account, view, updateType)
                    }
                return view
            }
        
        let previousEntries = Atomic<[ChatHistoryFragmentEntry]>(value: [])
        
        let controllerInteraction = ChatControllerInteraction(openMessage: { _ in }, openSecretMessagePreview: { _ in }, closeSecretMessagePreview: { }, openPeer: { _ in }, openPeerMention: { _ in }, openMessageContextMenu: { _ in }, navigateToMessage: { _ in }, clickThroughMessage: { }, toggleMessagesSelection: { _ in }, sendMessage: { _ in }, sendSticker: { _ in }, requestMessageActionCallback: { _ in }, openUrl: { _ in }, shareCurrentLocation: {}, shareAccountContact: {}, sendBotCommand: { _, _ in }, openInstantPage: { _ in }, openHashtag: { _ in }, updateInputState: { _ in })
        
        let messages = view
            |> map { (account, view, viewUpdateType) -> (Account, [ChatHistoryFragmentEntry], [Int: Int]) in
                var entries: [ChatHistoryFragmentEntry] = []
                for entry in view.entries.reversed() {
                    switch entry {
                        case let .MessageEntry(message, read, _):
                            entries.append(ChatHistoryFragmentEntry(message: message, read: read))
                        default:
                            break
                    }
                }
                
                var previousIndices: [Int: Int] = [:]
                let _ = previousEntries.modify { previousEntries in
                    var index = 0
                    for entry in entries {
                        var previousIndex = 0
                        for previousEntry in previousEntries {
                            if previousEntry.stableId == entry.stableId {
                                previousIndices[index] = previousIndex
                                break
                            }
                            previousIndex += 1
                        }
                        index += 1
                    }
                    
                    return entries
                }
                
                return (account, entries, previousIndices)
            }
        
        let displayItems = messages
            |> map { (account, messages, previousIndices) -> ([ChatHistoryFragmentDisplayItem], [Int: Int]) in
                var result: [ChatHistoryFragmentDisplayItem] = []
                for entry in messages {
                    result.append(ChatHistoryFragmentDisplayItem(item: ChatMessageItem(account: account, peerId: peerId, controllerInteraction: controllerInteraction, message: entry.message, read: entry.read)))
                }
                return (result, previousIndices)
            }
        
        let semaphore = DispatchSemaphore(value: 0)
        var resultItems: [ChatHistoryFragmentDisplayItem]?
        disposable.set(displayItems.start(next: { [weak self] (displayItems, previousIndices) in
            if resultItems == nil {
                resultItems = displayItems
                semaphore.signal()
            } else {
                Queue.mainQueue().async {
                    if let strongSelf = self {
                        var updatedDisplayItems: [ChatHistoryFragmentDisplayItem] = []
                        for i in 0 ..< displayItems.count {
                            if let previousIndex = previousIndices[i] {
                                updatedDisplayItems.append(ChatHistoryFragmentDisplayItem(item: displayItems[i].item, node: strongSelf.displayItems[previousIndex].node))
                            } else {
                                updatedDisplayItems.append(displayItems[i])
                            }
                        }
                        let previousIndexSet = Set(previousIndices.values)
                        for i in 0 ..< strongSelf.displayItems.count {
                            if !previousIndexSet.contains(i) {
                                strongSelf.displayItems[i].node?.removeFromSupernode()
                            }
                        }
                        strongSelf.displayItems = updatedDisplayItems
                        if let layoutWidth = strongSelf.layoutWidth {
                            strongSelf.updateDisplayItems(width: layoutWidth)
                        }
                    }
                }
            }
        }))
        semaphore.wait()
        if let resultItems = resultItems {
            self.displayItems = resultItems
        }
        if let layoutWidth = self.layoutWidth {
            self.updateDisplayItems(width: layoutWidth)
        }*/
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    private func updateDisplayItems(width: CGFloat) {
        for i in 0 ..< self.displayItems.count {
            if let node = self.displayItems[i].node {
                self.displayItems[i].item.updateNode(async: { $0() }, node: node, width: width, previousItem: i == 0 ? nil : self.displayItems[i - 1].item, nextItem: i == self.displayItems.count - 1 ? nil : self.displayItems[i + 1].item, animation: .None, completion: { layout, apply in
                    node.insets = layout.insets
                    node.contentSize = layout.contentSize
                    apply()
                })
                node.layoutForWidth(width, item: self.displayItems[i].item, previousItem: i == 0 ? nil : self.displayItems[i - 1].item, nextItem: i == self.displayItems.count - 1 ? nil : self.displayItems[i + 1].item)
            } else {
                self.displayItems[i].item.nodeConfiguredForWidth(async: { $0() }, width: width, previousItem: i == 0 ? nil : self.displayItems[i - 1].item, nextItem: i == self.displayItems.count - 1 ? nil : self.displayItems[i + 1].item, completion: { node, apply in
                    apply()
                    self.displayItems[i].node = node
                    self.addSubnode(node)
                })
            }
        }
        
        var verticalOffset: CGFloat = 4.0
        for displayItem in self.displayItems {
            if let node = displayItem.node {
                node.frame = CGRect(origin: CGPoint(x: 0.0, y: verticalOffset), size: node.layout.size)
                verticalOffset += node.layout.size.height
            }
        }
        
        let displaySize = CGSize(width: width, height: verticalOffset + 4.0)
        self.sizeUpdated(displaySize)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if self.layoutWidth != self.bounds.size.width {
            self.layoutWidth = self.bounds.size.width
            self.updateDisplayItems(width: self.bounds.size.width)
        }
    }
}
