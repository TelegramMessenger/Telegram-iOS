import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import ItemListUI
import PresentationDataUtils
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import MergeLists
import ChatListSearchItemHeader
import ItemListUI
import SearchUI
import ContextUI
import ListMessageItem
import ComponentFlow
import SearchInputPanelComponent
import ItemListPeerActionItem
import GlassBackgroundComponent
import ActivityIndicator
import SearchBarNode
import PeerMessagesMediaPlaylist

final class AttachmentFileSearchItem: ItemListControllerSearch {
    let context: AccountContext
    let mode: AttachmentFileControllerMode
    let presentationData: PresentationData
    let focus: () -> Void
    let cancel: () -> Void
    let send: (Message) -> Void
    let dismissInput: () -> Void
    let didPreviewAudio: () -> Void
    
    private var updateActivity: ((Bool) -> Void)?
    private var activity: ValuePromise<Bool> = ValuePromise(ignoreRepeated: false)
    private let activityDisposable = MetaDisposable()
    
    init(context: AccountContext, mode: AttachmentFileControllerMode, presentationData: PresentationData, focus: @escaping () -> Void, cancel: @escaping () -> Void, send: @escaping (Message) -> Void, dismissInput: @escaping () -> Void, didPreviewAudio: @escaping () -> Void) {
        self.context = context
        self.mode = mode
        self.presentationData = presentationData
        self.focus = focus
        self.cancel = cancel
        self.send = send
        self.dismissInput = dismissInput
        self.didPreviewAudio = didPreviewAudio
        self.activityDisposable.set((activity.get() |> mapToSignal { value -> Signal<Bool, NoError> in
            if value {
                return .single(value) |> delay(0.2, queue: Queue.mainQueue())
            } else {
                return .single(value)
            }
        }).startStrict(next: { [weak self] value in
            self?.updateActivity?(value)
        }))
    }
    
    deinit {
        self.activityDisposable.dispose()
    }
    
    func isEqual(to: ItemListControllerSearch) -> Bool {
        if let to = to as? AttachmentFileSearchItem {
            if self.context !== to.context {
                return false
            }
            return true
        } else {
            return false
        }
    }
    
    func titleContentNode(current: (NavigationBarContentNode & ItemListControllerSearchNavigationContentNode)?) -> (NavigationBarContentNode & ItemListControllerSearchNavigationContentNode)? {
        switch self.mode {
        case .audio:
            if let current = current as? AttachmentFileSearchNavigationContentNode {
                current.updateTheme(self.presentationData.theme)
                return current
            } else {
                return AttachmentFileSearchNavigationContentNode(theme: self.presentationData.theme, strings: self.presentationData.strings, cancel: self.cancel, focus: self.focus, updateActivity: { _ in
                })
            }
        default:
            return nil
        }
    }
    
    func node(current: ItemListControllerSearchNode?, titleContentNode: (NavigationBarContentNode & ItemListControllerSearchNavigationContentNode)?) -> ItemListControllerSearchNode {
        return AttachmentFileSearchItemNode(context: self.context, mode: self.mode, presentationData: self.presentationData, focus: self.focus, send: self.send, cancel: self.cancel, updateActivity: { [weak self] value in
            self?.activity.set(value)
        }, dismissInput: self.dismissInput, didPreviewAudio: self.didPreviewAudio)
    }
}

private final class AttachmentFileSearchItemNode: ItemListControllerSearchNode {
    private let context: AccountContext
    private let mode: AttachmentFileControllerMode
    private let presentationData: PresentationData
    private let focus: () -> Void
    private let cancel: () -> Void
    
    private let containerNode: AttachmentFileSearchContainerNode
    
    private let searchInput = ComponentView<Empty>()
    
    private var validLayout: ContainerViewLayout?
    
    init(context: AccountContext, mode: AttachmentFileControllerMode, presentationData: PresentationData, focus: @escaping () -> Void, send: @escaping (Message) -> Void, cancel: @escaping () -> Void, updateActivity: @escaping(Bool) -> Void, dismissInput: @escaping () -> Void, didPreviewAudio: @escaping () -> Void) {
        self.context = context
        self.mode = mode
        self.presentationData = presentationData
        self.focus = focus
        self.cancel = cancel
                
        self.containerNode = AttachmentFileSearchContainerNode(context: context, mode: mode, presentationData: presentationData, send: { message in
            send(message)
        }, updateActivity: updateActivity, didPreviewAudio: didPreviewAudio)

        super.init()
        
        self.addedUnderNavigationBar = true
        
        self.addSubnode(self.containerNode)
        
        self.containerNode.cancel = { [weak self] in
            dismissInput()
            cancel()
            self?.deactivateInput()
        }
        self.containerNode.dismissInput = {
            dismissInput()
        }
    }
    
    override func queryUpdated(_ query: String) {
        self.containerNode.searchTextUpdated(text: query)
    }
    
    override func scrollToTop() {
        self.containerNode.scrollToTop()
    }
    
    private func deactivateInput() {
        if let layout = self.validLayout, let searchInputView = self.searchInput.view as? SearchInputPanelComponent.View {
            let transition = ComponentTransition.spring(duration: 0.4)
            transition.setFrame(view: searchInputView, frame: CGRect(origin: CGPoint(x: searchInputView.frame.minX, y: layout.size.height), size: searchInputView.frame.size))
        }
    }
    
    override func updateLayout(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationBarHeight), size: CGSize(width: layout.size.width, height: layout.size.height - navigationBarHeight)))
        self.containerNode.containerLayoutUpdated(layout.withUpdatedSize(CGSize(width: layout.size.width, height: layout.size.height - navigationBarHeight)), navigationBarHeight: 0.0, transition: transition)
        
        if case .recent = self.mode {
            let searchInputSize = self.searchInput.update(
                transition: .immediate,
                component: AnyComponent(
                    SearchInputPanelComponent(
                        theme: self.presentationData.theme,
                        strings: self.presentationData.strings,
                        metrics: layout.metrics,
                        safeInsets: layout.safeInsets,
                        placeholder: self.presentationData.strings.Attachment_FilesSearchPlaceholder,
                        updated: { [weak self] query in
                            guard let self else {
                                return
                            }
                            self.queryUpdated(query)
                        },
                        cancel: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.cancel()
                            self.deactivateInput()
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: layout.size.width, height: layout.size.height)
            )
            
            let bottomInset: CGFloat = layout.insets(options: .input).bottom
            let searchInputFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - bottomInset - searchInputSize.height), size: searchInputSize)
            if let searchInputView = self.searchInput.view as? SearchInputPanelComponent.View {
                if searchInputView.superview == nil {
                    self.view.addSubview(searchInputView)
                    searchInputView.frame = CGRect(origin: CGPoint(x: searchInputFrame.minX, y: layout.size.height), size: searchInputFrame.size)
                    
                    self.focus()
                    searchInputView.activateInput()
                }
                transition.updateFrame(view: searchInputView, frame: searchInputFrame)
            }
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let searchInputView = self.searchInput.view as? SearchInputPanelComponent.View {
            if let result = searchInputView.hitTest(self.view.convert(point, to: searchInputView), with: event) {
                return result
            }
        }
        if let result = self.containerNode.hitTest(self.view.convert(point, to: self.containerNode.view), with: event) {
            return result
        }
        
        return super.hitTest(point, with: event)
    }
}


private final class AttachmentFileSearchContainerInteraction {
    let context: AccountContext
    let send: (Message) -> Void
    let toggleMediaPlayback: (Message) -> Void
    let expandSection: (Int32) -> Void
    
    init(context: AccountContext, send: @escaping (Message) -> Void, toggleMediaPlayback: @escaping (Message) -> Void, expandSection: @escaping (Int32) -> Void) {
        self.context = context
        self.send = send
        self.toggleMediaPlayback = toggleMediaPlayback
        self.expandSection = expandSection
    }
}

private enum AttachmentFileSearchEntryId: Hashable {
    case header(Int32)
    case placeholder(Int32, Int32)
    case message(Int32, MessageId)
    case showMore(Int32)
}

private func areMessagesEqual(_ lhsMessage: Message?, _ rhsMessage: Message?) -> Bool {
    guard let lhsMessage = lhsMessage, let rhsMessage = rhsMessage else {
        return lhsMessage == nil && rhsMessage == nil
    }
    if lhsMessage.stableVersion != rhsMessage.stableVersion {
        return false
    }
    if lhsMessage.id != rhsMessage.id || lhsMessage.flags != rhsMessage.flags {
        return false
    }
    return true
}

private enum AttachmentFileSearchEntry: Comparable, Identifiable {
    case header(title: String, section: Int32)
    case file(index: Int32, message: Message?, section: Int32)
    case showMore(text: String, section: Int32)
    
    var section: ItemListSectionId {
        switch self {
        case let .header(_, section):
            return section
        case let .file(_, _, section):
            return section
        case let .showMore(_, section):
            return section
        }
    }
    
    var stableId: AttachmentFileSearchEntryId {
        switch self {
        case let .header(_, section):
            return .header(section)
        case let .file(index, message, section):
            if let message {
                return .message(section, message.id)
            } else {
                return .placeholder(section, index)
            }
        case let .showMore(_, section):
            return .showMore(section)
        }
    }
    
    var sortId: Int64 {
        switch self {
        case let .header(_, section):
            return Int64(section) * 100000
        case let .file(index, _, section):
            return Int64(section) * 100000 + 1 + Int64(index)
        case let .showMore(_, section):
            return Int64(section + 1) * 100000 - 1
        }
    }
    
    static func ==(lhs: AttachmentFileSearchEntry, rhs: AttachmentFileSearchEntry) -> Bool {
        switch lhs {
        case let .header(lhsTitle, lhsSection):
            if case let .header(rhsTitle, rhsSection) = rhs, lhsTitle == rhsTitle, lhsSection == rhsSection {
                return true
            } else {
                return false
            }
        case let .file(lhsIndex, lhsMessage, lhsSection):
            if case let .file(rhsIndex, rhsMessage, rhsSection) = rhs, lhsIndex == rhsIndex, areMessagesEqual(lhsMessage, rhsMessage), lhsSection == rhsSection {
                return true
            } else {
                return false
            }
        case let .showMore(lhsText, lhsSection):
            if case let .showMore(rhsText, rhsSection) = rhs, lhsText == rhsText, lhsSection == rhsSection {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: AttachmentFileSearchEntry, rhs: AttachmentFileSearchEntry) -> Bool {
        return lhs.sortId < rhs.sortId
    }
    
    func item(context: AccountContext, presentationData: PresentationData, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, interaction: AttachmentFileSearchContainerInteraction, mode: AttachmentFileControllerMode) -> ListViewItem {
        switch self {
        case let .header(title, section):
            return ItemListSectionHeaderItem(presentationData: ItemListPresentationData(presentationData), text: title, sectionId: section)
        case let .file(_, message, section):
            let itemInteraction = ListMessageItemInteraction(openMessage: { message, _ in
                interaction.send(message)
                return false
            }, openMessageContextMenu: { _, _, _, _, _ in }, toggleMediaPlayback: { message in
                interaction.toggleMediaPlayback(message)
            }, toggleMessagesSelection: { _, _ in }, openUrl: { _, _, _, _ in }, openInstantPage: { _, _ in }, longTap: { _, _ in }, getHiddenMedia: { return [:] })
            
            let displayFileInfo = mode.isAudio
            let isStoryMusic = mode.isAudio
            let isDownloadList = mode.isAudio
            
            return ListMessageItem(presentationData: ChatPresentationData(presentationData: presentationData), systemStyle: .glass, context: interaction.context, chatLocation: .peer(id: PeerId(0)), interaction: itemInteraction, message: message, selection: .none, displayHeader: false, isDownloadList: isDownloadList, isStoryMusic: isStoryMusic, isAttachMusic: true, displayFileInfo: displayFileInfo, displayBackground: true, style: .blocks, sectionId: section)
        case let .showMore(text, section):
            return ItemListPeerActionItem(presentationData: ItemListPresentationData(presentationData), style: .blocks, systemStyle: .glass, icon: PresentationResourcesItemList.downArrowImage(presentationData.theme), title: text, sectionId: section, editing: false, action: {
                interaction.expandSection(section)
            })
        }
    }
}

struct AttachmentFileSearchContainerTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let isSearching: Bool
    let isEmpty: Bool
    let query: String
    let crossfade: Bool
}

private func attachmentFileSearchContainerPreparedRecentTransition(
    from fromEntries: [AttachmentFileSearchEntry],
    to toEntries: [AttachmentFileSearchEntry],
    isSearching: Bool,
    isEmpty: Bool,
    query: String,
    context: AccountContext,
    presentationData: PresentationData,
    nameSortOrder: PresentationPersonNameOrder,
    nameDisplayOrder: PresentationPersonNameOrder,
    interaction: AttachmentFileSearchContainerInteraction,
    mode: AttachmentFileControllerMode,
    crossfade: Bool
) -> AttachmentFileSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, nameSortOrder: nameSortOrder, nameDisplayOrder: nameDisplayOrder, interaction: interaction, mode: mode), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, nameSortOrder: nameSortOrder, nameDisplayOrder: nameDisplayOrder, interaction: interaction, mode: mode), directionHint: nil) }
    
    return AttachmentFileSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, isSearching: isSearching, isEmpty: isEmpty, query: query, crossfade: crossfade)
}


public final class AttachmentFileSearchContainerNode: SearchDisplayControllerContentNode {
    private let context: AccountContext
    private let send: (Message) -> Void
    
    private let dimNode: ASDisplayNode
    private let backgroundNode: ASDisplayNode
    private let listNode: ListView
    private let leftOverlayNode: ASDisplayNode
    private let rightOverlayNode: ASDisplayNode
    
    private let emptyResultsTitleNode: ImmediateTextNode
    private let emptyResultsTextNode: ImmediateTextNode
    
    private var enqueuedTransitions: [(AttachmentFileSearchContainerTransition, Bool)] = []
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    private let searchQuery = Promise<String?>()
    private let emptyQueryDisposable = MetaDisposable()
    private let searchDisposable = MetaDisposable()
    
    private let savedMusicContext: ProfileSavedMusicContext?
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private let presentationDataPromise: Promise<PresentationData>
    
    private var expandedSections = Set<Int32>() {
        didSet {
            self.expandedSectionsPromise.set(self.expandedSections)
        }
    }
    private var expandedSectionsPromise = ValuePromise<Set<Int32>>(Set())
        
    private var _hasDim: Bool = false
    override public var hasDim: Bool {
        return _hasDim
    }
        
    public init(context: AccountContext, mode: AttachmentFileControllerMode, presentationData: PresentationData, send: @escaping (Message) -> Void, updateActivity: @escaping (Bool) -> Void, didPreviewAudio: @escaping () -> Void) {
        self.context = context
        self.send = send
        
        let savedMusicContext: ProfileSavedMusicContext?
        switch mode {
        case .audio:
            savedMusicContext = ProfileSavedMusicContext(account: context.account, peerId: context.account.peerId)
        default:
            savedMusicContext = nil
        }
        self.savedMusicContext = savedMusicContext
        
        self.presentationData = presentationData
        
        self.presentationDataPromise = Promise(self.presentationData)
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = .clear
        
        self.backgroundNode = ASDisplayNode()
        
        self.listNode = ListViewImpl()
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        self.leftOverlayNode = ASDisplayNode()
        self.leftOverlayNode.isUserInteractionEnabled = false
        self.rightOverlayNode = ASDisplayNode()
        self.rightOverlayNode.isUserInteractionEnabled = false
        
        self.emptyResultsTitleNode = ImmediateTextNode()
        self.emptyResultsTitleNode.displaysAsynchronously = false
        self.emptyResultsTitleNode.attributedText = NSAttributedString(string: self.presentationData.strings.ChatList_Search_NoResults, font: Font.semibold(17.0), textColor: self.presentationData.theme.list.freeTextColor)
        self.emptyResultsTitleNode.textAlignment = .center
        self.emptyResultsTitleNode.isHidden = true
        
        self.emptyResultsTextNode = ImmediateTextNode()
        self.emptyResultsTextNode.displaysAsynchronously = false
        self.emptyResultsTextNode.maximumNumberOfLines = 0
        self.emptyResultsTextNode.textAlignment = .center
        self.emptyResultsTextNode.isHidden = true
        
        super.init()
                
        self.backgroundNode.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        self.backgroundNode.alpha = 0.0
        
        self.listNode.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        self.listNode.alpha = 0.0
        
        self.leftOverlayNode.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        self.rightOverlayNode.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        
        self._hasDim = true
        
        self.addSubnode(self.dimNode)
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.listNode)
        
        self.addSubnode(self.emptyResultsTitleNode)
        self.addSubnode(self.emptyResultsTextNode)
        
        let interaction = AttachmentFileSearchContainerInteraction(
            context: context,
            send: { [weak self] message in
                send(message)
                self?.listNode.clearHighlightAnimated(true)
            },
            toggleMediaPlayback: { [weak self] message in
                didPreviewAudio()
                
                let playlistLocation: PeerMessagesPlaylistLocation = .custom(messages: .single(([message], 0, false)), canReorder: false, at: message.id, loadMore: nil, hidePanel: true)
                context.sharedContext.mediaManager.setPlaylist((context, PeerMessagesMediaPlaylist(context: context, location: playlistLocation, chatLocationContextHolder: nil)), type: .music, control: .playback(.togglePlayPause))
                
                self?.view.window?.endEditing(true)
            },
            expandSection: { [weak self] section in
            self?.expandedSections.insert(section)
        })
        
        let presentationDataPromise = self.presentationDataPromise
                
        let searchQuery = self.searchQuery.get()
        |> mapToSignal { query -> Signal<String?, NoError> in
            return .single(query)
        }
        
        let expandedSectionsPromise = self.expandedSectionsPromise
        let foundItems = searchQuery
        |> mapToSignal { query -> Signal<[AttachmentFileSearchEntry]?, NoError> in
            guard let query, !query.isEmpty else {
                return .single(nil)
            }
            
            let queryTokens = stringTokens(query.lowercased())
            
            let shared: Signal<[Message]?, NoError>
            let savedMusic: Signal<[Message]?, NoError>
            let globalMusic: Signal<[Message]?, NoError>
            switch mode {
            case .recent:
                shared = .single(nil)
                |> then(
                    context.engine.messages.searchMessages(location: .sentMedia(tags: [.file]), query: query, state: nil)
                    |> delay(0.6, queue: Queue.mainQueue())
                    |> map { result -> [Message]? in
                        return result.0.messages
                    }
                )
                savedMusic = .single(nil)
                globalMusic = .single(nil)
            case .audio:
                shared = .single(nil)
                |> then(
                    context.engine.messages.searchMessages(location: .general(scope: .everywhere, tags: [.music], minDate: nil, maxDate: nil), query: query, state: nil)
                    |> delay(0.6, queue: Queue.mainQueue())
                    |> map { result -> [Message]? in
                        return result.0.messages.filter { !$0.isRestricted(platform: "ios", contentSettings: context.currentContentSettings.with { $0 }) }
                    }
                )
                savedMusic = .single(nil)
                |> then(
                    savedMusicContext!.state
                    |> delay(0.6, queue: Queue.mainQueue())
                    |> map { state in
                        let peerId = context.account.peerId
                        var messages: [Message] = []
                        let peers = SimpleDictionary<PeerId, Peer>()
                        for file in state.files {
                            var indexString = ""
                            for attribute in file.attributes {
                                if case let .Audio(_, _, title, performer, _) = attribute {
                                    if let title = title?.lowercased() {
                                        indexString += "\(title) "
                                    }
                                    if let performer = performer?.lowercased() {
                                        indexString += "\(performer) "
                                    }
                                } else if case let .FileName(fileName) = attribute {
                                    indexString += "\(fileName) "
                                }
                            }

                            let tokens = stringTokens(indexString)
                            guard matchStringTokens(tokens, with: queryTokens) else {
                                continue
                            }
                            let stableId = UInt32(clamping: file.fileId.id % Int64(Int32.max))
                            messages.append(Message(stableId: stableId, stableVersion: 0, id: MessageId(peerId: peerId, namespace: Namespaces.Message.Local, id: Int32(stableId)), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [], tags: [.music], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: nil, text: "", attributes: [], media: [file], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:]))
                        }
                        return messages
                    }
                )
                                
                if let data = context.currentAppConfiguration.with({ $0 }).data, let searchBot = data["music_search_username"] as? String, !searchBot.isEmpty, query.count >= 3 {
                    globalMusic = .single(nil)
                    |> then(
                        context.engine.peers.resolvePeerByName(name: searchBot, referrer: nil)
                        |> delay(0.6, queue: Queue.mainQueue())
                        |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
                            guard case let .result(result) = result else {
                                return .complete()
                            }
                            return .single(result)
                        }
                        |> mapToSignal { peer -> Signal<ChatContextResultCollection?, NoError> in
                            guard let peer = peer else {
                                return .single(nil)
                            }
                            return context.engine.messages.requestChatContextResults(botId: peer.id, peerId: context.account.peerId, query: query, offset: "")
                            |> map { results -> ChatContextResultCollection? in
                                return results?.results
                            }
                            |> `catch` { error -> Signal<ChatContextResultCollection?, NoError> in
                                return .single(nil)
                            }
                        }
                        |> map { contextResult in
                            guard let results = contextResult?.results else {
                                return []
                            }
                            let peerId = context.account.peerId
                            var messages: [Message] = []
                            let peers = SimpleDictionary<PeerId, Peer>()
                            for result in results {
                                switch result {
                                case let .internalReference(internalReference):
                                    if let file = internalReference.file {
                                        let stableId = UInt32(clamping: file.fileId.id % Int64(Int32.max))
                                        messages.append(Message(stableId: stableId, stableVersion: 0, id: MessageId(peerId: peerId, namespace: Namespaces.Message.Local, id: Int32(stableId)), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [], tags: [.music], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: nil, text: "", attributes: [], media: [file], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:]))
                                    }
                                default:
                                    break
                                }
                            }
                            return messages
                        }
                    )
                } else {
                    globalMusic = .single([])
                }
            }
            
            updateActivity(true)

            return combineLatest(shared, savedMusic, globalMusic, presentationDataPromise.get(), expandedSectionsPromise.get())
            |> mapToSignal { messages, savedMusic, globalMusic, presentationData, expandedSections -> Signal<[AttachmentFileSearchEntry]?, NoError> in
                var entries: [AttachmentFileSearchEntry] = []
                
                if let messages {
                    var section: Int32 = 0
                    var index: Int32 = 0
                    
                    if let savedMusic, !savedMusic.isEmpty {
                        entries.append(.header(title: presentationData.strings.Attachment_ProfileMusic, section: section))
                        
                        var savedMusic = savedMusic
                        var hasShowMore = false
                        if savedMusic.count > 4 && !expandedSections.contains(section) {
                            savedMusic = Array(savedMusic.prefix(3))
                            hasShowMore = true
                        }
                        for message in savedMusic {
                            entries.append(.file(index: index, message: message, section: section))
                            index += 1
                        }
                        if hasShowMore {
                            entries.append(.showMore(text: presentationData.strings.MediaEditor_Audio_ShowMore, section: section))
                        }
                    }
                    
                    index = 0
                    section += 1
                    
                    if !messages.isEmpty {
                        entries.append(.header(title: presentationData.strings.Attachment_ChatsMusic, section: section))
                        var messages = messages
                        var hasShowMore = false
                        if messages.count > 4 && !expandedSections.contains(section) {
                            messages = Array(messages.prefix(3))
                            hasShowMore = true
                        }
                        for message in messages {
                            entries.append(.file(index: index, message: message, section: section))
                            index += 1
                        }
                        if hasShowMore {
                            entries.append(.showMore(text: presentationData.strings.MediaEditor_Audio_ShowMore, section: section))
                        }
                    }
                    
                    if let globalMusic {
                        if !globalMusic.isEmpty {
                            index = 0
                            section += 1
                            
                            entries.append(.header(title: presentationData.strings.Attachment_PublicMusic, section: section))
                            for message in globalMusic {
                                entries.append(.file(index: index, message: message, section: section))
                                index += 1
                            }
                        }
                    } else if messages.isEmpty {
                        entries.append(.header(title: " ", section: 0))
                        var index: Int32 = 0
                        for _ in 0 ..< 16 {
                            entries.append(.file(index: index, message: nil, section: 0))
                            index += 1
                        }
                    }
                } else {
                    entries.append(.header(title: " ", section: 0))
                    var index: Int32 = 0
                    for _ in 0 ..< 16 {
                        entries.append(.file(index: index, message: nil, section: 0))
                        index += 1
                    }
                }

                return .single(entries)
            }
        }
        
        let previousSearchItems = Atomic<[AttachmentFileSearchEntry]?>(value: nil)
        let previousHadSharedItems = Atomic<Bool>(value: false)
        let previousHadSavedItems = Atomic<Bool>(value: false)
        let previousHadGlobalItems = Atomic<Bool>(value: false)
        self.searchDisposable.set((combineLatest(searchQuery, foundItems, self.presentationDataPromise.get())
        |> deliverOnMainQueue).startStrict(next: { [weak self] query, entries, presentationData in
            if let strongSelf = self {
                let previousEntries = previousSearchItems.swap(entries)
                updateActivity(false)
                let firstTime = previousEntries == nil
                
                var hasSharedItems = false
                var hasSavedItems = false
                var hasGlobalItems = false
                
                if let entries {
                    for entry in entries {
                        if case let .header(title, section) = entry, title != " " {
                            if section == 0 {
                                hasSharedItems = true
                            }
                            if section == 1 {
                                hasSavedItems = true
                            }
                            if section == 2 {
                                hasGlobalItems = true
                            }
                        }
                    }
                }
                let hadSharedItems = previousHadSharedItems.swap(hasSharedItems)
                let hadSavedItems = previousHadSavedItems.swap(hasSavedItems)
                let hadGlobalItems = previousHadGlobalItems.swap(hasGlobalItems)
                
                let crossfade = hadSharedItems != hasSharedItems || hadSavedItems != hasSavedItems || hadGlobalItems != hasGlobalItems
                
                let transition = attachmentFileSearchContainerPreparedRecentTransition(from: previousEntries ?? [], to: entries ?? [], isSearching: entries != nil, isEmpty: entries?.isEmpty ?? false, query: query ?? "", context: context, presentationData: presentationData, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder, interaction: interaction, mode: mode, crossfade: crossfade)
                strongSelf.enqueueTransition(transition, firstTime: firstTime)
            }
        }))
        
        self.listNode.beganInteractiveDragging = { [weak self] _ in
            self?.dismissInput?()
        }
        
        self.listNode.itemNodeHitTest = { [weak self] point in
            if let strongSelf = self {
                return point.x > strongSelf.leftOverlayNode.frame.maxX && point.x < strongSelf.rightOverlayNode.frame.minX
            } else {
                return true
            }
        }
    }
    
    deinit {
        self.searchDisposable.dispose()
        self.presentationDataDisposable?.dispose()
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
    }
    
    private func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.backgroundNode.backgroundColor = theme.list.blocksBackgroundColor
        self.listNode.backgroundColor = theme.list.blocksBackgroundColor
        self.leftOverlayNode.backgroundColor = theme.list.blocksBackgroundColor
        self.rightOverlayNode.backgroundColor = theme.list.blocksBackgroundColor
    }
    
    override public func searchTextUpdated(text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.searchQuery.set(.single(!trimmedText.isEmpty ? trimmedText : nil))
    }
    
    private func enqueueTransition(_ transition: AttachmentFileSearchContainerTransition, firstTime: Bool) {
        self.enqueuedTransitions.append((transition, firstTime))
        
        if let _ = self.validLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let (transition, _) = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            options.insert(.PreferSynchronousDrawing)
            options.insert(.PreferSynchronousResourceLoading)
            
            //options.insert(.AnimateInsertion)
            
            if transition.crossfade {
                options.insert(.AnimateCrossfade)
            }
            
            let isSearching = transition.isSearching
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                
                let containerTransition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .easeInOut)
                containerTransition.updateAlpha(node: strongSelf.backgroundNode, alpha: isSearching ? 1.0 : 0.0)
                containerTransition.updateAlpha(node: strongSelf.listNode, alpha: isSearching ? 1.0 : 0.0)
                strongSelf.dimNode.isHidden = transition.isSearching
                
                strongSelf.emptyResultsTextNode.attributedText = NSAttributedString(string: strongSelf.presentationData.strings.ChatList_Search_NoResultsQueryDescription(transition.query).string, font: Font.regular(15.0), textColor: strongSelf.presentationData.theme.list.freeTextColor)
                
                let emptyResults = transition.isSearching && transition.isEmpty
                strongSelf.emptyResultsTitleNode.isHidden = !emptyResults
                strongSelf.emptyResultsTextNode.isHidden = !emptyResults
                
                if let (layout, navigationBarHeight) = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                }
            })
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        let hadValidLayout = self.validLayout == nil
        self.validLayout = (layout, navigationBarHeight)
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        insets.bottom += 60.0
        
        let inset = max(16.0, floor((layout.size.width - 674.0) / 2.0))
        if layout.size.width >= 375.0 {
            insets.left += inset
            insets.right += inset
        }
        
        if self.rightOverlayNode.supernode == nil {
            self.insertSubnode(self.rightOverlayNode, aboveSubnode: self.listNode)
        }
        if self.leftOverlayNode.supernode == nil {
            self.insertSubnode(self.leftOverlayNode, aboveSubnode: self.listNode)
        }
        
        let topInset = navigationBarHeight
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: layout.size.width, height: layout.size.height - topInset)))
        
        self.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -66.0), size: CGSize(width: layout.size.width, height: 66.0))
        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        self.leftOverlayNode.frame = CGRect(x: 0.0, y: 0.0, width: insets.left, height: layout.size.height)
        self.rightOverlayNode.frame = CGRect(x: layout.size.width - insets.right, y: 0.0, width: insets.right, height: layout.size.height)
        
        let padding: CGFloat = 16.0
        let emptyTitleSize = self.emptyResultsTitleNode.updateLayout(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - padding * 2.0, height: CGFloat.greatestFiniteMagnitude))
        let emptyTextSize = self.emptyResultsTextNode.updateLayout(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - padding * 2.0, height: CGFloat.greatestFiniteMagnitude))
        
        let emptyTextSpacing: CGFloat = 8.0
        let emptyTotalHeight = emptyTitleSize.height + emptyTextSize.height + emptyTextSpacing
        let emptyTitleY = navigationBarHeight + floorToScreenPixels((layout.size.height - navigationBarHeight - max(insets.bottom, layout.intrinsicInsets.bottom) - emptyTotalHeight) / 2.0)
        
        transition.updateFrame(node: self.emptyResultsTitleNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + padding + (layout.size.width - layout.safeInsets.left - layout.safeInsets.right - padding * 2.0 - emptyTitleSize.width) / 2.0, y: emptyTitleY), size: emptyTitleSize))
        transition.updateFrame(node: self.emptyResultsTextNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + padding + (layout.size.width - layout.safeInsets.left - layout.safeInsets.right - padding * 2.0 - emptyTextSize.width) / 2.0, y: emptyTitleY + emptyTitleSize.height + emptyTextSpacing), size: emptyTextSize))
        
        if !hadValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    override public func scrollToTop() {
        if self.listNode.alpha > 0.0 {
            self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        }
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel?()
        }
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = self.view.hitTest(point, with: event) else {
            return nil
        }
        if result === self.view {
            return nil
        }
        return result
    }
}

private func stringTokens(_ string: String) -> [ValueBoxKey] {
    let nsString = string.folding(options: .diacriticInsensitive, locale: .current).lowercased() as NSString
    
    let flag = UInt(kCFStringTokenizerUnitWord)
    let tokenizer = CFStringTokenizerCreate(kCFAllocatorDefault, nsString, CFRangeMake(0, nsString.length), flag, CFLocaleCopyCurrent())
    var tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
    var tokens: [ValueBoxKey] = []
    
    var addedTokens = Set<ValueBoxKey>()
    while tokenType != [] {
        let currentTokenRange = CFStringTokenizerGetCurrentTokenRange(tokenizer)
        
        if currentTokenRange.location >= 0 && currentTokenRange.length != 0 {
            let token = ValueBoxKey(length: currentTokenRange.length * 2)
            nsString.getCharacters(token.memory.assumingMemoryBound(to: unichar.self), range: NSMakeRange(currentTokenRange.location, currentTokenRange.length))
            if !addedTokens.contains(token) {
                tokens.append(token)
                addedTokens.insert(token)
            }
        }
        tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
    }
    
    return tokens
}

private func matchStringTokens(_ tokens: [ValueBoxKey], with other: [ValueBoxKey]) -> Bool {
    if other.isEmpty {
        return false
    } else if other.count == 1 {
        let otherToken = other[0]
        for token in tokens {
            if otherToken.isPrefix(to: token) {
                return true
            }
        }
    } else {
        for otherToken in other {
            var found = false
            for token in tokens {
                if otherToken.isPrefix(to: token) {
                    found = true
                    break
                }
            }
            if !found {
                return false
            }
        }
        return true
    }
    return false
}

private let searchBarFont = Font.regular(17.0)

private final class AttachmentFileSearchNavigationContentNode: NavigationBarContentNode, ItemListControllerSearchNavigationContentNode {
    private struct Params: Equatable {
        let size: CGSize
        let leftInset: CGFloat
        let rightInset: CGFloat
        
        init(size: CGSize, leftInset: CGFloat, rightInset: CGFloat) {
            self.size = size
            self.leftInset = leftInset
            self.rightInset = rightInset
        }
    }
    
    private var theme: PresentationTheme
    private let strings: PresentationStrings
    
    private let cancel: () -> Void
    
    private let backgroundContainer: GlassBackgroundContainerView
    private let backgroundView: GlassBackgroundView
    private let iconView: UIImageView
    private var activityIndicator: ActivityIndicator?
    private let searchBar: SearchBarNode
    private let close: (background: GlassBackgroundView, icon: UIImageView)
    
    private var params: Params?
    
    private var queryUpdated: ((String) -> Void)?
    var activity: Bool = false {
        didSet {
            if self.activity != oldValue {
                if let params = self.params {
                    let _ = self.updateLayout(size: params.size, leftInset: params.leftInset, rightInset: params.rightInset, transition: .immediate)
                }
            }
        }
    }
    init(theme: PresentationTheme, strings: PresentationStrings, cancel: @escaping () -> Void, focus: @escaping () -> Void, updateActivity: @escaping( @escaping (Bool) -> Void) -> Void) {
        self.theme = theme
        self.strings = strings
        
        self.cancel = cancel
        
        self.backgroundContainer = GlassBackgroundContainerView()
        self.backgroundView = GlassBackgroundView()
        self.backgroundContainer.contentView.addSubview(self.backgroundView)
        self.iconView = UIImageView()
        self.backgroundView.contentView.addSubview(self.iconView)
        
        self.close = (GlassBackgroundView(), UIImageView())
        self.close.background.contentView.addSubview(self.close.icon)
        
        self.searchBar = SearchBarNode(
            theme: SearchBarNodeTheme(
                background: .clear,
                separator: .clear,
                inputFill: .clear,
                primaryText: theme.chat.inputPanel.panelControlColor,
                placeholder: theme.chat.inputPanel.inputPlaceholderColor,
                inputIcon: theme.chat.inputPanel.inputControlColor,
                inputClear: theme.chat.inputPanel.panelControlColor,
                accent: theme.chat.inputPanel.panelControlAccentColor,
                keyboard: theme.rootController.keyboardColor
            ),
            presentationTheme: theme,
            strings: strings,
            fieldStyle: .inlineNavigation,
            forceSeparator: false,
            displayBackground: false,
            cancelText: nil
        )
        
        super.init()
        
        self.view.addSubview(self.backgroundContainer)
        self.backgroundView.contentView.addSubview(self.searchBar.view)
        
        self.backgroundContainer.contentView.addSubview(self.close.background)
        self.close.background.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onCloseTapGesture(_:))))
        
        self.searchBar.cancel = { [weak self] in
            self?.searchBar.deactivate(clear: false)
            self?.cancel()
        }
        
        self.searchBar.textUpdated = { [weak self] query, _ in
            self?.queryUpdated?(query)
        }
        
        self.searchBar.focusUpdated = { hasFocus in
            if hasFocus {
                focus()
            }
        }
        
        updateActivity({ [weak self] value in
            self?.activity = value
        })
        
        self.updatePlaceholder()
    }
    
    @objc private func onCloseTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.searchBar.cancel?()
        }
    }
    
    func setQueryUpdated(_ f: @escaping (String) -> Void) {
        self.queryUpdated = f
    }
    
    func updateTheme(_ theme: PresentationTheme) {
        self.theme = theme
        
        let searchBarTheme = SearchBarNodeTheme(
            background: .clear,
            separator: .clear,
            inputFill: .clear,
            primaryText: theme.chat.inputPanel.panelControlColor,
            placeholder: theme.chat.inputPanel.inputPlaceholderColor,
            inputIcon: theme.chat.inputPanel.inputControlColor,
            inputClear: theme.chat.inputPanel.panelControlColor,
            accent: theme.chat.inputPanel.panelControlAccentColor,
            keyboard: theme.rootController.keyboardColor
        )
        
        self.searchBar.updateThemeAndStrings(theme: searchBarTheme, presentationTheme: theme, strings: self.strings)
        if let params = self.params {
            let _ = self.updateLayout(size: params.size, leftInset: params.leftInset, rightInset: params.rightInset, transition: .immediate)
        }
        self.updatePlaceholder()
    }
    
    func updatePlaceholder() {
        let placeholderText: String
        placeholderText = self.strings.Common_Search
        self.searchBar.placeholderString = NSAttributedString(string: placeholderText, font: searchBarFont, textColor: self.theme.rootController.navigationSearchBar.inputPlaceholderTextColor)
    }
    
    override var nominalHeight: CGFloat {
        return 68.0
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGSize {
        self.params = Params(size: size, leftInset: leftInset, rightInset: rightInset)
        
        let transition = ComponentTransition(transition)
        
        let backgroundFrame = CGRect(origin: CGPoint(x: leftInset + 16.0, y: 6.0), size: CGSize(width: size.width - 16.0 * 2.0 - leftInset - rightInset - 44.0 - 8.0, height: 44.0))
        let closeFrame = CGRect(origin: CGPoint(x: size.width - 16.0 - rightInset - 44.0, y: backgroundFrame.minY), size: CGSize(width: 44.0, height: 44.0))
        
        transition.setFrame(view: self.backgroundContainer, frame: CGRect(origin: CGPoint(), size: size))
        self.backgroundContainer.update(size: size, isDark: self.theme.overallDarkAppearance, transition: transition)
        
        transition.setFrame(view: self.backgroundView, frame: backgroundFrame)
        self.backgroundView.update(size: backgroundFrame.size, cornerRadius: backgroundFrame.height * 0.5, isDark: self.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: transition)

        if self.iconView.image == nil {
            self.iconView.image = UIImage(bundleImageName: "Navigation/Search")?.withRenderingMode(.alwaysTemplate)
        }
        transition.setTintColor(view: self.iconView, color: self.theme.rootController.navigationSearchBar.inputIconColor)
        
        if let image = self.iconView.image {
            let imageSize: CGSize
            let iconFrame: CGRect
            let iconFraction: CGFloat = 0.8
            imageSize = CGSize(width: image.size.width * iconFraction, height: image.size.height * iconFraction)
            iconFrame = CGRect(origin: CGPoint(x: 12.0, y: floor((backgroundFrame.height - imageSize.height) * 0.5)), size: imageSize)
            transition.setPosition(view: self.iconView, position: iconFrame.center)
            transition.setBounds(view: self.iconView, bounds: CGRect(origin: CGPoint(), size: iconFrame.size))
        }
        
        if self.activity {
            let activityIndicator: ActivityIndicator
            if let current = self.activityIndicator {
                activityIndicator = current
            } else {
                activityIndicator = ActivityIndicator(type: .custom(self.theme.chat.inputPanel.inputControlColor, 14.0, 14.0, false))
                self.activityIndicator = activityIndicator
                self.backgroundView.contentView.addSubview(activityIndicator.view)
            }
            let indicatorSize = activityIndicator.measure(CGSize(width: 32.0, height: 32.0))
            let indicatorFrame = CGRect(origin: CGPoint(x: 15.0, y: floorToScreenPixels((backgroundFrame.height - indicatorSize.height) * 0.5)), size: indicatorSize)
            transition.setPosition(view: activityIndicator.view, position: indicatorFrame.center)
            transition.setBounds(view: activityIndicator.view, bounds: CGRect(origin: CGPoint(), size: indicatorFrame.size))
        } else if let activityIndicator = self.activityIndicator {
            self.activityIndicator = nil
            activityIndicator.view.removeFromSuperview()
        }
        self.iconView.isHidden = self.activity
        
        let searchBarFrame = CGRect(origin: CGPoint(x: 36.0, y: 0.0), size: CGSize(width: backgroundFrame.width - 36.0 - 4.0, height: 44.0))
        transition.setFrame(view: self.searchBar.view, frame: searchBarFrame)
        self.searchBar.updateLayout(boundingSize: searchBarFrame.size, leftInset: 0.0, rightInset: 0.0, transition: transition.containedViewLayoutTransition)
        
        if self.close.icon.image == nil {
            self.close.icon.image = generateImage(CGSize(width: 40.0, height: 40.0), contextGenerator: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                
                context.setLineWidth(2.0)
                context.setLineCap(.round)
                context.setStrokeColor(UIColor.white.cgColor)
                
                context.beginPath()
                context.move(to: CGPoint(x: 12.0, y: 12.0))
                context.addLine(to: CGPoint(x: size.width - 12.0, y: size.height - 12.0))
                context.move(to: CGPoint(x: size.width - 12.0, y: 12.0))
                context.addLine(to: CGPoint(x: 12.0, y: size.height - 12.0))
                context.strokePath()
            })?.withRenderingMode(.alwaysTemplate)
        }
        
        if let image = close.icon.image {
            self.close.icon.frame = image.size.centered(in: CGRect(origin: CGPoint(), size: closeFrame.size))
        }
        self.close.icon.tintColor = self.theme.chat.inputPanel.panelControlColor
        
        transition.setFrame(view: self.close.background, frame: closeFrame)
        self.close.background.update(size: closeFrame.size, cornerRadius: closeFrame.height * 0.5, isDark: self.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: transition)
        
        return size
    }
    
    func activate() {
        self.searchBar.activate()
    }
    
    func deactivate() {
        self.searchBar.deactivate(clear: false)
    }
}
