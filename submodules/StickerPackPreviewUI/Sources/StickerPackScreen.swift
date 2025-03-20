import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import ShimmerEffect
import ContextUI
import MoreButtonNode
import UndoUI
import TextFormat
import PremiumUI
import OverlayStatusController
import PresentationDataUtils
import StickerPeekUI
import AnimationCache
import MultiAnimationRenderer
import Pasteboard
import StickerPackEditTitleController
import EntityKeyboard
import CameraScreen
import ComponentFlow
import EmojiStatusComponent

private let maxStickersCount = 120

private enum StickerPackPreviewGridEntry: Comparable, Identifiable {
    case sticker(index: Int, stableId: Int, stickerItem: StickerPackItem?, isEmpty: Bool, isPremium: Bool, isLocked: Bool, isEditing: Bool, isAdd: Bool)
    case add
    case emojis(index: Int, stableId: Int, info: StickerPackCollectionInfo, items: [StickerPackItem], title: String?, isInstalled: Bool?)
    
    var stableId: Int {
        switch self {
        case let .sticker(_, stableId, _, _, _, _, _, _):
            return stableId
        case .add:
            return -1
        case let .emojis(_, stableId, _, _, _, _):
            return stableId
        }
    }
    
    var index: Int {
        switch self {
        case let .sticker(index, _, _, _, _, _, _, _):
            return index
        case .add:
            return 100000
        case let .emojis(index, _, _, _, _, _):
            return index
        }
    }
    
    static func <(lhs: StickerPackPreviewGridEntry, rhs: StickerPackPreviewGridEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(context: AccountContext, interaction: StickerPackPreviewInteraction, theme: PresentationTheme, strings: PresentationStrings, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer, isEditable: Bool, isEditing: Bool) -> GridItem {
        switch self {
        case let .sticker(_, _, stickerItem, isEmpty, isPremium, isLocked, _, isAdd):
            return StickerPackPreviewGridItem(context: context, stickerItem: stickerItem, interaction: interaction, theme: theme, isPremium: isPremium, isLocked: isLocked, isEmpty: isEmpty, isEditable: isEditable, isEditing: isEditing, isAdd: isAdd)
        case .add:
            return StickerPackPreviewGridItem(context: context, stickerItem: nil, interaction: interaction, theme: theme, isPremium: false, isLocked: false, isEmpty: false, isEditable: false, isEditing: false, isAdd: true)
        case let .emojis(_, _, info, items, title, isInstalled):
            return StickerPackEmojisItem(context: context, animationCache: animationCache, animationRenderer: animationRenderer, interaction: interaction, info: info, items: items, theme: theme, strings: strings, title: title, isInstalled: isInstalled, isEmpty: false)
        }
    }
}

private struct StickerPackPreviewGridTransaction {
    let deletions: [Int]
    let insertions: [GridNodeInsertItem]
    let updates: [GridNodeUpdateItem]
    let scrollToItem: GridNodeScrollToItem?
    
    init(previousList: [StickerPackPreviewGridEntry], list: [StickerPackPreviewGridEntry], context: AccountContext, interaction: StickerPackPreviewInteraction, theme: PresentationTheme, strings: PresentationStrings, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer, scrollToItem: GridNodeScrollToItem?, isEditable: Bool, isEditing: Bool, invert: Bool = false) {
        var (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: previousList, rightList: list)
        
        if invert, deleteIndices.count == 1, indicesAndItems.count == 1 {
            if let _ = deleteIndices.first, let insertion = indicesAndItems.first, let update = updateIndices.first {
                deleteIndices = [insertion.0]
                indicesAndItems = [(update.0, update.1, update.2)]
                updateIndices = [(update.2, insertion.1, update.0)]
            }
        }
        
        self.deletions = deleteIndices
        self.insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(context: context, interaction: interaction, theme: theme, strings: strings, animationCache: animationCache, animationRenderer: animationRenderer, isEditable: isEditable, isEditing: isEditing), previousIndex: $0.2) }
        self.updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, interaction: interaction, theme: theme, strings: strings, animationCache: animationCache, animationRenderer: animationRenderer, isEditable: isEditable, isEditing: isEditing)) }
        
        self.scrollToItem = scrollToItem
    }
    
    init(list: [StickerPackPreviewGridEntry], context: AccountContext, interaction: StickerPackPreviewInteraction, theme: PresentationTheme, strings: PresentationStrings, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer, scrollToItem: GridNodeScrollToItem?, isEditable: Bool, isEditing: Bool) {
        self.deletions = []
        self.insertions = []
        
        var index = 0
        var updates: [GridNodeUpdateItem] = []
        for i in 0 ..< list.count {
            updates.append(GridNodeUpdateItem(index: i, previousIndex: i, item: list[i].item(context: context, interaction: interaction, theme: theme, strings: strings, animationCache: animationCache, animationRenderer: animationRenderer, isEditable: isEditable, isEditing: isEditing)))
            index += 1
        }
        self.updates = updates
        
        self.scrollToItem = nil
    }
}

private enum StickerPackAction {
    case add
    case remove
}

private enum StickerPackNextAction {
    case navigatedNext
    case dismiss
    case ignored
}

private final class StickerPackContainer: ASDisplayNode {
    let index: Int
    private let context: AccountContext
    private weak var controller: StickerPackScreenImpl?
    private var presentationData: PresentationData
    private let stickerPacks: [StickerPackReference]
    private let decideNextAction: (StickerPackContainer, StickerPackAction) -> StickerPackNextAction
    private let requestDismiss: () -> Void
    private let presentInGlobalOverlay: (ViewController, Any?) -> Void
    private let sendSticker: ((FileMediaReference, UIView, CGRect) -> Bool)?
    private let sendEmoji: ((String, ChatTextInputTextCustomEmojiAttribute) -> Void)?
    private let backgroundNode: ASImageNode
    private let previewIconFile: TelegramMediaFile?
    private var mainPreviewIcon: ComponentView<Empty>?
    private let gridNode: GridNode
    private let actionAreaBackgroundNode: NavigationBackgroundNode
    private let actionAreaSeparatorNode: ASDisplayNode
    private let buttonNode: HighlightableButtonNode
    private let titleBackgroundnode: NavigationBackgroundNode
    private let titleNode: ImmediateTextNode
    private var titlePlaceholderNode: ShimmerEffectNode?
    private let titleContainer: ASDisplayNode
    private let titleSeparatorNode: ASDisplayNode
    
    private let topContainerNode: ASDisplayNode
    private let cancelButtonNode: HighlightableButtonNode
    private let moreButtonNode: MoreButtonNode
    
    private(set) var validLayout: (ContainerViewLayout, CGRect, CGFloat, UIEdgeInsets)?
    
    private var nextStableId: Int = 1
    private var currentEntries: [StickerPackPreviewGridEntry] = []
    private var enqueuedTransactions: [StickerPackPreviewGridTransaction] = []
    
    private var updatedTitle: String?
    
    private var itemsDisposable: Disposable?
    private var currentContents: [LoadedStickerPack]?
    private(set) var currentStickerPack: (StickerPackCollectionInfo, [StickerPackItem], Bool)?
    private(set) var currentStickerPacks: [(StickerPackCollectionInfo, [StickerPackItem], Bool)] = []
    private var didReceiveStickerPackResult = false
    
    private let isReadyValue = Promise<Bool>()
    private var didSetReady = false
    var isReady: Signal<Bool, NoError> {
        return self.isReadyValue.get()
    }
    
    var expandProgress: CGFloat = 0.0
    var expandScrollProgress: CGFloat = 0.0
    var modalProgress: CGFloat = 0.0
    var isAnimatingAutoscroll: Bool = false
    let expandProgressUpdated: (StickerPackContainer, ContainedViewLayoutTransition, ContainedViewLayoutTransition) -> Void
    
    private var isDismissed: Bool = false
    
    private let interaction: StickerPackPreviewInteraction
    
    private weak var peekController: PeekController?
    
    var onLoading: () -> Void = {}
    var onReady: () -> Void = {}
    var onError: () -> Void = {}
    
    init(
        index: Int,
        context: AccountContext,
        presentationData: PresentationData,
        stickerPacks: [StickerPackReference],
        loadedStickerPacks: [LoadedStickerPack],
        previewIconFile: TelegramMediaFile?,
        decideNextAction: @escaping (StickerPackContainer, StickerPackAction) -> StickerPackNextAction,
        requestDismiss: @escaping () -> Void,
        expandProgressUpdated: @escaping (StickerPackContainer, ContainedViewLayoutTransition, ContainedViewLayoutTransition) -> Void,
        presentInGlobalOverlay: @escaping (ViewController, Any?) -> Void,
        sendSticker: ((FileMediaReference, UIView, CGRect) -> Bool)?,
        sendEmoji: ((String, ChatTextInputTextCustomEmojiAttribute) -> Void)?,
        longPressEmoji: ((String, ChatTextInputTextCustomEmojiAttribute, ASDisplayNode, CGRect) -> Void)?,
        openMention: @escaping (String) -> Void,
        controller: StickerPackScreenImpl?)
    {
        self.index = index
        self.context = context
        self.controller = controller
        self.presentationData = presentationData
        self.stickerPacks = stickerPacks
        self.decideNextAction = decideNextAction
        self.requestDismiss = requestDismiss
        self.presentInGlobalOverlay = presentInGlobalOverlay
        self.expandProgressUpdated = expandProgressUpdated
        self.sendSticker = sendSticker
        self.sendEmoji = sendEmoji
        self.isEditing = controller?.initialIsEditing ?? false
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = true
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 20.0, color: self.presentationData.theme.actionSheet.opaqueItemBackgroundColor)
        
        self.previewIconFile = previewIconFile
        if self.previewIconFile != nil {
            self.mainPreviewIcon = ComponentView()
        }
        
        self.gridNode = GridNode()
        self.gridNode.scrollView.alwaysBounceVertical = true
        self.gridNode.scrollView.showsVerticalScrollIndicator = false
        
        self.titleBackgroundnode = NavigationBackgroundNode(color: self.presentationData.theme.rootController.navigationBar.blurredBackgroundColor)
        
        self.actionAreaBackgroundNode = NavigationBackgroundNode(color: self.presentationData.theme.rootController.tabBar.backgroundColor)
        
        self.actionAreaSeparatorNode = ASDisplayNode()
        self.actionAreaSeparatorNode.backgroundColor = self.presentationData.theme.rootController.tabBar.separatorColor
        
        self.buttonNode = HighlightableButtonNode()
        self.titleNode = ImmediateTextNode()
        self.titleNode.textAlignment = .center
        self.titleNode.maximumNumberOfLines = 2
        self.titleNode.highlightAttributeAction = { attributes in
            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] {
                return NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)
            } else {
                return nil
            }
        }
        self.titleNode.tapAttributeAction = { attributes, _ in
            if let mention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String, mention.count > 1 {
                openMention(String(mention[mention.index(after:  mention.startIndex)...]))
            }
        }
        
        self.titleContainer = ASDisplayNode()
        self.titleSeparatorNode = ASDisplayNode()
        self.titleSeparatorNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
        
        self.topContainerNode = ASDisplayNode()
        self.cancelButtonNode = HighlightableButtonNode()
        self.moreButtonNode = MoreButtonNode(theme: self.presentationData.theme)
        self.moreButtonNode.iconNode.enqueueState(.more, animated: false)
        
        var addStickerPackImpl: ((StickerPackCollectionInfo, [StickerPackItem]) -> Void)?
        var removeStickerPackImpl: ((StickerPackCollectionInfo) -> Void)?
        var emojiSelectedImpl: ((String, ChatTextInputTextCustomEmojiAttribute) -> Void)?
        var emojiLongPressedImpl: ((String, ChatTextInputTextCustomEmojiAttribute, ASDisplayNode, CGRect) -> Void)?
        var addPressedImpl: (() -> Void)?
        self.interaction = StickerPackPreviewInteraction(playAnimatedStickers: true, addStickerPack: { info, items in
            addStickerPackImpl?(info, items)
        }, removeStickerPack: { info in
            removeStickerPackImpl?(info)
        }, emojiSelected: { text, attribute in
            emojiSelectedImpl?(text, attribute)
        }, emojiLongPressed: { text, attribute, node, frame in
            emojiLongPressedImpl?(text, attribute, node, frame)
        }, addPressed: {
            addPressedImpl?()
        })
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.gridNode)
        self.addSubnode(self.actionAreaBackgroundNode)
        self.addSubnode(self.actionAreaSeparatorNode)
        self.addSubnode(self.buttonNode)
        
        self.titleContainer.addSubnode(self.titleNode)
        self.addSubnode(self.titleContainer)
        self.addSubnode(self.titleSeparatorNode)
        
        self.addSubnode(self.topContainerNode)
        self.topContainerNode.addSubnode(self.cancelButtonNode)
        self.topContainerNode.addSubnode(self.moreButtonNode)
                
        self.gridNode.presentationLayoutUpdated = { [weak self] presentationLayout, transition in
            self?.gridPresentationLayoutUpdated(presentationLayout, transition: transition)
        }
        
        self.gridNode.scrollingInitiated = { [weak self] in
            guard let self else {
                return
            }
            self.hideMainPreviewIcon()
        }
        
        self.gridNode.interactiveScrollingEnded = { [weak self] in
            guard let strongSelf = self, !strongSelf.isDismissed else {
                return
            }
            if let (layout, _, _, _) = strongSelf.validLayout, case .regular = layout.metrics.widthClass {
                return
            }
            let contentOffset = strongSelf.gridNode.scrollView.contentOffset
            let insets = strongSelf.gridNode.scrollView.contentInset
            if contentOffset.y <= -insets.top - 30.0 {
                strongSelf.isDismissed = true
                DispatchQueue.main.async {
                    self?.requestDismiss()
                }
            }
        }
        
        self.gridNode.visibleContentOffsetChanged = { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateButtonBackgroundAlpha()
        }
        
        self.gridNode.interactiveScrollingWillBeEnded = { [weak self] contentOffset, velocity, targetOffset -> CGPoint in
            guard let strongSelf = self, !strongSelf.isDismissed else {
                return targetOffset
            }
            
            let insets = strongSelf.gridNode.scrollView.contentInset
            var modalProgress: CGFloat = 0.0
            
            var updatedOffset = targetOffset
            var resetOffset = false
            
            if targetOffset.y < 0.0 && targetOffset.y >= -insets.top {
                if contentOffset.y > 0.0 {
                    updatedOffset = CGPoint(x: 0.0, y: 0.0)
                    modalProgress = 1.0
                } else {
                    if targetOffset.y > -insets.top / 2.0 || velocity.y <= -100.0 {
                        modalProgress = 1.0
                        resetOffset = true
                    } else {
                        modalProgress = 0.0
                        if contentOffset.y > -insets.top {
                            resetOffset = true
                        }
                    }
                }
            } else if targetOffset.y >= 0.0 {
                modalProgress = 1.0
            }
            
            if abs(strongSelf.modalProgress - modalProgress) > CGFloat.ulpOfOne {
                if contentOffset.y > 0.0 && targetOffset.y > 0.0 {
                } else {
                    resetOffset = true
                }
                strongSelf.modalProgress = modalProgress
                strongSelf.expandProgressUpdated(strongSelf, .animated(duration: 0.4, curve: .spring), .immediate)
            }
            
            if resetOffset {
                let offset: CGPoint
                let isVelocityAligned: Bool
                if modalProgress.isZero {
                    offset = CGPoint(x: 0.0, y: -insets.top)
                    isVelocityAligned = velocity.y < 0.0
                } else {
                    offset = CGPoint(x: 0.0, y: 0.0)
                    isVelocityAligned = velocity.y > 0.0
                }
                
                DispatchQueue.main.async {
                    let duration: Double
                    if isVelocityAligned {
                        let minVelocity: CGFloat = 400.0
                        let maxVelocity: CGFloat = 1000.0
                        let clippedVelocity = max(minVelocity, min(maxVelocity, abs(velocity.y * 500.0)))
                        
                        let distance = abs(offset.y - contentOffset.y)
                        duration = Double(distance / clippedVelocity)
                    } else {
                        duration = 0.5
                    }
                    
                    strongSelf.isAnimatingAutoscroll = true
                    strongSelf.gridNode.autoscroll(toOffset: offset, duration: duration)
                    strongSelf.isAnimatingAutoscroll = false
                }
                updatedOffset = contentOffset
            }
            
            return updatedOffset
        }
        
        let ignoreCache = controller?.ignoreCache ?? false
        let fetchedStickerPacks: Signal<[LoadedStickerPack], NoError> = combineLatest(stickerPacks.map { packReference in
            for pack in loadedStickerPacks {
                if case let .result(info, _, _) = pack, case let .id(id, _) = packReference, info.id.id == id {
                    return .single(pack)
                }
            }
            return context.engine.stickers.loadedStickerPack(reference: packReference, forceActualized: true, ignoreCache: ignoreCache)
        })
        
        self.itemsDisposable = combineLatest(queue: Queue.mainQueue(), fetchedStickerPacks, context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))).start(next: { [weak self] contents, peer in
            guard let strongSelf = self else {
                return
            }
            var hasPremium = false
            if let peer = peer, peer.isPremium {
                hasPremium = true
            }
            strongSelf.updateStickerPackContents(contents, hasPremium: hasPremium)
        })
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.buttonNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.buttonNode.alpha = 0.8
                } else {
                    strongSelf.buttonNode.alpha = 1.0
                    strongSelf.buttonNode.layer.animateAlpha(from: 0.8, to: 1.0, duration: 0.3)
                }
            }
        }
        
        self.cancelButtonNode.setTitle(self.presentationData.strings.Common_Cancel, with: Font.regular(17.0), with: self.presentationData.theme.actionSheet.controlAccentColor, for: .normal)
        self.cancelButtonNode.addTarget(self, action: #selector(self.cancelPressed), forControlEvents: .touchUpInside)
        
        self.moreButtonNode.action = { [weak self] _, gesture in
            if let strongSelf = self {
                strongSelf.morePressed(node: strongSelf.moreButtonNode.contextSourceNode, gesture: gesture)
            }
        }
        
        self.titleNode.linkHighlightColor = self.presentationData.theme.actionSheet.controlAccentColor.withAlphaComponent(0.2)
        
        addStickerPackImpl = { [weak self] info, items in
            guard let strongSelf = self else {
                return
            }
            if let index = strongSelf.currentStickerPacks.firstIndex(where: { $0.0.id == info.id }) {
                strongSelf.currentStickerPacks[index].2 = true
                
                var contents: [LoadedStickerPack] = []
                for (info, items, isInstalled) in strongSelf.currentStickerPacks {
                    contents.append(.result(info: StickerPackCollectionInfo.Accessor(info), items: items, installed: isInstalled))
                }
                strongSelf.updateStickerPackContents(contents, hasPremium: false)
                
                let _ = strongSelf.context.engine.stickers.addStickerPackInteractively(info: info, items: items).start()
            }
        }
        
        removeStickerPackImpl = { [weak self] info in
            guard let strongSelf = self else {
                return
            }
            if let index = strongSelf.currentStickerPacks.firstIndex(where: { $0.0.id == info.id }) {
                strongSelf.currentStickerPacks[index].2 = false
                
                var contents: [LoadedStickerPack] = []
                for (info, items, isInstalled) in strongSelf.currentStickerPacks {
                    contents.append(.result(info: StickerPackCollectionInfo.Accessor(info), items: items, installed: isInstalled))
                }
                strongSelf.updateStickerPackContents(contents, hasPremium: false)
                
                let _ = strongSelf.context.engine.stickers.removeStickerPackInteractively(id: info.id, option: .delete).start()
            }
        }
        
        emojiSelectedImpl = { text, attribute in
            sendEmoji?(text, attribute)
        }
        
        emojiLongPressedImpl = { text, attribute, node, frame in
            longPressEmoji?(text, attribute, node, frame)
        }
        
        addPressedImpl = { [weak self] in
            self?.presentAddStickerOptions()
        }
    }
    
    deinit {
        self.itemsDisposable?.dispose()
    }
    
    private var peekGestureRecognizer: PeekControllerGestureRecognizer?
    private var reorderingGestureRecognizer: ReorderingGestureRecognizer?
    override func didLoad() {
        super.didLoad()
        
        let peekGestureRecognizer = PeekControllerGestureRecognizer(contentAtPoint: { [weak self] point -> Signal<(UIView, CGRect, PeekControllerContent)?, NoError>? in
            if let strongSelf = self {
                if let itemNode = strongSelf.gridNode.itemNodeAtPoint(point) as? StickerPackPreviewGridItemNode, let item = itemNode.stickerPackItem {
                    var canEdit = false
                    if let (info, _, _) = strongSelf.currentStickerPack, info.flags.contains(.isCreator) && !info.flags.contains(.isEmoji) {
                        canEdit = true
                    }
                    
                    let accountPeerId = strongSelf.context.account.peerId
                    return combineLatest(
                        strongSelf.context.engine.stickers.isStickerSaved(id: item.file.fileId),
                        strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: accountPeerId)) |> map { peer -> Bool in
                            var hasPremium = false
                            if case let .user(user) = peer, user.isPremium {
                                hasPremium = true
                            }
                            return hasPremium
                        }
                    )
                    |> deliverOnMainQueue
                    |> map { isStarred, hasPremium -> (UIView, CGRect, PeekControllerContent)? in
                        if let strongSelf = self {
                            var menuItems: [ContextMenuItem] = []
                            if let (info, _, _) = strongSelf.currentStickerPack, info.id.namespace == Namespaces.ItemCollection.CloudStickerPacks {
                                if strongSelf.sendSticker != nil {
                                    var iconName: String
                                    let actionTitle: String
                                    if let title = strongSelf.controller?.actionTitle {
                                        actionTitle = title
                                        iconName = "Chat/Context Menu/Add"
                                    } else {
                                        actionTitle = strongSelf.presentationData.strings.StickerPack_Send
                                        iconName = "Chat/Context Menu/Resend"
                                    }
                                    menuItems.append(.action(ContextMenuActionItem(text: actionTitle, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: iconName), color: theme.contextMenu.primaryColor) }, action: { _, f in
                                        if let strongSelf = self, let peekController = strongSelf.peekController {
                                            if let animationNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.animationNode {
                                                let _ = strongSelf.sendSticker?(.standalone(media: item.file._parse()), animationNode.view, animationNode.bounds)
                                            } else if let imageNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.imageNode {
                                                let _ = strongSelf.sendSticker?(.standalone(media: item.file._parse()), imageNode.view, imageNode.bounds)
                                            }
                                        }
                                        f(.default)
                                    })))
                                }
                                menuItems.append(.action(ContextMenuActionItem(text: isStarred ? strongSelf.presentationData.strings.Stickers_RemoveFromFavorites : strongSelf.presentationData.strings.Stickers_AddToFavorites, icon: { theme in generateTintedImage(image: isStarred ? UIImage(bundleImageName: "Chat/Context Menu/Unfave") : UIImage(bundleImageName: "Chat/Context Menu/Fave"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                                    f(.default)
                                    
                                    if let strongSelf = self {
                                        let _ = (strongSelf.context.engine.stickers.toggleStickerSaved(file: item.file._parse(), saved: !isStarred)
                                        |> deliverOnMainQueue).start(next: { [weak self] result in
                                            if let self, let contorller = self.controller {
                                                contorller.present(UndoOverlayController(presentationData: self.presentationData, content: .sticker(context: context, file: item.file._parse(), loop: true, title: nil, text: !isStarred ? self.presentationData.strings.Conversation_StickerAddedToFavorites : self.presentationData.strings.Conversation_StickerRemovedFromFavorites, undoText: nil, customAction: nil), elevatedLayout: false, action: { _ in return false }), in: .window(.root))
                                            }
                                        })
                                    }
                                })))
                                
                                if canEdit {
                                    menuItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Stickers_EditSticker, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Draw"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                                        f(.default)
                                        if let self {
                                            self.openEditSticker(item.file._parse())
                                        }
                                    })))
                                    if !strongSelf.isEditing {
                                        menuItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Stickers_Reorder, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ReorderItems"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                                            f(.default)
                                            if let self {
                                                self.updateIsEditing(true)
                                            }
                                        })))
                                    }
                                    menuItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Stickers_Delete, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { [weak self] c, f in
                                        if let self {
                                            let contextItems: [ContextMenuItem] = [
                                                .action(ContextMenuActionItem(text: self.presentationData.strings.Common_Back, icon: { theme in
                                                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.contextMenu.primaryColor)
                                                }, iconPosition: .left, action: { c ,f in
                                                    c?.popItems()
                                                })),
                                                .separator,
                                                .action(ContextMenuActionItem(text: self.presentationData.strings.Stickers_Delete_ForEveryone, textColor: .destructive, icon: { _ in return nil }, action: { [weak self] _ ,f in
                                                    f(.default)
                                                    
                                                    if let self, let (info, items, installed) = self.currentStickerPack {
                                                        let updatedItems = items.filter { $0.file.fileId != item.file.fileId }
                                                        if updatedItems.isEmpty {
                                                            let _ = (self.context.engine.stickers.deleteStickerSet(packReference: .id(id: info.id.id, accessHash: info.accessHash))
                                                            |> deliverOnMainQueue).startStandalone()
                                                            
                                                            self.controller?.controllerNode.dismiss()
                                                        } else {
                                                            self.currentStickerPack = (info, updatedItems, installed)
                                                            self.reorderAndUpdateEntries()
                                                            let _ = self.context.engine.stickers.deleteStickerFromStickerSet(sticker: .stickerPack(stickerPack: .id(id: info.id.id, accessHash: info.accessHash), media: item.file._parse())).startStandalone()
                                                        }
                                                    }
                                                }))
                                            ]
                                            c?.pushItems(items: .single(ContextController.Items(content: .list(contextItems))))
                                        }
                                    })))
                                }
                            }
                            return (itemNode.view, itemNode.bounds, StickerPreviewPeekContent(context: strongSelf.context, theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, item: .pack(item.file._parse()), isLocked: item.file.isPremiumSticker && !hasPremium, menu: menuItems, openPremiumIntro: { [weak self] in
                                guard let strongSelf = self else {
                                    return
                                }
                                let controller = PremiumIntroScreen(context: strongSelf.context, source: .stickers)
                                let navigationController = strongSelf.controller?.parentNavigationController
                                strongSelf.controller?.dismiss(animated: false, completion: nil)
                                navigationController?.pushViewController(controller)
                            }))
                        } else {
                            return nil
                        }
                    }
                } else if let itemNode = strongSelf.gridNode.itemNodeAtPoint(point) as? StickerPackEmojisItemNode, let targetItem = itemNode.targetItem(at: strongSelf.gridNode.view.convert(point, to: itemNode.view)) {
                    return strongSelf.emojiSuggestionPeekContent(itemLayer: targetItem.1, file: targetItem.0)
                }
            }
            return nil
        }, present: { [weak self] content, sourceView, sourceRect in
            if let strongSelf = self {
                strongSelf.hideMainPreviewIcon()
                
                let controller = PeekController(presentationData: strongSelf.presentationData, content: content, sourceView: {
                    return (sourceView, sourceRect)
                })
                controller.visibilityUpdated = { [weak self] visible in
                    if let strongSelf = self {
                        strongSelf.gridNode.forceHidden = visible
                    }
                }
                strongSelf.peekController = controller
                strongSelf.presentInGlobalOverlay(controller, nil)
                return controller
            }
            return nil
        }, updateContent: { [weak self] content in
            if let strongSelf = self {
                var item: StickerPreviewPeekItem?
                if let content = content as? StickerPreviewPeekContent {
                    item = content.item
                }
                strongSelf.updatePreviewingItem(item: item, animated: true)
            }
        }, activateBySingleTap: true)
        peekGestureRecognizer.longPressEnabled = !self.isEditing
        self.peekGestureRecognizer = peekGestureRecognizer
        self.gridNode.view.addGestureRecognizer(peekGestureRecognizer)
        
        let reorderingGestureRecognizer = ReorderingGestureRecognizer(animateOnTouch: false, shouldBegin: { [weak self] point in
            if let strongSelf = self, !strongSelf.gridNode.scrollView.isDragging && strongSelf.currentEntries.count > 1 {
                if let itemNode = strongSelf.gridNode.itemNodeAtPoint(point) as? StickerPackPreviewGridItemNode, !itemNode.isAdd {
                    return (true, true, itemNode)
                }
                return (false, false, nil)
            }
            return (false, false, nil)
        }, willBegin: { _ in

        }, began: { [weak self] itemNode in
            self?.beginReordering(itemNode: itemNode)
        }, ended: { [weak self] point in
            if let strongSelf = self {
                if let point = point {
                    strongSelf.endReordering(point: point)
                } else {
                    strongSelf.endReordering(point: nil)
                }
            }
        }, moved: { [weak self] point, offset in
            self?.updateReordering(point: point, offset: offset)
        })
        reorderingGestureRecognizer.isEnabled = self.isEditing
        self.reorderingGestureRecognizer = reorderingGestureRecognizer
        self.gridNode.view.addGestureRecognizer(reorderingGestureRecognizer)
    }
    
    private func hideMainPreviewIcon() {
        if let mainPreviewIconView = self.mainPreviewIcon?.view {
            mainPreviewIconView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak self] _ in
                guard let self else {
                    return
                }
                if let mainPreviewIconView = self.mainPreviewIcon?.view {
                    self.mainPreviewIcon = nil
                    mainPreviewIconView.removeFromSuperview()
                }
            })
            mainPreviewIconView.layer.animateScale(from: 1.0, to: 0.5, duration: 0.2, removeOnCompletion: false)
        }
    }
    
    private var reorderFeedback: HapticFeedback?
    private var reorderNode: ReorderingItemNode?
    private var reorderInitialIndex: Int?
    private var isReordering = false
    private var reorderPosition: Int?
    
    private func beginReordering(itemNode: StickerPackPreviewGridItemNode) {
        self.isReordering = true
        
        if let reorderNode = self.reorderNode {
            reorderNode.removeFromSupernode()
        }
        
        self.interaction.reorderingFileId = itemNode.stickerPackItem?.file.fileId
        
        var reorderInitialIndex: Int = 0
        for entry in self.currentEntries {
            if case let .sticker(_, _, item, _, _, _, _, _) = entry, item?.file.fileId == itemNode.stickerPackItem?.file.fileId {
                break
            }
            reorderInitialIndex += 1
        }
        self.reorderInitialIndex = reorderInitialIndex
                
        let reorderNode = ReorderingItemNode(itemNode: itemNode, initialLocation: itemNode.frame.origin)
        self.reorderNode = reorderNode
        self.gridNode.addSubnode(reorderNode)
        
        itemNode.isHidden = true
        
        if self.reorderFeedback == nil {
            self.reorderFeedback = HapticFeedback()
        }
        self.reorderFeedback?.impact()
    }
    
    private func endReordering(point: CGPoint?) {
        self.interaction.reorderingFileId = nil
        self.reorderInitialIndex = nil
        
        if let reorderNode = self.reorderNode {
            self.reorderNode = nil
        
            if let itemNode = reorderNode.itemNode, let _ = point {
                reorderNode.animateCompletion(completion: { [weak reorderNode] in
                    reorderNode?.removeFromSupernode()
                })
                self.reorderFeedback?.tap()
                
                if let reorderPosition = self.reorderPosition, let file = itemNode.stickerPackItem?.file {
                    let _ = self.context.engine.stickers.reorderSticker(sticker: .standalone(media: file._parse()), position: reorderPosition).startStandalone()
                    
                    if let (info, items, isInstalled) = self.currentStickerPack {
                        var updatedItems = items
                        if let index = items.firstIndex(where: { $0.file.fileId == file.fileId }) {
                            let item = items[index]
                            updatedItems.remove(at: index)
                            updatedItems.insert(item, at: reorderPosition)
                        }
                        self.currentStickerPack = (info, updatedItems, isInstalled)
                    }
                }
            } else {
                reorderNode.removeFromSupernode()
                reorderNode.itemNode?.isHidden = false
            }
            
            self.updateEntries(reload: true)
        }
        
        self.isReordering = false
        self.reorderPosition = nil
    }
    
    private func updateReordering(point: CGPoint, offset: CGPoint) {
        if let reorderNode = self.reorderNode {
            reorderNode.updateOffset(offset: offset)
            
            var targetNode: StickerPackPreviewGridItemNode?
            if let itemNode = self.gridNode.itemNodeAtPoint(point) as? StickerPackPreviewGridItemNode {
                targetNode = itemNode
            }
            
            var previousReorderPosition = self.reorderPosition
            if previousReorderPosition == nil {
                previousReorderPosition = self.reorderInitialIndex
            }
            
            var reorderPosition = self.reorderPosition
            if targetNode !== reorderNode.itemNode {
                var index = 0
                for entry in self.currentEntries {
                    if case let .sticker(_, _, item, _, _, _, _, _) = entry, item?.file.fileId == targetNode?.stickerPackItem?.file.fileId {
                        reorderPosition = index
                        break
                    }
                    index += 1
                }
            }
            
            var invert = false
            if let previousReorderPosition, let reorderPosition, reorderPosition < previousReorderPosition {
                invert = true
            }
            
            if self.reorderPosition != reorderPosition {
                self.reorderPosition = reorderPosition
                self.reorderAndUpdateEntries(invert: invert)
            }
        }
    }
    
    private func emojiSuggestionPeekContent(itemLayer: CALayer, file: TelegramMediaFile) -> Signal<(UIView, CGRect, PeekControllerContent)?, NoError> {
        let context = self.context
        
        var collectionId: ItemCollectionId?
        for attribute in file.attributes {
            if case let .CustomEmoji(_, _, _, packReference) = attribute {
                switch packReference {
                case let .id(id, _):
                    collectionId = ItemCollectionId(namespace: Namespaces.ItemCollection.CloudEmojiPacks, id: id)
                default:
                    break
                }
            }
        }
        
        var bubbleUpEmojiOrStickersets: [ItemCollectionId] = []
        if let collectionId {
            bubbleUpEmojiOrStickersets.append(collectionId)
        }
        
        let accountPeerId = context.account.peerId
        
        return context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: accountPeerId))
        |> map { peer -> Bool in
            var hasPremium = false
            if case let .user(user) = peer, user.isPremium {
                hasPremium = true
            }
            return hasPremium
        }
        |> deliverOnMainQueue
        |> map { [weak self, weak itemLayer] hasPremium -> (UIView, CGRect, PeekControllerContent)? in
            guard let strongSelf = self, let itemLayer = itemLayer else {
                return nil
            }
            
            var menuItems: [ContextMenuItem] = []
            menuItems.removeAll()
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            var isLocked = false
            if !hasPremium {
                isLocked = file.isPremiumEmoji
                /*if isLocked && chatPeerId == context.account.peerId {
                    isLocked = false
                }*/
            }
            
            let sendEmoji: (TelegramMediaFile) -> Void = { file in
                guard let self else {
                    return
                }
                var text = "."
                var emojiAttribute: ChatTextInputTextCustomEmojiAttribute?
                loop: for attribute in file.attributes {
                    switch attribute {
                    case let .CustomEmoji(_, _, displayText, stickerPackReference):
                        text = displayText
                        
                        var packId: ItemCollectionId?
                        if case let .id(id, _) = stickerPackReference {
                            packId = ItemCollectionId(namespace: Namespaces.ItemCollection.CloudEmojiPacks, id: id)
                        }
                        emojiAttribute = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: packId, fileId: file.fileId.id, file: file)
                        break loop
                    default:
                        break
                    }
                }
                
                if let emojiAttribute {
                    self.sendEmoji?(text, emojiAttribute)
                }
            }
            let setStatus: (TelegramMediaFile) -> Void = { file in
                guard let self else {
                    return
                }
                guard let controller = self.controller else {
                    return
                }
                
                let context = self.context
                
                let _ = context.engine.accountData.setEmojiStatus(file: file, expirationDate: nil).startStandalone()
                
                var animateInAsReplacement = false
                animateInAsReplacement = false
                                            
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                
                let undoController = UndoOverlayController(presentationData: presentationData, content: .sticker(context: context, file: file, loop: true, title: nil, text: presentationData.strings.EmojiStatus_AppliedText, undoText: nil, customAction: nil), elevatedLayout: false, animateInAsReplacement: animateInAsReplacement, action: { _ in return false })
                controller.present(undoController, in: .window(.root))
            }
            let copyEmoji: (TelegramMediaFile) -> Void = { file in
                var text = "."
                var emojiAttribute: ChatTextInputTextCustomEmojiAttribute?
                loop: for attribute in file.attributes {
                    switch attribute {
                    case let .CustomEmoji(_, _, displayText, _):
                        text = displayText
                        
                        emojiAttribute = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: file.fileId.id, file: file)
                        break loop
                    default:
                        break
                    }
                }
                
                if let _ = emojiAttribute {
                    storeMessageTextInPasteboard(text, entities: [MessageTextEntity(range: 0 ..< (text as NSString).length, type: .CustomEmoji(stickerPack: nil, fileId: file.fileId.id))])
                }
            }
            
            if strongSelf.sendEmoji != nil {
                menuItems.append(.action(ContextMenuActionItem(text: presentationData.strings.EmojiPreview_SendEmoji, icon: { theme in
                    if let image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Download"), color: theme.actionSheet.primaryTextColor) {
                        return generateImage(image.size, rotatedContext: { size, context in
                            context.clear(CGRect(origin: CGPoint(), size: size))
                            
                            if let cgImage = image.cgImage {
                                context.draw(cgImage, in: CGRect(origin: CGPoint(), size: size))
                            }
                        })
                    } else {
                        return nil
                    }
                }, action: { _, f in
                    sendEmoji(file)
                    f(.default)
                })))
            }
            
            menuItems.append(.action(ContextMenuActionItem(text: presentationData.strings.EmojiPreview_SetAsStatus, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Smile"), color: theme.actionSheet.primaryTextColor)
            }, action: { _, f in
                f(.default)
                
                guard let strongSelf = self else {
                    return
                }
                
                if hasPremium {
                    setStatus(file)
                } else {
                    var replaceImpl: ((ViewController) -> Void)?
                    let controller = PremiumDemoScreen(context: context, subject: .animatedEmoji, action: {
                        let controller = PremiumIntroScreen(context: context, source: .animatedEmoji)
                        replaceImpl?(controller)
                    })
                    replaceImpl = { [weak controller] c in
                        controller?.replace(with: c)
                    }
                    strongSelf.controller?.push(controller)
                }
            })))
            
            menuItems.append(.action(ContextMenuActionItem(text: presentationData.strings.EmojiPreview_CopyEmoji, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.actionSheet.primaryTextColor)
            }, action: { _, f in
                copyEmoji(file)
                f(.default)
            })))
            
            if menuItems.isEmpty {
                return nil
            }
            
            let content = StickerPreviewPeekContent(context: context, theme: presentationData.theme, strings: presentationData.strings, item: .pack(file), isLocked: isLocked, menu: menuItems, openPremiumIntro: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                let controller = PremiumIntroScreen(context: strongSelf.context, source: .stickers)
                let navigationController = strongSelf.controller?.parentNavigationController
                strongSelf.controller?.dismiss(animated: false, completion: nil)
                navigationController?.pushViewController(controller)
            })
            
            return (strongSelf.view, itemLayer.convert(itemLayer.bounds, to: strongSelf.view.layer), content)
        }
    }
        
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 20.0, color: self.presentationData.theme.actionSheet.opaqueItemBackgroundColor)
        
        self.titleBackgroundnode.updateColor(color: self.presentationData.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
        self.actionAreaBackgroundNode.updateColor(color: self.presentationData.theme.rootController.tabBar.backgroundColor, transition: .immediate)
        self.actionAreaSeparatorNode.backgroundColor = self.presentationData.theme.rootController.tabBar.separatorColor
        self.titleSeparatorNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
        
        self.cancelButtonNode.setTitle(self.presentationData.strings.Common_Cancel, with: Font.regular(17.0), with: self.presentationData.theme.actionSheet.controlAccentColor, for: .normal)
        self.moreButtonNode.theme = self.presentationData.theme
        
        self.titleNode.linkHighlightColor = self.presentationData.theme.actionSheet.controlAccentColor.withAlphaComponent(0.5)
        
        if let currentContents = self.currentContents?.first {
            let buttonColor: UIColor
            var buttonFont: UIFont = Font.semibold(17.0)
            
            if self.isEditing {
                buttonColor = self.presentationData.theme.list.itemCheckColors.foregroundColor
            } else if let controller = self.controller, let _ = controller.mainActionTitle {
                buttonColor = self.presentationData.theme.list.itemCheckColors.foregroundColor
            } else {
                switch currentContents {
                case .fetching:
                    buttonColor = .clear
                case .none:
                    buttonColor = self.presentationData.theme.list.itemAccentColor
                case let .result(info, _, installed):
                    if info.flags.contains(.isCreator) && !info.flags.contains(.isEmoji) {
                        buttonColor = installed ? self.presentationData.theme.list.itemAccentColor : self.presentationData.theme.list.itemCheckColors.foregroundColor
                    } else {
                        buttonColor = installed ? self.presentationData.theme.list.itemDestructiveColor : self.presentationData.theme.list.itemCheckColors.foregroundColor
                    }
                    if installed {
                        buttonFont = Font.regular(17.0)
                    }
                }
            }
    
            self.buttonNode.setTitle(self.buttonNode.attributedTitle(for: .normal)?.string ?? "", with: buttonFont, with: buttonColor, for: .normal)
        }
                
        if !self.currentEntries.isEmpty {
            self.updateEntries()
        }
        
        let titleFont = Font.semibold(17.0)
        let title = self.updatedTitle ?? (self.titleNode.attributedText?.string ?? "")
        let entities = generateTextEntities(title, enabledTypes: [.mention])
        self.titleNode.attributedText = stringWithAppliedEntities(title, entities: entities, baseColor: self.presentationData.theme.actionSheet.primaryTextColor, linkColor: self.presentationData.theme.actionSheet.controlAccentColor, baseFont: titleFont, linkFont: titleFont, boldFont: titleFont, italicFont: titleFont, boldItalicFont: titleFont, fixedFont: titleFont, blockQuoteFont: titleFont, message: nil)
        
        if let (layout, _, _, _) = self.validLayout {
            let _ = self.titleNode.updateLayout(CGSize(width: layout.size.width - max(12.0, self.cancelButtonNode.frame.width) * 2.0 - 40.0, height: .greatestFiniteMagnitude))
            self.updateLayout(layout: layout, transition: .immediate)
        }
    }
    
    private var isEditing = false
    func updateEntries(reload: Bool = false) {
        guard let controller = self.controller else {
            return
        }
        
        var isEditable = false
        if let info = self.currentStickerPack?.0, info.flags.contains(.isCreator) && !info.flags.contains(.isEmoji) {
            isEditable = true
        }
        
        let transaction: StickerPackPreviewGridTransaction
        if reload {
            transaction = StickerPackPreviewGridTransaction(list: self.currentEntries, context: self.context, interaction: self.interaction, theme: self.presentationData.theme, strings: self.presentationData.strings, animationCache: controller.animationCache, animationRenderer: controller.animationRenderer, scrollToItem: nil, isEditable: isEditable, isEditing: self.isEditing)
        } else {
            transaction = StickerPackPreviewGridTransaction(previousList: self.currentEntries, list: self.currentEntries, context: self.context, interaction: self.interaction, theme: self.presentationData.theme, strings: self.presentationData.strings, animationCache: controller.animationCache, animationRenderer: controller.animationRenderer, scrollToItem: nil, isEditable: isEditable, isEditing: self.isEditing)
        }
        self.enqueueTransaction(transaction)
    }
    
    private func updateIsEditing(_ isEditing: Bool) {
        self.isEditing = isEditing
        self.updateEntries(reload: true)
        self.updateButton()
        self.peekGestureRecognizer?.longPressEnabled = !isEditing
        self.reorderingGestureRecognizer?.isEnabled = isEditing
        if let (layout, _, _, _) = self.validLayout {
            self.updateLayout(layout: layout, transition: .animated(duration: 0.3, curve: .easeInOut))
        }
        
        if isEditing {
            self.expandIfNeeded(force: true)
        }
    }
    
    @objc private func morePressed(node: ContextReferenceContentNode, gesture: ContextGesture?) {
        guard let controller = self.controller else {
            return
        }
        let strings = self.presentationData.strings

        let text: String
        let shareSubject: ShareControllerSubject
        if !self.currentStickerPacks.isEmpty {
            var links: String = ""
            for (info, _, _) in self.currentStickerPacks {
                if !links.isEmpty {
                    links += "\n"
                }
                if info.id.namespace == Namespaces.ItemCollection.CloudEmojiPacks {
                    links += "https://t.me/addemoji/\(info.shortName)"
                } else {
                    links += "https://t.me/addstickers/\(info.shortName)"
                }
            }
            text = links
            shareSubject = .text(text)
        } else if let (info, _, _) = self.currentStickerPack {
            if info.id.namespace == Namespaces.ItemCollection.CloudEmojiPacks {
                text = "https://t.me/addemoji/\(info.shortName)"
            } else {
                text = "https://t.me/addstickers/\(info.shortName)"
            }
            shareSubject = .url(text)
        } else {
            return
        }
           
        var items: [ContextMenuItem] = []
        items.append(.action(ContextMenuActionItem(text: strings.StickerPack_Share, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Share"), color: theme.contextMenu.primaryColor)
        }, action: { [weak self] _, f in
            f(.default)
            
            if let strongSelf = self {
                let parentNavigationController = strongSelf.controller?.parentNavigationController
                let shareController = strongSelf.context.sharedContext.makeShareController(
                    context: strongSelf.context,
                    subject: shareSubject,
                    forceExternal: false,
                    shareStory: nil,
                    enqueued: nil,
                    actionCompleted: { [weak parentNavigationController] in
                        if let parentNavigationController = parentNavigationController, let controller = parentNavigationController.topViewController as? ViewController {
                            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                            controller.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                        }
                    }
                )
                strongSelf.controller?.present(shareController, in: .window(.root))
            }
        })))
        
        let copyTitle = self.currentStickerPacks.count > 1 ? strings.StickerPack_CopyLinks : strings.StickerPack_CopyLink
        let copyText = self.currentStickerPacks.count > 1 ? strings.Conversation_LinksCopied : strings.Conversation_LinkCopied
        items.append(.action(ContextMenuActionItem(text: copyTitle, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: theme.contextMenu.primaryColor)
        }, action: {  [weak self] _, f in
            f(.default)
        
            UIPasteboard.general.string = text
            
            if let strongSelf = self {
                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: copyText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
            }
        })))
        
        if let (info, packItems, _) = self.currentStickerPack, info.flags.contains(.isCreator) && !info.flags.contains(.isEmoji) {
            items.append(.separator)
            if packItems.count > 0 {
                items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.StickerPack_Reorder, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ReorderItems"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, f in
                    f(.default)
                    self?.updateIsEditing(true)
                })))
            }
            
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.StickerPack_EditName, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, f in
                f(.default)
                
                self?.presentEditPackTitle()
            })))
            
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.StickerPack_Delete, textColor: .destructive, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
            }, action: { [weak self] c, f in
                if let self, let (_, _, isInstalled) = self.currentStickerPack {
                    if isInstalled {
                        let contextItems: [ContextMenuItem] = [
                            .action(ContextMenuActionItem(text: self.presentationData.strings.StickerPack_Delete_DeleteForEveyone, textColor: .destructive, icon: { _ in return nil }, action: { [weak self] _ ,f in
                                f(.default)
                                
                                self?.presentDeletePack()
                            })),
                            .action(ContextMenuActionItem(text: self.presentationData.strings.StickerPack_Delete_RemoveForMe, icon: { _ in return nil }, action: { [weak self] _ ,f in
                                f(.default)
                                
                                self?.togglePackInstalled()
                            }))
                        ]
                        c?.setItems(.single(ContextController.Items(content: .list(contextItems))), minHeight: nil, animated: true)
                    } else {
                        f(.default)
                        self.presentDeletePack()
                    }
                }
            })))
            
            items.append(.separator)
            
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.StickerPack_EditInfo, textLayout: .multiline, textFont: .small, parseMarkdown: true, icon: { _ in
                return nil
            }, action: { [weak self] _, f in
                f(.default)

                guard let self, let controller = self.controller else {
                    return
                }
                
                controller.controllerNode.openMention("stickers")
            })))
        }
        
        let contextController = ContextController(presentationData: self.presentationData, source: .reference(StickerPackContextReferenceContentSource(controller: controller, sourceNode: node)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
        self.presentInGlobalOverlay(contextController, nil)
    }
    
    private let stickerPickerInputData = Promise<StickerPickerInput>()
    private func presentAddStickerOptions() {
        let actionSheet = ActionSheetController(presentationData: self.presentationData)
        var items: [ActionSheetItem] = []
        items.append(ActionSheetButtonItem(title: self.presentationData.strings.StickerPack_CreateNew, color: .accent, action: { [weak actionSheet, weak self] in
           actionSheet?.dismissAnimated()
          
            guard let self, let controller = self.controller else {
                return
            }
            self.presentCreateSticker()
            controller.controllerNode.dismiss()
        }))
        items.append(ActionSheetButtonItem(title: self.presentationData.strings.StickerPack_AddExisting, color: .accent, action: { [weak actionSheet, weak self] in
            actionSheet?.dismissAnimated()
            
            guard let self, let controller = self.controller else {
                return
            }
            self.presentAddExistingSticker()
            controller.controllerNode.dismiss()
        }))
        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        self.presentInGlobalOverlay(actionSheet, nil)
        
        let stickerItems = EmojiPagerContentComponent.stickerInputData(
            context: self.context,
            animationCache: self.context.animationCache,
            animationRenderer: self.context.animationRenderer,
            stickerNamespaces: [Namespaces.ItemCollection.CloudStickerPacks],
            stickerOrderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudSavedStickers, Namespaces.OrderedItemList.CloudRecentStickers, Namespaces.OrderedItemList.CloudAllPremiumStickers],
            chatPeerId: self.context.account.peerId,
            hasSearch: true,
            hasTrending: false,
            forceHasPremium: true
        )
        
        let signal = stickerItems
        |> deliverOnMainQueue
        |> map { stickers -> StickerPickerInput in
            return StickerPickerInputData(emoji: nil, stickers: stickers, gifs: nil)
        }
        
        self.stickerPickerInputData.set(signal)
    }
    
    private func presentCreateSticker() {
        guard let (info, _, _) = self.currentStickerPack else {
            return
        }
        let context = self.context
        let presentationData = self.presentationData
        let updatedPresentationData = self.controller?.updatedPresentationData
        let navigationController = self.controller?.parentNavigationController as? NavigationController
        let sendSticker = self.controller?.sendSticker
        
        var dismissImpl: (() -> Void)?
        let mainController = context.sharedContext.makeStickerMediaPickerScreen(
            context: context,
            getSourceRect: { return .zero },
            completion: { result, transitionView, transitionRect, transitionImage, fromCamera, completion, cancelled in
                let editorController = context.sharedContext.makeStickerEditorScreen(
                    context: context,
                    source: result,
                    intro: false,
                    transitionArguments: transitionView.flatMap { ($0, transitionRect, transitionImage) },
                    completion: { file, emoji, commit in
                        dismissImpl?()
                        let sticker = ImportSticker(
                            resource: .standalone(resource: file.resource),
                            emojis: emoji,
                            dimensions: file.dimensions ?? PixelDimensions(width: 512, height: 512),
                            duration: file.duration,
                            mimeType: file.mimeType,
                            keywords: ""
                        )
                        let packReference: StickerPackReference = .id(id: info.id.id, accessHash: info.accessHash)
                        let _ = (context.engine.stickers.addStickerToStickerSet(packReference: packReference, sticker: sticker)
                        |> deliverOnMainQueue).start(completed: {
                            commit()
                            
                            let packController = StickerPackScreen(context: context, updatedPresentationData: updatedPresentationData, mainStickerPack: packReference, stickerPacks: [packReference], loadedStickerPacks: [], previewIconFile: nil, expandIfNeeded: true, parentNavigationController: navigationController, sendSticker: sendSticker, sendEmoji: nil, actionPerformed: nil, dismissed: nil, getSourceRect: nil)
                            (navigationController?.viewControllers.last as? ViewController)?.present(packController, in: .window(.root))
                            
                            Queue.mainQueue().after(0.1) {
                                packController.present(UndoOverlayController(presentationData: presentationData, content: .sticker(context: context, file: file, loop: true, title: nil, text: presentationData.strings.StickerPack_StickerAdded(info.title).string, undoText: nil, customAction: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
                            }
                        })
                    },
                    cancelled: cancelled
                )
                navigationController?.pushViewController(editorController)
            },
            dismissed: {}
        )
        dismissImpl = { [weak mainController] in
            if let mainController, let navigationController = mainController.navigationController {
                var viewControllers = navigationController.viewControllers
                viewControllers = viewControllers.filter { c in
                    return !(c is CameraScreen) && c !== mainController
                }
                navigationController.setViewControllers(viewControllers, animated: false)
            }
        }
        navigationController?.pushViewController(mainController)
    }
    
    private func presentAddExistingSticker() {
        guard let (info, _, _) = self.currentStickerPack else {
            return
        }
        let presentationData = self.presentationData
        let updatedPresentationData = self.controller?.updatedPresentationData
        let navigationController = self.controller?.parentNavigationController as? NavigationController
        let sendSticker = self.controller?.sendSticker
        
        let context = self.context
        let controller = self.context.sharedContext.makeStickerPickerScreen(context: self.context, inputData: self.stickerPickerInputData, completion: { file in
            var emoji = "🫥"
            for attribute in file.media.attributes {
                if case let .Sticker(displayText, _, _) = attribute, !displayText.isEmpty {
                    emoji = displayText
                    break
                }
            }
            
            let sticker = ImportSticker(
                resource: file.resourceReference(file.media.resource),
                emojis: [emoji],
                dimensions: file.media.dimensions ?? PixelDimensions(width: 512, height: 512),
                duration: file.media.duration,
                mimeType: file.media.mimeType,
                keywords: ""
            )
            let packReference: StickerPackReference = .id(id: info.id.id, accessHash: info.accessHash)
            let _ = (context.engine.stickers.addStickerToStickerSet(packReference: packReference, sticker: sticker)
            |> deliverOnMainQueue).start(completed: {
                let packController = StickerPackScreen(context: context, updatedPresentationData: updatedPresentationData, mainStickerPack: packReference, stickerPacks: [packReference], loadedStickerPacks: [], previewIconFile: nil, expandIfNeeded: true, parentNavigationController: navigationController, sendSticker: sendSticker, sendEmoji: nil, actionPerformed: nil, dismissed: nil, getSourceRect: nil)
                (navigationController?.viewControllers.last as? ViewController)?.present(packController, in: .window(.root))
                
                Queue.mainQueue().after(0.1) {
                    packController.present(UndoOverlayController(presentationData: presentationData, content: .sticker(context: context, file: file.media, loop: true, title: nil, text: presentationData.strings.StickerPack_StickerAdded(info.title).string, undoText: nil, customAction: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
                }
            })
        })
        navigationController?.pushViewController(controller)
    }
    
    private func openEditSticker(_ initialFile: TelegramMediaFile) {
        guard let (info, items, _) = self.currentStickerPack else {
            return
        }
        
        var emoji: [String] = []
        if let item = items.first(where: { $0.file.fileId == initialFile.fileId }) {
            emoji = item.getStringRepresentationsOfIndexKeys()
        }
        
        let context = self.context
        let presentationData = self.presentationData
        let updatedPresentationData = self.controller?.updatedPresentationData
        let navigationController = self.controller?.parentNavigationController as? NavigationController
        let sendSticker = self.controller?.sendSticker
        
        self.controller?.dismiss()
        
        let controller = context.sharedContext.makeStickerEditorScreen(
            context: context,
            source: (initialFile, emoji),
            intro: false,
            transitionArguments: nil,
            completion: { file, emoji, commit in
                let sticker = ImportSticker(
                    resource: .standalone(resource: file.resource),
                    emojis: emoji,
                    dimensions: file.dimensions ?? PixelDimensions(width: 512, height: 512),
                    duration: file.duration,
                    mimeType: file.mimeType,
                    keywords: ""
                )
                let packReference: StickerPackReference = .id(id: info.id.id, accessHash: info.accessHash)
                
                let _ = (context.engine.stickers.replaceSticker(previousSticker: .stickerPack(stickerPack: .id(id: info.id.id, accessHash: info.accessHash), media: initialFile), sticker: sticker)
                |> deliverOnMainQueue).start(completed: {
                    commit()
                    
                    let packController = StickerPackScreen(context: context, updatedPresentationData: updatedPresentationData, mainStickerPack: packReference, stickerPacks: [packReference], loadedStickerPacks: [], previewIconFile: nil, expandIfNeeded: true, parentNavigationController: navigationController, sendSticker: sendSticker, sendEmoji: nil, actionPerformed: nil, dismissed: nil, getSourceRect: nil)
                    (navigationController?.viewControllers.last as? ViewController)?.present(packController, in: .window(.root))
                    
                    Queue.mainQueue().after(0.1) {
                        packController.present(UndoOverlayController(presentationData: presentationData, content: .sticker(context: context, file: file, loop: true, title: nil, text: presentationData.strings.StickerPack_StickerUpdated, undoText: nil, customAction: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
                    }
                })
            },
            cancelled: {}
        )
        navigationController?.pushViewController(controller)
    }
        
    private func presentEditPackTitle() {
        guard let (info, _, _) = self.currentStickerPack else {
            return
        }
        let context = self.context
        var dismissImpl: (() -> Void)?
        let controller = stickerPackEditTitleController(context: context, title: self.presentationData.strings.StickerPack_EditName_Title, text: self.presentationData.strings.StickerPack_EditName_Text, placeholder: self.presentationData.strings.ImportStickerPack_NamePlaceholder, actionTitle: presentationData.strings.Common_Done, value: self.updatedTitle ?? info.title, maxLength: 64, apply: { [weak self] title in
            guard let self, let title else {
                return
            }
            let _ = (context.engine.stickers.renameStickerSet(packReference: .id(id: info.id.id, accessHash: info.accessHash), title: title)
            |> deliverOnMainQueue).startStandalone()
            
            self.updatedTitle = title
            self.updatePresentationData(self.presentationData)
            
            dismissImpl?()
        }, cancel: {})
        dismissImpl = { [weak controller] in
            controller?.dismiss()
        }
        self.controller?.present(controller, in: .window(.root))
    }
    
    private func presentDeletePack() {
        guard let controller = self.controller, let (info, _, _) = self.currentStickerPack else {
            return
        }
        let context = self.context
        controller.present(textAlertController(context: context, updatedPresentationData: controller.updatedPresentationData, title: self.presentationData.strings.StickerPack_Delete_Title, text: self.presentationData.strings.StickerPack_Delete_Text, actions: [TextAlertAction(type: .genericAction, title: self.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .destructiveAction, title: self.presentationData.strings.StickerPack_Delete_Delete, action: { [weak self] in
            let _ = (context.engine.stickers.deleteStickerSet(packReference: .id(id: info.id.id, accessHash: info.accessHash))
            |> deliverOnMainQueue).startStandalone()
            
            self?.controller?.controllerNode.dismiss()
        })]), in: .window(.root))
    }
    
    @objc func cancelPressed() {
        self.requestDismiss()
    }
    
    @objc func buttonPressed() {
        if !self.currentStickerPacks.isEmpty {
            var installedCount = 0
            for (_, _, isInstalled) in self.currentStickerPacks {
                if isInstalled {
                    installedCount += 1
                }
            }
            
            if installedCount == self.currentStickerPacks.count {
                var removedPacks: Signal<[(info: ItemCollectionInfo, index: Int, items: [ItemCollectionItem])], NoError> = .single([])
                for (info, _, _) in self.currentStickerPacks {
                    removedPacks = removedPacks
                    |> mapToSignal { current -> Signal<[(info: ItemCollectionInfo, index: Int, items: [ItemCollectionItem])], NoError> in
                        return self.context.engine.stickers.removeStickerPackInteractively(id: info.id, option: .delete)
                        |> map { result -> [(info: ItemCollectionInfo, index: Int, items: [ItemCollectionItem])] in
                            if let result = result {
                                return current + [(info, result.0, result.1)]
                            } else {
                                return current
                            }
                        }
                    }
                }
                let _ = (removedPacks
                |> deliverOnMainQueue).start(next: { [weak self] results in
                    if !results.isEmpty {
                        self?.controller?.actionPerformed?(results.map { result -> (StickerPackCollectionInfo, [StickerPackItem], StickerPackScreenPerformedAction) in
                            return (result.0 as! StickerPackCollectionInfo, result.2.map { $0 as! StickerPackItem }, .remove(positionInList: result.1))
                        })
                    }
                })
            } else {
                var installedPacks: [(StickerPackCollectionInfo, [StickerPackItem], StickerPackScreenPerformedAction)] = []
                for (info, items, isInstalled) in self.currentStickerPacks {
                    if !isInstalled {
                        installedPacks.append((info, items, .add))
                        let _ = self.context.engine.stickers.addStickerPackInteractively(info: info, items: items).start()
                    }
                }
                
                self.controller?.actionPerformed?(installedPacks)
            }
            self.requestDismiss()
        } else if let (info, _, installed) = self.currentStickerPack {
            if installed, info.flags.contains(.isCreator) && !info.flags.contains(.isEmoji) {
                self.updateIsEditing(!self.isEditing)
                return
            }
            self.togglePackInstalled()
        } else {
            self.requestDismiss()
        }
    }
    
    private func togglePackInstalled() {
        if let (info, items, installed) = self.currentStickerPack {
            var dismissed = false
            switch self.decideNextAction(self, installed ? .remove : .add) {
                case .dismiss:
                    self.requestDismiss()
                    dismissed = true
                case .navigatedNext, .ignored:
                    self.updateStickerPackContents([.result(info: StickerPackCollectionInfo.Accessor(info), items: items, installed: !installed)], hasPremium: false)
            }
            
            let actionPerformed = self.controller?.actionPerformed
            if installed {
                let _ = (self.context.engine.stickers.removeStickerPackInteractively(id: info.id, option: .delete)
                |> deliverOnMainQueue).start(next: { indexAndItems in
                    guard let (positionInList, _) = indexAndItems else {
                        return
                    }
                    if dismissed {
                        actionPerformed?([(info, items, .remove(positionInList: positionInList))])
                    }
                })
            } else {
                let _ = self.context.engine.stickers.addStickerPackInteractively(info: info, items: items).start()
                if dismissed {
                    actionPerformed?([(info, items, .add)])
                }
            }
        }
    }
    
    private func updateButtonBackgroundAlpha() {
        let offset = self.gridNode.visibleContentOffset()
        
        let backgroundAlpha: CGFloat
        switch offset {
            case .known:
                let topPosition = self.view.convert(self.topContainerNode.frame, to: self.view).minY
                let bottomPosition = self.actionAreaBackgroundNode.view.convert(self.actionAreaBackgroundNode.bounds, to: self.view).minY
                let bottomEdgePosition = topPosition + self.topContainerNode.frame.height + self.gridNode.scrollView.contentSize.height
                let bottomOffset = bottomPosition - bottomEdgePosition

                backgroundAlpha = min(10.0, max(0.0, -1.0 * bottomOffset)) / 10.0
            case .unknown, .none:
                backgroundAlpha = 1.0
        }
        
        let transition: ContainedViewLayoutTransition
        var delay: Double = 0.0
        if backgroundAlpha >= self.actionAreaBackgroundNode.alpha || abs(backgroundAlpha - self.actionAreaBackgroundNode.alpha) < 0.01 {
            transition = .immediate
        } else {
            transition = .animated(duration: 0.2, curve: .linear)
            if abs(backgroundAlpha - self.actionAreaBackgroundNode.alpha) > 0.9 {
                delay = 0.2
            }
        }
        transition.updateAlpha(node: self.actionAreaBackgroundNode, alpha: backgroundAlpha, delay: delay)
        transition.updateAlpha(node: self.actionAreaSeparatorNode, alpha: backgroundAlpha, delay: delay)
    }
    
    private func updateButton(count: Int32 = 0) {
        if let currentContents = self.currentContents, currentContents.count == 1, let content = currentContents.first, case let .result(info, _, installed) = content {
            if installed {
                let text: String
                if info.flags.contains(.isCreator) && !info.flags.contains(.isEmoji) {
                    if self.isEditing {
                        var updated = false
                        if let current = self.buttonNode.attributedTitle(for: .normal)?.string, !current.isEmpty && current != self.presentationData.strings.Common_Done {
                            updated = true
                        }
                        
                        if updated, let snapshotView = self.buttonNode.view.snapshotView(afterScreenUpdates: false) {
                            snapshotView.frame = self.buttonNode.view.frame
                            self.buttonNode.view.superview?.insertSubview(snapshotView, belowSubview: self.buttonNode.view)
                            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                                snapshotView?.removeFromSuperview()
                            })
                            self.buttonNode.view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        }
                        
                        self.buttonNode.setTitle(self.presentationData.strings.Common_Done, with: Font.semibold(17.0), with: self.presentationData.theme.list.itemCheckColors.foregroundColor, for: .normal)
                        self.buttonNode.setBackgroundImage(generateStretchableFilledCircleImage(radius: 11, color: self.presentationData.theme.list.itemCheckColors.fillColor), for: [])
                    } else {
                        let buttonTitle = self.presentationData.strings.StickerPack_EditStickers
                        var updated = false
                        if let current = self.buttonNode.attributedTitle(for: .normal)?.string, !current.isEmpty && current != buttonTitle {
                            updated = true
                        }
                        
                        if updated, let snapshotView = self.buttonNode.view.snapshotView(afterScreenUpdates: false) {
                            snapshotView.frame = self.buttonNode.view.frame
                            self.buttonNode.view.superview?.insertSubview(snapshotView, belowSubview: self.buttonNode.view)
                            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                                snapshotView?.removeFromSuperview()
                            })
                            self.buttonNode.view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        }
                        
                        text = buttonTitle
                        self.buttonNode.setTitle(text, with: Font.regular(17.0), with: self.presentationData.theme.list.itemAccentColor, for: .normal)
                        self.buttonNode.setBackgroundImage(nil, for: [])
                    }
                } else {
                    if info.id.namespace == Namespaces.ItemCollection.CloudStickerPacks {
                        text = self.presentationData.strings.StickerPack_RemoveStickerCount(count)
                    } else if info.id.namespace == Namespaces.ItemCollection.CloudEmojiPacks {
                        text = self.presentationData.strings.StickerPack_RemoveEmojiCount(count)
                    } else {
                        text = self.presentationData.strings.StickerPack_RemoveMaskCount(count)
                    }
                    self.buttonNode.setTitle(text, with: Font.regular(17.0), with: self.presentationData.theme.list.itemDestructiveColor, for: .normal)
                    self.buttonNode.setBackgroundImage(nil, for: [])
                }
            } else {
                let text: String
                if info.id.namespace == Namespaces.ItemCollection.CloudStickerPacks {
                    text = self.presentationData.strings.StickerPack_AddStickerCount(count)
                } else if info.id.namespace == Namespaces.ItemCollection.CloudEmojiPacks {
                    text = self.presentationData.strings.StickerPack_AddEmojiCount(count)
                } else {
                    text = self.presentationData.strings.StickerPack_AddMaskCount(count)
                }
                self.buttonNode.setTitle(text, with: Font.semibold(17.0), with: self.presentationData.theme.list.itemCheckColors.foregroundColor, for: .normal)
                self.buttonNode.setBackgroundImage(generateStretchableFilledCircleImage(radius: 11, color: self.presentationData.theme.list.itemCheckColors.fillColor), for: [])
            }
        }
    }
    
    private func updateStickerPackContents(_ contents: [LoadedStickerPack], hasPremium: Bool) {
        self.currentContents = contents
        self.didReceiveStickerPackResult = true
        
        var entries: [StickerPackPreviewGridEntry] = []
        
        var updateLayout = false
        
        var scrollToItem: GridNodeScrollToItem?
        let titleFont = Font.semibold(17.0)
        
        var isEditable = false
        if contents.count > 1 {
            self.onLoading()
            
            var loadedCount = 0
            var error = false
            for content in contents {
                if case .result = content {
                    loadedCount += 1
                } else if case .none = content {
                    error = true
                }
            }
            
            if error {
                self.onError()
            } else if loadedCount == contents.count {
                self.onReady()
                
                if !contents.isEmpty && self.currentStickerPacks.isEmpty {
                    if let _ = self.validLayout, abs(self.expandScrollProgress - 1.0) < .ulpOfOne {
                        scrollToItem = GridNodeScrollToItem(index: 0, position: .top(0.0), transition: .immediate, directionHint: .up, adjustForSection: false)
                    }
                }
            
                if self.titleNode.attributedText == nil {
                    if let titlePlaceholderNode = self.titlePlaceholderNode {
                        self.titlePlaceholderNode = nil
                        titlePlaceholderNode.removeFromSupernode()
                    }
                }
                
                self.titleNode.attributedText = NSAttributedString(string: self.presentationData.strings.EmojiPack_Title, font: titleFont, textColor: self.presentationData.theme.actionSheet.primaryTextColor, paragraphAlignment: .center)
                updateLayout = true
                
                var currentStickerPacks: [(StickerPackCollectionInfo, [StickerPackItem], Bool)] = []
                
                var index = 0
                var installedCount = 0
                for content in contents {
                    if case let .result(info, items, isInstalled) = content {
                        entries.append(.emojis(index: index, stableId: index, info: info._parse(), items: items, title: info.title, isInstalled: isInstalled))
                        if isInstalled {
                            installedCount += 1
                        }
                        currentStickerPacks.append((info._parse(), items, isInstalled))
                    }
                    index += 1
                }
                self.currentStickerPacks = currentStickerPacks
                
                if installedCount == contents.count {
                    let text = self.presentationData.strings.StickerPack_RemoveEmojiPacksCount(Int32(contents.count))
                    self.buttonNode.setTitle(text, with: Font.regular(17.0), with: self.presentationData.theme.list.itemDestructiveColor, for: .normal)
                    self.buttonNode.setBackgroundImage(nil, for: [])
                } else {
                    let text = self.presentationData.strings.StickerPack_AddEmojiPacksCount(Int32(contents.count - installedCount))
                    self.buttonNode.setTitle(text, with: Font.semibold(17.0), with: self.presentationData.theme.list.itemCheckColors.foregroundColor, for: .normal)
                    let roundedAccentBackground = generateImage(CGSize(width: 22.0, height: 22.0), rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.setFillColor(self.presentationData.theme.list.itemCheckColors.fillColor.cgColor)
                        context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height)))
                    })?.stretchableImage(withLeftCapWidth: 11, topCapHeight: 11)
                    self.buttonNode.setBackgroundImage(roundedAccentBackground, for: [])
                }
            }
        } else if let contents = contents.first {
            switch contents {
            case .fetching:
                self.onLoading()
                entries = []
                self.buttonNode.setTitle(self.presentationData.strings.Channel_NotificationLoading, with: Font.semibold(17.0), with: self.presentationData.theme.list.itemDisabledTextColor, for: .normal)
                self.buttonNode.setBackgroundImage(nil, for: [])
                
                for _ in 0 ..< 16 {
                    var stableId: Int?
                    inner: for entry in self.currentEntries {
                        if case let .sticker(index, currentStableId, stickerItem, _, _, _, _, _) = entry, stickerItem == nil, index == entries.count {
                            stableId = currentStableId
                            break inner
                        }
                    }
                    
                    let resolvedStableId: Int
                    if let stableId = stableId {
                        resolvedStableId = stableId
                    } else {
                        resolvedStableId = self.nextStableId
                        self.nextStableId += 1
                    }
                    
                    self.nextStableId += 1
                    entries.append(.sticker(index: entries.count, stableId: resolvedStableId, stickerItem: nil, isEmpty: false, isPremium: false, isLocked: false, isEditing: false, isAdd: false))
                }
                if self.titlePlaceholderNode == nil {
                    let titlePlaceholderNode = ShimmerEffectNode()
                    self.titlePlaceholderNode = titlePlaceholderNode
                    self.titleContainer.addSubnode(titlePlaceholderNode)
                }
            case .none:
                self.onError()
                self.controller?.present(textAlertController(context: self.context, title: nil, text: self.presentationData.strings.StickerPack_ErrorNotFound, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                self.controller?.dismiss(animated: true, completion: nil)
            case let .result(info, items, installed):
                isEditable = info.flags.contains(.isCreator) && !info.flags.contains(.isEmoji)
                self.onReady()
                
                let info = info._parse()
                
                if !items.isEmpty && self.currentStickerPack == nil {
                    if let _ = self.validLayout, abs(self.expandScrollProgress - 1.0) < .ulpOfOne {
                        scrollToItem = GridNodeScrollToItem(index: 0, position: .top(0.0), transition: .immediate, directionHint: .up, adjustForSection: false)
                    }
                }
                
                self.currentStickerPack = (info, items, installed)
                
                if self.titleNode.attributedText == nil {
                    if let titlePlaceholderNode = self.titlePlaceholderNode {
                        self.titlePlaceholderNode = nil
                        titlePlaceholderNode.removeFromSupernode()
                    }
                }
                
                let entities = generateTextEntities(info.title, enabledTypes: [.mention])
                self.titleNode.attributedText = stringWithAppliedEntities(info.title, entities: entities, baseColor: self.presentationData.theme.actionSheet.primaryTextColor, linkColor: self.presentationData.theme.actionSheet.controlAccentColor, baseFont: titleFont, linkFont: titleFont, boldFont: titleFont, italicFont: titleFont, boldItalicFont: titleFont, fixedFont: titleFont, blockQuoteFont: titleFont, message: nil)
                
                updateLayout = true
                
                if info.id.namespace == Namespaces.ItemCollection.CloudEmojiPacks {
                    entries.append(.emojis(index: 0, stableId: 0, info: info, items: items, title: nil, isInstalled: nil))
                } else {
                    let premiumConfiguration = PremiumConfiguration.with(appConfiguration: self.context.currentAppConfiguration.with { $0 })
                    
                    var generalItems: [StickerPackItem] = []
                    var premiumItems: [StickerPackItem] = []
                    
                    for item in items {
                        if item.file.isPremiumSticker {
                            premiumItems.append(item)
                        } else {
                            generalItems.append(item)
                        }
                    }
                    
                    let addItem: (StickerPackItem, Bool, Bool) -> Void = { item, isPremium, isLocked in
                        var stableId: Int?
                        inner: for entry in self.currentEntries {
                            if case let .sticker(_, currentStableId, stickerItem, _, _, _, _, _) = entry, let stickerItem = stickerItem, stickerItem.file.fileId == item.file.fileId {
                                stableId = currentStableId
                                break inner
                            }
                        }
                        let resolvedStableId: Int
                        if let stableId = stableId {
                            resolvedStableId = stableId
                        } else {
                            resolvedStableId = self.nextStableId
                            self.nextStableId += 1
                        }
                        entries.append(.sticker(index: entries.count, stableId: resolvedStableId, stickerItem: item, isEmpty: false, isPremium: isPremium, isLocked: isLocked, isEditing: false, isAdd: false))
                    }
                    
                    for item in generalItems {
                        addItem(item, false, false)
                    }
                    
                    if !premiumConfiguration.isPremiumDisabled {
                        if !premiumItems.isEmpty {
                            for item in premiumItems {
                                addItem(item, true, !hasPremium)
                            }
                        }
                    }
                }
                
                if let mainActionTitle = self.controller?.mainActionTitle {
                    self.buttonNode.setTitle(mainActionTitle, with: Font.semibold(17.0), with: self.presentationData.theme.list.itemCheckColors.foregroundColor, for: .normal)
                    self.buttonNode.setBackgroundImage(generateStretchableFilledCircleImage(radius: 11, color: self.presentationData.theme.list.itemCheckColors.fillColor), for: [])
                } else {
                    let count: Int32
                    if info.id.namespace == Namespaces.ItemCollection.CloudStickerPacks {
                        count = Int32(entries.count)
                    } else if info.id.namespace == Namespaces.ItemCollection.CloudEmojiPacks {
                        count = Int32(items.count)
                    } else {
                        count = Int32(entries.count)
                    }
                    self.updateButton(count: count)
                }
                
                if info.flags.contains(.isCreator) && !info.flags.contains(.isEmoji) && entries.count < maxStickersCount {
                    entries.append(.add)
                }
            }
        }
        let previousEntries = self.currentEntries
        self.currentEntries = entries
        
        if let titlePlaceholderNode = self.titlePlaceholderNode {
            let fakeTitleSize = CGSize(width: 160.0, height: 22.0)
            let titlePlaceholderFrame = CGRect(origin: CGPoint(x: floor((-fakeTitleSize.width) / 2.0), y: floor((-fakeTitleSize.height) / 2.0)), size: fakeTitleSize)
            titlePlaceholderNode.frame = titlePlaceholderFrame
            let theme = self.presentationData.theme
            titlePlaceholderNode.update(backgroundColor: theme.list.itemBlocksBackgroundColor, foregroundColor: theme.list.mediaPlaceholderColor, shimmeringColor: theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4), shapes: [.roundedRect(rect: CGRect(origin: CGPoint(), size: titlePlaceholderFrame.size), cornerRadius: 4.0)], size: titlePlaceholderFrame.size)
            updateLayout = true
        }
        
        if updateLayout, let (layout, _, _, _) = self.validLayout {
            self.updateLayout(layout: layout, transition: .immediate)
        }
        
        if let controller = self.controller {
            let transaction = StickerPackPreviewGridTransaction(previousList: previousEntries, list: entries, context: self.context, interaction: self.interaction, theme: self.presentationData.theme, strings: self.presentationData.strings, animationCache: controller.animationCache, animationRenderer: controller.animationRenderer, scrollToItem: scrollToItem, isEditable: isEditable, isEditing: self.isEditing)
            self.enqueueTransaction(transaction)
        }
    }
    
    func reorderAndUpdateEntries(invert: Bool = false) {
        guard let (info, items, _) = self.currentStickerPack else {
            return
        }
        let hasPremium = self.context.isPremium
        let previousEntries = self.currentEntries
        var entries: [StickerPackPreviewGridEntry] = []
        
        let premiumConfiguration = PremiumConfiguration.with(appConfiguration: self.context.currentAppConfiguration.with { $0 })
        
        var generalItems: [StickerPackItem] = []
        var premiumItems: [StickerPackItem] = []
        
        for item in items {
            if item.file.isPremiumSticker {
                premiumItems.append(item)
            } else {
                generalItems.append(item)
            }
        }
        
        let addItem: (StickerPackItem, Bool, Bool) -> Void = { item, isPremium, isLocked in
            var stableId: Int?
            inner: for entry in self.currentEntries {
                if case let .sticker(_, currentStableId, stickerItem, _, _, _, _, _) = entry, let stickerItem = stickerItem, stickerItem.file.fileId == item.file.fileId {
                    stableId = currentStableId
                    break inner
                }
            }
            let resolvedStableId: Int
            if let stableId = stableId {
                resolvedStableId = stableId
            } else {
                resolvedStableId = self.nextStableId
                self.nextStableId += 1
            }
            
            entries.append(.sticker(index: entries.count, stableId: resolvedStableId, stickerItem: item, isEmpty: false, isPremium: isPremium, isLocked: isLocked, isEditing: false, isAdd: false))
        }

        var addedReorderItem = false
        var currentIndex: Int = 0
        for item in generalItems {
            if self.isReordering, let reorderItem = self.reorderNode?.itemNode?.stickerPackItem, let reorderPosition = self.reorderPosition {
                if currentIndex == reorderPosition {
                    addItem(reorderItem, false, false)
                    currentIndex += 1
                    addedReorderItem = true
                }
                    
                if item.file.fileId == reorderItem.file.fileId {
                    
                } else {
                    addItem(item, false, false)
                    currentIndex += 1
                }
            } else {
                addItem(item, false, false)
                currentIndex += 1
            }
        }
        if !addedReorderItem, let reorderItem = self.reorderNode?.itemNode?.stickerPackItem, let reorderPosition = self.reorderPosition, currentIndex == reorderPosition {
            addItem(reorderItem, false, false)
            currentIndex += 1
            addedReorderItem = true
        }
        
        if !premiumConfiguration.isPremiumDisabled {
            if !premiumItems.isEmpty {
                for item in premiumItems {
                    addItem(item, true, !hasPremium)
                    currentIndex += 1
                }
            }
        }

        if entries.count < maxStickersCount {
            entries.append(.add)
        }
        
        self.currentEntries = entries
        
        if let controller = self.controller {
            let transaction = StickerPackPreviewGridTransaction(previousList: previousEntries, list: entries, context: self.context, interaction: self.interaction, theme: self.presentationData.theme, strings: self.presentationData.strings, animationCache: controller.animationCache, animationRenderer: controller.animationRenderer, scrollToItem: nil, isEditable: info.flags.contains(.isCreator) && !info.flags.contains(.isEmoji), isEditing: self.isEditing, invert: invert)
            self.enqueueTransaction(transaction)
        }
    }
    
    var topContentInset: CGFloat {
        guard let (_, gridFrame, titleAreaInset, gridInsets) = self.validLayout else {
            return 0.0
        }
        return min(self.backgroundNode.frame.minY, gridFrame.minY + gridInsets.top - titleAreaInset)
    }
    
    func syncExpandProgress(expandScrollProgress: CGFloat, expandProgress: CGFloat, modalProgress: CGFloat, transition: ContainedViewLayoutTransition) {
        guard let (_, _, _, gridInsets) = self.validLayout else {
            return
        }
        
        let contentOffset = (1.0 - expandScrollProgress) * (-gridInsets.top)
        if case let .animated(duration, _) = transition {
            self.gridNode.autoscroll(toOffset: CGPoint(x: 0.0, y: contentOffset), duration: duration)
        } else {
            if expandScrollProgress.isZero {
            }
            self.gridNode.scrollView.setContentOffset(CGPoint(x: 0.0, y: contentOffset), animated: false)
        }
        
        self.expandScrollProgress = expandScrollProgress
        self.expandProgress = expandProgress
        self.modalProgress = modalProgress
    }
    
    func animateIn() {
        if let mainPreviewIconView = self.mainPreviewIcon?.view {
            mainPreviewIconView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
            mainPreviewIconView.layer.animateScale(from: 0.5, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
        }
    }
    
    func animateOut() {
        if let mainPreviewIconView = self.mainPreviewIcon?.view {
            mainPreviewIconView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
            mainPreviewIconView.layer.animateScale(from: 1.0, to: 0.5, duration: 0.2, removeOnCompletion: false)
        }
    }
    
    func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        var insets = layout.insets(options: [.statusBar])
        if case .regular = layout.metrics.widthClass {
            insets.top = 0.0
        } else if case .compact = layout.metrics.widthClass, layout.size.width > layout.size.height {
            insets.top = 0.0
        } else {
            insets.top += 10.0
        }
        
        var buttonHeight: CGFloat = 50.0
        var actionAreaTopInset: CGFloat = 8.0
        var actionAreaBottomInset: CGFloat = 16.0
        if let _ = self.controller?.mainActionTitle {
            
        } else {
            if !self.currentStickerPacks.isEmpty {
                var installedCount = 0
                for (_, _, isInstalled) in self.currentStickerPacks {
                    if isInstalled {
                        installedCount += 1
                    }
                }
                if installedCount == self.currentStickerPacks.count {
                    buttonHeight = 42.0
                    actionAreaTopInset = 1.0
                    actionAreaBottomInset = 2.0
                }
            }
            if let (info, _, isInstalled) = self.currentStickerPack, isInstalled, (!info.flags.contains(.isCreator) || info.flags.contains(.isEmoji)) {
                buttonHeight = 42.0
                actionAreaTopInset = 1.0
                actionAreaBottomInset = 2.0
            }
        }
        
        let buttonSideInset: CGFloat = 16.0
        let titleAreaInset: CGFloat = 56.0
        
        var actionAreaHeight: CGFloat = buttonHeight
        actionAreaHeight += insets.bottom + actionAreaBottomInset
        
        transition.updateFrame(node: self.buttonNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + buttonSideInset, y: layout.size.height - actionAreaHeight + actionAreaTopInset), size: CGSize(width: layout.size.width - buttonSideInset * 2.0 - layout.safeInsets.left - layout.safeInsets.right, height: buttonHeight)))

        transition.updateFrame(node: self.actionAreaBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - actionAreaHeight), size: CGSize(width: layout.size.width, height: actionAreaHeight)))
        self.actionAreaBackgroundNode.update(size: CGSize(width: layout.size.width, height: actionAreaHeight), transition: .immediate)
        transition.updateFrame(node: self.actionAreaSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - actionAreaHeight), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
        
        let gridFrame = CGRect(origin: CGPoint(x: 0.0, y: insets.top + titleAreaInset), size: CGSize(width: layout.size.width, height: layout.size.height - insets.top - titleAreaInset))
        
        let itemsPerRow = 5
        let fillingWidth = horizontalContainerFillingSizeForLayout(layout: layout, sideInset: 0.0)
        let itemWidth = floor(fillingWidth / CGFloat(itemsPerRow))
        let gridLeftInset = floor((layout.size.width - fillingWidth) / 2.0)
        let contentHeight: CGFloat
        if !self.currentStickerPacks.isEmpty {
            var packsHeight = 0.0
            for stickerPack in currentStickerPacks {
                let layout = ItemLayout(width: fillingWidth, itemsCount: stickerPack.1.count)
                packsHeight += layout.height + 61.0
            }
            contentHeight = packsHeight + 8.0
        } else if let (info, items, _) = self.currentStickerPack {
            if info.id.namespace == Namespaces.ItemCollection.CloudEmojiPacks {
                let layout = ItemLayout(width: fillingWidth, itemsCount: items.count)
                contentHeight = layout.height
            } else {
                var itemsCount = items.count
                if info.flags.contains(.isCreator) && itemsCount < 120 {
                    itemsCount += 1
                }
                let rowCount = itemsCount / itemsPerRow + ((itemsCount % itemsPerRow) == 0 ? 0 : 1)
                contentHeight = itemWidth * CGFloat(rowCount)
            }
        } else {
            contentHeight = gridFrame.size.height
        }
        
        let initialRevealedRowCount: CGFloat = 4.5
        
        let topInset: CGFloat
        if case .regular = layout.metrics.widthClass {
            topInset = 0.0
        } else {
            topInset = insets.top + max(0.0, layout.size.height - floor(initialRevealedRowCount * itemWidth) - insets.top - actionAreaHeight - titleAreaInset)
        }
        let additionalGridBottomInset = max(0.0, gridFrame.size.height - actionAreaHeight - contentHeight)
        let gridInsets = UIEdgeInsets(top: topInset, left: gridLeftInset, bottom: actionAreaHeight + additionalGridBottomInset, right: layout.size.width - fillingWidth - gridLeftInset)
        
        let firstTime = self.validLayout == nil
        self.validLayout = (layout, gridFrame, titleAreaInset, gridInsets)
        
        transition.updateFrame(node: self.gridNode, frame: gridFrame)
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: gridFrame.size, insets: gridInsets, scrollIndicatorInsets: nil, preloadSize: 200.0, type: .fixed(itemSize: CGSize(width: itemWidth, height: itemWidth), fillWidth: nil, lineSpacing: 0.0, itemSpacing: nil)), transition: transition), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil, updateOpaqueState: nil, synchronousLoads: false), completion: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.didReceiveStickerPackResult {
                if !strongSelf.didSetReady {
                    strongSelf.didSetReady = true
                    strongSelf.isReadyValue.set(.single(true))
                }
            }
        })
        
        if let titlePlaceholderNode = self.titlePlaceholderNode {
            titlePlaceholderNode.updateAbsoluteRect(titlePlaceholderNode.frame.offsetBy(dx: self.titleContainer.frame.minX, dy: self.titleContainer.frame.minY - gridInsets.top - gridFrame.minY), within: gridFrame.size)
        }
        
        let cancelSize = self.cancelButtonNode.measure(CGSize(width: layout.size.width, height: .greatestFiniteMagnitude))
        self.cancelButtonNode.frame = CGRect(origin: CGPoint(x: layout.safeInsets.left + 16.0, y: 18.0), size: cancelSize)
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: layout.size.width - cancelSize.width * 2.0 - 40.0, height: .greatestFiniteMagnitude))
        self.titleNode.frame = CGRect(origin: CGPoint(x: floor((-titleSize.width) / 2.0), y: floor((-titleSize.height) / 2.0)), size: titleSize)
        
        self.moreButtonNode.frame = CGRect(origin: CGPoint(x: layout.size.width - layout.safeInsets.right - 46.0, y: 5.0), size: CGSize(width: 44.0, height: 44.0))
                
        
        transition.updateAlpha(node: self.cancelButtonNode, alpha: self.isEditing ? 0.0 : 1.0)
        transition.updateAlpha(node: self.moreButtonNode, alpha: self.isEditing ? 0.0 : 1.0)
        
        if firstTime {
            while !self.enqueuedTransactions.isEmpty {
                self.dequeueTransaction()
            }
        }
    }
    
    private func gridPresentationLayoutUpdated(_ presentationLayout: GridNodeCurrentPresentationLayout, transition: ContainedViewLayoutTransition) {
        guard let (layout, gridFrame, titleAreaInset, gridInsets) = self.validLayout else {
            return
        }
        
        if self.skipNextGridLayoutUpdate {
            self.skipNextGridLayoutUpdate = false
            return
        }
        
        let minBackgroundY = gridFrame.minY - titleAreaInset
        let unclippedBackgroundY = gridFrame.minY - presentationLayout.contentOffset.y - titleAreaInset
        
        let offsetFromInitialPosition = presentationLayout.contentOffset.y + gridInsets.top
        let expandHeight: CGFloat = 100.0
        let expandProgress = max(0.0, min(1.0, offsetFromInitialPosition / expandHeight))
        let expandScrollProgress = 1.0 - max(0.0, min(1.0, presentationLayout.contentOffset.y / (-gridInsets.top)))
        let modalProgress = max(0.0, min(1.0, expandScrollProgress))
        
        let expandProgressTransition = transition
        var expandUpdated = false
        
        if abs(self.expandScrollProgress - expandScrollProgress) > CGFloat.ulpOfOne {
            self.expandScrollProgress = expandScrollProgress
            expandUpdated = true
        }
        
        if abs(self.expandProgress - expandProgress) > CGFloat.ulpOfOne {
            self.expandProgress = expandProgress
            expandUpdated = true
        }
        
        if abs(self.modalProgress - modalProgress) > CGFloat.ulpOfOne {
            self.modalProgress = modalProgress
            expandUpdated = true
        }
        
        if expandUpdated {
            self.expandProgressUpdated(self, expandProgressTransition, self.isAnimatingAutoscroll ? transition : .immediate)
        }
        
        if !transition.isAnimated {
            self.backgroundNode.layer.removeAllAnimations()
            self.titleContainer.layer.removeAllAnimations()
            self.titleSeparatorNode.layer.removeAllAnimations()
        }
        
        var backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: max(minBackgroundY, unclippedBackgroundY)), size: CGSize(width: layout.size.width, height: layout.size.height))
        var titleContainerFrame: CGRect
        if case .regular = layout.metrics.widthClass {
            backgroundFrame.origin.y = min(0.0, backgroundFrame.origin.y)
            titleContainerFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX + floor((backgroundFrame.width) / 2.0), y: floor((56.0) / 2.0)), size: CGSize())
        } else {
            titleContainerFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX + floor((backgroundFrame.width) / 2.0), y: backgroundFrame.minY + floor((56.0) / 2.0)), size: CGSize())
        }
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        
        if let previewIconFile = self.previewIconFile, let mainPreviewIcon = self.mainPreviewIcon {
            let iconFitSize = CGSize(width: 120.0, height: 120.0)
            let iconSize = mainPreviewIcon.update(
                transition: .immediate,
                component: AnyComponent(EmojiStatusComponent(
                    context: self.context,
                    animationCache: self.context.animationCache,
                    animationRenderer: self.context.animationRenderer,
                    content: .animation(
                        content: .file(file: previewIconFile),
                        size: iconFitSize,
                        placeholderColor: .clear,
                        themeColor: self.presentationData.theme.list.itemPrimaryTextColor,
                        loopMode: .forever
                    ),
                    isVisibleForAnimations: true,
                    action: nil
                )),
                environment: {},
                containerSize: iconFitSize
            )
            let iconFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX + floor((backgroundFrame.width - iconSize.width) * 0.5), y: backgroundFrame.minY - 50.0 - iconSize.height), size: iconSize)
            if let iconView = mainPreviewIcon.view {
                if iconView.superview == nil {
                    self.backgroundNode.view.superview?.addSubview(iconView)
                }
                transition.updatePosition(layer: iconView.layer, position: iconFrame.center)
                iconView.bounds = CGRect(origin: CGPoint(), size: iconFrame.size)
            }
        }
        
        transition.updateFrame(node: self.titleContainer, frame: titleContainerFrame)
        transition.updateFrame(node: self.titleSeparatorNode, frame: CGRect(origin: CGPoint(x: backgroundFrame.minX, y: backgroundFrame.minY + 56.0 - UIScreenPixel), size: CGSize(width: backgroundFrame.width, height: UIScreenPixel)))
        transition.updateFrame(node: self.titleBackgroundnode, frame: CGRect(origin: CGPoint(x: backgroundFrame.minX, y: backgroundFrame.minY), size: CGSize(width: backgroundFrame.width, height: 56.0)))
        self.titleBackgroundnode.update(size: CGSize(width: layout.size.width, height: 56.0), transition: .immediate)
        
        transition.updateFrame(node: self.topContainerNode, frame: CGRect(origin: CGPoint(x: backgroundFrame.minX, y: backgroundFrame.minY), size: CGSize(width: backgroundFrame.width, height: 56.0)))
        
        let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
        transition.updateAlpha(node: self.titleSeparatorNode, alpha: unclippedBackgroundY < minBackgroundY ? 1.0 : 0.0)
    }
    
    private func enqueueTransaction(_ transaction: StickerPackPreviewGridTransaction) {
        self.enqueuedTransactions.append(transaction)
        
        if let _ = self.validLayout {
            self.dequeueTransaction()
        }
    }
    
    private var didAutomaticExpansion = false
    private var skipNextGridLayoutUpdate = true
    private func dequeueTransaction() {
        if self.enqueuedTransactions.isEmpty {
            return
        }
        let transaction = self.enqueuedTransactions.removeFirst()
        
        self.gridNode.transaction(GridNodeTransaction(deleteItems: transaction.deletions, insertItems: transaction.insertions, updateItems: transaction.updates, scrollToItem: transaction.scrollToItem, updateLayout: nil, itemTransition: self.isReordering ? .animated(duration: 0.3, curve: .easeInOut) : .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { [weak self] _ in
            guard let self else {
                return
            }
            
            self.expandIfNeeded()
        })
    }
    
    private func expandIfNeeded(force: Bool = false) {
        if self.currentEntries.count >= 15, force || (self.controller?.expandIfNeeded == true && !self.didAutomaticExpansion) {
            self.didAutomaticExpansion = true
            self.gridNode.autoscroll(toOffset: CGPoint(x: 0.0, y: max(0.0, self.gridNode.scrollView.contentSize.height + self.gridNode.scrollView.contentInset.bottom - self.gridNode.scrollView.bounds.height)), duration: 0.4)
            self.skipNextGridLayoutUpdate = true
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.contains(point) {
            if !self.backgroundNode.bounds.contains(self.convert(point, to: self.backgroundNode)) {
                return nil
            }
            
            let titlePoint = self.view.convert(point, to: self.titleNode.view)
            if self.titleNode.bounds.contains(titlePoint) {
                return self.titleNode.view
            }
        }
        
        let result = super.hitTest(point, with: event)
        return result
    }
    
    private func updatePreviewingItem(item: StickerPreviewPeekItem?, animated: Bool) {
        if self.interaction.previewedItem != item {
            self.interaction.previewedItem = item
            
            self.gridNode.forEachItemNode { itemNode in
                if let itemNode = itemNode as? StickerPackPreviewGridItemNode {
                    itemNode.updatePreviewing(animated: animated)
                }
            }
        }
    }
}

private final class StickerPackScreenNode: ViewControllerTracingNode {
    private let context: AccountContext
    private weak var controller: StickerPackScreenImpl?
    private var presentationData: PresentationData
    private let stickerPacks: [StickerPackReference]
    private let previewIconFile: TelegramMediaFile?
    private let modalProgressUpdated: (CGFloat, ContainedViewLayoutTransition) -> Void
    private let dismissed: () -> Void
    private let presentInGlobalOverlay: (ViewController, Any?) -> Void
    private let sendSticker: ((FileMediaReference, UIView, CGRect) -> Bool)?
    private let sendEmoji: ((String, ChatTextInputTextCustomEmojiAttribute) -> Void)?
    private let longPressEmoji: ((String, ChatTextInputTextCustomEmojiAttribute, ASDisplayNode, CGRect) -> Void)?
    fileprivate let openMention: (String) -> Void
    
    private let dimNode: ASDisplayNode
    private let shadowNode: ASImageNode
    private let arrowNode: ASImageNode
    private let containerContainingNode: ASDisplayNode
    
    private var containers: [Int: StickerPackContainer] = [:]
    private var selectedStickerPackIndex: Int
    private var relativeToSelectedStickerPackTransition: CGFloat = 0.0
    
    private var validLayout: ContainerViewLayout?
    private var isDismissed: Bool = false
    
    private let _ready = Promise<Bool>()
    var ready: Promise<Bool> {
        return self._ready
    }
    
    var onLoading: () -> Void = {}
    var onReady: () -> Void = {}
    var onError: () -> Void = {}
    
    init(
        context: AccountContext,
        controller: StickerPackScreenImpl,
        stickerPacks: [StickerPackReference],
        previewIconFile: TelegramMediaFile?,
        initialSelectedStickerPackIndex: Int,
        modalProgressUpdated: @escaping (CGFloat, ContainedViewLayoutTransition) -> Void,
        dismissed: @escaping () -> Void,
        presentInGlobalOverlay: @escaping (ViewController, Any?) -> Void,
        sendSticker: ((FileMediaReference, UIView, CGRect) -> Bool)?,
        sendEmoji: ((String, ChatTextInputTextCustomEmojiAttribute) -> Void)?,
        longPressEmoji: ((String, ChatTextInputTextCustomEmojiAttribute, ASDisplayNode, CGRect) -> Void)?,
        openMention: @escaping (String) -> Void)
    {
        self.context = context
        self.controller = controller
        self.presentationData = controller.presentationData
        self.stickerPacks = stickerPacks
        self.previewIconFile = previewIconFile
        self.selectedStickerPackIndex = initialSelectedStickerPackIndex
        self.modalProgressUpdated = modalProgressUpdated
        self.dismissed = dismissed
        self.presentInGlobalOverlay = presentInGlobalOverlay
        self.sendSticker = sendSticker
        self.sendEmoji = sendEmoji
        self.longPressEmoji = longPressEmoji
        self.openMention = openMention
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.25)
        self.dimNode.alpha = 0.0
        
        self.shadowNode = ASImageNode()
        self.shadowNode.displaysAsynchronously = false
        self.shadowNode.isUserInteractionEnabled = false
        
        self.arrowNode = ASImageNode()
        self.arrowNode.displaysAsynchronously = false
        self.arrowNode.isUserInteractionEnabled = false
        self.arrowNode.image = generateArrowImage(color: self.presentationData.theme.actionSheet.opaqueItemBackgroundColor)
        
        self.containerContainingNode = ASDisplayNode()
        self.containerContainingNode.clipsToBounds = true
        
        super.init()
        
        self.addSubnode(self.dimNode)
        self.addSubnode(self.shadowNode)
        self.addSubnode(self.arrowNode)
        self.addSubnode(self.containerContainingNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimNodeTapGesture(_:))))
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        for (_, container) in self.containers {
            container.updatePresentationData(presentationData)
        }
        self.arrowNode.image = generateArrowImage(color: presentationData.theme.actionSheet.opaqueItemBackgroundColor)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let firstTime = self.validLayout == nil
        
        self.validLayout = layout
        
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
       
        let containerContainingFrame: CGRect
        let containerInsets: UIEdgeInsets
        if case .regular = layout.metrics.widthClass {
            self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.01)
            self.containerContainingNode.cornerRadius = 10.0
            
            let size = CGSize(width: 390.0, height: min(560.0, layout.size.height - 60.0))
            var contentRect: CGRect
            if let sourceRect = self.controller?.getSourceRect?() {
                let sideSpacing: CGFloat = 10.0
                let margin: CGFloat = 64.0
                contentRect = CGRect(origin: CGPoint(x: sourceRect.maxX + sideSpacing, y: floor(sourceRect.midY - size.height / 2.0)), size: size)
                contentRect.origin.y = min(layout.size.height - margin - size.height - layout.intrinsicInsets.bottom, max(margin, contentRect.origin.y))
                
                let arrowSize = CGSize(width: 23.0, height: 12.0)
                let arrowFrame: CGRect
                if contentRect.maxX > layout.size.width {
                    contentRect.origin.x = sourceRect.minX - size.width - sideSpacing
                    arrowFrame = CGRect(origin: CGPoint(x: contentRect.maxX - (arrowSize.width - arrowSize.height) / 2.0, y: floor(sourceRect.midY - arrowSize.height / 2.0)), size: arrowSize)
                    self.arrowNode.transform = CATransform3DMakeRotation(-.pi / 2.0, 0.0, 0.0, 1.0)
                } else {
                    arrowFrame = CGRect(origin: CGPoint(x: contentRect.minX - arrowSize.width + (arrowSize.width - arrowSize.height) / 2.0, y: floor(sourceRect.midY - arrowSize.height / 2.0)), size: arrowSize)
                    self.arrowNode.transform = CATransform3DMakeRotation(.pi / 2.0, 0.0, 0.0, 1.0)
                }
                
                self.arrowNode.frame = arrowFrame
                self.arrowNode.isHidden = false
    
            } else {
                let masterWidth = min(max(320.0, floor(layout.size.width / 3.0)), floor(layout.size.width / 2.0))
                let detailWidth = layout.size.width - masterWidth
                contentRect = CGRect(origin:  CGPoint(x: masterWidth + floor((detailWidth - size.width) / 2.0), y: floor((layout.size.height - size.height) / 2.0)), size: size)
                self.arrowNode.isHidden = true
            }
            
            containerContainingFrame = contentRect
            containerInsets = .zero
            
            self.shadowNode.alpha = 1.0
            if self.shadowNode.image == nil {
                self.shadowNode.image = generateShadowImage()
            }
        } else {
            self.containerContainingNode.cornerRadius = 0.0
            
            self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.25)
            containerContainingFrame = CGRect(origin: CGPoint(), size: layout.size)
            containerInsets = layout.intrinsicInsets
            
            self.arrowNode.isHidden = true
            self.shadowNode.alpha = 0.0
        }
        transition.updateFrame(node: self.containerContainingNode, frame: containerContainingFrame)
        
        let shadowFrame = containerContainingFrame.insetBy(dx: -60.0, dy: -60.0)
        transition.updateFrame(node: self.shadowNode, frame: shadowFrame)
        
        let expandProgress: CGFloat = 1.0
        let scaledInset: CGFloat = 12.0
        let scaledDistance: CGFloat = 4.0
        let minScale = (layout.size.width - scaledInset * 2.0) / layout.size.width
        let containerScale = expandProgress * 1.0 + (1.0 - expandProgress) * minScale
        
        let containerVerticalOffset: CGFloat = (1.0 - expandProgress) * scaledInset * 2.0
                
        let i = 0
        let indexOffset = i - self.selectedStickerPackIndex
        var scaledOffset: CGFloat = 0.0
        scaledOffset = -CGFloat(indexOffset) * (1.0 - expandProgress) * (scaledInset * 2.0) + CGFloat(indexOffset) * scaledDistance
        
        if abs(indexOffset) <= 1 {
            let containerTransition: ContainedViewLayoutTransition
            let container: StickerPackContainer
            var wasAdded = false
            if let current = self.containers[i] {
                containerTransition = transition
                container = current
            } else {
                wasAdded = true
                containerTransition = .immediate
                let index = i
                container = StickerPackContainer(index: index, context: self.context, presentationData: self.presentationData, stickerPacks: self.stickerPacks, loadedStickerPacks: self.controller?.loadedStickerPacks ?? [], previewIconFile: self.previewIconFile, decideNextAction: { [weak self] container, action in
                    guard let strongSelf = self, let layout = strongSelf.validLayout else {
                        return .dismiss
                    }
                    if index == strongSelf.stickerPacks.count - 1 {
                        return .dismiss
                    } else {
                        switch action {
                        case .add:
                            var allAdded = true
                            for _ in index + 1 ..< strongSelf.stickerPacks.count {
                                if let container = strongSelf.containers[index], let (_, _, installed) = container.currentStickerPack {
                                    if !installed {
                                        allAdded = false
                                    }
                                } else {
                                    allAdded = false
                                }
                            }
                            if allAdded {
                                return .dismiss
                            }
                        case .remove:
                            if strongSelf.stickerPacks.count == 1 {
                                return .dismiss
                            } else {
                                return .ignored
                            }
                        }
                    }
                    
                    strongSelf.selectedStickerPackIndex = strongSelf.selectedStickerPackIndex + 1
                    strongSelf.containerLayoutUpdated(layout, transition: .animated(duration: 0.3, curve: .spring))
                    return .navigatedNext
                }, requestDismiss: { [weak self] in
                    self?.dismiss()
                }, expandProgressUpdated: { [weak self] container, transition, expandTransition in
                    guard let strongSelf = self, let layout = strongSelf.validLayout else {
                        return
                    }
                    if index == strongSelf.selectedStickerPackIndex, let container = strongSelf.containers[strongSelf.selectedStickerPackIndex] {
                        let modalProgress = container.modalProgress
                        strongSelf.modalProgressUpdated(modalProgress, transition)
                        strongSelf.containerLayoutUpdated(layout, transition: expandTransition)
                        for (_, otherContainer) in strongSelf.containers {
                            if otherContainer !== container {
                                otherContainer.syncExpandProgress(expandScrollProgress: container.expandScrollProgress, expandProgress: container.expandProgress, modalProgress: container.modalProgress, transition: expandTransition)
                            }
                        }
                    }
                }, presentInGlobalOverlay: presentInGlobalOverlay, sendSticker: self.sendSticker, sendEmoji: self.sendEmoji, longPressEmoji: self.longPressEmoji, openMention: self.openMention, controller: self.controller)
                container.onReady = { [weak self] in
                    self?.onReady()
                }
                container.onLoading = { [weak self] in
                    self?.onLoading()
                }
                container.onError = { [weak self] in
                    self?.onError()
                }
                self.containerContainingNode.addSubnode(container)
                self.containers[i] = container
            }
            
            let containerFrame = CGRect(origin: CGPoint(x: CGFloat(indexOffset) * containerContainingFrame.size.width + self.relativeToSelectedStickerPackTransition + scaledOffset, y: containerVerticalOffset), size: containerContainingFrame.size)
            containerTransition.updateFrame(node: container, frame: containerFrame, beginWithCurrentState: true)
            containerTransition.updateSublayerTransformScaleAndOffset(node: container, scale: containerScale, offset: CGPoint(), beginWithCurrentState: true)
            var containerLayout = layout
            containerLayout.size = containerFrame.size
            containerLayout.intrinsicInsets = containerInsets
            
            if container.validLayout?.0 != layout {
                container.updateLayout(layout: containerLayout, transition: containerTransition)
            }
            
            if wasAdded {
                if let selectedContainer = self.containers[self.selectedStickerPackIndex] {
                    if selectedContainer !== container {
                        container.syncExpandProgress(expandScrollProgress: selectedContainer.expandScrollProgress, expandProgress: selectedContainer.expandProgress, modalProgress: selectedContainer.modalProgress, transition: .immediate)
                    }
                }
            }
        } else {
            if let container = self.containers[i] {
                container.removeFromSupernode()
                self.containers.removeValue(forKey: i)
            }
        }
        
        if firstTime {
            if !self.containers.isEmpty {
                self._ready.set(combineLatest(self.containers.map { (_, container) in container.isReady })
                |> map { values -> Bool in
                    for value in values {
                        if !value {
                            return false
                        }
                    }
                    return true
                })
            } else {
                self._ready.set(.single(true))
            }
        }
    }
    
    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            break
        case .changed:
            let translation = recognizer.translation(in: self.view)
            self.relativeToSelectedStickerPackTransition = translation.x
            if self.selectedStickerPackIndex == 0 {
                self.relativeToSelectedStickerPackTransition = min(0.0, self.relativeToSelectedStickerPackTransition)
            }
            if self.selectedStickerPackIndex == self.stickerPacks.count - 1 {
                self.relativeToSelectedStickerPackTransition = max(0.0, self.relativeToSelectedStickerPackTransition)
            }
            if let layout = self.validLayout {
                self.containerLayoutUpdated(layout, transition: .immediate)
            }
        case .ended, .cancelled:
            let translation = recognizer.translation(in: self.view)
            let velocity = recognizer.velocity(in: self.view)
            if abs(translation.x) > 30.0 {
                let deltaIndex = translation.x > 0 ? -1 : 1
                self.selectedStickerPackIndex = max(0, min(self.stickerPacks.count - 1, Int(self.selectedStickerPackIndex + deltaIndex)))
            } else if abs(velocity.x) > 100.0 {
                let deltaIndex = velocity.x > 0 ? -1 : 1
                self.selectedStickerPackIndex = max(0, min(self.stickerPacks.count - 1, Int(self.selectedStickerPackIndex + deltaIndex)))
            }
            let deltaOffset = self.relativeToSelectedStickerPackTransition
            self.relativeToSelectedStickerPackTransition = 0.0
            if let layout = self.validLayout {
                var previousFrames: [Int: CGRect] = [:]
                for (key, container) in self.containers {
                    previousFrames[key] = container.frame
                }
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.35, curve: .spring)
                self.containerLayoutUpdated(layout, transition: .immediate)
                for (key, container) in self.containers {
                    if let previousFrame = previousFrames[key] {
                        transition.animatePositionAdditive(node: container, offset: CGPoint(x: previousFrame.minX - container.frame.minX, y: 0.0))
                    } else {
                        transition.animatePositionAdditive(node: container, offset: CGPoint(x: -deltaOffset, y: 0.0))
                    }
                }
            }
        default:
            break
        }
    }
    
    func animateIn() {
        guard let layout = self.validLayout else {
            return
        }
        self.dimNode.alpha = 1.0
        self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        
        if case .regular = layout.metrics.widthClass {
            
        } else {
            let minInset: CGFloat = (self.containers.map { (_, container) -> CGFloat in container.topContentInset }).max() ?? 0.0
            self.containerContainingNode.layer.animatePosition(from: CGPoint(x: 0.0, y: self.containerContainingNode.bounds.height - minInset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        }
        
        for (_, container) in self.containers {
            container.animateIn()
        }
    }
    
    func animateOut(completion: @escaping () -> Void) {
        guard let layout = self.validLayout else {
            return
        }
        self.dimNode.alpha = 0.0
        self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
        
        if case .regular = layout.metrics.widthClass {
            self.layer.allowsGroupOpacity = true
            self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
                completion()
            })
        } else {
            let minInset: CGFloat = (self.containers.map { (_, container) -> CGFloat in container.topContentInset }).max() ?? 0.0
            self.containerContainingNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: self.containerContainingNode.bounds.height - minInset), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true, completion: { _ in
                completion()
            })
            
            self.modalProgressUpdated(0.0, .animated(duration: 0.2, curve: .easeInOut))
        }
        
        for (_, container) in self.containers {
            container.animateOut()
        }
    }
    
    func dismiss() {
        if self.isDismissed {
            return
        }
        self.isDismissed = true
        self.animateOut(completion: { [weak self] in
            self?.dismissed()
        })
        
        self.dismissAllTooltips()
    }
    
    private func dismissAllTooltips() {
        guard let controller = self.controller else {
            return
        }

        controller.window?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController, !controller.keepOnParentDismissal {
                controller.dismissWithCommitAction()
            }
        })
        controller.forEachController({ controller in
            if let controller = controller as? UndoOverlayController, !controller.keepOnParentDismissal {
                controller.dismissWithCommitAction()
            }
            return true
        })
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.bounds.contains(point) {
            return nil
        }
        
        if let selectedContainer = self.containers[self.selectedStickerPackIndex] {
            if selectedContainer.hitTest(self.view.convert(point, to: selectedContainer.view), with: event) == nil {
                return self.dimNode.view
            }
        }
        
        if let result = super.hitTest(point, with: event) {
            for (index, container) in self.containers {
                if result.isDescendant(of: container.view) {
                    if index != self.selectedStickerPackIndex {
                        return self.containerContainingNode.view
                    }
                }
            }
            return result
        } else {
            return nil
        }
    }
    
    @objc private func dimNodeTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.dismiss()
        }
    }
}

public final class StickerPackScreenImpl: ViewController, StickerPackScreen {
    private let context: AccountContext
    fileprivate var presentationData: PresentationData
    fileprivate let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    private var presentationDataDisposable: Disposable?
    
    private let stickerPacks: [StickerPackReference]
    fileprivate let loadedStickerPacks: [LoadedStickerPack]
    let previewIconFile: TelegramMediaFile?
    
    private let initialSelectedStickerPackIndex: Int
    fileprivate weak var parentNavigationController: NavigationController?
    fileprivate let sendSticker: ((FileMediaReference, UIView, CGRect) -> Bool)?
    private let sendEmoji: ((String, ChatTextInputTextCustomEmojiAttribute) -> Void)?
    
    fileprivate var controllerNode: StickerPackScreenNode {
        return self.displayNode as! StickerPackScreenNode
    }
    
    public var dismissed: (() -> Void)?
    public var actionPerformed: (([(StickerPackCollectionInfo, [StickerPackItem], StickerPackScreenPerformedAction)]) -> Void)?
    
    public var getSourceRect: (() -> CGRect?)?
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private let openMentionDisposable = MetaDisposable()
    
    private var alreadyDidAppear: Bool = false
    private var animatedIn: Bool = false
    fileprivate var initialIsEditing: Bool = false
    fileprivate var expandIfNeeded: Bool = false
    fileprivate let ignoreCache: Bool
    
    let animationCache: AnimationCache
    let animationRenderer: MultiAnimationRenderer
    
    let mainActionTitle: String?
    let actionTitle: String?
        
    public init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
        stickerPacks: [StickerPackReference],
        loadedStickerPacks: [LoadedStickerPack],
        previewIconFile: TelegramMediaFile?,
        selectedStickerPackIndex: Int = 0,
        mainActionTitle: String? = nil,
        actionTitle: String? = nil,
        isEditing: Bool = false,
        expandIfNeeded: Bool = false,
        ignoreCache: Bool = false,
        parentNavigationController: NavigationController? = nil,
        sendSticker: ((FileMediaReference, UIView, CGRect) -> Bool)? = nil,
        sendEmoji: ((String, ChatTextInputTextCustomEmojiAttribute) -> Void)?,
        actionPerformed: (([(StickerPackCollectionInfo, [StickerPackItem], StickerPackScreenPerformedAction)]) -> Void)? = nil
    ) {
        self.context = context
        self.presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        self.updatedPresentationData = updatedPresentationData
        self.stickerPacks = stickerPacks
        self.loadedStickerPacks = loadedStickerPacks
        self.previewIconFile = previewIconFile
        self.initialSelectedStickerPackIndex = selectedStickerPackIndex
        self.mainActionTitle = mainActionTitle
        self.actionTitle = actionTitle
        self.initialIsEditing = isEditing
        self.expandIfNeeded = expandIfNeeded
        self.ignoreCache = ignoreCache
        self.parentNavigationController = parentNavigationController
        self.sendSticker = sendSticker
        self.sendEmoji = sendEmoji
        self.actionPerformed = actionPerformed

        self.animationCache = context.animationCache
        self.animationRenderer = context.animationRenderer
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        
        self.presentationDataDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                strongSelf.presentationData = presentationData
                strongSelf.controllerNode.updatePresentationData(presentationData)
            }
        })
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.openMentionDisposable.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = StickerPackScreenNode(context: self.context, controller: self, stickerPacks: self.stickerPacks, previewIconFile: self.previewIconFile, initialSelectedStickerPackIndex: self.initialSelectedStickerPackIndex, modalProgressUpdated: { [weak self] value, transition in
            DispatchQueue.main.async {
                guard let strongSelf = self else {
                    return
                }
                strongSelf.updateModalStyleOverlayTransitionFactor(value, transition: transition)
            }
        }, dismissed: { [weak self] in
            self?.dismissed?()
            self?.dismiss()
        }, presentInGlobalOverlay: { [weak self] c, a in
            self?.presentInGlobalOverlay(c, with: a)
        }, sendSticker: self.sendSticker.flatMap { [weak self] sendSticker in
            return { file, sourceNode, sourceRect in
                if sendSticker(file, sourceNode, sourceRect) {
                    self?.dismiss()
                    return true
                } else {
                    return false
                }
            }
        }, sendEmoji: self.sendEmoji.flatMap { [weak self] sendEmoji in
            return { text, attribute in
                sendEmoji(text, attribute)
                self?.controllerNode.dismiss()
            }
        }, longPressEmoji: { [weak self] text, attribute, node, frame in
            guard let strongSelf = self else {
                return
            }
            
            var actions: [ContextMenuAction] = []

            actions.append(ContextMenuAction(content: .text(title: strongSelf.presentationData.strings.Conversation_ContextMenuCopy, accessibilityLabel: strongSelf.presentationData.strings.Conversation_ContextMenuCopy), action: { [weak self] in
                storeMessageTextInPasteboard(
                    text,
                    entities: [
                        MessageTextEntity(
                            range: 0 ..< (text as NSString).length,
                            type: .CustomEmoji(
                                stickerPack: nil,
                                fileId: attribute.fileId
                            )
                        )
                    ]
                )
                
                if let strongSelf = self, let file = attribute.file {
                    let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                    strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .sticker(context: strongSelf.context, file: file, loop: true, title: nil, text: presentationData.strings.Conversation_EmojiCopied, undoText: nil, customAction: nil), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                }
            }))
            
            let contextMenuController = makeContextMenuController(actions: actions)
            strongSelf.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self] in
                if let strongSelf = self {
                    return (node, frame.insetBy(dx: -40.0, dy: 0.0), strongSelf.controllerNode, strongSelf.controllerNode.view.bounds)
                } else {
                    return nil
                }
            }))
        }, openMention: { [weak self] mention in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.openMentionDisposable.set((strongSelf.context.engine.peers.resolvePeerByName(name: mention, referrer: nil)
            |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
                guard case let .result(result) = result else {
                    return .complete()
                }
                return .single(result)
            }
            |> mapToSignal { peer -> Signal<Peer?, NoError> in
                if let peer = peer {
                    return .single(peer._asPeer())
                } else {
                    return .single(nil)
                }
            }
            |> deliverOnMainQueue).start(next: { peer in
                guard let strongSelf = self else {
                    return
                }
                if let peer {
                    if let parentNavigationController = strongSelf.parentNavigationController {
                        strongSelf.controllerNode.dismiss()
                        strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: parentNavigationController, context: strongSelf.context, chatLocation: .peer(EnginePeer(peer)), keepStack: .always, animated: true))
                    }
                } else {
                    strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.Resolve_ErrorNotFound, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                }
            }))
        })
        
        var loaded = false
        var dismissed = false
        
        var overlayStatusController: ViewController?
        let cancelImpl: (() -> Void)? = { [weak self] in
            dismissed = true
            overlayStatusController?.dismiss()
            self?.dismiss()
        }
        
        self.controllerNode.onReady = { [weak self] in
            loaded = true
            
            if let strongSelf = self {
                if !dismissed {
                    if let overlayStatusController = overlayStatusController {
                        overlayStatusController.dismiss()
                    }
                    
                    if strongSelf.alreadyDidAppear {
                        
                    } else {
                        strongSelf.isReady = true
                    }
                    
                    strongSelf.controllerNode.isHidden = false
                    if !strongSelf.animatedIn {
                        strongSelf.animatedIn = true
                        strongSelf.controllerNode.animateIn()
                    }
                }
            }
        }
         
        let presentationData = self.presentationData
        self.controllerNode.onLoading = { [weak self] in
            Queue.mainQueue().after(0.15, {
                if !loaded {
                    let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                        cancelImpl?()
                    }))
                    self?.present(controller, in: .window(.root))
                    overlayStatusController = controller
                }
            })
        }
        
        self.controllerNode.onError = {
            loaded = true
            
            if let overlayStatusController = overlayStatusController {
                overlayStatusController.dismiss()
            }
        }
        
        self.controllerNode.isHidden = true
        
        self._ready.set(self.controllerNode.ready.get())
        
        super.displayNodeDidLoad()
    }
    
    private var isReady = false
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.alreadyDidAppear {
            self.alreadyDidAppear = true
            
            if self.isReady {
                self.animatedIn = true
                self.controllerNode.animateIn()
            }
        }
    }
    
    private var validLayout: ContainerViewLayout?
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let previousSize = self.validLayout?.size
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.validLayout = layout
        if let previousSize, previousSize != layout.size {
            Queue.mainQueue().after(0.1) {
                self.controllerNode.containerLayoutUpdated(layout, transition: transition)
            }
        }
        self.controllerNode.containerLayoutUpdated(layout, transition: transition)
    }
}

public enum StickerPackScreenPerformedAction {
    case add
    case remove(positionInList: Int)
}

public func StickerPackScreen(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
    mode: StickerPackPreviewControllerMode = .default,
    mainStickerPack: StickerPackReference,
    stickerPacks: [StickerPackReference],
    loadedStickerPacks: [LoadedStickerPack] = [],
    previewIconFile: TelegramMediaFile? = nil,
    mainActionTitle: String? = nil,
    actionTitle: String? = nil,
    isEditing: Bool = false,
    expandIfNeeded: Bool = false,
    ignoreCache: Bool = false,
    parentNavigationController: NavigationController? = nil,
    sendSticker: ((FileMediaReference, UIView, CGRect) -> Bool)? = nil,
    sendEmoji: ((String, ChatTextInputTextCustomEmojiAttribute) -> Void)? = nil,
    actionPerformed: (([(StickerPackCollectionInfo, [StickerPackItem], StickerPackScreenPerformedAction)]) -> Void)? = nil,
    dismissed: (() -> Void)? = nil,
    getSourceRect: (() -> CGRect?)? = nil
) -> ViewController {
    let controller = StickerPackScreenImpl(
        context: context,
        updatedPresentationData: updatedPresentationData,
        stickerPacks: stickerPacks,
        loadedStickerPacks: loadedStickerPacks,
        previewIconFile: previewIconFile,
        selectedStickerPackIndex: stickerPacks.firstIndex(of: mainStickerPack) ?? 0,
        mainActionTitle: mainActionTitle,
        actionTitle: actionTitle,
        isEditing: isEditing,
        expandIfNeeded: expandIfNeeded,
        ignoreCache: ignoreCache,
        parentNavigationController: parentNavigationController,
        sendSticker: sendSticker,
        sendEmoji: sendEmoji,
        actionPerformed: actionPerformed
    )
    controller.dismissed = dismissed
    controller.getSourceRect = getSourceRect
    return controller
}


private final class StickerPackContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceNode: ContextReferenceContentNode
    
    init(controller: ViewController, sourceNode: ContextReferenceContentNode) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceNode.view, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}


private func generateShadowImage() -> UIImage? {
    return generateImage(CGSize(width: 140.0, height: 140.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.saveGState()
        context.setShadow(offset: CGSize(), blur: 60.0, color: UIColor(white: 0.0, alpha: 0.4).cgColor)
        let path = UIBezierPath(roundedRect: CGRect(x: 60.0, y: 60.0, width: 20.0, height: 20.0), cornerRadius: 10.0).cgPath
        context.addPath(path)
        context.fillPath()
        
        context.restoreGState()
        
        context.setBlendMode(.clear)
        context.addPath(path)
        context.fillPath()
    })?.stretchableImage(withLeftCapWidth: 70, topCapHeight: 70)
}

private func generateArrowImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 23.0, height: 12.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
      
        context.setFillColor(color.cgColor)
    
        context.translateBy(x: -183.0, y: -209.0)
        
        try? drawSvgPath(context, path: "M183.219,208.89 H206.781 C205.648,208.89 204.567,209.371 203.808,210.214 L197.23,217.523 C196.038,218.848 193.962,218.848 192.77,217.523 L186.192,210.214 C185.433,209.371 184.352,208.89 183.219,208.89 Z ")
    })
}


private class ReorderingGestureRecognizer: UIGestureRecognizer {
    private let shouldBegin: (CGPoint) -> (allowed: Bool, requiresLongPress: Bool, itemNode: StickerPackPreviewGridItemNode?)
    private let willBegin: (CGPoint) -> Void
    private let began: (StickerPackPreviewGridItemNode) -> Void
    private let ended: (CGPoint?) -> Void
    private let moved: (CGPoint, CGPoint) -> Void
    
    private var initialLocation: CGPoint?
    private var longPressTimer: SwiftSignalKit.Timer?
    
    var animateOnTouch = true
    
    private var itemNode: StickerPackPreviewGridItemNode?
    
    public init(animateOnTouch: Bool, shouldBegin: @escaping (CGPoint) -> (allowed: Bool, requiresLongPress: Bool, itemNode: StickerPackPreviewGridItemNode?), willBegin: @escaping (CGPoint) -> Void, began: @escaping (StickerPackPreviewGridItemNode) -> Void, ended: @escaping (CGPoint?) -> Void, moved: @escaping (CGPoint, CGPoint) -> Void) {
        self.animateOnTouch = animateOnTouch
        self.shouldBegin = shouldBegin
        self.willBegin = willBegin
        self.began = began
        self.ended = ended
        self.moved = moved
        
        super.init(target: nil, action: nil)
    }
    
    deinit {
        self.longPressTimer?.invalidate()
    }
    
    private func startLongPressTimer() {
        self.longPressTimer?.invalidate()
        let longPressTimer = SwiftSignalKit.Timer(timeout: 0.3, repeat: false, completion: { [weak self] in
            self?.longPressTimerFired()
        }, queue: Queue.mainQueue())
        self.longPressTimer = longPressTimer
        longPressTimer.start()
    }
    
    private func stopLongPressTimer() {
        self.itemNode = nil
        self.longPressTimer?.invalidate()
        self.longPressTimer = nil
    }
    
    override public func reset() {
        super.reset()
        
        self.itemNode = nil
        self.stopLongPressTimer()
        self.initialLocation = nil
    }
    
 
    private func longPressTimerFired() {
        guard let _ = self.initialLocation else {
            return
        }
        
        self.state = .began
        self.longPressTimer?.invalidate()
        self.longPressTimer = nil
        if let itemNode = self.itemNode {
            self.began(itemNode)
        }
    }
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if self.numberOfTouches > 1 {
            self.state = .failed
            self.ended(nil)
            return
        }
        
        if self.state == .possible {
            if let location = touches.first?.location(in: self.view) {
                let (allowed, requiresLongPress, itemNode) = self.shouldBegin(location)
                if allowed {
                    if let itemNode = itemNode, self.animateOnTouch {
                        itemNode.layer.animateScale(from: 1.0, to: 0.98, duration: 0.2, delay: 0.1)
                    }
                    self.itemNode = itemNode
                    self.initialLocation = location
                    if requiresLongPress {
                        self.startLongPressTimer()
                    } else {
                        self.state = .began
                        if let itemNode = self.itemNode {
                            self.began(itemNode)
                        }
                    }
                } else {
                    self.state = .failed
                }
            } else {
                self.state = .failed
            }
        }
    }
    
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        self.initialLocation = nil
        
        if self.longPressTimer != nil {
            self.stopLongPressTimer()
            self.state = .failed
        }
        if self.state == .began || self.state == .changed {
            if let location = touches.first?.location(in: self.view) {
                self.ended(location)
            } else {
                self.ended(nil)
            }
            self.state = .failed
        }
    }
    
    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        self.initialLocation = nil
        
        if self.longPressTimer != nil {
            self.stopLongPressTimer()
            self.state = .failed
        }
        if self.state == .began || self.state == .changed {
            self.ended(nil)
            self.state = .failed
        }
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        if (self.state == .began || self.state == .changed), let initialLocation = self.initialLocation, let location = touches.first?.location(in: self.view) {
            self.state = .changed
            self.moved(location, CGPoint(x: location.x - initialLocation.x, y: location.y - initialLocation.y))
        } else if let touch = touches.first, let initialTapLocation = self.initialLocation, self.longPressTimer != nil {
            let touchLocation = touch.location(in: self.view)
            let dX = touchLocation.x - initialTapLocation.x
            let dY = touchLocation.y - initialTapLocation.y
            
            if dX * dX + dY * dY > 3.0 * 3.0 {
                self.itemNode?.layer.removeAllAnimations()
                
                self.stopLongPressTimer()
                self.initialLocation = nil
                self.state = .failed
            }
        }
    }
}

private func generateShadowImage(corners: CACornerMask, radius: CGFloat) -> UIImage? {
    return generateImage(CGSize(width: 120.0, height: 120), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
//        context.saveGState()
        context.setShadow(offset: CGSize(), blur: 28.0, color: UIColor(white: 0.0, alpha: 0.4).cgColor)

        var rectCorners: UIRectCorner = []
        if corners.contains(.layerMinXMinYCorner) {
            rectCorners.insert(.topLeft)
        }
        if corners.contains(.layerMaxXMinYCorner) {
            rectCorners.insert(.topRight)
        }
        if corners.contains(.layerMinXMaxYCorner) {
            rectCorners.insert(.bottomLeft)
        }
        if corners.contains(.layerMaxXMaxYCorner) {
            rectCorners.insert(.bottomRight)
        }
        
        let path = UIBezierPath(roundedRect: CGRect(x: 30.0, y: 30.0, width: 60.0, height: 60.0), byRoundingCorners: rectCorners, cornerRadii: CGSize(width: radius, height: radius)).cgPath
        context.addPath(path)
        context.fillPath()
//        context.restoreGState()
        
//        context.setBlendMode(.clear)
//        context.addPath(path)
//        context.fillPath()
    })?.stretchableImage(withLeftCapWidth: 60, topCapHeight: 60)
}

private final class CopyView: UIView {
    let shadow: UIImageView
    var snapshotView: UIView?
    
    init(frame: CGRect, corners: CACornerMask, radius: CGFloat) {
        self.shadow = UIImageView()
        self.shadow.contentMode = .scaleToFill
        
        super.init(frame: frame)
        
        self.addSubview(self.shadow)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class ReorderingItemNode: ASDisplayNode {
    weak var itemNode: StickerPackPreviewGridItemNode?
    
    var currentState: (Int, Int)?
    
    private let copyView: CopyView
    private let initialLocation: CGPoint
    
    init(itemNode: StickerPackPreviewGridItemNode, initialLocation: CGPoint) {
        self.itemNode = itemNode
        self.copyView = CopyView(frame: CGRect(), corners: [], radius: 0.0)
        let snapshotView = itemNode.view.snapshotView(afterScreenUpdates: false)
        self.initialLocation = initialLocation
        
        super.init()
        
        if let snapshotView = snapshotView {
            snapshotView.frame = CGRect(origin: CGPoint(), size: itemNode.bounds.size)
            snapshotView.bounds.origin = itemNode.bounds.origin
            snapshotView.layer.shadowRadius = 10.0
            snapshotView.layer.shadowColor = UIColor.black.cgColor
            self.copyView.addSubview(snapshotView)
            self.copyView.snapshotView = snapshotView
        }
        self.view.addSubview(self.copyView)
        self.copyView.frame = CGRect(origin: CGPoint(x: initialLocation.x, y: initialLocation.y), size: itemNode.bounds.size)
        self.copyView.shadow.frame = CGRect(origin: CGPoint(x: -30.0, y: -30.0), size: CGSize(width: itemNode.bounds.size.width + 60.0, height: itemNode.bounds.size.height + 60.0))
        self.copyView.shadow.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
        
        self.copyView.snapshotView?.layer.animateScale(from: 1.0, to: 1.1, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        self.copyView.shadow.layer.animateScale(from: 1.0, to: 1.1, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
    }
    
    func updateOffset(offset: CGPoint) {
        self.copyView.frame = CGRect(origin: CGPoint(x: initialLocation.x + offset.x, y: initialLocation.y + offset.y), size: copyView.bounds.size)
    }
    
    func currentOffset() -> CGFloat? {
        return self.copyView.center.y
    }
    
    func animateCompletion(completion: @escaping () -> Void) {
        if let itemNode = self.itemNode {
            itemNode.view.superview?.bringSubviewToFront(itemNode.view)
                        
            itemNode.layer.animateScale(from: 1.1, to: 1.0, duration: 0.25, removeOnCompletion: false)
            
//            let sourceFrame = self.view.convert(self.copyView.frame, to: itemNode.supernode?.view)
//            let targetFrame = itemNode.frame
//            itemNode.updateLayout(size: sourceFrame.size, transition: .immediate)
//            itemNode.layer.animateFrame(from: sourceFrame, to: targetFrame, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, completion: { _ in
//                completion()
//            })
//            itemNode.updateLayout(size: targetFrame.size, transition: .animated(duration: 0.3, curve: .spring))
            
            itemNode.isHidden = false
            self.copyView.isHidden = true
            
            completion()
        } else {
            completion()
        }
    }
}
