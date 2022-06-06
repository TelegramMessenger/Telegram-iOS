import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import TelegramCore
import Display
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import StickerPackPreviewUI
import ContextUI
import ChatPresentationInterfaceState
import PremiumUI
import UndoUI

final class HorizontalStickersChatContextPanelInteraction {
    var previewedStickerItem: StickerPackItem?
}

private func backgroundCenterImage(_ theme: PresentationTheme) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 82.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(theme.list.itemPlainSeparatorColor.cgColor)
        context.setFillColor(theme.list.plainBackgroundColor.cgColor)
        let lineWidth = UIScreenPixel
        context.setLineWidth(lineWidth)
        
        context.translateBy(x: 460.5, y: 364)
        let _ = try? drawSvgPath(context, path: "M-490.476836,-365 L-394.167708,-365 L-394.167708,-291.918214 C-394.167708,-291.918214 -383.538396,-291.918214 -397.691655,-291.918214 C-402.778486,-291.918214 -424.555168,-291.918214 -434.037301,-291.918214 C-440.297129,-291.918214 -440.780682,-283.5 -445.999879,-283.5 C-450.393041,-283.5 -452.491241,-291.918214 -456.502636,-291.918214 C-465.083339,-291.918214 -476.209155,-291.918214 -483.779021,-291.918214 C-503.033963,-291.918214 -490.476836,-291.918214 -490.476836,-291.918214 L-490.476836,-365 ")
        context.fillPath()
        context.translateBy(x: 0.0, y: lineWidth / 2.0)
        let _ = try? drawSvgPath(context, path: "M-490.476836,-365 L-394.167708,-365 L-394.167708,-291.918214 C-394.167708,-291.918214 -383.538396,-291.918214 -397.691655,-291.918214 C-402.778486,-291.918214 -424.555168,-291.918214 -434.037301,-291.918214 C-440.297129,-291.918214 -440.780682,-283.5 -445.999879,-283.5 C-450.393041,-283.5 -452.491241,-291.918214 -456.502636,-291.918214 C-465.083339,-291.918214 -476.209155,-291.918214 -483.779021,-291.918214 C-503.033963,-291.918214 -490.476836,-291.918214 -490.476836,-291.918214 L-490.476836,-365 ")
        context.strokePath()
        context.translateBy(x: -460.5, y: -lineWidth / 2.0 - 364.0)
        context.move(to: CGPoint(x: 0.0, y: lineWidth / 2.0))
        context.addLine(to: CGPoint(x: size.width, y: lineWidth / 2.0))
        context.strokePath()
    })
}
private func backgroundLeftImage(_ theme: PresentationTheme) -> UIImage? {
    return generateImage(CGSize(width: 8.0, height: 16.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(theme.list.itemPlainSeparatorColor.cgColor)
        context.setFillColor(theme.list.plainBackgroundColor.cgColor)
        let lineWidth = UIScreenPixel
        context.setLineWidth(lineWidth)
        
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.height, height: size.height)))
        context.strokeEllipse(in: CGRect(origin: CGPoint(x: lineWidth / 2.0, y: lineWidth / 2.0), size: CGSize(width: size.height - lineWidth, height: size.height - lineWidth)))
    })?.stretchableImage(withLeftCapWidth: 8, topCapHeight: 8)
}

private struct StickerEntry: Identifiable, Comparable {
    let index: Int
    let file: TelegramMediaFile
    
    var stableId: MediaId {
        return self.file.fileId
    }
    
    static func ==(lhs: StickerEntry, rhs: StickerEntry) -> Bool {
        return lhs.index == rhs.index && lhs.stableId == rhs.stableId
    }
    
    static func <(lhs: StickerEntry, rhs: StickerEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(account: Account, stickersInteraction: HorizontalStickersChatContextPanelInteraction, interfaceInteraction: ChatPanelInterfaceInteraction, theme: PresentationTheme) -> GridItem {
        return HorizontalStickerGridItem(account: account, file: self.file, theme: theme, isPreviewed: { item in
            return false//stickersInteraction.previewedStickerItem == item
        }, sendSticker: { file, node, rect in
            let _ = interfaceInteraction.sendSticker(file, true, node, rect)
        })
    }
}

private struct StickerEntryTransition {
    let deletions: [Int]
    let insertions: [GridNodeInsertItem]
    let updates: [GridNodeUpdateItem]
    let updateFirstIndexInSectionOffset: Int?
    let stationaryItems: GridNodeStationaryItems
    let scrollToItem: GridNodeScrollToItem?
}

private func preparedGridEntryTransition(account: Account, from fromEntries: [StickerEntry], to toEntries: [StickerEntry], stickersInteraction: HorizontalStickersChatContextPanelInteraction, interfaceInteraction: ChatPanelInterfaceInteraction, theme: PresentationTheme) -> StickerEntryTransition {
    let stationaryItems: GridNodeStationaryItems = .none
    let scrollToItem: GridNodeScrollToItem? = nil
    
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices
    let insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(account: account, stickersInteraction: stickersInteraction, interfaceInteraction: interfaceInteraction, theme: theme), previousIndex: $0.2) }
    let updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, stickersInteraction: stickersInteraction, interfaceInteraction: interfaceInteraction, theme: theme)) }
    
    return StickerEntryTransition(deletions: deletions, insertions: insertions, updates: updates, updateFirstIndexInSectionOffset: nil, stationaryItems: stationaryItems, scrollToItem: scrollToItem)
}

final class HorizontalStickersChatContextPanelNode: ChatInputContextPanelNode {
    private var strings: PresentationStrings
    
    private let backgroundLeftNode: ASImageNode
    private let backgroundNode: ASImageNode
    private let backgroundRightNode: ASImageNode
    private let clippingNode: ASDisplayNode
    private let gridNode: GridNode
    
    private var validLayout: (CGSize, CGFloat, CGFloat, CGFloat, ChatPresentationInterfaceState)?
    private var currentEntries: [StickerEntry] = []
    private var enqueuedTransitions: [StickerEntryTransition] = []
    
    public var controllerInteraction: ChatControllerInteraction?
    private let stickersInteraction: HorizontalStickersChatContextPanelInteraction
    
    private var stickerPreviewController: StickerPreviewController?
    
    override init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize) {
        self.strings = strings
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.image = backgroundCenterImage(theme)
        
        self.backgroundLeftNode = ASImageNode()
        self.backgroundLeftNode.displayWithoutProcessing = true
        self.backgroundLeftNode.displaysAsynchronously = false
        self.backgroundLeftNode.image = backgroundLeftImage(theme)
        
        self.backgroundRightNode = ASImageNode()
        self.backgroundRightNode.displayWithoutProcessing = true
        self.backgroundRightNode.displaysAsynchronously = false
        self.backgroundRightNode.image = backgroundLeftImage(theme)
        self.backgroundRightNode.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
        
        self.clippingNode = ASDisplayNode()
        self.clippingNode.clipsToBounds = true
        self.gridNode = GridNode()
        self.gridNode.transform = CATransform3DMakeRotation(-CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
        self.gridNode.view.disablesInteractiveTransitionGestureRecognizer = true
        
        self.stickersInteraction = HorizontalStickersChatContextPanelInteraction()
        
        super.init(context: context, theme: theme, strings: strings, fontSize: fontSize)
        
        self.placement = .overTextInput
        self.isOpaque = false
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.backgroundLeftNode)
        self.addSubnode(self.backgroundRightNode)
        
        self.addSubnode(self.clippingNode)
        self.clippingNode.addSubnode(self.gridNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.gridNode.view.disablesInteractiveTransitionGestureRecognizer = true
        self.gridNode.view.disablesInteractiveKeyboardGestureRecognizer = true
        
        self.view.addGestureRecognizer(PeekControllerGestureRecognizer(contentAtPoint: { [weak self] point in
            if let strongSelf = self {
                let convertedPoint = strongSelf.gridNode.view.convert(point, from: strongSelf.view)
                guard strongSelf.gridNode.bounds.contains(convertedPoint) else {
                    return nil
                }
                
                if let itemNode = strongSelf.gridNode.itemNodeAtPoint(strongSelf.view.convert(point, to: strongSelf.gridNode.view)) as? HorizontalStickerGridItemNode, let item = itemNode.stickerItem {
                    return strongSelf.context.engine.stickers.isStickerSaved(id: item.file.fileId)
                    |> deliverOnMainQueue
                    |> map { isStarred -> (ASDisplayNode, PeekControllerContent)? in
                        if let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction {
                            var menuItems: [ContextMenuItem] = []
                            menuItems = [
                                .action(ContextMenuActionItem(text: strongSelf.strings.StickerPack_Send, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Resend"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                                    f(.default)
                                
                                    let _ = controllerInteraction.sendSticker(.standalone(media: item.file), false, false, nil, true, itemNode, itemNode.bounds)
                                })),
                                .action(ContextMenuActionItem(text: isStarred ? strongSelf.strings.Stickers_RemoveFromFavorites : strongSelf.strings.Stickers_AddToFavorites, icon: { theme in generateTintedImage(image: isStarred ? UIImage(bundleImageName: "Chat/Context Menu/Unfave") : UIImage(bundleImageName: "Chat/Context Menu/Fave"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                                    f(.default)
                                    
                                    if let strongSelf = self {
                                        let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                        let _ = (strongSelf.context.engine.stickers.toggleStickerSaved(file: item.file, saved: !isStarred)
                                        |> deliverOnMainQueue).start(next: { result in
                                            switch result {
                                                case .generic:
                                                    strongSelf.interfaceInteraction?.presentGlobalOverlayController(UndoOverlayController(presentationData: presentationData, content: .sticker(context: strongSelf.context, file: item.file, title: nil, text: !isStarred ? strongSelf.strings.Conversation_StickerAddedToFavorites : strongSelf.strings.Conversation_StickerRemovedFromFavorites, undoText: nil), elevatedLayout: false, action: { _ in return false }), nil)
                                                case let .limitExceeded(limit, premiumLimit):
                                                    let premiumConfiguration = PremiumConfiguration.with(appConfiguration: strongSelf.context.currentAppConfiguration.with { $0 })
                                                    let text: String
                                                    if limit == premiumLimit || premiumConfiguration.isPremiumDisabled {
                                                        text = strongSelf.strings.Premium_MaxFavedStickersFinalText
                                                    } else {
                                                        text = strongSelf.strings.Premium_MaxFavedStickersText("\(premiumLimit)").string
                                                    }
                                                    strongSelf.interfaceInteraction?.presentGlobalOverlayController(UndoOverlayController(presentationData: presentationData, content: .sticker(context: strongSelf.context, file: item.file, title: strongSelf.strings.Premium_MaxFavedStickersTitle("\(limit)").string, text: text, undoText: nil), elevatedLayout: false, action: { [weak self] action in
                                                        if let strongSelf = self {
                                                            if case .info = action {
                                                                let controller = PremiumIntroScreen(context: strongSelf.context, source: .savedStickers)
                                                                strongSelf.controllerInteraction?.navigationController()?.pushViewController(controller)
                                                                return true
                                                            }
                                                        }
                                                        return false
                                                    }), nil)
                                            }
                                        })
                                    }
                                })),
                                .action(ContextMenuActionItem(text: strongSelf.strings.StickerPack_ViewPack, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Sticker"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                                    f(.default)
                                
                                    if let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction {
                                        loop: for attribute in item.file.attributes {
                                            switch attribute {
                                            case let .Sticker(_, packReference, _):
                                                if let packReference = packReference {
                                                    let controller = StickerPackScreen(context: strongSelf.context, mainStickerPack: packReference, stickerPacks: [packReference], parentNavigationController: controllerInteraction.navigationController(), sendSticker: { file, sourceNode, sourceRect in
                                                        if let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction {
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
                            ]
                            return (itemNode, StickerPreviewPeekContent(account: strongSelf.context.account, theme: strongSelf.theme, strings: strongSelf.strings, item: .pack(item), menu: menuItems, openPremiumIntro: { [weak self] in
                                guard let strongSelf = self else {
                                    return
                                }
                                let controller = PremiumIntroScreen(context: strongSelf.context, source: .stickers)
                                strongSelf.controllerInteraction?.navigationController()?.pushViewController(controller)
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
                    strongSelf.interfaceInteraction?.presentGlobalOverlayController(controller, nil)
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
    
    func updateResults(_ results: [TelegramMediaFile]) {
        let previousEntries = self.currentEntries
        var entries: [StickerEntry] = []
        for i in 0 ..< results.count {
            entries.append(StickerEntry(index: i, file: results[i]))
        }
        self.currentEntries = entries
        
        if let validLayout = self.validLayout {
            self.updateLayout(size: validLayout.0, leftInset: validLayout.1, rightInset: validLayout.2, bottomInset: validLayout.3, transition: .immediate, interfaceState: validLayout.4)
        }
        
        let transition = preparedGridEntryTransition(account: self.context.account, from: previousEntries, to: entries, stickersInteraction: self.stickersInteraction, interfaceInteraction: self.interfaceInteraction!, theme: self.theme)
        self.enqueueTransition(transition)
    }
    
    private func enqueueTransition(_ transition: StickerEntryTransition) {
        self.enqueuedTransitions.append(transition)
        if self.validLayout != nil {
            self.dequeueTransition()
        }
    }
    
    private func dequeueTransition() {
        while !self.enqueuedTransitions.isEmpty {
            let transition = self.enqueuedTransitions.removeFirst()
            self.gridNode.transaction(GridNodeTransaction(deleteItems: transition.deletions, insertItems: transition.insertions, updateItems: transition.updates, scrollToItem: transition.scrollToItem, updateLayout: nil, itemTransition: .immediate, stationaryItems: transition.stationaryItems, updateFirstIndexInSectionOffset: transition.updateFirstIndexInSectionOffset), completion: { _ in })
        }
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
        let sideInsets: CGFloat = 10.0 + leftInset
        let contentWidth = min(size.width - sideInsets - sideInsets, max(24.0, CGFloat(self.currentEntries.count) * 66.0 + 6.0))
        
        var contentLeftInset: CGFloat = 40.0
        var leftOffset: CGFloat = 0.0
        if sideInsets + floor(contentWidth / 2.0) < sideInsets + contentLeftInset + 15.0 {
            let updatedLeftInset = sideInsets + floor(contentWidth / 2.0) - 15.0 - sideInsets
            leftOffset = contentLeftInset - updatedLeftInset
            contentLeftInset = updatedLeftInset
        }
        
        let backgroundFrame = CGRect(origin: CGPoint(x: sideInsets + leftOffset, y: size.height - 82.0 + 4.0), size: CGSize(width: contentWidth, height: 82.0))
        let backgroundLeftFrame = CGRect(origin: backgroundFrame.origin, size: CGSize(width: contentLeftInset, height: backgroundFrame.size.height - 10.0 + UIScreenPixel))
        let backgroundCenterFrame = CGRect(origin: CGPoint(x: backgroundLeftFrame.maxX, y: backgroundFrame.minY), size: CGSize(width: 30.0, height: 82.0))
        let backgroundRightFrame = CGRect(origin: CGPoint(x: backgroundCenterFrame.maxX, y: backgroundFrame.minY), size: CGSize(width: max(0.0, backgroundFrame.minX + backgroundFrame.size.width - backgroundCenterFrame.maxX), height: backgroundFrame.size.height - 10.0 + UIScreenPixel))
        transition.updateFrame(node: self.backgroundLeftNode, frame: backgroundLeftFrame)
        transition.updateFrame(node: self.backgroundNode, frame: backgroundCenterFrame)
        transition.updateFrame(node: self.backgroundRightNode, frame: backgroundRightFrame)
        
        let gridFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX, y: backgroundFrame.minY + 4.0), size: CGSize(width: backgroundFrame.size.width, height: 66.0))
        transition.updateFrame(node: self.clippingNode, frame: gridFrame)
        self.gridNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: gridFrame.size.height, height: gridFrame.size.width))
        
        let gridBounds = self.gridNode.bounds
        self.gridNode.bounds = CGRect(x: gridBounds.minX, y: gridBounds.minY, width: gridFrame.size.height, height: gridFrame.size.width)
        self.gridNode.position = CGPoint(x: gridFrame.size.width / 2.0, y: gridFrame.size.height / 2.0)
        
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: CGSize(width: gridFrame.size.height, height: gridFrame.size.width), insets: UIEdgeInsets(top: 3.0, left: 0.0, bottom: 3.0, right: 0.0), preloadSize: 100.0, type: .fixed(itemSize: CGSize(width: 66.0, height: 66.0), fillWidth: nil, lineSpacing: 0.0, itemSpacing: nil)), transition: .immediate), itemTransition: .immediate, stationaryItems: .all, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        
        let dequeue = self.validLayout == nil
        self.validLayout = (size, leftInset, rightInset, bottomInset, interfaceState)
        
        if dequeue {
            self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.dequeueTransition()
        }
        
        if self.theme !== interfaceState.theme {
            self.theme = interfaceState.theme
            self.backgroundNode.image = backgroundCenterImage(theme)
            self.backgroundLeftNode.image = backgroundLeftImage(theme)
            self.backgroundRightNode.image = backgroundLeftImage(theme)
        }
    }
    
    override func animateOut(completion: @escaping () -> Void) {
        self.layer.allowsGroupOpacity = true
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.clippingNode.frame.contains(point) {
            return nil
        }
        return super.hitTest(point, with: event)
    }
    
    private func updatePreviewingItem(item: StickerPackItem?, animated: Bool) {
        if self.stickersInteraction.previewedStickerItem != item {
            self.stickersInteraction.previewedStickerItem = item
            
            self.gridNode.forEachItemNode { itemNode in
                if let itemNode = itemNode as? HorizontalStickerGridItemNode {
                    itemNode.updatePreviewing(animated: animated)
                }
            }
        }
    }
}
