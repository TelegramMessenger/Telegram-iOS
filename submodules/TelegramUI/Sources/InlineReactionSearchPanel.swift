import Foundation
import UIKit
import SwiftSignalKit
import Display
import AsyncDisplayKit
import TelegramCore
import SyncCore
import Postbox
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import StickerPackPreviewUI

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
    
    private let scrollNode: ASScrollNode
    private var items: [TelegramMediaFile] = []
    private var displayItems: [DisplayItem] = []
    private var topInset: CGFloat?
    private var itemNodes: [MediaId: HorizontalStickerGridItemNode] = [:]
    
    private var validLayout: CGSize?
    private var ignoreScrolling: Bool = false
    private var animateInOnLayout: Bool = false
    
    var previewedStickerItem: StickerPackItem?
    
    var updateBackgroundOffset: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    var sendSticker: ((FileMediaReference, ASDisplayNode, CGRect) -> Void)?
    
    var getControllerInteraction: (() -> ChatControllerInteraction?)?
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings) {
        self.context = context
        self.theme = theme
        self.strings = strings
        
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
                    return strongSelf.context.account.postbox.transaction { transaction -> Bool in
                        return getIsStickerSaved(transaction: transaction, fileId: item.file.fileId)
                    }
                    |> deliverOnMainQueue
                    |> map { isStarred -> (ASDisplayNode, PeekControllerContent)? in
                        if let strongSelf = self, let controllerInteraction = strongSelf.getControllerInteraction?() {
                            var menuItems: [PeekControllerMenuItem] = []
                            menuItems = [
                                PeekControllerMenuItem(title: strongSelf.strings.StickerPack_Send, color: .accent, font: .bold, action: { _, _ in
                                    return controllerInteraction.sendSticker(.standalone(media: item.file), true, itemNode, itemNode.bounds)
                                }),
                                PeekControllerMenuItem(title: isStarred ? strongSelf.strings.Stickers_RemoveFromFavorites : strongSelf.strings.Stickers_AddToFavorites, color: isStarred ? .destructive : .accent, action: { _, _ in
                                    if let strongSelf = self {
                                        if isStarred {
                                            let _ = removeSavedSticker(postbox: strongSelf.context.account.postbox, mediaId: item.file.fileId).start()
                                        } else {
                                            let _ = addSavedSticker(postbox: strongSelf.context.account.postbox, network: strongSelf.context.account.network, file: item.file).start()
                                        }
                                    }
                                    return true
                                }),
                                PeekControllerMenuItem(title: strongSelf.strings.StickerPack_ViewPack, color: .accent, action: { _, _ in
                                    if let strongSelf = self, let controllerInteraction = strongSelf.getControllerInteraction?() {
                                        loop: for attribute in item.file.attributes {
                                            switch attribute {
                                            case let .Sticker(_, packReference, _):
                                                if let packReference = packReference {
                                                    let controller = StickerPackScreen(context: strongSelf.context, mainStickerPack: packReference, stickerPacks: [packReference], parentNavigationController: controllerInteraction.navigationController(), sendSticker: { file, sourceNode, sourceRect in
                                                        if let strongSelf = self, let controllerInteraction = strongSelf.getControllerInteraction?() {
                                                            return controllerInteraction.sendSticker(file, true, sourceNode, sourceRect)
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
                                        return true
                                    }
                                    return true
                                }),
                                PeekControllerMenuItem(title: strongSelf.strings.Common_Cancel, color: .accent, font: .bold, action: { _, _ in return true })
                            ]
                            return (itemNode, StickerPreviewPeekContent(account: strongSelf.context.account, item: .pack(item), menu: menuItems))
                        } else {
                            return nil
                        }
                    }
                }
            }
            return nil
            }, present: { [weak self] content, sourceNode in
                if let strongSelf = self {
                    let controller = PeekController(theme: PeekControllerTheme(presentationTheme: strongSelf.theme), content: content, sourceNode: {
                        return sourceNode
                    })
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
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !self.ignoreScrolling {
            self.updateVisibleItems(synchronous: false)
            self.updateBackground(transition: .immediate)
        }
    }
    
    private func updateBackground(transition: ContainedViewLayoutTransition) {
        if let topInset = self.topInset {
            self.updateBackgroundOffset?(max(0.0, -self.scrollNode.view.contentOffset.y + topInset), transition)
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
                self.updateBackground(transition: transition)
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
            self.updateBackgroundOffset?(size.height, .immediate)
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
        
        if self.animateInOnLayout {
            self.animateInOnLayout = false
            backgroundTransition = .animated(duration: 0.3, curve: .spring)
            if let topInset = self.topInset {
                let currentBackgroundOffset = max(0.0, -self.scrollNode.view.contentOffset.y + topInset)
                backgroundTransition.animateOffsetAdditive(node: self.scrollNode, offset: currentBackgroundOffset - size.height)
            }
        } else {
            if let previousBackgroundOffset = previousBackgroundOffset, let topInset = self.topInset {
                let currentBackgroundOffset = max(0.0, -self.scrollNode.view.contentOffset.y + topInset)
                if abs(currentBackgroundOffset - previousBackgroundOffset) > .ulpOfOne {
                    transition.animateOffsetAdditive(node: self.scrollNode, offset: currentBackgroundOffset - previousBackgroundOffset)
                }
            }
        }
        
        self.updateBackground(transition: backgroundTransition)
    }
    
    private func updateItemsLayout(width: CGFloat) {
        self.displayItems.removeAll()
        
        let itemsPerRow = min(8, max(4, Int(width / 80)))
        let sideInset: CGFloat = 4.0
        let itemSpacing: CGFloat = 4.0
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

private let backroundDiameter: CGFloat = 20.0
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
    
    override init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize) {
        self.containerNode = ASDisplayNode()
        
        self.backgroundNode = ASDisplayNode()
        
        let shadowImage = generateImage(CGSize(width: backroundDiameter + shadowBlur * 2.0, height: floor(backroundDiameter / 2.0 + shadowBlur)), rotatedContext: { size, context in
            let diameter = backroundDiameter
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
        })?.stretchableImage(withLeftCapWidth: Int(backroundDiameter / 2.0 + shadowBlur), topCapHeight: 0)
        
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
        
        self.stickersNode = InlineReactionSearchStickersNode(context: context, theme: theme, strings: strings)
        
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
        
        self.stickersNode.updateBackgroundOffset = { [weak self] offset, transition in
            guard let strongSelf = self, let (_, _) = strongSelf.validLayout else {
                return
            }
            transition.updateFrame(node: strongSelf.backgroundContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: offset), size: CGSize()), beginWithCurrentState: false)
            
            let cornersTransitionDistance: CGFloat = 20.0
            let cornersTransition: CGFloat = max(0.0, min(1.0, (cornersTransitionDistance - offset) / cornersTransitionDistance))
            transition.updateSublayerTransformScaleAndOffset(node: strongSelf.backgroundTopLeftContainerNode, scale: 1.0, offset: CGPoint(x: -cornersTransition * backroundDiameter, y: 0.0), beginWithCurrentState: true)
            transition.updateSublayerTransformScaleAndOffset(node: strongSelf.backgroundTopRightContainerNode, scale: 1.0, offset: CGPoint(x: cornersTransition * backroundDiameter, y: 0.0), beginWithCurrentState: true)
        }
        
        self.stickersNode.sendSticker = { [weak self] file, node, rect in
            guard let strongSelf = self else {
                return
            }
            let _ = strongSelf.controllerInteraction?.sendSticker(file, true, node, rect)
        }
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
        self.view.disablesInteractiveKeyboardGestureRecognizer = true
    }
    
    override func didLoad() {
        super.didLoad()
        
    }
    
    func updateResults(results: [TelegramMediaFile]) {
        self.stickersNode.updateItems(items: results)
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
        self.validLayout = (size, leftInset)
        
        transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(), size: size))
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: backroundDiameter / 2.0), size: size))
        
        transition.updateFrame(node: self.backgroundTopLeftContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -shadowBlur), size: CGSize(width: size.width / 2.0, height: backroundDiameter / 2.0 + shadowBlur)))
        transition.updateFrame(node: self.backgroundTopRightContainerNode, frame: CGRect(origin: CGPoint(x: size.width / 2.0, y: -shadowBlur), size: CGSize(width: size.width - size.width / 2.0, height: backroundDiameter / 2.0 + shadowBlur)))
        
        transition.updateFrame(node: self.backgroundTopLeftNode, frame: CGRect(origin: CGPoint(x: -shadowBlur, y: 0.0), size: CGSize(width: size.width + shadowBlur * 2.0, height: backroundDiameter / 2.0 + shadowBlur)))
        transition.updateFrame(node: self.backgroundTopRightNode, frame: CGRect(origin: CGPoint(x: -shadowBlur - size.width / 2.0, y: 0.0), size: CGSize(width: size.width + shadowBlur * 2.0, height: backroundDiameter / 2.0 + shadowBlur)))
        
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
