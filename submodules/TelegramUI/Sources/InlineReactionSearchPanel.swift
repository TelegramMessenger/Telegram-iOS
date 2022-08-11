import Foundation
import UIKit
import SwiftSignalKit
import Display
import AsyncDisplayKit
import TelegramCore
import Postbox
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import StickerPackPreviewUI
import ContextUI
import ChatPresentationInterfaceState
import PremiumUI
import UndoUI

private final class InlineReactionSearchStickersNode: ASDisplayNode, UIScrollViewDelegate {
    private final class DisplayItem {
        let file: TelegramMediaFile
        let frame: CGRect
        
        init(file: TelegramMediaFile, frame: CGRect) {
            self.file = file
            self.frame = frame
        }
    }
    
    private let context: AccountContext
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private let peerId: PeerId?
    
    private let scrollNode: ASScrollNode
    private var items: [TelegramMediaFile] = []
    private var displayItems: [DisplayItem] = []
    private var topInset: CGFloat?
    private var itemNodes: [MediaId: HorizontalStickerGridItemNode] = [:]
    
    private var validLayout: CGSize?
    private var ignoreScrolling: Bool = false
    private var animateInOnLayout: Bool = false
    
    private weak var peekController: PeekController?
    
    var previewedStickerItem: StickerPackItem?
    
    var updateBackgroundOffset: ((CGFloat, Bool, ContainedViewLayoutTransition) -> Void)?
    var sendSticker: ((FileMediaReference, ASDisplayNode, CGRect) -> Void)?
    
    var getControllerInteraction: (() -> ChatControllerInteraction?)?
    
    private var scrollingStickersGridPromise = ValuePromise<Bool>(false)
    private var previewingStickersPromise = ValuePromise<Bool>(false)
    var choosingSticker: Signal<Bool, NoError> {
        return combineLatest(self.scrollingStickersGridPromise.get(), self.previewingStickersPromise.get())
        |> map { scrollingStickersGrid, previewingStickers -> Bool in
            return scrollingStickersGrid || previewingStickers
        }
        |> distinctUntilChanged
    }
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, peerId: PeerId?) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.peerId = peerId
        
        self.scrollNode = ASScrollNode()
        
        super.init()
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        self.scrollNode.view.alwaysBounceVertical = true
        self.scrollNode.view.showsVerticalScrollIndicator = false
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.delegate = self
        
        self.addSubnode(self.scrollNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(PeekControllerGestureRecognizer(contentAtPoint: { [weak self] point in
            if let strongSelf = self {
                let convertedPoint = strongSelf.scrollNode.view.convert(point, from: strongSelf.view)
                guard strongSelf.scrollNode.view.bounds.contains(convertedPoint) else {
                    return nil
                }
                
                var selectedNode: HorizontalStickerGridItemNode?
                for (_, node) in strongSelf.itemNodes {
                    if node.frame.contains(convertedPoint) {
                        selectedNode = node
                        break
                    }
                }
                
                if let itemNode = selectedNode, let item = itemNode.stickerItem {
                    return strongSelf.context.engine.stickers.isStickerSaved(id: item.file.fileId)
                    |> deliverOnMainQueue
                    |> map { isStarred -> (ASDisplayNode, PeekControllerContent)? in
                        if let strongSelf = self, let controllerInteraction = strongSelf.getControllerInteraction?() {
                            var menuItems: [ContextMenuItem] = []
                            
                            if strongSelf.peerId != strongSelf.context.account.peerId && strongSelf.peerId?.namespace != Namespaces.Peer.SecretChat  {
                                menuItems.append(.action(ContextMenuActionItem(text: strongSelf.strings.Conversation_SendMessage_SendSilently, icon: { theme in
                                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/SilentIcon"), color: theme.actionSheet.primaryTextColor)
                                }, action: { _, f in
                                    if let strongSelf = self, let peekController = strongSelf.peekController {
                                        if let animationNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.animationNode {
                                            let _ = controllerInteraction.sendSticker(.standalone(media: item.file), true, false, nil, true, animationNode, animationNode.bounds)
                                        } else if let imageNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.imageNode {
                                            let _ = controllerInteraction.sendSticker(.standalone(media: item.file), true, false, nil, true, imageNode, imageNode.bounds)
                                        }
                                    }
                                    f(.default)
                                })))
                            }
                        
                            menuItems.append(.action(ContextMenuActionItem(text: strongSelf.strings.Conversation_SendMessage_ScheduleMessage, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/ScheduleIcon"), color: theme.actionSheet.primaryTextColor)
                            }, action: { _, f in
                                if let strongSelf = self, let peekController = strongSelf.peekController {
                                    if let animationNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.animationNode {
                                        let _ = controllerInteraction.sendSticker(.standalone(media: item.file), false, true, nil, true, animationNode, animationNode.bounds)
                                    } else if let imageNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.imageNode {
                                        let _ = controllerInteraction.sendSticker(.standalone(media: item.file), false, true, nil, true, imageNode, imageNode.bounds)
                                    }
                                }
                                f(.default)
                            })))
                            
                            menuItems.append(
                                .action(ContextMenuActionItem(text: isStarred ? strongSelf.strings.Stickers_RemoveFromFavorites : strongSelf.strings.Stickers_AddToFavorites, icon: { theme in generateTintedImage(image: isStarred ? UIImage(bundleImageName: "Chat/Context Menu/Unfave") : UIImage(bundleImageName: "Chat/Context Menu/Fave"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                                    f(.default)
                                    
                                    if let strongSelf = self {
                                        let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                        let _ = (strongSelf.context.engine.stickers.toggleStickerSaved(file: item.file, saved: !isStarred)
                                        |> deliverOnMainQueue).start(next: { result in
                                            switch result {
                                                case .generic:
                                                    strongSelf.getControllerInteraction?()?.presentGlobalOverlayController(UndoOverlayController(presentationData: presentationData, content: .sticker(context: strongSelf.context, file: item.file, title: nil, text: !isStarred ? strongSelf.strings.Conversation_StickerAddedToFavorites : strongSelf.strings.Conversation_StickerRemovedFromFavorites, undoText: nil), elevatedLayout: false, action: { _ in return false }), nil)
                                                case let .limitExceeded(limit, premiumLimit):
                                                    let premiumConfiguration = PremiumConfiguration.with(appConfiguration: strongSelf.context.currentAppConfiguration.with { $0 })
                                                    let text: String
                                                    if limit == premiumLimit || premiumConfiguration.isPremiumDisabled {
                                                        text = strongSelf.strings.Premium_MaxFavedStickersFinalText
                                                    } else {
                                                        text = strongSelf.strings.Premium_MaxFavedStickersText("\(premiumLimit)").string
                                                    }
                                                    strongSelf.getControllerInteraction?()?.presentGlobalOverlayController(UndoOverlayController(presentationData: presentationData, content: .sticker(context: strongSelf.context, file: item.file, title: strongSelf.strings.Premium_MaxFavedStickersTitle("\(limit)").string, text: text, undoText: nil), elevatedLayout: false, action: { [weak self] action in
                                                        if let strongSelf = self {
                                                            if case .info = action {
                                                                let controller = PremiumIntroScreen(context: strongSelf.context, source: .savedStickers)
                                                                strongSelf.getControllerInteraction?()?.navigationController()?.pushViewController(controller)
                                                                return true
                                                            }
                                                        }
                                                        return false
                                                    }), nil)
                                            }
                                        })
                                    }
                                }))
                            )
                                
                            menuItems.append(
                                .action(ContextMenuActionItem(text: strongSelf.strings.StickerPack_ViewPack, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Sticker"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                                    f(.default)
                                
                                    if let strongSelf = self, let controllerInteraction = strongSelf.getControllerInteraction?() {
                                        loop: for attribute in item.file.attributes {
                                            switch attribute {
                                            case let .Sticker(_, packReference, _):
                                                if let packReference = packReference {
                                                    let controller = StickerPackScreen(context: strongSelf.context, mainStickerPack: packReference, stickerPacks: [packReference], parentNavigationController: controllerInteraction.navigationController(), sendSticker: { file, sourceNode, sourceRect in
                                                        if let strongSelf = self, let controllerInteraction = strongSelf.getControllerInteraction?() {
                                                            return controllerInteraction.sendSticker(file, false, false, nil, true, sourceNode, sourceRect)
                                                        } else {
                                                            return false
                                                        }
                                                    })
                                                    
                                                    controllerInteraction.navigationController()?.view.window?.endEditing(true)
                                                    controllerInteraction.presentController(controller, nil)
                                                }
                                                break loop
                                            default:
                                                break
                                            }
                                        }
                                    }
                                }))
                            )
                            return (itemNode, StickerPreviewPeekContent(account: strongSelf.context.account, theme: strongSelf.theme, strings: strongSelf.strings, item: .pack(item), menu: menuItems, openPremiumIntro: { [weak self] in
                                guard let strongSelf = self, let controllerInteraction = strongSelf.getControllerInteraction?() else {
                                    return
                                }
                                let controller = PremiumIntroScreen(context: strongSelf.context, source: .stickers)
                                controllerInteraction.navigationController()?.pushViewController(controller)
                            }))
                        } else {
                            return nil
                        }
                    }
                }
            }
            return nil
            }, present: { [weak self] content, sourceNode in
                if let strongSelf = self {
                    let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                    let controller = PeekController(presentationData: presentationData, content: content, sourceNode: {
                        return sourceNode
                    })
                    controller.visibilityUpdated = { [weak self] visible in
                        self?.previewingStickersPromise.set(visible)
                    }
                    strongSelf.peekController = controller
                    strongSelf.getControllerInteraction?()?.presentGlobalOverlayController(controller, nil)
                    return controller
                }
                return nil
            }, updateContent: { [weak self] content in
                if let strongSelf = self {
                    var item: StickerPackItem?
                    if let content = content as? StickerPreviewPeekContent, case let .pack(contentItem) = content.item {
                        item = contentItem
                    }
                    strongSelf.updatePreviewingItem(item: item, animated: true)
                }
        }))
    }
    
    private func updatePreviewingItem(item: StickerPackItem?, animated: Bool) {
        if self.previewedStickerItem != item {
            self.previewedStickerItem = item
            
            for (_, itemNode) in self.itemNodes {
                itemNode.updatePreviewing(animated: animated)
            }
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.scrollingStickersGridPromise.set(true)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            self.scrollingStickersGridPromise.set(false)
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.scrollingStickersGridPromise.set(false)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !self.ignoreScrolling {
            self.updateVisibleItems(synchronous: false)
            self.updateBackground(animateIn: false, transition: .immediate)
        }
    }
    
    private func updateBackground(animateIn: Bool, transition: ContainedViewLayoutTransition) {
        if let topInset = self.topInset {
            self.updateBackgroundOffset?(max(0.0, -self.scrollNode.view.contentOffset.y + topInset), animateIn, transition)
        }
    }
    
    func updateScrollNode() {
        guard let size = self.validLayout else {
            return
        }
        var contentHeight: CGFloat = 0.0
        if let item = self.displayItems.last {
            let maxY = item.frame.maxY + 4.0
            
            var topInset = size.height - floor(item.frame.height * 1.5)
            if topInset + maxY < size.height {
                topInset = size.height - maxY
            }
            self.topInset = topInset
            contentHeight = topInset + maxY
        } else {
            self.topInset = size.height
        }
        self.scrollNode.view.contentSize = CGSize(width: size.width, height: max(contentHeight, size.height))
    }
    
    func updateItems(items: [TelegramMediaFile]) {
        self.items = items
        
        var previousBackgroundOffset: CGFloat?
        if let topInset = self.topInset {
            previousBackgroundOffset = max(0.0, -self.scrollNode.view.contentOffset.y + topInset)
        } else {
            previousBackgroundOffset = self.validLayout?.height
        }
        
        if let size = self.validLayout {
            self.updateItemsLayout(width: size.width)
            self.updateScrollNode()
        }
        
        self.updateVisibleItems(synchronous: true)
        
        let transition: ContainedViewLayoutTransition = .animated(duration: 0.3, curve: .spring)
        
        if let previousBackgroundOffset = previousBackgroundOffset, let topInset = self.topInset {
            let currentBackgroundOffset = max(0.0, -self.scrollNode.view.contentOffset.y + topInset)
            if abs(currentBackgroundOffset - previousBackgroundOffset) > .ulpOfOne {
                transition.animateOffsetAdditive(node: self.scrollNode, offset: currentBackgroundOffset - previousBackgroundOffset)
                self.updateBackground(animateIn: false, transition: transition)
            }
        } else {
            self.animateInOnLayout = true
        }
    }
    
    func update(size: CGSize, transition: ContainedViewLayoutTransition) {
        var previousBackgroundOffset: CGFloat?
        if let topInset = self.topInset {
            previousBackgroundOffset = max(0.0, -self.scrollNode.view.contentOffset.y + topInset)
        } else {
            previousBackgroundOffset = self.validLayout?.height
        }
        
        let previousLayout = self.validLayout
        self.validLayout = size
        
        if self.animateInOnLayout {
            self.updateBackgroundOffset?(size.height, false, .immediate)
        }
        
        var synchronous = false
        if previousLayout?.width != size.width {
            synchronous = true
            self.updateItemsLayout(width: size.width)
        }
        
        self.ignoreScrolling = true
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: size))
        self.updateScrollNode()
        self.ignoreScrolling = false
        
        self.updateVisibleItems(synchronous: synchronous)
        
        var backgroundTransition = transition
        
        var animateIn = false
        if self.animateInOnLayout {
            animateIn = true
            self.animateInOnLayout = false
            backgroundTransition = .animated(duration: 0.3, curve: .spring)
            if let topInset = self.topInset {
                let currentBackgroundOffset = max(0.0, -self.scrollNode.view.contentOffset.y + topInset)
                let bounds = self.scrollNode.bounds
                self.scrollNode.bounds = bounds.offsetBy(dx: 0.0, dy: currentBackgroundOffset - size.height)
                backgroundTransition.animateView {
                    self.scrollNode.bounds = bounds
                }
            }
        } else {
            if let previousBackgroundOffset = previousBackgroundOffset, let topInset = self.topInset {
                let currentBackgroundOffset = max(0.0, -self.scrollNode.view.contentOffset.y + topInset)
                if abs(currentBackgroundOffset - previousBackgroundOffset) > .ulpOfOne {
                    transition.animateOffsetAdditive(node: self.scrollNode, offset: currentBackgroundOffset - previousBackgroundOffset)
                }
            }
        }
        
        self.updateBackground(animateIn: animateIn, transition: backgroundTransition)
    }
    
    private func updateItemsLayout(width: CGFloat) {
        self.displayItems.removeAll()
        
        let itemsPerRow = min(8, max(5, Int(width / 80)))
        let sideInset: CGFloat = 2.0
        let itemSpacing: CGFloat = 2.0
        let itemSize = floor((width - sideInset * 2.0 - itemSpacing * (CGFloat(itemsPerRow) - 1.0)) / CGFloat(itemsPerRow))
        
        var columnIndex = 0
        var topOffset: CGFloat = 7.0
        for i in 0 ..< self.items.count {
            self.displayItems.append(DisplayItem(file: self.items[i], frame: CGRect(origin: CGPoint(x: sideInset + CGFloat(columnIndex) * (itemSize + itemSpacing), y: topOffset), size: CGSize(width: itemSize, height: itemSize))))
            
            columnIndex += 1
            if columnIndex == itemsPerRow {
                columnIndex = 0
                topOffset += itemSize + itemSpacing
            }
        }
    }
    
    private func updateVisibleItems(synchronous: Bool) {
        guard let _ = self.validLayout, let topInset = self.topInset else {
            return
        }
        
        var minVisibleY = self.scrollNode.view.bounds.minY
        var maxVisibleY = self.scrollNode.view.bounds.maxY
        
        let containerSize = self.scrollNode.view.bounds.size
        let absoluteOffset: CGFloat = -self.scrollNode.view.contentOffset.y
        
        let minActivatedY = minVisibleY
        let maxActivatedY = maxVisibleY
        
        minVisibleY -= 200.0
        maxVisibleY += 200.0
        
        var validIds = Set<MediaId>()
        for i in 0 ..< self.displayItems.count {
            let item = self.displayItems[i]
            
            let itemFrame = item.frame.offsetBy(dx: 0.0, dy: topInset)
            
            if itemFrame.maxY >= minVisibleY {
                let isActivated = itemFrame.maxY >= minActivatedY && itemFrame.minY <= maxActivatedY
                
                let itemNode: HorizontalStickerGridItemNode
                if let current = self.itemNodes[item.file.fileId] {
                    itemNode = current
                } else {
                    let item = HorizontalStickerGridItem(
                        account: self.context.account,
                        file: item.file,
                        theme: self.theme,
                        isPreviewed: { [weak self] item in
                            return item.file.fileId == self?.previewedStickerItem?.file.fileId
                        }, sendSticker: { [weak self] file, node, rect in
                            self?.sendSticker?(file, node, rect)
                        }
                    )
                    itemNode = item.node(layout: GridNodeLayout(
                        size: CGSize(),
                        insets: UIEdgeInsets(),
                        scrollIndicatorInsets: nil,
                        preloadSize: 0.0,
                        type: .fixed(itemSize: CGSize(), fillWidth: nil, lineSpacing: 0.0, itemSpacing: nil)
                    ), synchronousLoad: synchronous) as! HorizontalStickerGridItemNode
                    itemNode.subnodeTransform = CATransform3DMakeRotation(-CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
                    self.itemNodes[item.file.fileId] = itemNode
                    self.scrollNode.addSubnode(itemNode)
                }
                itemNode.frame = itemFrame
                itemNode.updateAbsoluteRect(itemFrame.offsetBy(dx: 0.0, dy: absoluteOffset), within: containerSize)
                itemNode.isVisibleInGrid = isActivated
                validIds.insert(item.file.fileId)
            }
            if itemFrame.minY > maxVisibleY {
                break
            }
        }
        
        var removeIds: [MediaId] = []
        for (id, itemNode) in self.itemNodes {
            if !validIds.contains(id) {
                removeIds.append(id)
                itemNode.removeFromSupernode()
            }
        }
        for id in removeIds {
            self.itemNodes.removeValue(forKey: id)
        }
    }
}

private let backgroundDiameter: CGFloat = 20.0
private let shadowBlur: CGFloat = 6.0

final class InlineReactionSearchPanel: ChatInputContextPanelNode {
    private let containerNode: ASDisplayNode
    private let backgroundNode: ASDisplayNode
    private let backgroundTopLeftNode: ASImageNode
    private let backgroundTopLeftContainerNode: ASDisplayNode
    private let backgroundTopRightNode: ASImageNode
    private let backgroundTopRightContainerNode: ASDisplayNode
    private let backgroundContainerNode: ASDisplayNode
    private let stickersNode: InlineReactionSearchStickersNode
    
    var controllerInteraction: ChatControllerInteraction?
    
    private var validLayout: (CGSize, CGFloat)?
    private var query: String?
    
    private var choosingStickerDisposable: Disposable?
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize, peerId: PeerId?) {
        self.containerNode = ASDisplayNode()
        
        self.backgroundNode = ASDisplayNode()
        
        let shadowImage = generateImage(CGSize(width: backgroundDiameter + shadowBlur * 2.0, height: floor(backgroundDiameter / 2.0 + shadowBlur)), rotatedContext: { size, context in
            let diameter = backgroundDiameter
            let shadow = UIColor(white: 0.0, alpha: 0.5)
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            context.saveGState()
            context.setFillColor(shadow.cgColor)
            context.setShadow(offset: CGSize(), blur: shadowBlur, color: shadow.cgColor)
            
            context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
            
            context.setFillColor(UIColor.clear.cgColor)
            context.setBlendMode(.copy)
            
            context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
            
            context.restoreGState()
            
            context.setFillColor(theme.list.plainBackgroundColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
        })?.stretchableImage(withLeftCapWidth: Int(backgroundDiameter / 2.0 + shadowBlur), topCapHeight: 0)
        
        self.backgroundTopLeftNode = ASImageNode()
        self.backgroundTopLeftNode.image = shadowImage
        self.backgroundTopLeftContainerNode = ASDisplayNode()
        self.backgroundTopLeftContainerNode.clipsToBounds = true
        self.backgroundTopLeftContainerNode.addSubnode(self.backgroundTopLeftNode)
        
        self.backgroundTopRightNode = ASImageNode()
        self.backgroundTopRightNode.image = shadowImage
        self.backgroundTopRightContainerNode = ASDisplayNode()
        self.backgroundTopRightContainerNode.clipsToBounds = true
        self.backgroundTopRightContainerNode.addSubnode(self.backgroundTopRightNode)
        
        self.backgroundContainerNode = ASDisplayNode()
        
        self.stickersNode = InlineReactionSearchStickersNode(context: context, theme: theme, strings: strings, peerId: peerId)
        
        super.init(context: context, theme: theme, strings: strings, fontSize: fontSize)
        
        self.placement = .overPanels
        self.isOpaque = false
        self.clipsToBounds = true
        
        self.backgroundContainerNode.addSubnode(self.backgroundNode)
        self.backgroundContainerNode.addSubnode(self.backgroundTopLeftContainerNode)
        self.backgroundContainerNode.addSubnode(self.backgroundTopRightContainerNode)
        self.containerNode.addSubnode(self.backgroundContainerNode)
        self.containerNode.addSubnode(self.stickersNode)
        
        self.addSubnode(self.containerNode)
        
        self.backgroundNode.backgroundColor = theme.list.plainBackgroundColor
        
        self.stickersNode.getControllerInteraction = { [weak self] in
            return self?.controllerInteraction
        }
        
        self.stickersNode.updateBackgroundOffset = { [weak self] offset, animateIn, transition in
            guard let strongSelf = self, let (_, _) = strongSelf.validLayout else {
                return
            }
            if animateIn {
                transition.animateView {
                    strongSelf.backgroundContainerNode.frame = CGRect(origin: CGPoint(x: 0.0, y: offset), size: CGSize())
                }
            } else {
                transition.updateFrame(node: strongSelf.backgroundContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: offset), size: CGSize()), beginWithCurrentState: false)
            }
            let cornersTransitionDistance: CGFloat = 20.0
            let cornersTransition: CGFloat = max(0.0, min(1.0, (cornersTransitionDistance - offset) / cornersTransitionDistance))
            transition.updateSublayerTransformScaleAndOffset(node: strongSelf.backgroundTopLeftContainerNode, scale: 1.0, offset: CGPoint(x: -cornersTransition * backgroundDiameter, y: 0.0), beginWithCurrentState: true)
            transition.updateSublayerTransformScaleAndOffset(node: strongSelf.backgroundTopRightContainerNode, scale: 1.0, offset: CGPoint(x: cornersTransition * backgroundDiameter, y: 0.0), beginWithCurrentState: true)
        }
        
        self.stickersNode.sendSticker = { [weak self] file, node, rect in
            guard let strongSelf = self else {
                return
            }
            let _ = strongSelf.controllerInteraction?.sendSticker(file, false, false, strongSelf.query, true, node, rect)
        }
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
        self.view.disablesInteractiveKeyboardGestureRecognizer = true
        
        self.choosingStickerDisposable = (self.stickersNode.choosingSticker
        |> deliverOnMainQueue).start(next: { [weak self] value in
            if let strongSelf = self {
                strongSelf.controllerInteraction?.updateChoosingSticker(value)
            }
        })
    }
    
    deinit {
        self.choosingStickerDisposable?.dispose()
    }
    
    func updateResults(results: [TelegramMediaFile], query: String?) {
        self.query = query
        self.stickersNode.updateItems(items: results)
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
        self.validLayout = (size, leftInset)
        
        transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(), size: size))
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: backgroundDiameter / 2.0), size: size))
        
        transition.updateFrame(node: self.backgroundTopLeftContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -shadowBlur), size: CGSize(width: size.width / 2.0, height: backgroundDiameter / 2.0 + shadowBlur)))
        transition.updateFrame(node: self.backgroundTopRightContainerNode, frame: CGRect(origin: CGPoint(x: size.width / 2.0, y: -shadowBlur), size: CGSize(width: size.width - size.width / 2.0, height: backgroundDiameter / 2.0 + shadowBlur)))
        
        transition.updateFrame(node: self.backgroundTopLeftNode, frame: CGRect(origin: CGPoint(x: -shadowBlur, y: 0.0), size: CGSize(width: size.width + shadowBlur * 2.0, height: backgroundDiameter / 2.0 + shadowBlur)))
        transition.updateFrame(node: self.backgroundTopRightNode, frame: CGRect(origin: CGPoint(x: -shadowBlur - size.width / 2.0, y: 0.0), size: CGSize(width: size.width + shadowBlur * 2.0, height: backgroundDiameter / 2.0 + shadowBlur)))
        
        transition.updateFrame(node: self.stickersNode, frame: CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: CGSize(width: size.width - leftInset * 2.0, height: size.height)))
        self.stickersNode.update(size: CGSize(width: size.width - leftInset * 2.0, height: size.height), transition: transition)
    }
    
    override func animateOut(completion: @escaping () -> Void) {
        self.containerNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: self.containerNode.bounds.height - self.backgroundContainerNode.frame.minY), duration: 0.2, removeOnCompletion: false, additive: true, completion: { _ in
            completion()
        })
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.backgroundNode.frame.contains(self.view.convert(point, to: self.backgroundNode.view)) {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}
