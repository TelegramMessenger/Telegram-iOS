import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import LegacyComponents
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import ItemListPeerActionItem
import AttachmentUI
import TelegramStringFormatting
import ListMessageItem
import ComponentFlow
import GlassBarButtonComponent
import BundleIconComponent
import EdgeEffect
import SaveToCameraRoll

private final class AttachmentFileControllerArguments {
    let context: AccountContext
    let isAudio: Bool
    let openGallery: () -> Void
    let openFiles: () -> Void
    let expandSavedMusic: () -> Void
    let send: (Message) -> Void
   
    init(context: AccountContext, isAudio: Bool, openGallery: @escaping () -> Void, openFiles: @escaping () -> Void, expandSavedMusic: @escaping () -> Void, send: @escaping (Message) -> Void) {
        self.context = context
        self.isAudio = isAudio
        self.openGallery = openGallery
        self.openFiles = openFiles
        self.expandSavedMusic = expandSavedMusic
        self.send = send
    }
}

private enum AttachmentFileSection: Int32 {
    case select
    case savedMusic
    case recent
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

private enum AttachmentFileEntry: ItemListNodeEntry {
    case selectFromGallery(PresentationTheme, String)
    case selectFromFiles(PresentationTheme, String)
    
    case savedHeader(PresentationTheme, String)
    case savedFile(Int32, PresentationTheme, Message?)
    case showMore(PresentationTheme, String)
    
    case recentHeader(PresentationTheme, String)
    case file(Int32, PresentationTheme, Message?)
  
    var section: ItemListSectionId {
        switch self {
            case .selectFromGallery, .selectFromFiles:
                return AttachmentFileSection.select.rawValue
            case .savedHeader, .savedFile, .showMore:
                return AttachmentFileSection.savedMusic.rawValue
            case .recentHeader, .file:
                return AttachmentFileSection.recent.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .selectFromGallery:
                return 0
            case .selectFromFiles:
                return 1
            case .savedHeader:
                return 2
            case let .savedFile(index, _, _):
                return 3 + index
            case .showMore:
                return 9999
            case .recentHeader:
                return 10000
            case let .file(index, _, _):
                return 10001 + index
        }
    }
    
    static func ==(lhs: AttachmentFileEntry, rhs: AttachmentFileEntry) -> Bool {
        switch lhs {
            case let .selectFromGallery(lhsTheme, lhsText):
                if case let .selectFromGallery(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .selectFromFiles(lhsTheme, lhsText):
                if case let .selectFromFiles(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .savedHeader(lhsTheme, lhsText):
                if case let .savedHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .savedFile(lhsIndex, lhsTheme, lhsMessage):
                if case let .savedFile(rhsIndex, rhsTheme, rhsMessage) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, areMessagesEqual(lhsMessage, rhsMessage) {
                    return true
                } else {
                    return false
                }
            case let .showMore(lhsTheme, lhsText):
                if case let .showMore(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .recentHeader(lhsTheme, lhsText):
                if case let .recentHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .file(lhsIndex, lhsTheme, lhsMessage):
                if case let .file(rhsIndex, rhsTheme, rhsMessage) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, areMessagesEqual(lhsMessage, rhsMessage) {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: AttachmentFileEntry, rhs: AttachmentFileEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AttachmentFileControllerArguments
        switch self {
            case let .selectFromGallery(_, text):
                return ItemListPeerActionItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesItemList.imageIcon(presentationData.theme), title: text, alwaysPlain: false, sectionId: self.section, height: .generic, editing: false, action: {
                    arguments.openGallery()
                })
            case let .selectFromFiles(_, text):
                return ItemListPeerActionItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesItemList.cloudIcon(presentationData.theme), title: text, alwaysPlain: false, sectionId: self.section, height: .generic, editing: false, action: {
                    arguments.openFiles()
                })
            
            case let .savedHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .savedFile(_, _, message):
                let interaction = ListMessageItemInteraction(openMessage: { message, _ in
                    arguments.send(message)
                    return false
                }, openMessageContextMenu: { _, _, _, _, _ in }, toggleMessagesSelection: { _, _ in }, openUrl: { _, _, _, _ in }, openInstantPage: { _, _ in }, longTap: { _, _ in }, getHiddenMedia: { return [:] })
            
                let dateTimeFormat = arguments.context.sharedContext.currentPresentationData.with({$0}).dateTimeFormat
                let chatPresentationData = ChatPresentationData(theme: ChatPresentationThemeData(theme: presentationData.theme, wallpaper: .color(0)), fontSize: presentationData.fontSize, strings: presentationData.strings, dateTimeFormat: dateTimeFormat, nameDisplayOrder: .firstLast, disableAnimations: false, largeEmoji: false, chatBubbleCorners: PresentationChatBubbleCorners(mainRadius: 0, auxiliaryRadius: 0, mergeBubbleCorners: false))
                return ListMessageItem(presentationData: chatPresentationData, systemStyle: .glass, context: arguments.context, chatLocation: .peer(id: arguments.context.account.peerId), interaction: interaction, message: message, selection: .none, displayHeader: false, isDownloadList: arguments.isAudio, isStoryMusic: true, displayFileInfo: true, displayBackground: true, style: .blocks, sectionId: self.section)
            case let .showMore(theme, text):
                return ItemListPeerActionItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesItemList.downArrowImage(theme), title: text, sectionId: self.section, editing: false, action: {
                    arguments.expandSavedMusic()
                })
            case let .recentHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .file(_, _, message):
                let interaction = ListMessageItemInteraction(openMessage: { message, _ in
                    arguments.send(message)
                    return false
                }, openMessageContextMenu: { _, _, _, _, _ in }, toggleMessagesSelection: { _, _ in }, openUrl: { _, _, _, _ in }, openInstantPage: { _, _ in }, longTap: { _, _ in }, getHiddenMedia: { return [:] })
            
                let dateTimeFormat = arguments.context.sharedContext.currentPresentationData.with({$0}).dateTimeFormat
                let chatPresentationData = ChatPresentationData(theme: ChatPresentationThemeData(theme: presentationData.theme, wallpaper: .color(0)), fontSize: presentationData.fontSize, strings: presentationData.strings, dateTimeFormat: dateTimeFormat, nameDisplayOrder: .firstLast, disableAnimations: false, largeEmoji: false, chatBubbleCorners: PresentationChatBubbleCorners(mainRadius: 0, auxiliaryRadius: 0, mergeBubbleCorners: false))
            
                return ListMessageItem(presentationData: chatPresentationData, systemStyle: .glass, context: arguments.context, chatLocation: .peer(id: PeerId(0)), interaction: interaction, message: message, selection: .none, displayHeader: false, isDownloadList: arguments.isAudio, isStoryMusic: true, displayFileInfo: true, displayBackground: true, style: .blocks, sectionId: self.section)
        }
    }
}

private func attachmentFileControllerEntries(presentationData: PresentationData, mode: AttachmentFileControllerMode, state: AttachmentFileControllerState, savedMusic: [Message]?, recentDocuments: [Message]?, empty: Bool) -> [AttachmentFileEntry] {
    guard !empty else {
        return []
    }
    var entries: [AttachmentFileEntry] = []
    if case .recent = mode {
        entries.append(.selectFromGallery(presentationData.theme, presentationData.strings.Attachment_SelectFromGallery))
    }
    entries.append(.selectFromFiles(presentationData.theme, presentationData.strings.Attachment_SelectFromFiles))
    
    let listTitle: String
    switch mode {
    case .recent:
        listTitle = presentationData.strings.Attachment_RecentlySentFiles
    case .audio:
        listTitle = presentationData.strings.Attachment_SharedAudio
    }
    
    if case .audio = mode {
        if let savedMusic, savedMusic.count > 0 {
            entries.append(.savedHeader(presentationData.theme, presentationData.strings.MediaEditor_Audio_SavedMusic.uppercased()))
            var savedMusic = savedMusic
            var showMore = false
            if savedMusic.count > 4 && !state.savedMusicExpanded {
                savedMusic = Array(savedMusic.prefix(3))
                showMore = true
            }
            var i: Int32 = 0
            for file in savedMusic {
                entries.append(.savedFile(i, presentationData.theme, file))
                i += 1
            }
            if showMore {
                entries.append(.showMore(presentationData.theme, presentationData.strings.MediaEditor_Audio_ShowMore))
            }
        }
    }
    
    if let recentDocuments = recentDocuments {
        if recentDocuments.count > 0 {
            entries.append(.recentHeader(presentationData.theme, listTitle.uppercased()))
            var i: Int32 = 0
            for file in recentDocuments {
                entries.append(.file(i, presentationData.theme, file))
                i += 1
            }
        }
    } else {
        entries.append(.recentHeader(presentationData.theme, listTitle.uppercased()))
        for i in 0 ..< 11 {
            entries.append(.file(Int32(i), presentationData.theme, nil))
        }
    }

    return entries
}

private final class AttachmentFileContext: AttachmentMediaPickerContext {
}

public class AttachmentFileControllerImpl: ItemListController, AttachmentFileController, AttachmentContainable {
    public var requestAttachmentMenuExpansion: () -> Void = {}
    public var updateNavigationStack: (@escaping ([AttachmentContainable]) -> ([AttachmentContainable], AttachmentMediaPickerContext?)) -> Void = { _ in }
    public var parentController: () -> ViewController? = {
        return nil
    }
    public var updateTabBarAlpha: (CGFloat, ContainedViewLayoutTransition) -> Void = { _, _ in }
    public var updateTabBarVisibility: (Bool, ContainedViewLayoutTransition) -> Void = { _, _ in }
    public var cancelPanGesture: () -> Void = { }
    public var isContainerPanning: () -> Bool = { return false }
    public var isContainerExpanded: () -> Bool = { return false }
    public var isMinimized: Bool = false
    
    var delayDisappear = false
    
    var hasBottomEdgeEffect = true
    
    var resetForReuseImpl: () -> Void = {}
    public func resetForReuse() {
        self.resetForReuseImpl()
        self.scrollToTop?()
    }
    
    public func prepareForReuse() {
        self.delayDisappear = true
        self.visibleBottomContentOffsetChanged?(self.visibleBottomContentOffset)
        self.delayDisappear = false
    }
    
    public var mediaPickerContext: AttachmentMediaPickerContext? {
        return AttachmentFileContext()
    }
    
    private var topEdgeEffectView: EdgeEffectView?
    private var bottomEdgeEffectView: EdgeEffectView?
    
    var isSearching: Bool = false {
        didSet {
            self.requestLayout(transition: .animated(duration: 0.2, curve: .easeInOut))
        }
    }
    
    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        let topEdgeEffectView: EdgeEffectView
        if let current = self.topEdgeEffectView {
            topEdgeEffectView = current
        } else {
            topEdgeEffectView = EdgeEffectView()
            if let navigationBar = self.navigationBar {
                self.view.insertSubview(topEdgeEffectView, belowSubview: navigationBar.view)
            }
            self.topEdgeEffectView = topEdgeEffectView
        }
        
        let edgeEffectHeight: CGFloat = 88.0
        let topEdgeEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: edgeEffectHeight))
        transition.updateFrame(view: topEdgeEffectView, frame: topEdgeEffectFrame)
        topEdgeEffectView.update(content: .clear, blur: true, alpha: 1.0, rect: topEdgeEffectFrame, edge: .top, edgeSize: topEdgeEffectFrame.height, transition: ComponentTransition(transition))
        
        if self.hasBottomEdgeEffect {
            let bottomEdgeEffectView: EdgeEffectView
            if let current = self.bottomEdgeEffectView {
                bottomEdgeEffectView = current
            } else {
                bottomEdgeEffectView = EdgeEffectView()
                self.view.addSubview(bottomEdgeEffectView)
                self.bottomEdgeEffectView = bottomEdgeEffectView
            }
            
            let bottomEdgeEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - edgeEffectHeight - layout.additionalInsets.bottom), size: CGSize(width: layout.size.width, height: edgeEffectHeight))
            transition.updateFrame(view: bottomEdgeEffectView, frame: bottomEdgeEffectFrame)
            transition.updateAlpha(layer: bottomEdgeEffectView.layer, alpha: self.isSearching ? 0.0 : 1.0)
            bottomEdgeEffectView.update(content: .clear, blur: true, alpha: 1.0, rect: bottomEdgeEffectFrame, edge: .bottom, edgeSize: bottomEdgeEffectFrame.height, transition: ComponentTransition(transition))
        } else if let bottomEdgeEffectView = self.bottomEdgeEffectView {
            bottomEdgeEffectView.removeFromSuperview()
        }
    }
}

private struct AttachmentFileControllerState: Equatable {
    var searching: Bool
    var savedMusicExpanded: Bool
}

public enum AttachmentFileControllerMode {
    case recent
    case audio
}

public func makeAttachmentFileControllerImpl(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, mode: AttachmentFileControllerMode = .recent, bannedSendMedia: (Int32, Bool)?, presentGallery: @escaping () -> Void, presentFiles: @escaping () -> Void, send: @escaping (AnyMediaReference) -> Void) -> AttachmentFileController {
    let actionsDisposable = DisposableSet()
    
    let statePromise = ValuePromise(AttachmentFileControllerState(searching: false, savedMusicExpanded: false), ignoreRepeated: true)
    let stateValue = Atomic(value: AttachmentFileControllerState(searching: false, savedMusicExpanded: false))
    let updateState: ((AttachmentFileControllerState) -> AttachmentFileControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var updateTabBarVisibilityImpl: ((Bool) -> Void)?
    var expandImpl: (() -> Void)?
    var dismissImpl: (() -> Void)?
    var dismissInputImpl: (() -> Void)?
    var updateIsSearchingImpl: ((Bool) -> Void)?
    let arguments = AttachmentFileControllerArguments(
        context: context,
        isAudio: mode == .audio,
        openGallery: {
            presentGallery()
        },
        openFiles: {
            presentFiles()
        },
        expandSavedMusic: {
            updateState { state in
                var updatedState = state
                updatedState.savedMusicExpanded = true
                return updatedState
            }
        },
        send: { message in
            if message.id.namespace == Namespaces.Message.Local {
                if let file = message.media.first(where: { $0 is TelegramMediaFile }) as? TelegramMediaFile {
                    send(.standalone(media: file))
                }
            } else {
                let _ = (context.engine.messages.getMessagesLoadIfNecessary([message.id], strategy: .cloud(skipLocal: true))
                |> `catch` { _ in
                    return .single(.result([]))
                }
                |> mapToSignal { result -> Signal<[Message], NoError> in
                    guard case let .result(result) = result else {
                        return .complete()
                    }
                    return .single(result)
                }
                |> deliverOnMainQueue).startStandalone(next: { messages in
                    if let message = messages.first, let file = message.media.first(where: { $0 is TelegramMediaFile }) as? TelegramMediaFile {
                        send(.message(message: MessageReference(message), media: file))
                    }
                    dismissImpl?()
                })
            }
        }
    )
    
    let recentDocuments: Signal<[Message]?, NoError>
    let savedMusicContext: ProfileSavedMusicContext?
    let savedMusic: Signal<[Message]?, NoError>
    switch mode {
    case .recent:
        recentDocuments = .single(nil)
        |> then(
            context.engine.messages.searchMessages(location: .sentMedia(tags: [.file]), query: "", state: nil)
            |> map { result -> [Message]? in
                return result.0.messages
            }
        )
        savedMusicContext = nil
        savedMusic = .single(nil)
    case .audio:
        recentDocuments = .single(nil)
        |> then(
            context.engine.messages.searchMessages(location: .general(scope: .everywhere, tags: [.music], minDate: nil, maxDate: nil), query: "", state: nil)
            |> map { result -> [Message]? in
                return result.0.messages
            }
        )
        savedMusicContext = ProfileSavedMusicContext(account: context.account, peerId: context.account.peerId)
        savedMusic = .single(nil)
        |> then(
            savedMusicContext!.state
            |> map { state in
                let peerId = context.account.peerId
                var messages: [Message] = []
                let peers = SimpleDictionary<PeerId, Peer>()
//                if let peer {
//                    peers[peerId] = peer._asPeer()
//                }
                for file in state.files {
                    let stableId = UInt32(clamping: file.fileId.id % Int64(Int32.max))
                    messages.append(Message(stableId: stableId, stableVersion: 0, id: MessageId(peerId: peerId, namespace: Namespaces.Message.Local, id: Int32(stableId)), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [], tags: [.music], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: nil, text: "", attributes: [], media: [file], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:]))
                }
                return messages
            }
        )
    }
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
        
    let existingCloseButton = Atomic<BarComponentHostNode?>(value: nil)
    let existingSearchButton = Atomic<BarComponentHostNode?>(value: nil)
    
    let previousRecentDocuments = Atomic<[Message]?>(value: nil)
    let signal = combineLatest(queue: Queue.mainQueue(),
        presentationData,
        recentDocuments,
        savedMusic,
        statePromise.get()
    )
    |> map { presentationData, recentDocuments, savedMusic, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var presentationData = presentationData
        
        let updatedTheme = presentationData.theme.withModalBlocksBackground()
        presentationData = presentationData.withUpdated(theme: updatedTheme)
        
        let barButtonSize = CGSize(width: 44.0, height: 44.0)
        let closeButton = GlassBarButtonComponent(
            size: barButtonSize,
            backgroundColor: nil,
            isDark: presentationData.theme.overallDarkAppearance,
            state: .generic,
            animateScale: false,
            component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                BundleIconComponent(
                    name: "Navigation/Close",
                    tintColor: presentationData.theme.chat.inputPanel.panelControlColor
                )
            )),
            action: { _ in
                dismissImpl?()
            }
        )
        let closeButtonComponent = AnyComponentWithIdentity(id: "close", component: AnyComponent(closeButton))
        let closeButtonNode = existingCloseButton.modify { current in
            let buttonNode: BarComponentHostNode
            if let current {
                buttonNode = current
                buttonNode.component = closeButtonComponent
            } else {
                buttonNode = BarComponentHostNode(component: closeButtonComponent, size: barButtonSize)
            }
            return buttonNode
        }
                
        let searchButton = GlassBarButtonComponent(
            size: barButtonSize,
            backgroundColor: nil,
            isDark: presentationData.theme.overallDarkAppearance,
            state: .generic,
            animateScale: false,
            component: AnyComponentWithIdentity(id: "search", component: AnyComponent(
                BundleIconComponent(
                    name: "Navigation/Search",
                    tintColor: presentationData.theme.chat.inputPanel.panelControlColor
                )
            )),
            action: { _ in
                updateState { state in
                    var updatedState = state
                    updatedState.searching = true
                    return updatedState
                }
                updateTabBarVisibilityImpl?(false)
                updateIsSearchingImpl?(true)
            }
        )
        let searchButtonComponent = state.searching ? nil : AnyComponentWithIdentity(id: "search", component: AnyComponent(searchButton))
        let searchButtonNode: BarComponentHostNode? = !state.searching ? existingSearchButton.modify { current in
            let buttonNode: BarComponentHostNode
            if let current {
                buttonNode = current
                buttonNode.component = searchButtonComponent
            } else {
                buttonNode = BarComponentHostNode(component: searchButtonComponent, size: barButtonSize)
            }
            return buttonNode
        } : nil
                
        let previousRecentDocuments = previousRecentDocuments.swap(recentDocuments)
        let crossfade = previousRecentDocuments == nil && recentDocuments != nil
        var animateChanges = false
        if let previousRecentDocuments = previousRecentDocuments,
           let recentDocuments = recentDocuments,
           !previousRecentDocuments.isEmpty && !recentDocuments.isEmpty,
           !crossfade {
            animateChanges = true
        }
        
        let leftNavigationButton =  closeButtonNode.flatMap { ItemListNavigationButton(content: .node($0), style: .regular, enabled: true, action: {}) }
        
        var rightNavigationButton: ItemListNavigationButton?
        if bannedSendMedia == nil && (recentDocuments == nil || (recentDocuments?.count ?? 0) > 10) {
            rightNavigationButton = searchButtonNode.flatMap { ItemListNavigationButton(content: .node($0), style: .regular, enabled: true, action: {}) }
        }
        
        let title: String
        switch mode {
        case .recent:
            title = presentationData.strings.Attachment_File
        case .audio:
            title = presentationData.strings.MediaEditor_Audio_Title
        }
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(title),
            leftNavigationButton: leftNavigationButton,
            rightNavigationButton: rightNavigationButton,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: true
        )
        
        var emptyItem: AttachmentFileEmptyStateItem?
        if let (untilDate, personal) = bannedSendMedia {
            let banDescription: String
            if untilDate != 0 && untilDate != Int32.max {
                banDescription = presentationData.strings.Conversation_RestrictedMediaTimed(stringForFullDate(timestamp: untilDate, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat)).string
            } else if personal {
                banDescription = presentationData.strings.Conversation_RestrictedMedia
            } else {
                banDescription = presentationData.strings.Conversation_DefaultRestrictedMedia
            }
            emptyItem = AttachmentFileEmptyStateItem(context: context, theme: presentationData.theme, strings: presentationData.strings, content: .bannedSendMedia(text: banDescription, canBoost: false))
        } else if let recentDocuments = recentDocuments,
                  recentDocuments.isEmpty {
            emptyItem = AttachmentFileEmptyStateItem(context: context, theme: presentationData.theme, strings: presentationData.strings, content: .intro)
        }
        
        var searchItem: ItemListControllerSearch?
        if state.searching {
            searchItem = AttachmentFileSearchItem(context: context, mode: mode, presentationData: presentationData, focus: {
                expandImpl?()
            }, cancel: {
                updateState { state in
                    var updatedState = state
                    updatedState.searching = false
                    return updatedState
                }
                updateTabBarVisibilityImpl?(true)
                updateIsSearchingImpl?(false)
            }, send: { message in
                arguments.send(message)
            }, dismissInput: {
                dismissInputImpl?()
            })
        }
        
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: attachmentFileControllerEntries(presentationData: presentationData, mode: mode, state: state, savedMusic: savedMusic, recentDocuments: recentDocuments, empty: bannedSendMedia != nil), style: .blocks, emptyStateItem: emptyItem, searchItem: searchItem, crossfadeState: crossfade, animateChanges: animateChanges)
        
        return (controllerState, (listState, arguments))
    } |> afterDisposed {
        actionsDisposable.dispose()
        let _ = savedMusicContext?.state
    }
    
    let controller = AttachmentFileControllerImpl(context: context, state: signal, hideNavigationBarBackground: true)
    if case .audio = mode {
        controller.hasBottomEdgeEffect = false
    }
    controller.delayDisappear = true
    controller.visibleBottomContentOffsetChanged = { [weak controller] offset in
        switch offset {
            case let .known(value):
                let backgroundAlpha: CGFloat = min(30.0, max(0.0, value)) / 30.0
                if backgroundAlpha.isZero && controller?.delayDisappear == true {
                    Queue.mainQueue().after(0.25, {
                        controller?.updateTabBarAlpha(backgroundAlpha, .animated(duration: 0.1, curve: .easeInOut))
                    })
                } else {
                    controller?.updateTabBarAlpha(backgroundAlpha, .immediate)
                }
            case .unknown, .none:
                controller?.updateTabBarAlpha(1.0, .immediate)
                controller?.delayDisappear = false
        }
    }
    controller.resetForReuseImpl = {
        updateState { state in
            var updatedState = state
            updatedState.searching = false
            return updatedState
        }
    }
    updateIsSearchingImpl = { [weak controller] isSearching in
        controller?.isSearching = isSearching
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss(animated: true)
    }
    dismissInputImpl = { [weak controller] in
        controller?.view.endEditing(true)
    }
    expandImpl = { [weak controller] in
        controller?.requestAttachmentMenuExpansion()
    }
    updateTabBarVisibilityImpl = { [weak controller] isVisible in
        controller?.updateTabBarVisibility(isVisible, .animated(duration: 0.4, curve: .spring))
    }
    return controller
}

public func storyAudioPickerController(
    context: AccountContext,
    selectFromFiles: @escaping () -> Void,
    dismissed: @escaping () -> Void,
    completion: @escaping (AnyMediaReference) -> Void,
) -> ViewController {
    var dismissImpl: (() -> Void)?
    let presentationData = context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: defaultDarkColorPresentationTheme)
    let updatedPresentationData: (PresentationData, Signal<PresentationData, NoError>) = (presentationData, .single(presentationData))
    let controller = AttachmentController(context: context, updatedPresentationData: updatedPresentationData, style: .glass, chatLocation: nil, buttons: [.standalone], initialButton: .standalone, fromMenu: false, hasTextInput: false)
    controller.requestController = { _, present in
        let filePickerController = makeAttachmentFileControllerImpl(context: context, updatedPresentationData: updatedPresentationData, mode: .audio, bannedSendMedia: nil, presentGallery: {}, presentFiles: {
            selectFromFiles()
            dismissImpl?()
        }, send: { file in
            completion(file)
            dismissImpl?()
        }) as! AttachmentFileControllerImpl
        present(filePickerController, filePickerController.mediaPickerContext)
    }
    controller.navigationPresentation = .flatModal
    controller.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    controller.didDismiss = {
        dismissed()
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss(animated: true)
    }
    return controller
}
