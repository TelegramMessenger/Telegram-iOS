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
import RadialStatusNode
import UndoUI

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
    
    private let radialStatus: RadialStatusNode
    private let radialCheck: RadialStatusNode
    private let radialStatusBackground: ASImageNode
    private let radialStatusText: ImmediateTextNode
    private let progressText: ImmediateTextNode
    
    private var interaction: StickerPackPreviewInteraction!
    
    var present: ((ViewController, Any?) -> Void)?
    var presentInGlobalOverlay: ((ViewController, Any?) -> Void)?
    var dismiss: (() -> Void)?
    var cancel: (() -> Void)?
    
    let ready = Promise<Bool>()
    private var didSetReady = false
    
    private var pendingItems: [StickerPackPreviewGridEntry] = []
    private var currentItems: [StickerPackPreviewGridEntry] = []
    
    private var hapticFeedback: HapticFeedback?
    
    private let disposable = MetaDisposable()
    
    private var progress: (CGFloat, Int32, Int32)?
        
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
        
        self.radialStatus = RadialStatusNode(backgroundNodeColor: .clear)
        self.radialCheck = RadialStatusNode(backgroundNodeColor: .clear)
        self.radialStatusBackground = ASImageNode()
        self.radialStatusBackground.isUserInteractionEnabled = false
        self.radialStatusBackground.displaysAsynchronously = false
        self.radialStatusBackground.image = generateCircleImage(diameter: 180.0, lineWidth: 6.0, color: self.presentationData.theme.list.itemAccentColor.withMultipliedAlpha(0.2))
        
        self.radialStatusText = ImmediateTextNode()
        self.radialStatusText.isUserInteractionEnabled = false
        self.radialStatusText.displaysAsynchronously = false
        self.radialStatusText.maximumNumberOfLines = 1
        self.radialStatusText.isAccessibilityElement = false
        
        self.progressText = ImmediateTextNode()
        self.progressText.isUserInteractionEnabled = false
        self.progressText.displaysAsynchronously = false
        self.progressText.maximumNumberOfLines = 1
        self.progressText.isAccessibilityElement = false
        
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
        
        self.wrappingScrollNode.addSubnode(self.radialStatusBackground)
        self.wrappingScrollNode.addSubnode(self.radialStatus)
        self.wrappingScrollNode.addSubnode(self.radialCheck)
        self.wrappingScrollNode.addSubnode(self.radialStatusText)
        self.wrappingScrollNode.addSubnode(self.progressText)
        
        self.contentGridNode.presentationLayoutUpdated = { [weak self] presentationLayout, transition in
            self?.gridPresentationLayoutUpdated(presentationLayout, transition: transition)
        }
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.wrappingScrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        self.contentGridNode.view.addGestureRecognizer(PeekControllerGestureRecognizer(contentAtPoint: { [weak self] point -> Signal<(ASDisplayNode, PeekControllerContent)?, NoError>? in
            if let strongSelf = self {
                if let itemNode = strongSelf.contentGridNode.itemNodeAtPoint(point) as? StickerPackPreviewGridItemNode, let item = itemNode.stickerPackItem {
                    var menuItems: [ContextMenuItem] = []
                    if strongSelf.currentItems.count > 1 {
                        menuItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.ImportStickerPack_RemoveFromImport, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { [weak self] c, f in
                            f(.dismissWithoutContent)
                            
                            if let strongSelf = self {
                                var updatedItems = strongSelf.currentItems
                                updatedItems.removeAll(where: { $0.stickerItem.uuid == item.uuid })
                                strongSelf.pendingItems = updatedItems
                                
                                if let (layout, navigationHeight) = strongSelf.containerLayout {
                                    strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .animated(duration: 0.3, curve: .easeInOut))
                                }
                            }
                        })))
                    }
                    return .single((itemNode, StickerPreviewPeekContent(account: strongSelf.context.account, item: item, menu: menuItems)))
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
    
    private var hadProgress = false
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
        
        var forceTitleUpdate = false
        if self.progress != nil && !self.hadProgress {
            self.hadProgress = true
            forceTitleUpdate = true
        }
        
        if let _ = self.stickerPack, self.currentItems.isEmpty || self.currentItems.count != self.pendingItems.count || forceTitleUpdate {
            let previousItems = self.currentItems
            self.currentItems = self.pendingItems
            
            let titleFont = Font.medium(20.0)
            let title: String
            if let _ = self.progress {
                title = self.presentationData.strings.ImportStickerPack_ImportingStickers
            } else {
                title = self.presentationData.strings.ImportStickerPack_StickerCount(Int32(self.currentItems.count))
            }
            self.contentTitleNode.attributedText = stringWithAppliedEntities(title, entities: [], baseColor: self.presentationData.theme.actionSheet.primaryTextColor, linkColor: self.presentationData.theme.actionSheet.controlAccentColor, baseFont: titleFont, linkFont: titleFont, boldFont: titleFont, italicFont: titleFont, boldItalicFont: titleFont, fixedFont: titleFont, blockQuoteFont: titleFont)
            animateIn = true
            itemCount = self.currentItems.count

            if !forceTitleUpdate {
                transaction = StickerPackPreviewGridTransaction(previousList: previousItems, list: self.currentItems, account: self.context.account, interaction: self.interaction, theme: self.presentationData.theme)
            }
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
        
        var bottomGridInset = buttonHeight
        if let _ = self.progress {
            bottomGridInset += 210.0
        }
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
                
        transition.updateAlpha(node: self.contentGridNode, alpha: self.progress == nil ? 1.0 : 0.0)
        
        if let (progress, count, total) = self.progress {
            let effectiveProgress = progress
            
            let availableHeight: CGFloat = 330.0
            var radialStatusSize = CGSize(width: 186.0, height: 186.0)
            var maxIconStatusSpacing: CGFloat = 46.0
            var maxProgressTextSpacing: CGFloat = 33.0
            var progressStatusSpacing: CGFloat = 14.0
            var statusButtonSpacing: CGFloat = 19.0
            
            var maxK: CGFloat = availableHeight / (30.0 + maxProgressTextSpacing + 320.0)
            maxK = max(0.5, min(1.0, maxK))
            
            radialStatusSize.width = floor(radialStatusSize.width * maxK)
            radialStatusSize.height = floor(radialStatusSize.height * maxK)
            maxIconStatusSpacing = floor(maxIconStatusSpacing * maxK)
            maxProgressTextSpacing = floor(maxProgressTextSpacing * maxK)
            progressStatusSpacing = floor(progressStatusSpacing * maxK)
            statusButtonSpacing = floor(statusButtonSpacing * maxK)
            
            var updateRadialBackround = false
            if let width = self.radialStatusBackground.image?.size.width {
                if abs(width - radialStatusSize.width) > 0.01 {
                    updateRadialBackround = true
                }
            } else {
                updateRadialBackround = true
            }
            
            if updateRadialBackround {
                self.radialStatusBackground.image = generateCircleImage(diameter: radialStatusSize.width, lineWidth: 6.0, color: self.presentationData.theme.list.itemAccentColor.withMultipliedAlpha(0.2))
            }
            
            let contentOrigin = self.contentBackgroundNode.frame.minY + 72.0
        
            transition.updateAlpha(node: self.radialStatusText, alpha: 1.0)
            transition.updateAlpha(node: self.progressText, alpha: 1.0)
            transition.updateAlpha(node: self.radialStatus, alpha: 1.0)
            transition.updateAlpha(node: self.installActionButtonNode, alpha: 0.0)
            transition.updateAlpha(node: self.contentSeparatorNode, alpha: 0.0)
            transition.updateAlpha(node: self.installActionSeparatorNode, alpha: 0.0)
            
            self.radialStatusText.attributedText = NSAttributedString(string: "\(Int(effectiveProgress * 100.0))%", font: Font.with(size: floor(36.0 * maxK), design: .round, weight: .semibold), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
            let radialStatusTextSize = self.radialStatusText.updateLayout(CGSize(width: 200.0, height: .greatestFiniteMagnitude))
            
            self.progressText.attributedText = NSAttributedString(string:  self.presentationData.strings.ImportStickerPack_Of(String(count), String(total)).0, font: Font.semibold(17.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
            let progressTextSize = self.progressText.updateLayout(CGSize(width: layout.size.width - 16.0 * 2.0, height: .greatestFiniteMagnitude))
            
            self.radialStatus.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - radialStatusSize.width) / 2.0), y: contentOrigin), size: radialStatusSize)
            let checkSize: CGFloat = 130.0
            self.radialCheck.frame = CGRect(origin: CGPoint(x: self.radialStatus.frame.minX + floor((self.radialStatus.frame.width - checkSize) / 2.0), y: self.radialStatus.frame.minY + floor((self.radialStatus.frame.height - checkSize) / 2.0)), size: CGSize(width: checkSize, height: checkSize))
            self.radialStatusBackground.frame = self.radialStatus.frame
            
            self.radialStatusText.frame = CGRect(origin: CGPoint(x: self.radialStatus.frame.minX + floor((self.radialStatus.frame.width - radialStatusTextSize.width) / 2.0), y: self.radialStatus.frame.minY + floor((self.radialStatus.frame.height - radialStatusTextSize.height) / 2.0)), size: radialStatusTextSize)
            
            self.progressText.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - progressTextSize.width) / 2.0), y: (self.radialStatus.frame.maxY + maxProgressTextSpacing)), size: progressTextSize)
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
        let controller = importStickerPackTitleController(sharedContext: self.context.sharedContext, account: self.context.account, title: self.presentationData.strings.ImportStickerPack_ChooseName, text: self.presentationData.strings.ImportStickerPack_ChooseNameDescription, placeholder: "", doneButtonTitle: nil, value: nil, maxLength: 128, apply: { [weak self] title in
            if let strongSelf = self, let stickerPack = strongSelf.stickerPack, var title = title {
                title = title.trimmingTrailingSpaces()
                let shortName = title.replacingOccurrences(of: " ", with: "") + "_by_laktyushin"
                var stickers: [ImportSticker] = []
                for item in strongSelf.currentItems {
                    var dimensions = PixelDimensions(width: 512, height: 512)
                    if case let .image(data) = item.stickerItem.content, let image = UIImage(data: data) {
                        dimensions = PixelDimensions(image.size)
                    }
                    let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                    strongSelf.context.account.postbox.mediaBox.storeResourceData(resource.id, data: item.stickerItem.data)
                    stickers.append(ImportSticker(resource: resource, emojis: item.stickerItem.emojis, dimensions: dimensions))
                }
                var thumbnailSticker: ImportSticker?
                if let thumbnail = stickerPack.thumbnail {
                    var dimensions = PixelDimensions(width: 512, height: 512)
                    if case let .image(data) = thumbnail.content, let image = UIImage(data: data) {
                        dimensions = PixelDimensions(image.size)
                    }
                    let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                    strongSelf.context.account.postbox.mediaBox.storeResourceData(resource.id, data: thumbnail.data)
                    thumbnailSticker = ImportSticker(resource: resource, emojis: [], dimensions: dimensions)
                }
                
                strongSelf.progress = (0.0, 0, Int32(stickers.count))
                strongSelf.radialStatus.transitionToState(.progress(color: strongSelf.presentationData.theme.list.itemAccentColor, lineWidth: 6.0, value: max(0.01, 0.0), cancelEnabled: false, animateRotation: false), animated: false, synchronous: true, completion: {})
                if let (layout, navigationBarHeight) = strongSelf.containerLayout {
                    strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition:  .animated(duration: 0.2, curve: .easeInOut))
                }
                
                strongSelf.disposable.set((createStickerSet(account: strongSelf.context.account, title: title, shortName: shortName, stickers: stickers, thumbnail: thumbnailSticker, isAnimated: stickerPack.isAnimated)
                |> deliverOnMainQueue).start(next: { [weak self] status in
                    if let strongSelf = self {
                        if case let .complete(info, items) = status {
                            if let (_, _, count) = strongSelf.progress {
                                strongSelf.progress = (1.0, count, count)
                                if let (layout, navigationBarHeight) = strongSelf.containerLayout {
                                    strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                                }
                            }
                            let _ = strongSelf.context.engine.stickers.addStickerPackInteractively(info: info, items: items).start()
                            
                            strongSelf.radialCheck.transitionToState(.progress(color: .clear, lineWidth: 6.0, value: 1.0, cancelEnabled: false, animateRotation: false), animated: false, synchronous: true, completion: {})
                            strongSelf.radialCheck.transitionToState(.check(strongSelf.presentationData.theme.list.itemAccentColor), animated: true, synchronous: true, completion: {})
                            strongSelf.radialStatus.layer.animateScale(from: 1.0, to: 1.05, duration: 0.07, delay: 0.0, timingFunction: CAMediaTimingFunctionName.linear.rawValue, removeOnCompletion: false, additive: false, completion: { [weak self] _ in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.radialStatus.layer.animateScale(from: 1.05, to: 1.0, duration: 0.07, delay: 0.0, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, additive: false)
                            })
                            strongSelf.radialStatusBackground.layer.animateScale(from: 1.0, to: 1.05, duration: 0.07, delay: 0.0, timingFunction: CAMediaTimingFunctionName.linear.rawValue, removeOnCompletion: false, additive: false, completion: { [weak self] _ in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.radialStatusBackground.layer.animateScale(from: 1.05, to: 1.0, duration: 0.07, delay: 0.0, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, additive: false)
                            })
                            strongSelf.radialCheck.layer.animateScale(from: 1.0, to: 1.05, duration: 0.07, delay: 0.0, timingFunction: CAMediaTimingFunctionName.linear.rawValue, removeOnCompletion: false, additive: false, completion: { [weak self] _ in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.radialCheck.layer.animateScale(from: 1.05, to: 1.0, duration: 0.07, delay: 0.0, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, additive: false)
                            })
                            strongSelf.radialStatusText.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                            strongSelf.radialStatusText.layer.animateScale(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                            
                            strongSelf.cancelButtonNode.isUserInteractionEnabled = false
                            
                            Queue.mainQueue().after(1.0) {
                                strongSelf.presentInGlobalOverlay?(UndoOverlayController(presentationData: strongSelf.presentationData, content: .stickersModified(title: strongSelf.presentationData.strings.StickerPackActionInfo_AddedTitle, text: strongSelf.presentationData.strings.StickerPackActionInfo_AddedText(info.title).0, undo: false, info: info, topItem: items.first, context: strongSelf.context), elevatedLayout: false, action: { _ in return true}), nil)
                                strongSelf.dismiss?()
                            }
                        } else if case let .progress(progress, count, total) = status {
                            strongSelf.progress = (CGFloat(progress), count, total)
                            strongSelf.radialStatus.transitionToState(.progress(color: strongSelf.presentationData.theme.list.itemAccentColor, lineWidth: 6.0, value: max(0.01, CGFloat(progress)), cancelEnabled: false, animateRotation: false), animated: true, synchronous: true, completion: {})
                            if let (layout, navigationBarHeight) = strongSelf.containerLayout {
                                strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                            }
                        }
                    }
                }, error: { error in
                    if let strongSelf = self {
                        
                    }
                }))
            }
        })
        self.present?(controller, nil)
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
        var updatedItems: [StickerPackPreviewGridEntry] = []
        for item in stickerPack.stickers {
            updatedItems.append(StickerPackPreviewGridEntry(index: updatedItems.count, stickerItem: item))
        }
        self.pendingItems = updatedItems
      
//        self.interaction.playAnimatedStickers = stickerSettings.loopAnimatedStickers
        
        if let _ = self.containerLayout {
            self.dequeueUpdateStickerPack()
        }
        self.installActionButtonNode.setTitle(self.presentationData.strings.ImportStickerPack_CreateStickerSet, with: Font.regular(20.0), with: self.presentationData.theme.actionSheet.controlAccentColor, for: .normal)
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
