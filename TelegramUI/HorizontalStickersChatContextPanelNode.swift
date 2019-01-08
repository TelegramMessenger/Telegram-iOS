import Foundation
import AsyncDisplayKit
import Postbox
import TelegramCore
import Display
import SwiftSignalKit

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
    private var strings: PresentationStrings
    
    private let gridNode: GridNode
    
    private var validLayout: (CGSize, CGFloat, CGFloat, ChatPresentationInterfaceState)?
    private var currentEntries: [StickerEntry] = []
    private var queuedTransitions: [StickerEntryTransition] = []
    
    public var controllerInteraction: ChatControllerInteraction?
    private let stickersInteraction: HorizontalStickersChatContextPanelInteraction
    
    private var stickerPreviewController: StickerPreviewController?
    
    override init(account: Account, theme: PresentationTheme, strings: PresentationStrings) {
        self.strings = strings
        
        self.gridNode = GridNode()
        self.gridNode.view.disablesInteractiveTransitionGestureRecognizer = true
        
        self.stickersInteraction = HorizontalStickersChatContextPanelInteraction()
        
        super.init(account: account, theme: theme, strings: strings)
        
        self.isOpaque = false
        self.clipsToBounds = true
        
        self.addSubnode(self.gridNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(PeekControllerGestureRecognizer(contentAtPoint: { [weak self] point in
            if let strongSelf = self {
                let convertedPoint = strongSelf.gridNode.view.convert(point, from: strongSelf.view)
                guard strongSelf.gridNode.bounds.contains(convertedPoint) else {
                    return nil
                }
                
                if let itemNode = strongSelf.gridNode.itemNodeAtPoint(strongSelf.view.convert(point, to: strongSelf.gridNode.view)) as? HorizontalStickerGridItemNode, let item = itemNode.stickerItem {
                        return strongSelf.account.postbox.transaction { transaction -> Bool in
                            return getIsStickerSaved(transaction: transaction, fileId: item.file.fileId)
                            }
                            |> deliverOnMainQueue
                            |> map { isStarred -> (ASDisplayNode, PeekControllerContent)? in
                                if let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction {
                                    var menuItems: [PeekControllerMenuItem] = []
                                    menuItems = [
                                        PeekControllerMenuItem(title: strongSelf.strings.StickerPack_Send, color: .accent, font: .bold, action: {
                                            controllerInteraction.sendSticker(.standalone(media: item.file), true)
                                        }),
                                        PeekControllerMenuItem(title: isStarred ? strongSelf.strings.Stickers_RemoveFromFavorites : strongSelf.strings.Stickers_AddToFavorites, color: isStarred ? .destructive : .accent, action: {
                                            if let strongSelf = self {
                                                if isStarred {
                                                    let _ = removeSavedSticker(postbox: strongSelf.account.postbox, mediaId: item.file.fileId).start()
                                                } else {
                                                    let _ = addSavedSticker(postbox: strongSelf.account.postbox, network: strongSelf.account.network, file: item.file).start()
                                                }
                                            }
                                        }),
                                        PeekControllerMenuItem(title: strongSelf.strings.StickerPack_ViewPack, color: .accent, action: {
                                            if let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction {
                                                loop: for attribute in item.file.attributes {
                                                    switch attribute {
                                                    case let .Sticker(_, packReference, _):
                                                        if let packReference = packReference {
                                                            let controller = StickerPackPreviewController(account: strongSelf.account, stickerPack: packReference, parentNavigationController: controllerInteraction.navigationController())
                                                            controller.sendSticker = { file in
                                                                if let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction {
                                                                    controllerInteraction.sendSticker(file, true)
                                                                }
                                                            }
                                                            
                                                            controllerInteraction.navigationController()?.view.window?.endEditing(true)
                                                            controllerInteraction.presentController(controller, nil)
                                                        }
                                                        break loop
                                                    default:
                                                        break
                                                    }
                                                }
                                            }
                                        }),
                                        PeekControllerMenuItem(title: strongSelf.strings.Common_Cancel, color: .accent, action: {})
                                    ]
                                    return (itemNode, StickerPreviewPeekContent(account: strongSelf.account, item: .pack(item), menu: menuItems))
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
    
    private func topInsetForLayout(size: CGSize) -> CGFloat {
        let minimumItemHeights: CGFloat = floor(66.0 * 1.5)
        
        return max(size.height - minimumItemHeights, 0.0)
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {

        var insets = UIEdgeInsets()
        insets.top = self.topInsetForLayout(size: size)
        insets.left = leftInset
        insets.right = rightInset
        
        transition.updateFrame(node: self.gridNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
        
        var duration: Double = 0.0
        var curve: UInt = 0
        switch transition {
        case .immediate:
            break
        case let .animated(animationDuration, animationCurve):
            duration = animationDuration
            switch animationCurve {
            case .easeInOut:
                break
            case .spring:
                curve = 7
            }
        }
        
        let listViewCurve: ListViewAnimationCurve
        if curve == 7 {
            listViewCurve = .Spring(duration: duration)
        } else {
            listViewCurve = .Default(duration: duration)
        }
        
        //let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: size, insets: insets, duration: duration, curve: listViewCurve)
    
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: size, insets: insets, preloadSize: 100.0, type: .fixed(itemSize: CGSize(width: 66.0, height: 66.0), fillWidth: nil, lineSpacing: 0.0, itemSpacing: nil)), transition: .immediate), itemTransition: .immediate, stationaryItems: .all, updateFirstIndexInSectionOffset: nil), completion: { _ in })

        let dequeue = self.validLayout == nil
        self.validLayout = (size, leftInset, rightInset, interfaceState)
        
        if dequeue {
            self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.dequeueTransitions()
        }
        
        if self.theme !== interfaceState.theme {
            self.theme = interfaceState.theme
        }
    }
    
    override func animateOut(completion: @escaping () -> Void) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let listViewFrame = self.gridNode.frame
        return self.gridNode.hitTest(CGPoint(x: point.x - listViewFrame.minX, y: point.y - listViewFrame.minY), with: event)
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
