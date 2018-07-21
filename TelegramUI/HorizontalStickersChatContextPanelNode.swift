import Foundation
import AsyncDisplayKit
import Postbox
import TelegramCore
import Display

final class HorizontalStickersChatContextPanelInteraction {
    var previewedStickerItem: StickerPackItem?
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
    
    func item(account: Account, stickersInteraction: HorizontalStickersChatContextPanelInteraction, interfaceInteraction: ChatPanelInterfaceInteraction) -> GridItem {
        return HorizontalStickerGridItem(account: account, file: self.file, stickersInteraction: stickersInteraction, interfaceInteraction: interfaceInteraction)
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

private func preparedGridEntryTransition(account: Account, from fromEntries: [StickerEntry], to toEntries: [StickerEntry], stickersInteraction: HorizontalStickersChatContextPanelInteraction, interfaceInteraction: ChatPanelInterfaceInteraction) -> StickerEntryTransition {
    let stationaryItems: GridNodeStationaryItems = .none
    let scrollToItem: GridNodeScrollToItem? = nil
    
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices
    let insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(account: account, stickersInteraction: stickersInteraction, interfaceInteraction: interfaceInteraction), previousIndex: $0.2) }
    let updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, stickersInteraction: stickersInteraction, interfaceInteraction: interfaceInteraction)) }
    
    return StickerEntryTransition(deletions: deletions, insertions: insertions, updates: updates, updateFirstIndexInSectionOffset: nil, stationaryItems: stationaryItems, scrollToItem: scrollToItem)
}

final class HorizontalStickersChatContextPanelNode: ChatInputContextPanelNode {
    private var theme: PresentationTheme
    
    private let backgroundLeftNode: ASImageNode
    private let backgroundNode: ASImageNode
    private let backgroundRightNode: ASImageNode
    private let clippingNode: ASDisplayNode
    private let gridNode: GridNode
    
    private var validLayout: (CGSize, CGFloat, CGFloat, ChatPresentationInterfaceState)?
    private var currentEntries: [StickerEntry] = []
    private var queuedTransitions: [StickerEntryTransition] = []
    
    private let stickersInteraction: HorizontalStickersChatContextPanelInteraction
    
    private var stickerPreviewController: StickerPreviewController?
    
    override init(account: Account, theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        
         let backgroundCenterImage = generateImage(CGSize(width: 30.0, height: 82.0), rotatedContext: { size, context in
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
        
        let backgroundLeftImage = generateImage(CGSize(width: 8.0, height: 16.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setStrokeColor(theme.list.itemPlainSeparatorColor.cgColor)
            context.setFillColor(theme.list.plainBackgroundColor.cgColor)
            let lineWidth = UIScreenPixel
            context.setLineWidth(lineWidth)
            
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.height, height: size.height)))
            context.strokeEllipse(in: CGRect(origin: CGPoint(x: lineWidth / 2.0, y: lineWidth / 2.0), size: CGSize(width: size.height - lineWidth, height: size.height - lineWidth)))
        })?.stretchableImage(withLeftCapWidth: 8, topCapHeight: 8)
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.image = backgroundCenterImage
        
        self.backgroundLeftNode = ASImageNode()
        self.backgroundLeftNode.displayWithoutProcessing = true
        self.backgroundLeftNode.displaysAsynchronously = false
        self.backgroundLeftNode.image = backgroundLeftImage
        
        self.backgroundRightNode = ASImageNode()
        self.backgroundRightNode.displayWithoutProcessing = true
        self.backgroundRightNode.displaysAsynchronously = false
        self.backgroundRightNode.image = backgroundLeftImage
        self.backgroundRightNode.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
        
        self.clippingNode = ASDisplayNode()
        self.clippingNode.clipsToBounds = true
        self.gridNode = GridNode()
        self.gridNode.transform = CATransform3DMakeRotation(-CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
        self.gridNode.view.disablesInteractiveTransitionGestureRecognizer = true
        
        self.stickersInteraction = HorizontalStickersChatContextPanelInteraction()
        
        super.init(account: account, theme: theme, strings: strings)
        
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
        
        let longTapRecognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.previewGesture(_:)))
        longTapRecognizer.tapActionAtPoint = { [weak self] location in
            if let strongSelf = self, let _ = strongSelf.gridNode.itemNodeAtPoint(location) as? HorizontalStickerGridItemNode {
                return .waitForHold(timeout: 0.2, acceptTap: false)
            }
            return .fail
        }
        self.gridNode.view.addGestureRecognizer(longTapRecognizer)
    }
    
    func updateResults(_ results: [TelegramMediaFile]) {
        let previousEntries = self.currentEntries
        var entries: [StickerEntry] = []
        for i in 0 ..< results.count {
            entries.append(StickerEntry(index: i, file: results[i]))
        }
        self.currentEntries = entries
        
        if let validLayout = self.validLayout {
            self.updateLayout(size: validLayout.0, leftInset: validLayout.1, rightInset: validLayout.2, transition: .immediate, interfaceState: validLayout.3)
        }
        
        let transition = preparedGridEntryTransition(account: self.account, from: previousEntries, to: entries, stickersInteraction: self.stickersInteraction, interfaceInteraction: self.interfaceInteraction!)
        self.enqueueTransition(transition)
    }
    
    private func enqueueTransition(_ transition: StickerEntryTransition) {
        self.queuedTransitions.append(transition)
        if self.validLayout != nil {
            self.dequeueTransitions()
        }
    }
    
    private func dequeueTransitions() {
        while !self.queuedTransitions.isEmpty {
            let transition = self.queuedTransitions.removeFirst()
            self.gridNode.transaction(GridNodeTransaction(deleteItems: transition.deletions, insertItems: transition.insertions, updateItems: transition.updates, scrollToItem: transition.scrollToItem, updateLayout: nil, itemTransition: .immediate, stationaryItems: transition.stationaryItems, updateFirstIndexInSectionOffset: transition.updateFirstIndexInSectionOffset), completion: { _ in })
        }
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
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
        
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: CGSize(width: gridFrame.size.height, height: gridFrame.size.width), insets: UIEdgeInsets(top: 3.0, left: 0.0, bottom: 3.0, right: 0.0), preloadSize: 100.0, type: .fixed(itemSize: CGSize(width: 66.0, height: 66.0), lineSpacing: 0.0)), transition: .immediate), itemTransition: .immediate, stationaryItems: .all, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        
        let dequeue = self.validLayout == nil
        self.validLayout = (size, leftInset, rightInset, interfaceState)
        
        if dequeue {
            self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.dequeueTransitions()
        }
    }
    
    override func animateOut(completion: @escaping () -> Void) {
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
    
    @objc func previewGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
            case .began:
                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation, case .hold = gesture {
                    if let itemNode = self.gridNode.itemNodeAtPoint(location) as? HorizontalStickerGridItemNode {
                        self.updatePreviewingItem(item: itemNode.stickerItem, animated: true)
                    }
                }
            case .ended, .cancelled:
                self.updatePreviewingItem(item: nil, animated: true)
            case .changed:
                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation, case .hold = gesture, let itemNode = self.gridNode.itemNodeAtPoint(location) as? HorizontalStickerGridItemNode {
                    self.updatePreviewingItem(item: itemNode.stickerItem, animated: true)
                }
            default:
                break
        }
    }
    
    private func updatePreviewingItem(item: StickerPackItem?, animated: Bool) {
        if self.stickersInteraction.previewedStickerItem != item {
            self.stickersInteraction.previewedStickerItem = item
            
            self.gridNode.forEachItemNode { itemNode in
                if let itemNode = itemNode as? HorizontalStickerGridItemNode {
                    itemNode.updatePreviewing(animated: animated)
                }
            }
            
            if let item = item {
                if let stickerPreviewController = self.stickerPreviewController {
                    stickerPreviewController.updateItem(item)
                } else {
                    let stickerPreviewController = StickerPreviewController(account: self.account, item: item)
                    self.stickerPreviewController = stickerPreviewController
                    self.interfaceInteraction?.presentController(stickerPreviewController, StickerPreviewControllerPresentationArguments(transitionNode: { [weak self] item in
                        if let strongSelf = self {
                            var result: ASDisplayNode?
                            strongSelf.gridNode.forEachItemNode { itemNode in
                                if let itemNode = itemNode as? HorizontalStickerGridItemNode, itemNode.stickerItem == item {
                                    result = itemNode.transitionNode()
                                }
                            }
                            return result
                        }
                        return nil
                    }))
                }
            } else if let stickerPreviewController = self.stickerPreviewController {
                stickerPreviewController.dismiss()
                self.stickerPreviewController = nil
            }
        }
    }
}
