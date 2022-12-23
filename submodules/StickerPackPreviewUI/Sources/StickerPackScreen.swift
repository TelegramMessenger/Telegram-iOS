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
import ShareController
import TextFormat
import PremiumUI
import OverlayStatusController
import PresentationDataUtils
import StickerPeekUI
import AnimationCache
import MultiAnimationRenderer
import Pasteboard

private enum StickerPackPreviewGridEntry: Comparable, Identifiable {
    case sticker(index: Int, stableId: Int, stickerItem: StickerPackItem?, isEmpty: Bool, isPremium: Bool, isLocked: Bool)
    case emojis(index: Int, stableId: Int, info: StickerPackCollectionInfo, items: [StickerPackItem], title: String?, isInstalled: Bool?)
    
    var stableId: Int {
        switch self {
            case let .sticker(_, stableId, _, _, _, _):
                return stableId
            case let .emojis(_, stableId, _, _, _, _):
                return stableId
        }
    }
    
    var index: Int {
        switch self {
            case let .sticker(index, _, _, _, _, _):
                return index
            case let .emojis(index, _, _, _, _, _):
                return index
        }
    }
    
    static func <(lhs: StickerPackPreviewGridEntry, rhs: StickerPackPreviewGridEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(context: AccountContext, interaction: StickerPackPreviewInteraction, theme: PresentationTheme, strings: PresentationStrings, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer) -> GridItem {
        switch self {
            case let .sticker(_, _, stickerItem, isEmpty, isPremium, isLocked):
                return StickerPackPreviewGridItem(account: context.account, stickerItem: stickerItem, interaction: interaction, theme: theme, isPremium: isPremium, isLocked: isLocked, isEmpty: isEmpty)
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
    
    init(previousList: [StickerPackPreviewGridEntry], list: [StickerPackPreviewGridEntry], context: AccountContext, interaction: StickerPackPreviewInteraction, theme: PresentationTheme, strings: PresentationStrings, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer, scrollToItem: GridNodeScrollToItem?) {
         let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: previousList, rightList: list)
        
        self.deletions = deleteIndices
        self.insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(context: context, interaction: interaction, theme: theme, strings: strings, animationCache: animationCache, animationRenderer: animationRenderer), previousIndex: $0.2) }
        self.updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, interaction: interaction, theme: theme, strings: strings, animationCache: animationCache, animationRenderer: animationRenderer)) }
        
        self.scrollToItem = scrollToItem
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
    private let backgroundNode: ASImageNode
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
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = true
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 20.0, color: self.presentationData.theme.actionSheet.opaqueItemBackgroundColor)
        
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
        self.interaction = StickerPackPreviewInteraction(playAnimatedStickers: true, addStickerPack: { info, items in
            addStickerPackImpl?(info, items)
        }, removeStickerPack: { info in
            removeStickerPackImpl?(info)
        }, emojiSelected: { text, attribute in
            emojiSelectedImpl?(text, attribute)
        }, emojiLongPressed: { text, attribute, node, frame in
            emojiLongPressedImpl?(text, attribute, node, frame)
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
        
        self.gridNode.interactiveScrollingEnded = { [weak self] in
            guard let strongSelf = self, !strongSelf.isDismissed else {
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
        
        
        
        let fetchedStickerPacks: Signal<[LoadedStickerPack], NoError> = combineLatest(stickerPacks.map { packReference in
            for pack in loadedStickerPacks {
                if case let .result(info, _, _) = pack, case let .id(id, _) = packReference, info.id.id == id {
                    return .single(pack)
                }
            }
            return context.engine.stickers.loadedStickerPack(reference: packReference, forceActualized: true)
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
        
        self.titleNode.linkHighlightColor = self.presentationData.theme.actionSheet.controlAccentColor.withAlphaComponent(0.5)
        
        addStickerPackImpl = { [weak self] info, items in
            guard let strongSelf = self else {
                return
            }
            if let index = strongSelf.currentStickerPacks.firstIndex(where: { $0.0.id == info.id }) {
                strongSelf.currentStickerPacks[index].2 = true
                
                var contents: [LoadedStickerPack] = []
                for (info, items, isInstalled) in strongSelf.currentStickerPacks {
                    contents.append(.result(info: info, items: items, installed: isInstalled))
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
                    contents.append(.result(info: info, items: items, installed: isInstalled))
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
    }
    
    deinit {
        self.itemsDisposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.gridNode.view.addGestureRecognizer(PeekControllerGestureRecognizer(contentAtPoint: { [weak self] point -> Signal<(UIView, CGRect, PeekControllerContent)?, NoError>? in
            if let strongSelf = self {
                if let itemNode = strongSelf.gridNode.itemNodeAtPoint(point) as? StickerPackPreviewGridItemNode, let item = itemNode.stickerPackItem {
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
                                    menuItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.StickerPack_Send, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Resend"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                                        if let strongSelf = self, let peekController = strongSelf.peekController {
                                            if let animationNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.animationNode {
                                                let _ = strongSelf.sendSticker?(.standalone(media: item.file), animationNode.view, animationNode.bounds)
                                            } else if let imageNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.imageNode {
                                                let _ = strongSelf.sendSticker?(.standalone(media: item.file), imageNode.view, imageNode.bounds)
                                            }
                                        }
                                        f(.default)
                                    })))
                                }
                                menuItems.append(.action(ContextMenuActionItem(text: isStarred ? strongSelf.presentationData.strings.Stickers_RemoveFromFavorites : strongSelf.presentationData.strings.Stickers_AddToFavorites, icon: { theme in generateTintedImage(image: isStarred ? UIImage(bundleImageName: "Chat/Context Menu/Unfave") : UIImage(bundleImageName: "Chat/Context Menu/Fave"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                                    f(.default)
                                    
                                    if let strongSelf = self {
                                        let _ = strongSelf.context.engine.stickers.toggleStickerSaved(file: item.file, saved: !isStarred).start(next: { _ in
                                            
                                        })
                                    }
                                })))
                            }
                            return (itemNode.view, itemNode.bounds, StickerPreviewPeekContent(account: strongSelf.context.account, theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, item: .pack(item.file), isLocked: item.file.isPremiumSticker && !hasPremium, menu: menuItems, openPremiumIntro: { [weak self] in
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
                }
            }
            return nil
        }, present: { [weak self] content, sourceView, sourceRect in
            if let strongSelf = self {
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
        }, activateBySingleTap: true))
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
            switch currentContents {
                case .fetching:
                    buttonColor = .clear
                case .none:
                    buttonColor = self.presentationData.theme.list.itemAccentColor
                case let .result(_, _, installed):
                    buttonColor = installed ? self.presentationData.theme.list.itemDestructiveColor : self.presentationData.theme.list.itemCheckColors.foregroundColor
                    if installed {
                        buttonFont = Font.regular(17.0)
                    }
            }
            self.buttonNode.setTitle(self.buttonNode.attributedTitle(for: .normal)?.string ?? "", with: buttonFont, with: buttonColor, for: .normal)
        }
                
        if !self.currentEntries.isEmpty, let controller = self.controller {
            let transaction = StickerPackPreviewGridTransaction(previousList: self.currentEntries, list: self.currentEntries, context: self.context, interaction: self.interaction, theme: self.presentationData.theme, strings: self.presentationData.strings, animationCache: controller.animationCache, animationRenderer: controller.animationRenderer, scrollToItem: nil)
            self.enqueueTransaction(transaction)
        }
        
        let titleFont = Font.semibold(17.0)
        let title = self.titleNode.attributedText?.string ?? ""
        let entities = generateTextEntities(title, enabledTypes: [.mention])
        self.titleNode.attributedText = stringWithAppliedEntities(title, entities: entities, baseColor: self.presentationData.theme.actionSheet.primaryTextColor, linkColor: self.presentationData.theme.actionSheet.controlAccentColor, baseFont: titleFont, linkFont: titleFont, boldFont: titleFont, italicFont: titleFont, boldItalicFont: titleFont, fixedFont: titleFont, blockQuoteFont: titleFont, message: nil)
        
        if let (layout, _, _, _) = self.validLayout {
            let _ = self.titleNode.updateLayout(CGSize(width: layout.size.width - max(12.0, self.cancelButtonNode.frame.width) * 2.0 - 40.0, height: .greatestFiniteMagnitude))
            self.updateLayout(layout: layout, transition: .immediate)
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
                let shareController = ShareController(context: strongSelf.context, subject: shareSubject)
                shareController.actionCompleted = { [weak parentNavigationController] in
                    if let parentNavigationController = parentNavigationController, let controller = parentNavigationController.topViewController as? ViewController {
                        let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                        controller.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                    }
                }
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
                strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: copyText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
            }
        })))
        
        let contextController = ContextController(account: self.context.account, presentationData: self.presentationData, source: .reference(StickerPackContextReferenceContentSource(controller: controller, sourceNode: node)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
        self.presentInGlobalOverlay(contextController, nil)
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
        } else if let (info, items, installed) = self.currentStickerPack {
            var dismissed = false
            switch self.decideNextAction(self, installed ? .remove : .add) {
                case .dismiss:
                    self.requestDismiss()
                    dismissed = true
                case .navigatedNext, .ignored:
                    self.updateStickerPackContents([.result(info: info, items: items, installed: !installed)], hasPremium: false)
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
        } else {
            self.requestDismiss()
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
    
    private func updateStickerPackContents(_ contents: [LoadedStickerPack], hasPremium: Bool) {
        self.currentContents = contents
        self.didReceiveStickerPackResult = true
        
        var entries: [StickerPackPreviewGridEntry] = []
        
        var updateLayout = false
        
        var scrollToItem: GridNodeScrollToItem?
        let titleFont = Font.semibold(17.0)
        
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
                        entries.append(.emojis(index: index, stableId: index, info: info, items: items, title: info.title, isInstalled: isInstalled))
                        if isInstalled {
                            installedCount += 1
                        }
                        currentStickerPacks.append((info, items, isInstalled))
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
                        if case let .sticker(index, currentStableId, stickerItem, _, _, _) = entry, stickerItem == nil, index == entries.count {
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
                    entries.append(.sticker(index: entries.count, stableId: resolvedStableId, stickerItem: nil, isEmpty: false, isPremium: false, isLocked: false))
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
                self.onReady()
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
                            if case let .sticker(_, currentStableId, stickerItem, _, _, _) = entry, let stickerItem = stickerItem, stickerItem.file.fileId == item.file.fileId {
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
                        entries.append(.sticker(index: entries.count, stableId: resolvedStableId, stickerItem: item, isEmpty: false, isPremium: isPremium, isLocked: isLocked))
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
                
                if installed {
                    let text: String
                    if info.id.namespace == Namespaces.ItemCollection.CloudStickerPacks {
                        text = self.presentationData.strings.StickerPack_RemoveStickerCount(Int32(entries.count))
                    } else if info.id.namespace == Namespaces.ItemCollection.CloudEmojiPacks {
                        text = self.presentationData.strings.StickerPack_RemoveEmojiCount(Int32(items.count))
                    } else {
                        text = self.presentationData.strings.StickerPack_RemoveMaskCount(Int32(entries.count))
                    }
                    self.buttonNode.setTitle(text, with: Font.regular(17.0), with: self.presentationData.theme.list.itemDestructiveColor, for: .normal)
                    self.buttonNode.setBackgroundImage(nil, for: [])
                } else {
                    let text: String
                    if info.id.namespace == Namespaces.ItemCollection.CloudStickerPacks {
                        text = self.presentationData.strings.StickerPack_AddStickerCount(Int32(entries.count))
                    } else if info.id.namespace == Namespaces.ItemCollection.CloudEmojiPacks {
                        text = self.presentationData.strings.StickerPack_AddEmojiCount(Int32(items.count))
                    } else {
                        text = self.presentationData.strings.StickerPack_AddMaskCount(Int32(entries.count))
                    }
                    self.buttonNode.setTitle(text, with: Font.semibold(17.0), with: self.presentationData.theme.list.itemCheckColors.foregroundColor, for: .normal)
                    let roundedAccentBackground = generateImage(CGSize(width: 22.0, height: 22.0), rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.setFillColor(self.presentationData.theme.list.itemCheckColors.fillColor.cgColor)
                        context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height)))
                    })?.stretchableImage(withLeftCapWidth: 11, topCapHeight: 11)
                    self.buttonNode.setBackgroundImage(roundedAccentBackground, for: [])
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
            let transaction = StickerPackPreviewGridTransaction(previousList: previousEntries, list: entries, context: self.context, interaction: self.interaction, theme: self.presentationData.theme, strings: self.presentationData.strings, animationCache: controller.animationCache, animationRenderer: controller.animationRenderer, scrollToItem: scrollToItem)
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
    
    func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        var insets = layout.insets(options: [.statusBar])
        if case .compact = layout.metrics.widthClass, layout.size.width > layout.size.height {
            insets.top = 0.0
        } else {
            insets.top += 10.0
        }
        
        var buttonHeight: CGFloat = 50.0
        var actionAreaTopInset: CGFloat = 8.0
        var actionAreaBottomInset: CGFloat = 16.0
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
        if let (_, _, isInstalled) = self.currentStickerPack, isInstalled {
            buttonHeight = 42.0
            actionAreaTopInset = 1.0
            actionAreaBottomInset = 2.0
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
                let rowCount = items.count / itemsPerRow + ((items.count % itemsPerRow) == 0 ? 0 : 1)
                contentHeight = itemWidth * CGFloat(rowCount)
            }
        } else {
            contentHeight = gridFrame.size.height
        }
        
        let initialRevealedRowCount: CGFloat = 4.5
        
        let topInset = max(0.0, layout.size.height - floor(initialRevealedRowCount * itemWidth) - insets.top - actionAreaHeight - titleAreaInset)
        
        let additionalGridBottomInset = max(0.0, gridFrame.size.height - actionAreaHeight - contentHeight)
        
        let gridInsets = UIEdgeInsets(top: insets.top + topInset, left: gridLeftInset, bottom: actionAreaHeight + additionalGridBottomInset, right: layout.size.width - fillingWidth - gridLeftInset)
        
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
        
        let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: max(minBackgroundY, unclippedBackgroundY)), size: CGSize(width: layout.size.width, height: layout.size.height))
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        transition.updateFrame(node: self.titleContainer, frame: CGRect(origin: CGPoint(x: backgroundFrame.minX + floor((backgroundFrame.width) / 2.0), y: backgroundFrame.minY + floor((56.0) / 2.0)), size: CGSize()))
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
    
    private func dequeueTransaction() {
        if self.enqueuedTransactions.isEmpty {
            return
        }
        let transaction = self.enqueuedTransactions.removeFirst()
        
        self.gridNode.transaction(GridNodeTransaction(deleteItems: transaction.deletions, insertItems: transaction.insertions, updateItems: transaction.updates, scrollToItem: transaction.scrollToItem, updateLayout: nil, itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
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
    private let modalProgressUpdated: (CGFloat, ContainedViewLayoutTransition) -> Void
    private let dismissed: () -> Void
    private let presentInGlobalOverlay: (ViewController, Any?) -> Void
    private let sendSticker: ((FileMediaReference, UIView, CGRect) -> Bool)?
    private let sendEmoji: ((String, ChatTextInputTextCustomEmojiAttribute) -> Void)?
    private let longPressEmoji: ((String, ChatTextInputTextCustomEmojiAttribute, ASDisplayNode, CGRect) -> Void)?
    private let openMention: (String) -> Void
    
    private let dimNode: ASDisplayNode
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
        
        self.containerContainingNode = ASDisplayNode()
        
        super.init()
        
        self.addSubnode(self.dimNode)
        
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
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let firstTime = self.validLayout == nil
        
        self.validLayout = layout
        
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(node: self.containerContainingNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
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
                container = StickerPackContainer(index: index, context: self.context, presentationData: self.presentationData, stickerPacks: self.stickerPacks, loadedStickerPacks: self.controller?.loadedStickerPacks ?? [], decideNextAction: { [weak self] container, action in
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
            
            let containerFrame = CGRect(origin: CGPoint(x: CGFloat(indexOffset) * layout.size.width + self.relativeToSelectedStickerPackTransition + scaledOffset, y: containerVerticalOffset), size: layout.size)
            containerTransition.updateFrame(node: container, frame: containerFrame, beginWithCurrentState: true)
            containerTransition.updateSublayerTransformScaleAndOffset(node: container, scale: containerScale, offset: CGPoint(), beginWithCurrentState: true)
            if container.validLayout?.0 != layout {
                container.updateLayout(layout: layout, transition: containerTransition)
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
        self.dimNode.alpha = 1.0
        self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        
        let minInset: CGFloat = (self.containers.map { (_, container) -> CGFloat in container.topContentInset }).max() ?? 0.0
        self.containerContainingNode.layer.animatePosition(from: CGPoint(x: 0.0, y: self.containerContainingNode.bounds.height - minInset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
    }
    
    func animateOut(completion: @escaping () -> Void) {
        self.dimNode.alpha = 0.0
        self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
        
        let minInset: CGFloat = (self.containers.map { (_, container) -> CGFloat in container.topContentInset }).max() ?? 0.0
        self.containerContainingNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: self.containerContainingNode.bounds.height - minInset), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true, completion: { _ in
            completion()
        })
        
        self.modalProgressUpdated(0.0, .animated(duration: 0.2, curve: .easeInOut))
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

public final class StickerPackScreenImpl: ViewController {
    private let context: AccountContext
    fileprivate var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let stickerPacks: [StickerPackReference]
    fileprivate let loadedStickerPacks: [LoadedStickerPack]
    
    private let initialSelectedStickerPackIndex: Int
    fileprivate weak var parentNavigationController: NavigationController?
    private let sendSticker: ((FileMediaReference, UIView, CGRect) -> Bool)?
    private let sendEmoji: ((String, ChatTextInputTextCustomEmojiAttribute) -> Void)?
    
    private var controllerNode: StickerPackScreenNode {
        return self.displayNode as! StickerPackScreenNode
    }
    
    public var dismissed: (() -> Void)?
    public var actionPerformed: (([(StickerPackCollectionInfo, [StickerPackItem], StickerPackScreenPerformedAction)]) -> Void)?
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private let openMentionDisposable = MetaDisposable()
    
    private var alreadyDidAppear: Bool = false
    private var animatedIn: Bool = false
    
    let animationCache: AnimationCache
    let animationRenderer: MultiAnimationRenderer
    
    public init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
        stickerPacks: [StickerPackReference],
        loadedStickerPacks: [LoadedStickerPack],
        selectedStickerPackIndex: Int = 0,
        parentNavigationController: NavigationController? = nil,
        sendSticker: ((FileMediaReference, UIView, CGRect) -> Bool)? = nil,
        sendEmoji: ((String, ChatTextInputTextCustomEmojiAttribute) -> Void)?,
        actionPerformed: (([(StickerPackCollectionInfo, [StickerPackItem], StickerPackScreenPerformedAction)]) -> Void)? = nil
    ) {
        self.context = context
        self.presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        self.stickerPacks = stickerPacks
        self.loadedStickerPacks = loadedStickerPacks
        self.initialSelectedStickerPackIndex = selectedStickerPackIndex
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
        self.displayNode = StickerPackScreenNode(context: self.context, controller: self, stickerPacks: self.stickerPacks, initialSelectedStickerPackIndex: self.initialSelectedStickerPackIndex, modalProgressUpdated: { [weak self] value, transition in
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
                    strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .sticker(context: strongSelf.context, file: file, title: nil, text: presentationData.strings.Conversation_EmojiCopied, undoText: nil, customAction: nil), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                }
            }))
            
            let contextMenuController = ContextMenuController(actions: actions)
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
            
            strongSelf.openMentionDisposable.set((strongSelf.context.engine.peers.resolvePeerByName(name: mention)
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
                if let peer = peer, let parentNavigationController = strongSelf.parentNavigationController {
                    strongSelf.dismiss()
                    strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: parentNavigationController, context: strongSelf.context, chatLocation: .peer(EnginePeer(peer)), animated: true))
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
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
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
    parentNavigationController: NavigationController? = nil,
    sendSticker: ((FileMediaReference, UIView, CGRect) -> Bool)? = nil,
    sendEmoji: ((String, ChatTextInputTextCustomEmojiAttribute) -> Void)? = nil,
    actionPerformed: (([(StickerPackCollectionInfo, [StickerPackItem], StickerPackScreenPerformedAction)]) -> Void)? = nil,
    dismissed: (() -> Void)? = nil) -> ViewController
{
    let controller = StickerPackScreenImpl(
        context: context,
        stickerPacks: stickerPacks,
        loadedStickerPacks: loadedStickerPacks,
        selectedStickerPackIndex: stickerPacks.firstIndex(of: mainStickerPack) ?? 0,
        parentNavigationController: parentNavigationController,
        sendSticker: sendSticker,
        sendEmoji: sendEmoji,
        actionPerformed: actionPerformed
    )
    controller.dismissed = dismissed
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
