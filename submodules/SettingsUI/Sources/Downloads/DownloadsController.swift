import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import ReactionImageComponent
import WebPBinding
import FetchManagerImpl
import ListMessageItem
import ListSectionHeaderNode

private struct DownloadItem: Equatable {
    let resourceId: MediaResourceId
    let message: Message
    let priority: FetchManagerPriorityKey
    
    static func ==(lhs: DownloadItem, rhs: DownloadItem) -> Bool {
        if lhs.resourceId != rhs.resourceId {
            return false
        }
        if lhs.message.id != rhs.message.id {
            return false
        }
        if lhs.priority != rhs.priority {
            return false
        }
        return true
    }
}

private final class DownloadsControllerArguments {
    let context: AccountContext
    
    init(
        context: AccountContext
    ) {
        self.context = context
    }
}

private enum DownloadsControllerSection: Int32 {
    case items
}

public final class DownloadsItemHeader: ListViewItemHeader {
    public let id: ListViewItemNode.HeaderId
    public let title: String
    public let stickDirection: ListViewItemHeaderStickDirection = .top
    public let stickOverInsets: Bool = true
    public let theme: PresentationTheme
    
    public let height: CGFloat = 28.0
    
    public init(id: ListViewItemNode.HeaderId, title: String, theme: PresentationTheme) {
        self.id = id
        self.title = title
        self.theme = theme
    }

    public func combinesWith(other: ListViewItemHeader) -> Bool {
        if let other = other as? DownloadsItemHeader, other.id == self.id {
            return true
        } else {
            return false
        }
    }
    
    public func node(synchronousLoad: Bool) -> ListViewItemHeaderNode {
        return DownloadsItemHeaderNode(title: self.title, theme: self.theme)
    }
    
    public func updateNode(_ node: ListViewItemHeaderNode, previous: ListViewItemHeader?, next: ListViewItemHeader?) {
        (node as? DownloadsItemHeaderNode)?.update(title: self.title)
    }
}

public final class DownloadsItemHeaderNode: ListViewItemHeaderNode {
    private var title: String
    private var theme: PresentationTheme
    
    private var validLayout: (size: CGSize, leftInset: CGFloat, rightInset: CGFloat)?
    
    private let sectionHeaderNode: ListSectionHeaderNode
    
    public init(title: String, theme: PresentationTheme) {
        self.title = title
        self.theme = theme
        
        self.sectionHeaderNode = ListSectionHeaderNode(theme: theme)
        
        super.init()
        
        self.sectionHeaderNode.title = title
        self.sectionHeaderNode.action = nil
        
        self.addSubnode(self.sectionHeaderNode)
    }
    
    public func updateTheme(theme: PresentationTheme) {
        self.theme = theme
        self.sectionHeaderNode.updateTheme(theme: theme)
    }
    
    public func update(title: String) {
        self.sectionHeaderNode.title = title
        self.sectionHeaderNode.action = nil
        
        if let (size, leftInset, rightInset) = self.validLayout {
            self.sectionHeaderNode.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset)
        }
    }
    
    override public func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat) {
        self.validLayout = (size, leftInset, rightInset)
        self.sectionHeaderNode.frame = CGRect(origin: CGPoint(), size: size)
        self.sectionHeaderNode.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset)
    }
    
    override public func animateRemoved(duration: Double) {
        self.alpha = 0.0
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: true)
    }
}

private enum DownloadsControllerEntry: ItemListNodeEntry {
    enum StableId: Hashable {
        case item(MediaResourceId)
    }
    
    case item(item: DownloadItem)
    
    var section: ItemListSectionId {
        switch self {
        case .item:
            return DownloadsControllerSection.items.rawValue
        }
    }
    
    var stableId: StableId {
        switch self {
        case let .item(item):
            return .item(item.resourceId)
        }
    }
    
    var sortId: FetchManagerPriorityKey {
        switch self {
        case let .item(item):
            return item.priority
        }
    }
    
    static func ==(lhs: DownloadsControllerEntry, rhs: DownloadsControllerEntry) -> Bool {
        switch lhs {
        case let .item(item):
            if case .item(item) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: DownloadsControllerEntry, rhs: DownloadsControllerEntry) -> Bool {
        return lhs.sortId < rhs.sortId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! DownloadsControllerArguments
        let _ = arguments
        switch self {
        case let .item(item):
            let listInteraction = ListMessageItemInteraction(openMessage: { message, mode -> Bool in
                return false
            }, openMessageContextMenu: { message, _, node, rect, gesture in
            }, toggleMessagesSelection: { messageId, selected in
            }, openUrl: { url, _, _, message in
            }, openInstantPage: { message, data in
            }, longTap: { action, message in
            }, getHiddenMedia: {
                return [:]
            })
            
            let presentationData = arguments.context.sharedContext.currentPresentationData.with({ $0 })
            
            return ListMessageItem(presentationData: ChatPresentationData(presentationData: presentationData), context: arguments.context, chatLocation: .peer(item.message.id.peerId), interaction: listInteraction, message: item.message, selection: .none, displayHeader: false, customHeader: nil/*DownloadsItemHeader(id: ListViewItemNode.HeaderId(space: 0, id: item.message.id.peerId), title: item.message.peers[item.message.id.peerId].flatMap(EnginePeer.init)?.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder) ?? "", theme: presentationData.theme)*/, hintIsLink: false, isGlobalSearchResult: false)
        }
    }
}

private struct DownloadsControllerState: Equatable {
    var hasReaction: Bool = false
}

private func downloadsControllerEntries(
    presentationData: PresentationData,
    items: [DownloadItem],
    state: DownloadsControllerState
) -> [DownloadsControllerEntry] {
    var entries: [DownloadsControllerEntry] = []
    
    var index = 0
    for item in items {
        entries.append(.item(
            item: item
        ))
        index += 1
    }
    
    return entries
}

public func downloadsController(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil
) -> ViewController {
    let statePromise = ValuePromise(DownloadsControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: DownloadsControllerState())
    let updateState: ((DownloadsControllerState) -> DownloadsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    let _ = updateState
    
    var dismissImpl: (() -> Void)?
    let _ = dismissImpl
    
    let actionsDisposable = DisposableSet()
    
    let arguments = DownloadsControllerArguments(
        context: context
    )
    
    let settings = context.account.postbox.preferencesView(keys: [PreferencesKeys.reactionSettings])
    |> map { preferencesView -> ReactionSettings in
        let reactionSettings: ReactionSettings
        if let entry = preferencesView.values[PreferencesKeys.reactionSettings], let value = entry.get(ReactionSettings.self) {
            reactionSettings = value
        } else {
            reactionSettings = .default
        }
        return reactionSettings
    }
    
    let downloadItems: Signal<[DownloadItem], NoError> = (context.fetchManager as! FetchManagerImpl).entriesSummary
    |> mapToSignal { entries -> Signal<[DownloadItem], NoError> in
        var itemSignals: [Signal<DownloadItem?, NoError>] = []
        
        for entry in entries {
            switch entry.id.locationKey {
            case let .messageId(id):
                itemSignals.append(context.account.postbox.transaction { transaction -> DownloadItem? in
                    if let message = transaction.getMessage(id) {
                        return DownloadItem(resourceId: entry.resourceReference.resource.id, message: message, priority: entry.priority)
                    }
                    return nil
                })
            default:
                break
            }
        }
        
        return combineLatest(queue: .mainQueue(), itemSignals)
        |> map { items -> [DownloadItem] in
            return items.compactMap { $0 }
        }
    }
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(queue: .mainQueue(),
        presentationData,
        statePromise.get(),
        context.engine.stickers.availableReactions(),
        settings,
        downloadItems
    )
    |> deliverOnMainQueue
    |> map { presentationData, state, availableReactions, settings, downloadItems -> (ItemListControllerState, (ItemListNodeState, Any)) in
        //TODO:localize
        let title: String = "Downloads"
        
        let entries = downloadsControllerEntries(
            presentationData: presentationData,
            items: downloadItems,
            state: state
        )
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(title),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: false
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .plain,
            animateChanges: true
        )
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    controller.didScrollWithOffset = { [weak controller] offset, transition, _ in
        guard let controller = controller else {
            return
        }
        controller.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ReactionChatPreviewItemNode {
                itemNode.standaloneReactionAnimation?.addRelativeContentOffset(CGPoint(x: 0.0, y: offset), transition: transition)
            }
        }
    }
    
    dismissImpl = { [weak controller] in
        guard let controller = controller else {
            return
        }
        controller.dismiss()
    }
    
    return controller
}

