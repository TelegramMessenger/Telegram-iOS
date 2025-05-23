import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import TelegramCore
import Display
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import ChatPresentationInterfaceState
import ChatControllerInteraction
import ItemListUI
import ChatContextQuery
import ChatInputContextPanelNode
import ChatListUI
import ComponentFlow
import ComponentDisplayAdapters

private enum CommandChatInputContextPanelEntryStableId: Hashable {
    case editShortcuts
    case command(PeerCommand)
    case shortcut(Int32)
}

private struct CommandChatInputContextPanelEntry: Comparable, Identifiable {
    struct Command: Equatable {
        let command: ChatInputTextCommand
        let accountPeer: EnginePeer?
        let searchQuery: String?
        
        static func ==(lhs: Command, rhs: Command) -> Bool {
            return lhs.command == rhs.command && lhs.accountPeer == rhs.accountPeer && lhs.searchQuery == rhs.searchQuery
        }
    }
    
    enum Content: Equatable {
        case editShortcuts
        case command(Command)
    }
    
    let content: Content
    let index: Int
    let theme: PresentationTheme
    
    init(index: Int, content: Content, theme: PresentationTheme) {
        self.content = content
        self.index = index
        self.theme = theme
    }
    
    static func ==(lhs: CommandChatInputContextPanelEntry, rhs: CommandChatInputContextPanelEntry) -> Bool {
        return lhs.index == rhs.index && lhs.content == rhs.content && lhs.theme === rhs.theme
    }
    
    static func <(lhs: CommandChatInputContextPanelEntry, rhs: CommandChatInputContextPanelEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    var stableId: CommandChatInputContextPanelEntryStableId {
        switch self.content {
        case .editShortcuts:
            return .editShortcuts
        case let .command(command):
            switch command.command {
            case let .command(command):
                return .command(command)
            case let .shortcut(shortcut):
                if let shortcutId = shortcut.id {
                    return .shortcut(shortcutId)
                } else {
                    return .shortcut(0)
                }
            }
        }
    }
    
    func withUpdatedTheme(_ theme: PresentationTheme) -> CommandChatInputContextPanelEntry {
        return CommandChatInputContextPanelEntry(index: self.index, content: self.content, theme: theme)
    }
    
    func item(context: AccountContext, presentationData: PresentationData, commandSelected: @escaping (ChatInputTextCommand, Bool) -> Void, openEditShortcuts: @escaping () -> Void) -> ListViewItem {
        switch self.content {
        case .editShortcuts:
            return VerticalListContextResultsChatInputPanelButtonItem(theme: presentationData.theme, style: .round, title: presentationData.strings.Chat_CommandList_EditQuickReplies, pressed: {
                openEditShortcuts()
            })
        case let .command(command):
            switch command.command {
            case let .command(command):
                return CommandChatInputPanelItem(context: context, presentationData: ItemListPresentationData(presentationData), command: command, commandSelected: { value, sendImmediately in
                    commandSelected(.command(value), sendImmediately)
                })
            case let .shortcut(shortcut):
                let chatListNodeInteraction = ChatListNodeInteraction(
                    context: context,
                    animationCache: context.animationCache,
                    animationRenderer: context.animationRenderer,
                    activateSearch: {
                    },
                    peerSelected: { _, _, _, _, _ in
                        commandSelected(.shortcut(shortcut), true)
                    },
                    disabledPeerSelected: { _, _, _ in
                    },
                    togglePeerSelected: { _, _ in
                    },
                    togglePeersSelection: { _, _ in
                    },
                    additionalCategorySelected: { _ in
                    },
                    messageSelected: { _, _, _, _ in
                        commandSelected(.shortcut(shortcut), true)
                    },
                    groupSelected: { _ in
                    },
                    addContact: { _ in
                    },
                    setPeerIdWithRevealedOptions: { _, _ in
                    },
                    setItemPinned: { _, _ in
                    },
                    setPeerMuted: { _, _ in
                    },
                    setPeerThreadMuted: { _, _, _ in
                    },
                    deletePeer: { _, _ in
                    },
                    deletePeerThread: { _, _ in
                    },
                    setPeerThreadStopped: { _, _, _ in
                    },
                    setPeerThreadPinned: { _, _, _ in
                    },
                    setPeerThreadHidden: { _, _, _ in
                    },
                    updatePeerGrouping: { _, _ in
                    },
                    togglePeerMarkedUnread: { _, _ in
                    },
                    toggleArchivedFolderHiddenByDefault: {
                    },
                    toggleThreadsSelection: { _, _ in
                    },
                    hidePsa: { _ in
                    },
                    activateChatPreview: { _, _, _, _, _ in
                    },
                    present: { _ in
                    },
                    openForumThread: { _, _ in
                    },
                    openStorageManagement: {
                    },
                    openPasswordSetup: {
                    },
                    openPremiumIntro: {
                    },
                    openPremiumGift: { _, _ in
                    },
                    openPremiumManagement: {
                    },
                    openActiveSessions: {
                    },
                    openBirthdaySetup: {
                    },
                    performActiveSessionAction: { _, _ in
                    },
                    openChatFolderUpdates: {
                    },
                    hideChatFolderUpdates: {
                    },
                    openStories: { _, _ in
                    },
                    openStarsTopup: { _ in
                    },
                    dismissNotice: { _ in
                    },
                    editPeer: { _ in
                    },
                    openWebApp: { _ in
                    },
                    openPhotoSetup: {
                    },
                    openAdInfo: { _, _ in
                    },
                    openAccountFreezeInfo: {
                    },
                    openUrl: { _ in
                    }
                )
                
                let chatListPresentationData = ChatListPresentationData(
                    theme: presentationData.theme,
                    fontSize: presentationData.listsFontSize,
                    strings: presentationData.strings,
                    dateTimeFormat: presentationData.dateTimeFormat,
                    nameSortOrder: presentationData.nameSortOrder,
                    nameDisplayOrder: presentationData.nameDisplayOrder,
                    disableAnimations: false
                )
                
                let renderedPeer: EngineRenderedPeer
                if let accountPeer = command.accountPeer {
                    renderedPeer = EngineRenderedPeer(peer: accountPeer)
                } else {
                    renderedPeer = EngineRenderedPeer(peerId: context.account.peerId, peers: [:], associatedMedia: [:])
                }
                
                return ChatListItem(
                    presentationData: chatListPresentationData,
                    context: context,
                    chatListLocation: .chatList(groupId: .root),
                    filterData: nil,
                    index: EngineChatList.Item.Index.chatList(ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex(id: MessageId(peerId: context.account.peerId, namespace: 0, id: 0), timestamp: 0))),
                    content: .peer(ChatListItemContent.PeerData(
                        messages: [shortcut.topMessage],
                        peer: renderedPeer,
                        threadInfo: nil,
                        combinedReadState: nil,
                        isRemovedFromTotalUnreadCount: false,
                        presence: nil,
                        hasUnseenMentions: false,
                        hasUnseenReactions: false,
                        draftState: nil,
                        mediaDraftContentType: nil,
                        inputActivities: nil,
                        promoInfo: nil,
                        ignoreUnreadBadge: false,
                        displayAsMessage: false,
                        hasFailedMessages: false,
                        forumTopicData: nil,
                        topForumTopicItems: [],
                        autoremoveTimeout: nil,
                        storyState: nil,
                        requiresPremiumForMessaging: false,
                        displayAsTopicList: false,
                        tags: [],
                        customMessageListData: ChatListItemContent.CustomMessageListData(
                            commandPrefix: "/\(shortcut.shortcut)",
                            searchQuery: command.searchQuery.flatMap { "/\($0)"},
                            messageCount: shortcut.totalCount,
                            hideSeparator: false,
                            hideDate: true,
                            hidePeerStatus: true
                        )
                    )),
                    editing: false,
                    hasActiveRevealControls: false,
                    selected: false,
                    header: nil,
                    enabledContextActions: nil,
                    hiddenOffset: false,
                    interaction: chatListNodeInteraction
                )
            }
        }
    }
}

private struct CommandChatInputContextPanelTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let hasShortcuts: Bool
    let itemCountChanged: Bool
}

private func preparedTransition(from fromEntries: [CommandChatInputContextPanelEntry], to toEntries: [CommandChatInputContextPanelEntry], context: AccountContext, presentationData: PresentationData,  commandSelected: @escaping (ChatInputTextCommand, Bool) -> Void, openEditShortcuts: @escaping () -> Void) -> CommandChatInputContextPanelTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, commandSelected: commandSelected, openEditShortcuts: openEditShortcuts), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, commandSelected: commandSelected, openEditShortcuts: openEditShortcuts), directionHint: nil) }
    
    let itemCountChanged = fromEntries.count != toEntries.count
    
    return CommandChatInputContextPanelTransition(deletions: deletions, insertions: insertions, updates: updates, hasShortcuts: toEntries.contains(where: { entry in
        if case .editShortcuts = entry.content {
            return true
        }
        return false
    }), itemCountChanged: itemCountChanged)
}

final class CommandChatInputContextPanelNode: ChatInputContextPanelNode {
    private let listView: ListView
    private let listBackgroundView: UIView
    private var currentEntries: [CommandChatInputContextPanelEntry]?
    private var contentOffsetChangeTransition: ComponentTransition?
    private var isAnimatingOut: Bool = false
    
    private var enqueuedTransitions: [(CommandChatInputContextPanelTransition, Bool)] = []
    private var validLayout: (CGSize, CGFloat, CGFloat, CGFloat)?
    
    override init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize, chatPresentationContext: ChatPresentationContext) {
        self.listView = ListView()
        self.listView.isOpaque = false
        self.listView.stackFromBottom = true
        self.listView.keepBottomItemOverscrollBackground = theme.list.plainBackgroundColor
        self.listView.limitHitTestToNodes = true
        self.listView.view.disablesInteractiveTransitionGestureRecognizer = true
        self.listView.accessibilityPageScrolledString = { row, count in
            return strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        self.listBackgroundView = UIView()
        self.listBackgroundView.backgroundColor = theme.list.plainBackgroundColor
        self.listBackgroundView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        self.listBackgroundView.layer.cornerRadius = 10.0
        
        super.init(context: context, theme: theme, strings: strings, fontSize: fontSize, chatPresentationContext: chatPresentationContext)
        
        self.isOpaque = false
        self.clipsToBounds = true
        
        self.view.addSubview(self.listBackgroundView)
        self.addSubnode(self.listView)
        
        self.listView.visibleContentOffsetChanged = { [weak self] offset in
            guard let self else {
                return
            }
            
            if self.isAnimatingOut {
                return
            }
            
            var topItemOffset: CGFloat = self.listView.bounds.height
            var isFirst = true
            self.listView.forEachItemNode { itemNode in
                if isFirst {
                    isFirst = false
                    topItemOffset = itemNode.frame.minY
                }
            }
            
            let transition: ComponentTransition = self.contentOffsetChangeTransition ?? .immediate
            transition.setFrame(view: self.listBackgroundView, frame: CGRect(origin: CGPoint(x: 0.0, y: topItemOffset), size: CGSize(width: self.listView.bounds.width, height: self.listView.bounds.height + 1000.0)))
        }
    }
    
    func updateResults(_ results: [ChatInputTextCommand], accountPeer: EnginePeer?, hasShortcuts: Bool, query: String?) {
        var entries: [CommandChatInputContextPanelEntry] = []
        var index = 0
        var stableIds = Set<CommandChatInputContextPanelEntryStableId>()
        if hasShortcuts {
            let entry = CommandChatInputContextPanelEntry(index: index, content: .editShortcuts, theme: self.theme)
            stableIds.insert(entry.stableId)
            entries.append(entry)
            index += 1
        }
        for command in results {
            let entry = CommandChatInputContextPanelEntry(index: index, content: .command(CommandChatInputContextPanelEntry.Command(command: command, accountPeer: accountPeer, searchQuery: query)), theme: self.theme)
            if stableIds.contains(entry.stableId) {
                continue
            }
            stableIds.insert(entry.stableId)
            entries.append(entry)
            index += 1
        }
        self.prepareTransition(from: self.currentEntries ?? [], to: entries)
    }
    
    private func prepareTransition(from: [CommandChatInputContextPanelEntry]? , to: [CommandChatInputContextPanelEntry]) {
        let firstTime = self.currentEntries == nil
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let transition = preparedTransition(from: from ?? [], to: to, context: self.context, presentationData: presentationData, commandSelected: { [weak self] command, sendImmediately in
            guard let strongSelf = self, let interfaceInteraction = strongSelf.interfaceInteraction else {
                return
            }
            switch command {
            case let .command(command):
                if sendImmediately {
                    interfaceInteraction.sendBotCommand(command.peer, "/" + command.command.text)
                } else {
                    interfaceInteraction.updateTextInputStateAndMode { textInputState, inputMode in
                        var commandQueryRange: NSRange?
                        inner: for (range, type, _) in textInputStateContextQueryRangeAndType(textInputState) {
                            if type == [.command] {
                                commandQueryRange = range
                                break inner
                            }
                        }
                        
                        if let range = commandQueryRange {
                            let inputText = NSMutableAttributedString(attributedString: textInputState.inputText)
                            
                            let replacementText = command.command.text + " "
                            inputText.replaceCharacters(in: range, with: replacementText)
                            
                            let selectionPosition = range.lowerBound + (replacementText as NSString).length
                            
                            return (ChatTextInputState(inputText: inputText, selectionRange: selectionPosition ..< selectionPosition), inputMode)
                        }
                        return (textInputState, inputMode)
                    }
                }
            case let .shortcut(shortcut):
                if let shortcutId = shortcut.id {
                    interfaceInteraction.sendShortcut(shortcutId)
                }
            }
        }, openEditShortcuts: { [weak self] in
            guard let self, let interfaceInteraction = self.interfaceInteraction else {
                return
            }
            interfaceInteraction.openEditShortcuts()
        })
        self.currentEntries = to
        self.enqueueTransition(transition, firstTime: firstTime)
    }
    
    private func enqueueTransition(_ transition: CommandChatInputContextPanelTransition, firstTime: Bool) {
        enqueuedTransitions.append((transition, firstTime))
        
        if self.validLayout != nil {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let validLayout = self.validLayout, let (transition, firstTime) = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            options.insert(.Synchronous)
            options.insert(.LowLatency)
            options.insert(.PreferSynchronousResourceLoading)
            if firstTime {
                self.contentOffsetChangeTransition = .immediate
                
                self.listBackgroundView.frame = CGRect(origin: CGPoint(x: 0.0, y: self.listView.bounds.height), size: CGSize(width: self.listView.bounds.width, height: self.listView.bounds.height + 1000.0))
            } else {
                if transition.itemCountChanged {
                    options.insert(.AnimateTopItemPosition)
                    options.insert(.AnimateCrossfade)
                }
                
                self.contentOffsetChangeTransition = .spring(duration: 0.4)
            }
            
            var insets = UIEdgeInsets()
            insets.top = topInsetForLayout(size: validLayout.0)
            insets.left = validLayout.1
            insets.right = validLayout.2
            
            let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: self.listView.bounds.size, insets: insets, duration: 0.0, curve: .Default(duration: nil))
            
            self.listView.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: updateSizeAndInsets, updateOpaqueState: nil, completion: { [weak self] _ in
                if let strongSelf = self, firstTime {
                    var topItemOffset: CGFloat?
                    strongSelf.listView.forEachItemNode { itemNode in
                        if topItemOffset == nil {
                            topItemOffset = itemNode.frame.minY
                        }
                    }
                    
                    if let topItemOffset = topItemOffset {
                        let transition: ContainedViewLayoutTransition = .animated(duration: 0.4, curve: .spring)
                        
                        transition.animatePositionAdditive(layer: strongSelf.listView.layer, offset: CGPoint(x: 0.0, y: strongSelf.listView.bounds.size.height - topItemOffset))
                        transition.animatePositionAdditive(layer: strongSelf.listBackgroundView.layer, offset: CGPoint(x: 0.0, y: strongSelf.listView.bounds.size.height - topItemOffset))
                    }
                }
            })
            
            self.contentOffsetChangeTransition = nil
        }
    }
    
    private func topInsetForLayout(size: CGSize) -> CGFloat {
        var minimumItemHeights: CGFloat = 0.0
        if let currentEntries = self.currentEntries, !currentEntries.isEmpty {
            let indexLimit = min(4, currentEntries.count - 1)
            for i in 0 ... indexLimit {
                var itemHeight: CGFloat
                switch currentEntries[i].content {
                case .editShortcuts:
                    itemHeight = VerticalListContextResultsChatInputPanelButtonItemNode.itemHeight(style: .round)
                case let .command(command):
                    switch command.command {
                    case .command:
                        itemHeight = MentionChatInputPanelItemNode.itemHeight
                    case .shortcut:
                        itemHeight = 58.0
                    }
                }
                if indexLimit >= 4 && i == indexLimit {
                    minimumItemHeights += floor(itemHeight * 0.5)
                } else {
                    minimumItemHeights += itemHeight
                }
            }
        } else {
            minimumItemHeights = floor(MentionChatInputPanelItemNode.itemHeight * 3.5)
        }
        
        return max(size.height - minimumItemHeights, 0.0)
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
        let hadValidLayout = self.validLayout != nil
        self.validLayout = (size, leftInset, rightInset, bottomInset)
        
        var insets = UIEdgeInsets()
        insets.top = self.topInsetForLayout(size: size)
        insets.left = leftInset
        insets.right = rightInset
        
        transition.updateFrame(node: self.listView, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: size, insets: insets, duration: duration, curve: curve)
        
        self.contentOffsetChangeTransition = ComponentTransition(transition)
        
        self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        self.contentOffsetChangeTransition = nil
        
        if !hadValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
        
        if self.theme !== interfaceState.theme {
            self.theme = interfaceState.theme
            self.listView.keepBottomItemOverscrollBackground = self.theme.list.plainBackgroundColor
            
            let new = self.currentEntries?.map({$0.withUpdatedTheme(interfaceState.theme)}) ?? []
            prepareTransition(from: self.currentEntries, to: new)
        }
    }
    
    override func animateOut(completion: @escaping () -> Void) {
        self.isAnimatingOut = true
        
        var topItemOffset: CGFloat?
        self.listView.forEachItemNode { itemNode in
            if topItemOffset == nil {
                topItemOffset = itemNode.frame.minY
            }
        }
        
        if let topItemOffset = topItemOffset {
            let position = self.listView.layer.position
            let offset = (self.listView.bounds.size.height - topItemOffset)
            self.listView.layer.animatePosition(from: position, to: CGPoint(x: position.x, y: position.y + offset), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
                completion()
            })
            self.listBackgroundView.layer.animatePosition(from: self.listBackgroundView.layer.position, to: CGPoint(x: self.listBackgroundView.layer.position.x, y: self.listBackgroundView.layer.position.y + offset), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            })
        } else {
            completion()
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let listViewFrame = self.listView.frame
        return self.listView.hitTest(CGPoint(x: point.x - listViewFrame.minX, y: point.y - listViewFrame.minY), with: event)
    }
    
    override var topItemFrame: CGRect? {
        var topItemFrame: CGRect?
        self.listView.forEachItemNode { itemNode in
            if topItemFrame == nil {
                topItemFrame = itemNode.frame
            }
        }
        return topItemFrame
    }
}
