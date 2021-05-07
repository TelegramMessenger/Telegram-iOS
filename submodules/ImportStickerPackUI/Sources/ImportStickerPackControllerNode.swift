import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import ActivityIndicator
import TextFormat
import AccountContext
import ContextUI

private struct StickerPackPreviewGridEntry: Comparable, Identifiable {
    let index: Int
    let stickerItem: ImportStickerPack.Sticker
    
    var stableId: Int {
        return self.index
//        return self.stickerItem.file.fileId
    }
    
    static func <(lhs: StickerPackPreviewGridEntry, rhs: StickerPackPreviewGridEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(account: Account, interaction: StickerPackPreviewInteraction, theme: PresentationTheme) -> StickerPackPreviewGridItem {
        return StickerPackPreviewGridItem(account: account, stickerItem: self.stickerItem, interaction: interaction, theme: theme, isEmpty: false)
    }
}

private struct StickerPackPreviewGridTransaction {
    let deletions: [Int]
    let insertions: [GridNodeInsertItem]
    let updates: [GridNodeUpdateItem]
    
    init(previousList: [StickerPackPreviewGridEntry], list: [StickerPackPreviewGridEntry], account: Account, interaction: StickerPackPreviewInteraction, theme: PresentationTheme) {
         let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: previousList, rightList: list)
        
        self.deletions = deleteIndices
        self.insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(account: account, interaction: interaction, theme: theme), previousIndex: $0.2) }
        self.updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, interaction: interaction, theme: theme)) }
    }
}

final class ImportStickerPackControllerNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var stickerPack: ImportStickerPack?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private let dimNode: ASDisplayNode
    
    private let wrappingScrollNode: ASScrollNode
    private let cancelButtonNode: ASButtonNode
    
    private let contentContainerNode: ASDisplayNode
    private let contentBackgroundNode: ASImageNode
    private let contentGridNode: GridNode
    private let installActionButtonNode: ASButtonNode
    private let installActionSeparatorNode: ASDisplayNode
    private let contentTitleNode: ImmediateTextNode
    private let contentSeparatorNode: ASDisplayNode
    
    private var interaction: StickerPackPreviewInteraction!
    
    var presentInGlobalOverlay: ((ViewController, Any?) -> Void)?
    var dismiss: (() -> Void)?
    var cancel: (() -> Void)?
    
    let ready = Promise<Bool>()
    private var didSetReady = false
    
    private var currentItems: [StickerPackPreviewGridEntry] = []
    
    private var hapticFeedback: HapticFeedback?
    
    init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.wrappingScrollNode = ASScrollNode()
        self.wrappingScrollNode.view.alwaysBounceVertical = true
        self.wrappingScrollNode.view.delaysContentTouches = false
        self.wrappingScrollNode.view.canCancelContentTouches = true
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        
        self.cancelButtonNode = ASButtonNode()
        self.cancelButtonNode.displaysAsynchronously = false
        
        self.contentContainerNode = ASDisplayNode()
        self.contentContainerNode.isOpaque = false
        self.contentContainerNode.clipsToBounds = true
        
        self.contentBackgroundNode = ASImageNode()
        self.contentBackgroundNode.displaysAsynchronously = false
        self.contentBackgroundNode.displayWithoutProcessing = true
        
        self.contentGridNode = GridNode()
        
        self.installActionButtonNode = HighlightTrackingButtonNode()
        self.installActionButtonNode.displaysAsynchronously = false
        self.installActionButtonNode.titleNode.displaysAsynchronously = false
        
        self.contentTitleNode = ImmediateTextNode()
        self.contentTitleNode.displaysAsynchronously = false
        self.contentTitleNode.maximumNumberOfLines = 1
        
        self.contentSeparatorNode = ASDisplayNode()
        self.contentSeparatorNode.isLayerBacked = true
        
        self.installActionSeparatorNode = ASDisplayNode()
        self.installActionSeparatorNode.isLayerBacked = true
        self.installActionSeparatorNode.displaysAsynchronously = false
        
        super.init()
        
        self.interaction = StickerPackPreviewInteraction(playAnimatedStickers: false)
        
        self.backgroundColor = nil
        self.isOpaque = false
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        self.addSubnode(self.dimNode)
        
        self.wrappingScrollNode.view.delegate = self
        self.addSubnode(self.wrappingScrollNode)
        
        self.wrappingScrollNode.addSubnode(self.cancelButtonNode)
        self.cancelButtonNode.addTarget(self, action: #selector(self.cancelButtonPressed), forControlEvents: .touchUpInside)
        
        self.installActionButtonNode.addTarget(self, action: #selector(self.installActionButtonPressed), forControlEvents: .touchUpInside)
        
        self.wrappingScrollNode.addSubnode(self.contentBackgroundNode)
        
        self.wrappingScrollNode.addSubnode(self.contentContainerNode)
        self.contentContainerNode.addSubnode(self.contentGridNode)
        self.contentContainerNode.addSubnode(self.installActionSeparatorNode)
        self.contentContainerNode.addSubnode(self.installActionButtonNode)
        self.wrappingScrollNode.addSubnode(self.contentTitleNode)
        self.wrappingScrollNode.addSubnode(self.contentSeparatorNode)
        
        self.contentGridNode.presentationLayoutUpdated = { [weak self] presentationLayout, transition in
            self?.gridPresentationLayoutUpdated(presentationLayout, transition: transition)
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.wrappingScrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        self.contentGridNode.view.addGestureRecognizer(PeekControllerGestureRecognizer(contentAtPoint: { [weak self] point -> Signal<(ASDisplayNode, PeekControllerContent)?, NoError>? in
            if let strongSelf = self {
                if let itemNode = strongSelf.contentGridNode.itemNodeAtPoint(point) as? StickerPackPreviewGridItemNode, let item = itemNode.stickerPackItem {
//                    var menuItems: [PeekControllerMenuItem] = []
//                    if let stickerPack = strongSelf.stickerPack, case let .result(info, _, _) = stickerPack, info.id.namespace == Namespaces.ItemCollection.CloudStickerPacks {
//                        if strongSelf.sendSticker != nil {
//                            menuItems.append(PeekControllerMenuItem(title: strongSelf.presentationData.strings.ShareMenu_Send, color: .accent, font: .bold, action: { node, rect in
//                                if let strongSelf = self {
//                                    return strongSelf.sendSticker?(.standalone(media: item.file), node, rect) ?? false
//                                } else {
//                                    return false
//                                }
//                            }))
//                        }
//                        menuItems.append(PeekControllerMenuItem(title: isStarred ? strongSelf.presentationData.strings.Stickers_RemoveFromFavorites : strongSelf.presentationData.strings.Stickers_AddToFavorites, color: isStarred ? .destructive : .accent, action: { _, _ in
//                                if let strongSelf = self {
//                                    if isStarred {
//                                        let _ = removeSavedSticker(postbox: strongSelf.context.account.postbox, mediaId: item.file.fileId).start()
//                                    } else {
//                                        let _ = addSavedSticker(postbox: strongSelf.context.account.postbox, network: strongSelf.context.account.network, file: item.file).start()
//                                    }
//                                }
//                            return true
//                        }))
//                        menuItems.append(PeekControllerMenuItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { _, _ in return true }))
//                    }
//                    return (itemNode, StickerPreviewPeekContent(account: strongSelf.context.account, item: .pack(item), menu: menuItems))
                    return .single((itemNode, StickerPreviewPeekContent(account: strongSelf.context.account, item: item, menu: [])))
                }
            }
            return nil
        }, present: { [weak self] content, sourceNode in
            if let strongSelf = self {
                let controller = PeekController(presentationData: strongSelf.presentationData, content: content, sourceNode: {
                    return sourceNode
                })
                controller.visibilityUpdated = { [weak self] visible in
                    if let strongSelf = self {
                        strongSelf.contentGridNode.forceHidden = visible
                    }
                }
                strongSelf.presentInGlobalOverlay?(controller, nil)
                return controller
            }
            return nil
        }, updateContent: { [weak self] content in
            if let strongSelf = self {
                var item: ImportStickerPack.Sticker?
                if let content = content as? StickerPreviewPeekContent {
                    item = content.item
                }
                strongSelf.updatePreviewingItem(item: item, animated: true)
            }
        }, activateBySingleTap: true))
        
        self.updatePresentationData(self.presentationData)
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        let theme = presentationData.theme
        let solidBackground = generateImage(CGSize(width: 1.0, height: 1.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(theme.actionSheet.opaqueItemBackgroundColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height)))
        })?.stretchableImage(withLeftCapWidth: 16, topCapHeight: 1)
        
        let highlightedSolidBackground = generateImage(CGSize(width: 1.0, height: 1.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(theme.actionSheet.opaqueItemHighlightedBackgroundColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height)))
        })?.stretchableImage(withLeftCapWidth: 16, topCapHeight: 1)
        
        let halfRoundedBackground = generateImage(CGSize(width: 32.0, height: 32.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(theme.actionSheet.opaqueItemBackgroundColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height)))
            context.fill(CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height / 2.0)))
        })?.stretchableImage(withLeftCapWidth: 16, topCapHeight: 1)
        
        let highlightedHalfRoundedBackground = generateImage(CGSize(width: 32.0, height: 32.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(theme.actionSheet.opaqueItemHighlightedBackgroundColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height)))
            context.fill(CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height / 2.0)))
        })?.stretchableImage(withLeftCapWidth: 16, topCapHeight: 1)
        
        let roundedBackground = generateStretchableFilledCircleImage(radius: 16.0, color: presentationData.theme.actionSheet.opaqueItemBackgroundColor)
        let highlightedRoundedBackground = generateStretchableFilledCircleImage(radius: 16.0, color: presentationData.theme.actionSheet.opaqueItemHighlightedBackgroundColor)
        
        self.contentBackgroundNode.image = roundedBackground
        
        self.cancelButtonNode.setBackgroundImage(roundedBackground, for: .normal)
        self.cancelButtonNode.setBackgroundImage(highlightedRoundedBackground, for: .highlighted)

        self.installActionButtonNode.setBackgroundImage(halfRoundedBackground, for: .normal)
        self.installActionButtonNode.setBackgroundImage(highlightedHalfRoundedBackground, for: .highlighted)

        self.contentSeparatorNode.backgroundColor = presentationData.theme.actionSheet.opaqueItemSeparatorColor
        self.installActionSeparatorNode.backgroundColor = presentationData.theme.actionSheet.opaqueItemSeparatorColor

        self.cancelButtonNode.setTitle(presentationData.strings.Common_Cancel, with: Font.medium(20.0), with: presentationData.theme.actionSheet.standardActionTextColor, for: .normal)
        
        self.contentTitleNode.linkHighlightColor = presentationData.theme.actionSheet.controlAccentColor.withAlphaComponent(0.5)
        
        if let (layout, navigationBarHeight) = self.containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        transition.updateFrame(node: self.wrappingScrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        var insets = layout.insets(options: [.statusBar])
        insets.top = max(10.0, insets.top)
        let cleanInsets = layout.insets(options: [.statusBar])
        
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        var bottomInset: CGFloat = 10.0 + cleanInsets.bottom
        if insets.bottom > 0 {
            bottomInset -= 12.0
        }
        
        let buttonHeight: CGFloat = 57.0
        let sectionSpacing: CGFloat = 8.0
        let titleAreaHeight: CGFloat = 51.0
        
        let width = horizontalContainerFillingSizeForLayout(layout: layout, sideInset: 10.0 + layout.safeInsets.left)
        
        let sideInset = floor((layout.size.width - width) / 2.0)
        
        transition.updateFrame(node: self.cancelButtonNode, frame: CGRect(origin: CGPoint(x: sideInset, y: layout.size.height - bottomInset - buttonHeight), size: CGSize(width: width, height: buttonHeight)))
        
        let maximumContentHeight = layout.size.height - insets.top - bottomInset - buttonHeight - sectionSpacing
        
        let contentContainerFrame = CGRect(origin: CGPoint(x: sideInset, y: insets.top), size: CGSize(width: width, height: maximumContentHeight))
        let contentFrame = contentContainerFrame.insetBy(dx: 12.0, dy: 0.0)
        
        var transaction: StickerPackPreviewGridTransaction?
        
        var itemCount = 0
        var animateIn = false
        
        if let stickerPack = self.stickerPack {
            var updatedItems: [StickerPackPreviewGridEntry] = []
            for item in stickerPack.stickers {
                updatedItems.append(StickerPackPreviewGridEntry(index: updatedItems.count, stickerItem: item))
            }
            
            if self.currentItems.isEmpty && !updatedItems.isEmpty {
                let entities = generateTextEntities(stickerPack.name, enabledTypes: [.mention])
                let font = Font.medium(20.0)
                self.contentTitleNode.attributedText = stringWithAppliedEntities(stickerPack.name, entities: entities, baseColor: self.presentationData.theme.actionSheet.primaryTextColor, linkColor: self.presentationData.theme.actionSheet.controlAccentColor, baseFont: font, linkFont: font, boldFont: font, italicFont: font, boldItalicFont: font, fixedFont: font, blockQuoteFont: font)
                animateIn = true
                itemCount = updatedItems.count
            }
            transaction = StickerPackPreviewGridTransaction(previousList: self.currentItems, list: updatedItems, account: self.context.account, interaction: self.interaction, theme: self.presentationData.theme)
            self.currentItems = updatedItems
        }
        
        let titleSize = self.contentTitleNode.updateLayout(CGSize(width: contentContainerFrame.size.width - 24.0, height: CGFloat.greatestFiniteMagnitude))
        let titleFrame = CGRect(origin: CGPoint(x: contentContainerFrame.minX + floor((contentContainerFrame.size.width - titleSize.width) / 2.0), y: self.contentBackgroundNode.frame.minY + 15.0), size: titleSize)
        let deltaTitlePosition = CGPoint(x: titleFrame.midX - self.contentTitleNode.frame.midX, y: titleFrame.midY - self.contentTitleNode.frame.midY)
        self.contentTitleNode.frame = titleFrame
        transition.animatePosition(node: self.contentTitleNode, from: CGPoint(x: titleFrame.midX + deltaTitlePosition.x, y: titleFrame.midY + deltaTitlePosition.y))
        
        transition.updateFrame(node: self.contentTitleNode, frame: titleFrame)
        transition.updateFrame(node: self.contentSeparatorNode, frame: CGRect(origin: CGPoint(x: contentContainerFrame.minX, y: self.contentBackgroundNode.frame.minY + titleAreaHeight), size: CGSize(width: contentContainerFrame.size.width, height: UIScreenPixel)))
        
        let itemsPerRow = 4
        let itemWidth = floor(contentFrame.size.width / CGFloat(itemsPerRow))
        let rowCount = itemCount / itemsPerRow + (itemCount % itemsPerRow != 0 ? 1 : 0)
        
        let minimallyRevealedRowCount: CGFloat = 3.5
        let initiallyRevealedRowCount = min(minimallyRevealedRowCount, CGFloat(rowCount))
        
        let bottomGridInset = buttonHeight
        let topInset = max(0.0, contentFrame.size.height - initiallyRevealedRowCount * itemWidth - titleAreaHeight - bottomGridInset)

        transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame)

        let installButtonOffset = buttonHeight
        transition.updateFrame(node: self.installActionButtonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentContainerFrame.size.height - installButtonOffset), size: CGSize(width: contentContainerFrame.size.width, height: buttonHeight)))
        transition.updateFrame(node: self.installActionSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentContainerFrame.size.height - installButtonOffset - UIScreenPixel), size: CGSize(width: contentContainerFrame.size.width, height: UIScreenPixel)))

        let gridSize = CGSize(width: contentFrame.size.width, height: max(32.0, contentFrame.size.height - titleAreaHeight))
        
        self.contentGridNode.transaction(GridNodeTransaction(deleteItems: transaction?.deletions ?? [], insertItems: transaction?.insertions ?? [], updateItems: transaction?.updates ?? [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: gridSize, insets: UIEdgeInsets(top: topInset, left: 0.0, bottom: bottomGridInset, right: 0.0), preloadSize: 80.0, type: .fixed(itemSize: CGSize(width: itemWidth, height: itemWidth), fillWidth: nil, lineSpacing: 0.0, itemSpacing: nil)), transition: transition), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        transition.updateFrame(node: self.contentGridNode, frame: CGRect(origin: CGPoint(x: floor((contentContainerFrame.size.width - contentFrame.size.width) / 2.0), y: titleAreaHeight), size: gridSize))
        
        if animateIn {
            self.contentGridNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.installActionButtonNode.titleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.installActionSeparatorNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        }
    }
    
    private func gridPresentationLayoutUpdated(_ presentationLayout: GridNodeCurrentPresentationLayout, transition: ContainedViewLayoutTransition) {
        if let (layout, _) = self.containerLayout {
            var insets = layout.insets(options: [.statusBar])
            insets.top = max(10.0, insets.top)
            let cleanInsets = layout.insets(options: [.statusBar])
            
            var bottomInset: CGFloat = 10.0 + cleanInsets.bottom
            if insets.bottom > 0 {
                bottomInset -= 12.0
            }
            
            let buttonHeight: CGFloat = 57.0
            let sectionSpacing: CGFloat = 8.0
            let titleAreaHeight: CGFloat = 51.0
            
            let width = horizontalContainerFillingSizeForLayout(layout: layout, sideInset: 10.0 + layout.safeInsets.left)
            
            let sideInset = floor((layout.size.width - width) / 2.0)
            
            let maximumContentHeight = layout.size.height - insets.top - bottomInset - buttonHeight - sectionSpacing
            let contentFrame = CGRect(origin: CGPoint(x: sideInset, y: insets.top), size: CGSize(width: width, height: maximumContentHeight))
             
            var backgroundFrame = CGRect(origin: CGPoint(x: contentFrame.minX, y: contentFrame.minY - presentationLayout.contentOffset.y), size: contentFrame.size)
            if backgroundFrame.minY < contentFrame.minY {
                backgroundFrame.origin.y = contentFrame.minY
            }
            if backgroundFrame.maxY > contentFrame.maxY {
                backgroundFrame.size.height += contentFrame.maxY - backgroundFrame.maxY
            }
            if backgroundFrame.size.height < buttonHeight + 32.0 {
                backgroundFrame.origin.y -= buttonHeight + 32.0 - backgroundFrame.size.height
                backgroundFrame.size.height = buttonHeight + 32.0
            }
            var compactFrame = false
            let backgroundDeltaY = backgroundFrame.minY - self.contentBackgroundNode.frame.minY
            transition.updateFrame(node: self.contentBackgroundNode, frame: backgroundFrame)
            transition.animatePositionAdditive(node: self.contentGridNode, offset: CGPoint(x: 0.0, y: -backgroundDeltaY))
            
            let titleSize = self.contentTitleNode.bounds.size
            let titleFrame = CGRect(origin: CGPoint(x: contentFrame.minX + floor((contentFrame.size.width - titleSize.width) / 2.0), y: backgroundFrame.minY + 15.0), size: titleSize)
            transition.updateFrame(node: self.contentTitleNode, frame: titleFrame)
        
            transition.updateFrame(node: self.contentSeparatorNode, frame: CGRect(origin: CGPoint(x: contentFrame.minX, y: backgroundFrame.minY + titleAreaHeight), size: CGSize(width: contentFrame.size.width, height: UIScreenPixel)))
            
            if !compactFrame && CGFloat(0.0).isLessThanOrEqualTo(presentationLayout.contentOffset.y) {
                self.contentSeparatorNode.alpha = 1.0
            } else {
                self.contentSeparatorNode.alpha = 0.0
            }
        }
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancelButtonPressed()
        }
    }
    
    @objc func cancelButtonPressed() {
        self.cancel?()
    }
    
    @objc func installActionButtonPressed() {

    }
    
    func animateIn() {
        self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
        
        let offset = self.bounds.size.height - self.contentBackgroundNode.frame.minY
        
        let dimPosition = self.dimNode.layer.position
        self.dimNode.layer.animatePosition(from: CGPoint(x: dimPosition.x, y: dimPosition.y - offset), to: dimPosition, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        self.layer.animateBoundsOriginYAdditive(from: -offset, to: 0.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        var dimCompleted = false
        var offsetCompleted = false
        
        let internalCompletion: () -> Void = { [weak self] in
            if let strongSelf = self, dimCompleted && offsetCompleted {
                strongSelf.dismiss?()
            }
            completion?()
        }
        
        self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
            dimCompleted = true
            internalCompletion()
        })
        
        let offset = self.bounds.size.height - self.contentBackgroundNode.frame.minY
        let dimPosition = self.dimNode.layer.position
        self.dimNode.layer.animatePosition(from: dimPosition, to: CGPoint(x: dimPosition.x, y: dimPosition.y - offset), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        self.layer.animateBoundsOriginYAdditive(from: 0.0, to: -offset, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            offsetCompleted = true
            internalCompletion()
        })
    }
    
    func updateStickerPack(_ stickerPack: ImportStickerPack) {
        self.stickerPack = stickerPack
      
//        self.interaction.playAnimatedStickers = stickerSettings.loopAnimatedStickers
        
        if let _ = self.containerLayout {
            self.dequeueUpdateStickerPack()
        }
        self.installActionButtonNode.setTitle("Create Sticker Set", with: Font.regular(20.0), with: self.presentationData.theme.actionSheet.controlAccentColor, for: .normal)
//        switch stickerPack {
//            case .none, .fetching:
//                self.installActionSeparatorNode.alpha = 0.0
//                self.shareActionSeparatorNode.alpha = 0.0
//                self.shareActionButtonNode.alpha = 0.0
//                self.installActionButtonNode.alpha = 0.0
//                self.installActionButtonNode.setTitle("", with: Font.medium(20.0), with: self.presentationData.theme.actionSheet.standardActionTextColor, for: .normal)
//            case let .result(info, _, installed):
//                if self.stickerPackInitiallyInstalled == nil {
//                    self.stickerPackInitiallyInstalled = installed
//                }
//                self.installActionSeparatorNode.alpha = 1.0
//                self.shareActionSeparatorNode.alpha = 1.0
//                self.shareActionButtonNode.alpha = 1.0
//                self.installActionButtonNode.alpha = 1.0
//                if installed {
//                    let text: String
//                    if info.id.namespace == Namespaces.ItemCollection.CloudStickerPacks {
//                        text = self.presentationData.strings.StickerPack_RemoveStickerCount(info.count)
//                    } else {
//                        text = self.presentationData.strings.StickerPack_RemoveMaskCount(info.count)
//                    }
//                    self.installActionButtonNode.setTitle(text, with: Font.regular(20.0), with: self.presentationData.theme.actionSheet.destructiveActionTextColor, for: .normal)
//                } else {
//                    let text: String
//                    if info.id.namespace == Namespaces.ItemCollection.CloudStickerPacks {
//                        text = self.presentationData.strings.StickerPack_AddStickerCount(info.count)
//                    } else {
//                        text = self.presentationData.strings.StickerPack_AddMaskCount(info.count)
//                    }
//                    self.installActionButtonNode.setTitle(text, with: Font.regular(20.0), with: self.presentationData.theme.actionSheet.controlAccentColor, for: .normal)
//                }
//        }
    }
    
    func dequeueUpdateStickerPack() {
        if let (layout, navigationBarHeight) = self.containerLayout, let _ = self.stickerPack {
            let transition: ContainedViewLayoutTransition
            if self.didSetReady {
                transition = .animated(duration: 0.4, curve: .spring)
            } else {
                transition = .immediate
            }
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
            
            if !self.didSetReady {
                self.didSetReady = true
                self.ready.set(.single(true))
            }
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.installActionButtonNode.hitTest(self.installActionButtonNode.convert(point, from: self), with: event) {
            return result
        }
        if self.bounds.contains(point) {
            if !self.contentBackgroundNode.bounds.contains(self.convert(point, to: self.contentBackgroundNode)) && !self.cancelButtonNode.bounds.contains(self.convert(point, to: self.cancelButtonNode)) {
                return self.dimNode.view
            }
        }
        return super.hitTest(point, with: event)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        let contentOffset = scrollView.contentOffset
        let additionalTopHeight = max(0.0, -contentOffset.y)
        
        if additionalTopHeight >= 30.0 {
            self.cancelButtonPressed()
        }
    }
    
    private func updatePreviewingItem(item: ImportStickerPack.Sticker?, animated: Bool) {
        if self.interaction.previewedItem !== item {
            self.interaction.previewedItem = item
            
            self.contentGridNode.forEachItemNode { itemNode in
                if let itemNode = itemNode as? StickerPackPreviewGridItemNode {
                    itemNode.updatePreviewing(animated: animated)
                }
            }
        }
    }
}
