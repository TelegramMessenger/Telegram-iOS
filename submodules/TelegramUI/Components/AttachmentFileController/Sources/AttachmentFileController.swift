import Foundation
import UIKit
import AsyncDisplayKit
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
import PeerMessagesMediaPlaylist
import ContextUI

private final class AttachmentFileControllerArguments {
    let context: AccountContext
    let isAudio: Bool
    let isAttach: Bool
    let openGallery: () -> Void
    let openFiles: () -> Void
    let scanDocument: () -> Void
    let expandSavedMusic: () -> Void
    let expandRecentMusic: () -> Void
    let send: (Message) -> Void
    let toggleMediaPlayback: (Message) -> Void
    let isSelectionActive: () -> Bool
    let toggleMessageSelection: (Message) -> Void
    let setMessageSelection: ([MessageId], Message?, Bool) -> Void
    let openMessageContextAction: ((EngineMessage, ASDisplayNode?, CGRect?, UIGestureRecognizer?) -> Void)

    init(context: AccountContext, isAudio: Bool, isAttach: Bool, openGallery: @escaping () -> Void, openFiles: @escaping () -> Void, scanDocument: @escaping () -> Void, expandSavedMusic: @escaping () -> Void, expandRecentMusic: @escaping () -> Void, send: @escaping (Message) -> Void, toggleMediaPlayback: @escaping (Message) -> Void, isSelectionActive: @escaping () -> Bool, toggleMessageSelection: @escaping (Message) -> Void, setMessageSelection: @escaping ([MessageId], Message?, Bool) -> Void, openMessageContextAction: @escaping ((EngineMessage, ASDisplayNode?, CGRect?, UIGestureRecognizer?) -> Void)) {
        self.context = context
        self.isAudio = isAudio
        self.isAttach = isAttach
        self.openGallery = openGallery
        self.openFiles = openFiles
        self.scanDocument = scanDocument
        self.expandSavedMusic = expandSavedMusic
        self.expandRecentMusic = expandRecentMusic
        self.send = send
        self.toggleMediaPlayback = toggleMediaPlayback
        self.isSelectionActive = isSelectionActive
        self.toggleMessageSelection = toggleMessageSelection
        self.setMessageSelection = setMessageSelection
        self.openMessageContextAction = openMessageContextAction
    }
}

private enum AttachmentFileSection: Int32 {
    case select
    case savedMusic
    case recent
    case global
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
    case scanDocument(PresentationTheme, String)

    case savedHeader(PresentationTheme, String)
    case savedFile(Int32, PresentationTheme, Message?, ChatHistoryMessageSelection)
    case savedShowMore(PresentationTheme, String)

    case recentHeader(PresentationTheme, String)
    case recentFile(Int32, PresentationTheme, Message?, ChatHistoryMessageSelection)
    case recentShowMore(PresentationTheme, String)

    case globalHeader(PresentationTheme, String)
    case globalFile(Int32, PresentationTheme, Message?, ChatHistoryMessageSelection)
    case globalShowMore(PresentationTheme, String)

    var section: ItemListSectionId {
        switch self {
        case .selectFromGallery, .selectFromFiles, .scanDocument:
            return AttachmentFileSection.select.rawValue
        case .savedHeader, .savedFile, .savedShowMore:
            return AttachmentFileSection.savedMusic.rawValue
        case .recentHeader, .recentFile, .recentShowMore:
            return AttachmentFileSection.recent.rawValue
        case .globalHeader, .globalFile, .globalShowMore:
            return AttachmentFileSection.global.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .selectFromGallery:
            return 0
        case .selectFromFiles:
            return 1
        case .scanDocument:
            return 2
        case .savedHeader:
            return 3
        case let .savedFile(index, _, _, _):
            return 4 + index
        case .savedShowMore:
            return 9999
        case .recentHeader:
            return 10000
        case let .recentFile(index, _, _, _):
            return 10001 + index
        case .recentShowMore:
            return 100000
        case .globalHeader:
            return 100001
        case let .globalFile(index, _, _, _):
            return 100002 + index
        case .globalShowMore:
            return 200000
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
        case let .scanDocument(lhsTheme, lhsText):
            if case let .scanDocument(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
        case let .savedFile(lhsIndex, lhsTheme, lhsMessage, lhsSelection):
            if case let .savedFile(rhsIndex, rhsTheme, rhsMessage, rhsSelection) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, areMessagesEqual(lhsMessage, rhsMessage), lhsSelection == rhsSelection {
                return true
            } else {
                return false
            }
        case let .savedShowMore(lhsTheme, lhsText):
            if case let .savedShowMore(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
        case let .recentFile(lhsIndex, lhsTheme, lhsMessage, lhsSelection):
            if case let .recentFile(rhsIndex, rhsTheme, rhsMessage, rhsSelection) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, areMessagesEqual(lhsMessage, rhsMessage), lhsSelection == rhsSelection {
                return true
            } else {
                return false
            }
        case let .recentShowMore(lhsTheme, lhsText):
            if case let .recentShowMore(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .globalHeader(lhsTheme, lhsText):
            if case let .globalHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .globalFile(lhsIndex, lhsTheme, lhsMessage, lhsSelection):
            if case let .globalFile(rhsIndex, rhsTheme, rhsMessage, rhsSelection) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, areMessagesEqual(lhsMessage, rhsMessage), lhsSelection == rhsSelection {
                return true
            } else {
                return false
            }
        case let .globalShowMore(lhsTheme, lhsText):
            if case let .globalShowMore(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
        case let .scanDocument(_, text):
            return ItemListPeerActionItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesItemList.scanIcon(presentationData.theme), title: text, alwaysPlain: false, sectionId: self.section, height: .generic, editing: false, action: {
                arguments.scanDocument()
            })
        case let .savedHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .savedFile(_, _, message, selection):
            let interaction = ListMessageItemInteraction(openMessage: { message, _ in
                if arguments.isSelectionActive() {
                    arguments.toggleMessageSelection(message)
                } else {
                    arguments.send(message)
                }
                return false
            }, openMessageContextMenu: { message, _, node, rect, gesture in
                arguments.openMessageContextAction(EngineMessage(message), node, rect, gesture)
            }, toggleMediaPlayback: { message in
                arguments.toggleMediaPlayback(message)
            }, toggleMessagesSelection: { ids, value in
                arguments.setMessageSelection(ids, message, value)
            }, openUrl: { _, _, _, _ in }, openInstantPage: { _, _ in }, longTap: { _, _ in }, getHiddenMedia: { return [:] })

            let dateTimeFormat = arguments.context.sharedContext.currentPresentationData.with({$0}).dateTimeFormat
            let chatPresentationData = ChatPresentationData(theme: ChatPresentationThemeData(theme: presentationData.theme, wallpaper: .color(0)), fontSize: presentationData.fontSize, strings: presentationData.strings, dateTimeFormat: dateTimeFormat, nameDisplayOrder: .firstLast, disableAnimations: false, largeEmoji: false, chatBubbleCorners: PresentationChatBubbleCorners(mainRadius: 0, auxiliaryRadius: 0, mergeBubbleCorners: false))
            return ListMessageItem(presentationData: chatPresentationData, systemStyle: .glass, context: arguments.context, chatLocation: .peer(id: arguments.context.account.peerId), interaction: interaction, message: message, selection: selection, displayHeader: false, isDownloadList: arguments.isAudio, isStoryMusic: true, isAttachMusic: arguments.isAttach, displayFileInfo: true, displayBackground: true, style: .blocks, sectionId: self.section)
        case let .savedShowMore(theme, text):
            return ItemListPeerActionItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesItemList.downArrowImage(theme), title: text, sectionId: self.section, editing: false, action: {
                arguments.expandSavedMusic()
            })
        case let .recentHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .recentFile(_, _, message, selection):
            let interaction = ListMessageItemInteraction(openMessage: { message, _ in
                if arguments.isSelectionActive() {
                    arguments.toggleMessageSelection(message)
                } else {
                    arguments.send(message)
                }
                return false
            }, openMessageContextMenu: { message, _, node, rect, gesture in
                arguments.openMessageContextAction(EngineMessage(message), node, rect, gesture)
            }, toggleMediaPlayback: { message in
                arguments.toggleMediaPlayback(message)
            }, toggleMessagesSelection: { ids, value in
                arguments.setMessageSelection(ids, message, value)
            }, openUrl: { _, _, _, _ in }, openInstantPage: { _, _ in }, longTap: { _, _ in }, getHiddenMedia: { return [:] })

            let dateTimeFormat = arguments.context.sharedContext.currentPresentationData.with({$0}).dateTimeFormat
            let chatPresentationData = ChatPresentationData(theme: ChatPresentationThemeData(theme: presentationData.theme, wallpaper: .color(0)), fontSize: presentationData.fontSize, strings: presentationData.strings, dateTimeFormat: dateTimeFormat, nameDisplayOrder: .firstLast, disableAnimations: false, largeEmoji: false, chatBubbleCorners: PresentationChatBubbleCorners(mainRadius: 0, auxiliaryRadius: 0, mergeBubbleCorners: false))
            return ListMessageItem(presentationData: chatPresentationData, systemStyle: .glass, context: arguments.context, chatLocation: .peer(id: PeerId(0)), interaction: interaction, message: message, selection: selection, displayHeader: false, isDownloadList: arguments.isAudio, isStoryMusic: true, isAttachMusic: arguments.isAttach, displayFileInfo: true, displayBackground: true, style: .blocks, sectionId: self.section)
        case let .recentShowMore(theme, text):
            return ItemListPeerActionItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesItemList.downArrowImage(theme), title: text, sectionId: self.section, editing: false, action: {
                arguments.expandRecentMusic()
            })
        case let .globalHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .globalFile(_, _, message, selection):
            let interaction = ListMessageItemInteraction(openMessage: { message, _ in
                if arguments.isSelectionActive() {
                    arguments.toggleMessageSelection(message)
                } else {
                    arguments.send(message)
                }
                return false
            }, openMessageContextMenu: { message, _, node, rect, gesture in
                arguments.openMessageContextAction(EngineMessage(message), node, rect, gesture)
            }, toggleMediaPlayback: { message in
                arguments.toggleMediaPlayback(message)
            }, toggleMessagesSelection: { ids, value in
                arguments.setMessageSelection(ids, message, value)
            }, openUrl: { _, _, _, _ in }, openInstantPage: { _, _ in }, longTap: { _, _ in }, getHiddenMedia: { return [:] })

            let dateTimeFormat = arguments.context.sharedContext.currentPresentationData.with({$0}).dateTimeFormat
            let chatPresentationData = ChatPresentationData(theme: ChatPresentationThemeData(theme: presentationData.theme, wallpaper: .color(0)), fontSize: presentationData.fontSize, strings: presentationData.strings, dateTimeFormat: dateTimeFormat, nameDisplayOrder: .firstLast, disableAnimations: false, largeEmoji: false, chatBubbleCorners: PresentationChatBubbleCorners(mainRadius: 0, auxiliaryRadius: 0, mergeBubbleCorners: false))
            return ListMessageItem(presentationData: chatPresentationData, systemStyle: .glass, context: arguments.context, chatLocation: .peer(id: PeerId(0)), interaction: interaction, message: message, selection: selection, displayHeader: false, isDownloadList: arguments.isAudio, isStoryMusic: true, isAttachMusic: arguments.isAttach, displayFileInfo: true, displayBackground: true, style: .blocks, sectionId: self.section)
        case let .globalShowMore(theme, text):
            return ItemListPeerActionItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesItemList.downArrowImage(theme), title: text, sectionId: self.section, editing: false, action: {

            })
        }
    }
}

private func attachmentFileControllerEntries(
    presentationData: PresentationData,
    mode: AttachmentFileControllerMode,
    state: AttachmentFileControllerState,
    savedMusic: [Message]?,
    recentDocuments: [Message]?,
    hasScan: Bool,
    empty: Bool
) -> [AttachmentFileEntry] {
    guard !empty else {
        return []
    }
    var entries: [AttachmentFileEntry] = []
    if case .recent = mode {
        entries.append(.selectFromGallery(presentationData.theme, presentationData.strings.Attachment_SelectFromGallery))
    }
    entries.append(.selectFromFiles(presentationData.theme, presentationData.strings.Attachment_SelectFromFiles))
    if hasScan {
        entries.append(.scanDocument(presentationData.theme, presentationData.strings.Attachment_ScanDocument))
    }

    let listTitle: String
    switch mode {
    case .recent:
        listTitle = presentationData.strings.Attachment_RecentlySentFiles
    case .audio:
        listTitle = presentationData.strings.Attachment_ChatsMusic
    }

    if case let .audio(audioMode) = mode, audioMode != .savedMusic {
        if let savedMusic, savedMusic.count > 0 {
            entries.append(.savedHeader(presentationData.theme, presentationData.strings.Attachment_ProfileMusic.uppercased()))

            var savedMusic = savedMusic
            var hasShowMore = false
            if savedMusic.count > 4 && !state.savedMusicExpanded {
                savedMusic = Array(savedMusic.prefix(3))
                hasShowMore = true
            }

            var i: Int32 = 0
            for file in savedMusic {
                entries.append(.savedFile(i, presentationData.theme, file, messageSelectionState(state: state, message: file)))
                i += 1
            }
            if hasShowMore {
                entries.append(.savedShowMore(presentationData.theme, presentationData.strings.MediaEditor_Audio_ShowMore))
            }
        }
    }

    if let recentDocuments {
        if recentDocuments.count > 0 {
            entries.append(.recentHeader(presentationData.theme, listTitle.uppercased()))

            var recentDocuments = recentDocuments
            var hasShowMore = false
            if !"".isEmpty, case .audio = mode, recentDocuments.count > 4 && !state.savedMusicExpanded {
                recentDocuments = Array(recentDocuments.prefix(3))
                hasShowMore = true
            }

            var i: Int32 = 0
            for file in recentDocuments {
                entries.append(.recentFile(i, presentationData.theme, file, messageSelectionState(state: state, message: file)))
                i += 1
            }
            if hasShowMore {
                entries.append(.recentShowMore(presentationData.theme, presentationData.strings.MediaEditor_Audio_ShowMore))
            }
        }
    } else {
        entries.append(.recentHeader(presentationData.theme, listTitle.uppercased()))
        for i in 0 ..< 11 {
            entries.append(.recentFile(Int32(i), presentationData.theme, nil, .none))
        }
    }

    return entries
}

final class AttachmentFileContext: AttachmentMediaPickerContext {
    private weak var controller: AttachmentFileControllerImpl?

    var selectionCount: Signal<Int, NoError> {
        if let controller = self.controller {
            return controller.selectionCount.get()
        } else {
            return .single(0)
        }
    }

    init(controller: AttachmentFileControllerImpl) {
        self.controller = controller
    }

    func setCaption(_ caption: NSAttributedString) {
        self.controller?.caption = caption
    }

    func send(mode: AttachmentMediaPickerSendMode, attachmentMode: AttachmentMediaPickerAttachmentMode, parameters: ChatSendMessageActionSheetController.SendParameters?) {
        self.controller?.mulitpleCompletion?(mode, .files, parameters, self.controller?.caption)
    }

    func schedule(parameters: ChatSendMessageActionSheetController.SendParameters?) {
//        self.controller?.presentScheduleTimePicker ({ time, repeatPeriod in
//            self.controller?.contactsNode.requestMultipleAction?(false, time, parameters)
//        })
    }

    func mainButtonAction() {
    }
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

    fileprivate var caption: NSAttributedString?
    fileprivate var selectionCount = ValuePromise<Int>(0)
    
    fileprivate var bottomEdgeColor: UIColor = .clear
    
    fileprivate var mulitpleCompletion: ((AttachmentMediaPickerSendMode, AttachmentMediaPickerAttachmentMode, ChatSendMessageActionSheetController.SendParameters?, NSAttributedString?) -> Void)?

    var delayDisappear = false

    var hasBottomEdgeEffect = true

    var resetForReuseImpl: () -> Void = {}
    var onDismissImpl: () -> Void = {}
    public func resetForReuse() {
        self.resetForReuseImpl()
        self.scrollToTop?()
    }

    public func prepareForReuse() {
        self.delayDisappear = true
        self.visibleBottomContentOffsetChanged?(self.visibleBottomContentOffset)
        self.delayDisappear = false
    }
    
    public func requestDismiss(completion: @escaping () -> Void) {
        self.onDismissImpl()
        completion()
    }
    
    public func shouldDismissImmediately() -> Bool {
        return true
    }

    public var mediaPickerContext: AttachmentMediaPickerContext? {
        return AttachmentFileContext(controller: self)
    }

    private var bottomEdgeEffectView: EdgeEffectView?

    var isSearching: Bool = false {
        didSet {
            self.requestLayout(transition: .animated(duration: 0.2, curve: .easeInOut))
        }
    }

    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        let edgeEffectHeight: CGFloat = 88.0

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
            bottomEdgeEffectView.update(content: self.bottomEdgeColor, blur: true, alpha: 1.0, rect: bottomEdgeEffectFrame, edge: .bottom, edgeSize: bottomEdgeEffectFrame.height, transition: ComponentTransition(transition))
        } else if let bottomEdgeEffectView = self.bottomEdgeEffectView {
            bottomEdgeEffectView.removeFromSuperview()
        }
    }
}

private struct AttachmentFileControllerState: Equatable {
    var searching: Bool
    var savedMusicExpanded: Bool
    var recentMusicExpanded: Bool
    var selectedMessageIds: [MessageId]?
    var messageMap: [MessageId: EngineMessage]
}

private func messageSelectionState(state: AttachmentFileControllerState, message: Message?) -> ChatHistoryMessageSelection {
    guard let message, let selectedMessageIds = state.selectedMessageIds else {
        return .none
    }
    if let index = selectedMessageIds.firstIndex(where: { $0 == message.id }) {
        return .selectable(selected: true, num: index)
    } else {
        return .selectable(selected: false, num: nil)
    }
}

public enum AttachmentFileControllerMode {
    public enum AudioMode {
        case chat
        case story
        case savedMusic
    }
    
    case recent
    case audio(AudioMode)
    
    var isAudio: Bool {
        if case .audio = self {
            return true
        } else {
            return false
        }
    }
}

public enum AttachmentFileControllerSource: Equatable {
    public enum PollMode: Equatable {
        case description
        case quizAnswer
    }
    
    case generic
    case poll(PollMode)
}

public func makeAttachmentFileControllerImpl(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
    mode: AttachmentFileControllerMode = .recent,
    source: AttachmentFileControllerSource = .generic,
    bannedSendMedia: (Int32, Bool)? = nil,
    presentGallery: @escaping () -> Void = {},
    presentFiles: @escaping () -> Void = {},
    presentDocumentScanner: (() -> Void)? = nil,
    send: @escaping ([AnyMediaReference], Bool, Int32?, NSAttributedString?) -> Void
) -> AttachmentFileController {
    let actionsDisposable = DisposableSet()

    let statePromise = ValuePromise(AttachmentFileControllerState(searching: false, savedMusicExpanded: false, recentMusicExpanded: false, selectedMessageIds: nil, messageMap: [:]), ignoreRepeated: true)
    let stateValue = Atomic(value: AttachmentFileControllerState(searching: false, savedMusicExpanded: false, recentMusicExpanded: false, selectedMessageIds: nil, messageMap: [:]))
    let updateState: ((AttachmentFileControllerState) -> AttachmentFileControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }

    var updateTabBarVisibilityImpl: ((Bool) -> Void)?
    var expandImpl: (() -> Void)?
    var dismissImpl: (() -> Void)?
    var dismissInputImpl: (() -> Void)?
    var updateIsSearchingImpl: ((Bool) -> Void)?
    var updateSelectionCountImpl: ((Int) -> Void)?
    var presentInGlobalOverlayImpl: ((ViewController) -> Void)?
    var updateBottomColorImpl: ((UIColor) -> Void)?
    
    var isAudio = false
    var isAttach = true
    if case let .audio(mode) = mode {
        isAudio = true
        if case .story = mode {
            isAttach = false
        }
    }
    
    var didPreviewAudio = false
    let arguments = AttachmentFileControllerArguments(
        context: context,
        isAudio: isAudio,
        isAttach: isAttach,
        openGallery: {
            presentGallery()
        },
        openFiles: {
            presentFiles()
        },
        scanDocument: {
            presentDocumentScanner?()
            dismissImpl?()
        },
        expandSavedMusic: {
            updateState { state in
                var updatedState = state
                updatedState.savedMusicExpanded = true
                return updatedState
            }
            expandImpl?()
        },
        expandRecentMusic: {
            updateState { state in
                var updatedState = state
                updatedState.recentMusicExpanded = true
                return updatedState
            }
        },
        send: { message in
            if message.id.namespace == Namespaces.Message.Local {
                if let file = message.media.first(where: { $0 is TelegramMediaFile }) as? TelegramMediaFile {
                    let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                    |> deliverOnMainQueue).start(next: { peer in
                        guard let peer, let peerReference = PeerReference(peer._asPeer()) else {
                            return
                        }
                        send([.savedMusic(peer: peerReference, media: file)], false, nil, nil)
                    })
                    dismissImpl?()
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
                        send([.message(message: MessageReference(message), media: file)], false, nil, nil)
                    }
                    dismissImpl?()
                })
            }
        },
        toggleMediaPlayback: { message in
            didPreviewAudio = true
            
            let playlistLocation: PeerMessagesPlaylistLocation = .custom(messages: .single(([message], 0, false)), canReorder: false, at: message.id, loadMore: nil, hidePanel: true)
            context.sharedContext.mediaManager.setPlaylist((context, PeerMessagesMediaPlaylist(context: context, location: playlistLocation, chatLocationContextHolder: nil)), type: .music, control: .playback(.togglePlayPause))
        },
        isSelectionActive: {
            return stateValue.with { $0.selectedMessageIds != nil }
        },
        toggleMessageSelection: { message in
            updateState { state in
                guard var selectedMessageIds = state.selectedMessageIds else {
                    return state
                }
                let messageId = message.id
                if selectedMessageIds.contains(messageId) {
                    selectedMessageIds.removeAll(where: { $0 == messageId })
                } else {
                    selectedMessageIds.append(messageId)
                }
                var updatedState = state
                updatedState.selectedMessageIds = selectedMessageIds
                updatedState.messageMap[messageId] = EngineMessage(message)
                updateSelectionCountImpl?(selectedMessageIds.count)
                return updatedState
            }
        },
        setMessageSelection: { messageIds, message, value in
            updateState { state in
                guard var selectedMessageIds = state.selectedMessageIds else {
                    return state
                }
                for messageId in messageIds {
                    if value {
                        selectedMessageIds.append(messageId)
                    } else {
                        selectedMessageIds.removeAll(where: { $0 == messageId })
                    }
                }
                var updatedState = state
                updatedState.selectedMessageIds = selectedMessageIds
                if let message {
                    updatedState.messageMap[message.id] = EngineMessage(message)
                }
                updateSelectionCountImpl?(selectedMessageIds.count)
                return updatedState
            }
        },
        openMessageContextAction: { message, node, rect, anyRecognizer in
            guard let node = node as? ContextExtractedContentContainingNode else {
                return
            }

            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let gesture: ContextGesture? = anyRecognizer as? ContextGesture

            var items: [ContextMenuItem] = []
            if case .audio = mode {
                items.append(.action(ContextMenuActionItem(text: "Play", icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Play"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                    c?.dismiss(completion: {})
                    
                    let playlistLocation: PeerMessagesPlaylistLocation = .custom(messages: .single(([message._asMessage()], 0, false)), canReorder: false, at: message.id, loadMore: nil, hidePanel: true)
                    context.sharedContext.mediaManager.setPlaylist((context, PeerMessagesMediaPlaylist(context: context, location: playlistLocation, chatLocationContextHolder: nil)), type: .music, control: .playback(.togglePlayPause))
                })))
            }

            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_ContextMenuSelect, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Select"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                c?.dismiss(completion: {})
                updateState { state in
                    var updatedState = state
                    var selectedMessageIds = updatedState.selectedMessageIds ?? []
                    selectedMessageIds.append(message.id)
                    updatedState.selectedMessageIds = selectedMessageIds
                    updatedState.messageMap[message.id] = message
                    updateSelectionCountImpl?(selectedMessageIds.count)
                    return updatedState
                }
            })))

            let controller = makeContextController(presentationData: presentationData, source: .extracted(MessageContextExtractedContentSource(sourceNode: node)), items: .single(ContextController.Items(content: .list(items))), recognizer: nil, gesture: gesture)
            presentInGlobalOverlayImpl?(controller)
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
            context.engine.messages.searchMessages(location: .general(scope: .everywhere, tags: [.music], minDate: nil, maxDate: nil, folderId: nil), query: "", state: nil)
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
        let isSelectionActive = state.selectedMessageIds != nil
        let searchButtonComponent = (state.searching || isSelectionActive) ? nil : AnyComponentWithIdentity(id: "search", component: AnyComponent(searchButton))
        let searchButtonNode: BarComponentHostNode? = (!state.searching && !isSelectionActive) ? existingSearchButton.modify { current in
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

        var hasAudioSearch = false
        if let data = context.currentAppConfiguration.with({ $0 }).data, let _ = data["music_search_username"] as? String {
            hasAudioSearch = true
        }

        var rightNavigationButton: ItemListNavigationButton?
        if bannedSendMedia == nil && (recentDocuments == nil || (recentDocuments?.count ?? 0) > 10 || (mode.isAudio && hasAudioSearch)) {
            rightNavigationButton = searchButtonNode.flatMap { ItemListNavigationButton(content: .node($0), style: .regular, enabled: true, action: {}) }
        }

        let title: String
        var subtitle: String?
        switch mode {
        case .recent:
            title = presentationData.strings.Attachment_File
        case .audio:
            title = presentationData.strings.MediaEditor_Audio_Title
        }
        
        if case let .poll(pollMode) = source {
            switch pollMode {
            case .description:
                subtitle = presentationData.strings.Attachment_File_PollSubtitle_Description
            case .quizAnswer:
                subtitle = presentationData.strings.Attachment_File_PollSubtitle_Explanation
            }
        }
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: subtitle.flatMap { .textWithSubtitle(title, $0) } ?? .text(title),
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
            }, didPreviewAudio: {
                didPreviewAudio = true
            })
        }

        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: attachmentFileControllerEntries(presentationData: presentationData, mode: mode, state: state, savedMusic: savedMusic, recentDocuments: recentDocuments, hasScan: presentDocumentScanner != nil, empty: bannedSendMedia != nil), style: .blocks, emptyStateItem: emptyItem, searchItem: searchItem, crossfadeState: crossfade, animateChanges: animateChanges)

        updateBottomColorImpl?(presentationData.theme.list.blocksBackgroundColor)
        
        return (controllerState, (listState, arguments))
    } |> afterDisposed {
        actionsDisposable.dispose()
        let _ = savedMusicContext?.state
    }

    let controller = AttachmentFileControllerImpl(context: context, state: signal, hideNavigationBarBackground: true)
    controller.mulitpleCompletion = { sendMode, _, _, caption in
        let _ = stateValue.with({ state in
            if let selectedMessageIds = state.selectedMessageIds {
                var remoteMessageIds: [MessageId] = []
                for id in selectedMessageIds {
                    if let message = state.messageMap[id]?._asMessage() {
                        if message.id.namespace == Namespaces.Message.Cloud {
                            remoteMessageIds.append(message.id)
                        }
                    }
                }
                let _ = combineLatest(queue: Queue.mainQueue(),
                    context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)),
                    context.engine.messages.getMessagesLoadIfNecessary(remoteMessageIds, strategy: .cloud(skipLocal: true))
                    |> `catch` { _ in
                        return .single(.result([]))
                    }
                    |> mapToSignal { result -> Signal<[Message], NoError> in
                    guard case let .result(result) = result else {
                        return .complete()
                    }
                    return .single(result)
                }
                ).start(next: { peer, remoteMessages in
                    guard let peer, let peerReference = PeerReference(peer._asPeer()) else {
                        return
                    }
                    var messageMap: [MessageId: Message] = [:]
                    for message in remoteMessages {
                        messageMap[message.id] = message
                    }
                    
                    var mediaReferences: [AnyMediaReference] = []
                    
                    for id in selectedMessageIds {
                        if var message = state.messageMap[id]?._asMessage() {
                            if message.id.namespace == Namespaces.Message.Cloud, let remoteMessage = messageMap[message.id] {
                                message = remoteMessage
                            }
                            if let file = message.media.first(where: { $0 is TelegramMediaFile}) as? TelegramMediaFile {
                                if message.id.namespace == Namespaces.Message.Cloud {
                                    mediaReferences.append(.message(message: MessageReference(message), media: file))
                                } else {
                                    mediaReferences.append(.savedMusic(peer: peerReference, media: file))
                                }
                            }
                        }
                    }
                    
                    send(mediaReferences, sendMode == .silently, nil, caption)
                })
                dismissImpl?()
            }
        })

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
            updatedState.selectedMessageIds = nil
            return updatedState
        }
        
        if didPreviewAudio {
            context.sharedContext.mediaManager.setPlaylist(nil, type: .music, control: .playback(.pause))
        }
    }
    controller.onDismissImpl = {
        if didPreviewAudio {
            context.sharedContext.mediaManager.setPlaylist(nil, type: .music, control: .playback(.pause))
        }
    }

    if case let .audio(audioMode) = mode, audioMode != .chat {
        controller.hasBottomEdgeEffect = false
    }
    
    updateIsSearchingImpl = { [weak controller] isSearching in
        controller?.isSearching = isSearching
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss(animated: true)
        
        if didPreviewAudio {
            context.sharedContext.mediaManager.setPlaylist(nil, type: .music, control: .playback(.pause))
        }
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
    updateSelectionCountImpl = { [weak controller] count in
        controller?.selectionCount.set(count)
    }
    presentInGlobalOverlayImpl = { [weak controller] c in
        controller?.presentInGlobalOverlay(c)
    }
    updateBottomColorImpl = { [weak controller] color in
        controller?.bottomEdgeColor = color
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
    let controller = AttachmentController(context: context, updatedPresentationData: updatedPresentationData, style: .glass, chatLocation: nil, buttons: [.audio], initialButton: .audio, fromMenu: false, hasTextInput: false)
    controller.requestController = { _, present in
        let filePickerController = makeAttachmentFileControllerImpl(context: context, updatedPresentationData: updatedPresentationData, mode: .audio(.story), bannedSendMedia: nil, presentGallery: {}, presentFiles: {
            selectFromFiles()
            dismissImpl?()
        }, presentDocumentScanner: nil, send: { files, _, _, _ in
            completion(files.first!)
            dismissImpl?()
        }) as! AttachmentFileControllerImpl
        present(filePickerController, filePickerController.mediaPickerContext)
        return true
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

private final class MessageContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = true
    let blurBackground: Bool = true

    let shouldBeDismissed: Signal<Bool, NoError>

    private let sourceNode: ContextExtractedContentContainingNode

    init(sourceNode: ContextExtractedContentContainingNode, shouldBeDismissed: Signal<Bool, NoError>? = nil) {
        self.sourceNode = sourceNode
        self.shouldBeDismissed = shouldBeDismissed ?? .single(false)
    }

    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(containingItem: .node(self.sourceNode), contentAreaInScreenSpace: UIScreen.main.bounds)
    }

    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
