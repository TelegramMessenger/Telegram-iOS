import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ActivityIndicator
import AccountContext
import AlertUI
import PresentationDataUtils
import MergeLists
import ItemListUI
import ItemListStickerPackItem

private struct ArchivedStickersNoticeEntry: Comparable, Identifiable {
    let index: Int
    let info: StickerPackCollectionInfo
    let topItem: StickerPackItem?
    let count: String
    
    var stableId: AnyHashable {
        return AnyHashable(self.info.id)
    }

    static func ==(lhs: ArchivedStickersNoticeEntry, rhs: ArchivedStickersNoticeEntry) -> Bool {
        return lhs.index == rhs.index && lhs.info.id == rhs.info.id && lhs.count == rhs.count
    }
    
    static func <(lhs: ArchivedStickersNoticeEntry, rhs: ArchivedStickersNoticeEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(account: Account, presentationData: PresentationData) -> ListViewItem {
        return ItemListStickerPackItem(presentationData: ItemListPresentationData(presentationData), account: account, packInfo: info, itemCount: self.count, topItem: topItem, unread: false, control: .none, editing: ItemListStickerPackItemEditing(editable: false, editing: false, revealed: false, reorderable: false, selectable: false), enabled: true, playAnimatedStickers: true, sectionId: 0, action: {
        }, setPackIdWithRevealedOptions: { current, previous in
        }, addPack: {
        }, removePack: {
        }, toggleSelected: {
        })
    }
}

private struct ArchivedStickersNoticeTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private func preparedTransition(from fromEntries: [ArchivedStickersNoticeEntry], to toEntries: [ArchivedStickersNoticeEntry], account: Account, presentationData: PresentationData) -> ArchivedStickersNoticeTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, presentationData: presentationData), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, presentationData: presentationData), directionHint: nil) }
    
    return ArchivedStickersNoticeTransition(deletions: deletions, insertions: insertions, updates: updates)
}


private final class ArchivedStickersNoticeAlertContentNode: AlertContentNode {
    private let presentationData: PresentationData
    private let archivedStickerPacks: [(StickerPackCollectionInfo, StickerPackItem?)]
    
    private let textNode: ASTextNode
    private let listView: ListView
    
    private var enqueuedTransitions: [ArchivedStickersNoticeTransition] = []
    
    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [TextAlertContentActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
    
    private let disposable = MetaDisposable()
    
    private var validLayout: CGSize?
    
    override var dismissOnOutsideTap: Bool {
        return self.isUserInteractionEnabled
    }
    
    init(theme: AlertControllerTheme, account: Account, presentationData: PresentationData, archivedStickerPacks: [(StickerPackCollectionInfo, StickerPackItem?)], actions: [TextAlertAction]) {
        self.presentationData = presentationData
        self.archivedStickerPacks = archivedStickerPacks
        
        self.textNode = ASTextNode()
        self.textNode.maximumNumberOfLines = 4
        
        self.listView = ListView()
        self.listView.isOpaque = false
        
        self.actionNodesSeparator = ASDisplayNode()
        self.actionNodesSeparator.isLayerBacked = true
        
        self.actionNodes = actions.map { action -> TextAlertContentActionNode in
            return TextAlertContentActionNode(theme: theme, action: action)
        }
        
        var actionVerticalSeparators: [ASDisplayNode] = []
        if actions.count > 1 {
            for _ in 0 ..< actions.count - 1 {
                let separatorNode = ASDisplayNode()
                separatorNode.isLayerBacked = true
                actionVerticalSeparators.append(separatorNode)
            }
        }
        self.actionVerticalSeparators = actionVerticalSeparators
        
        super.init()
        
        self.addSubnode(self.textNode)
        self.addSubnode(self.listView)
        
        self.addSubnode(self.actionNodesSeparator)
        
        for actionNode in self.actionNodes {
            self.addSubnode(actionNode)
        }
        self.actionNodes.last?.actionEnabled = false
        
        for separatorNode in self.actionVerticalSeparators {
            self.addSubnode(separatorNode)
        }
    
        self.updateTheme(theme)
        
        var index: Int = 0
        var entries: [ArchivedStickersNoticeEntry] = []
        for pack in archivedStickerPacks {
            let countTitle: String
            if pack.0.id.namespace == Namespaces.ItemCollection.CloudEmojiPacks {
                countTitle = presentationData.strings.StickerPack_EmojiCount(pack.0.count)
            } else if pack.0.id.namespace == Namespaces.ItemCollection.CloudMaskPacks {
                countTitle = presentationData.strings.StickerPack_MaskCount(pack.0.count)
            } else {
                countTitle = presentationData.strings.StickerPack_StickerCount(pack.0.count)
            }
            entries.append(ArchivedStickersNoticeEntry(index: index, info: pack.0, topItem: pack.1, count: countTitle))
            index += 1
        }
        
        let transition = preparedTransition(from: [], to: entries, account: account, presentationData: presentationData)
        self.enqueueTransition(transition)
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    private func enqueueTransition(_ transition: ArchivedStickersNoticeTransition) {
        self.enqueuedTransitions.append(transition)
        
        if let _ = self.validLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
       
    private func dequeueTransition() {
        guard let _ = self.validLayout, let transition = self.enqueuedTransitions.first else {
            return
        }
        self.enqueuedTransitions.remove(at: 0)
        
        let options = ListViewDeleteAndInsertOptions()
        
        self.listView.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { _ in
        })
    }
    
    override func updateTheme(_ theme: AlertControllerTheme) {
        self.textNode.attributedText = NSAttributedString(string: self.presentationData.strings.ArchivedPacksAlert_Title, font: Font.regular(13.0), textColor: theme.primaryColor, paragraphAlignment: .center)
        
        self.actionNodesSeparator.backgroundColor = theme.separatorColor
        for actionNode in self.actionNodes {
            actionNode.updateTheme(theme)
        }
        for separatorNode in self.actionVerticalSeparators {
            separatorNode.backgroundColor = theme.separatorColor
        }
        
        if let size = self.validLayout {
            _ = self.updateLayout(size: size, transition: .immediate)
        }
    }
    
    override func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        var size = size
        size.width = min(size.width, 270.0)
        let measureSize = CGSize(width: size.width - 16.0 * 2.0, height: CGFloat.greatestFiniteMagnitude)
        
        let hadValidLayout = self.validLayout != nil
        
        self.validLayout = size
        
        var origin: CGPoint = CGPoint(x: 0.0, y: 20.0)
        
        let textSize = self.textNode.measure(measureSize)
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: origin.y), size: textSize))
        origin.y += textSize.height + 16.0
        
        let actionButtonHeight: CGFloat = 44.0
        var minActionsWidth: CGFloat = 0.0
        let maxActionWidth: CGFloat = floor(size.width / CGFloat(self.actionNodes.count))
        let actionTitleInsets: CGFloat = 8.0
        
        var effectiveActionLayout = TextAlertContentActionLayout.horizontal
        for actionNode in self.actionNodes {
            let actionTitleSize = actionNode.titleNode.updateLayout(CGSize(width: maxActionWidth, height: actionButtonHeight))
            if case .horizontal = effectiveActionLayout, actionTitleSize.height > actionButtonHeight * 0.6667 {
                effectiveActionLayout = .vertical
            }
            switch effectiveActionLayout {
                case .horizontal:
                    minActionsWidth += actionTitleSize.width + actionTitleInsets
                case .vertical:
                    minActionsWidth = max(minActionsWidth, actionTitleSize.width + actionTitleInsets)
            }
        }
        
        let insets = UIEdgeInsets(top: 18.0, left: 18.0, bottom: 18.0, right: 18.0)
        
        var contentWidth = max(textSize.width, minActionsWidth)
        contentWidth = max(contentWidth, 234.0)
        
        var actionsHeight: CGFloat = 0.0
        switch effectiveActionLayout {
            case .horizontal:
                actionsHeight = actionButtonHeight
            case .vertical:
                actionsHeight = actionButtonHeight * CGFloat(self.actionNodes.count)
        }
        
        let resultWidth = contentWidth + insets.left + insets.right
        
        let listHeight: CGFloat = CGFloat(min(3, self.archivedStickerPacks.count)) * 56.0
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: CGSize(width: resultWidth, height: listHeight), insets: UIEdgeInsets(top: -35.0, left: 0.0, bottom: 0.0, right: 0.0), headerInsets: UIEdgeInsets(), scrollIndicatorInsets: UIEdgeInsets(), duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        transition.updateFrame(node: self.listView, frame: CGRect(x: 0.0, y: origin.y, width: resultWidth, height: listHeight))
        
        let resultSize = CGSize(width: resultWidth, height: textSize.height + actionsHeight + listHeight + 10.0 + insets.top + insets.bottom)
        
        transition.updateFrame(node: self.actionNodesSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight - UIScreenPixel), size: CGSize(width: resultSize.width, height: UIScreenPixel)))
        
        var actionOffset: CGFloat = 0.0
        let actionWidth: CGFloat = floor(resultSize.width / CGFloat(self.actionNodes.count))
        var separatorIndex = -1
        var nodeIndex = 0
        for actionNode in self.actionNodes {
            if separatorIndex >= 0 {
                let separatorNode = self.actionVerticalSeparators[separatorIndex]
                switch effectiveActionLayout {
                    case .horizontal:
                        transition.updateFrame(node: separatorNode, frame: CGRect(origin: CGPoint(x: actionOffset - UIScreenPixel, y: resultSize.height - actionsHeight), size: CGSize(width: UIScreenPixel, height: actionsHeight - UIScreenPixel)))
                    case .vertical:
                        transition.updateFrame(node: separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight + actionOffset - UIScreenPixel), size: CGSize(width: resultSize.width, height: UIScreenPixel)))
                }
            }
            separatorIndex += 1
            
            let currentActionWidth: CGFloat
            switch effectiveActionLayout {
            case .horizontal:
                if nodeIndex == self.actionNodes.count - 1 {
                    currentActionWidth = resultSize.width - actionOffset
                } else {
                    currentActionWidth = actionWidth
                }
            case .vertical:
                currentActionWidth = resultSize.width
            }
            
            let actionNodeFrame: CGRect
            switch effectiveActionLayout {
                case .horizontal:
                    actionNodeFrame = CGRect(origin: CGPoint(x: actionOffset, y: resultSize.height - actionsHeight), size: CGSize(width: currentActionWidth, height: actionButtonHeight))
                    actionOffset += currentActionWidth
                case .vertical:
                    actionNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight + actionOffset), size: CGSize(width: currentActionWidth, height: actionButtonHeight))
                    actionOffset += actionButtonHeight
            }
            
            transition.updateFrame(node: actionNode, frame: actionNodeFrame)
            
            nodeIndex += 1
        }
        
        if !hadValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
        
        return resultSize
    }
}

public func archivedStickerPacksNoticeController(context: AccountContext, archivedStickerPacks: [(StickerPackCollectionInfo, StickerPackItem?)]) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    
    var dismissImpl: (() -> Void)?
    
    let disposable = MetaDisposable()
    
    let contentNode = ArchivedStickersNoticeAlertContentNode(theme: AlertControllerTheme(presentationData: presentationData), account: context.account, presentationData: presentationData, archivedStickerPacks: archivedStickerPacks, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
       dismissImpl?()
    })])
    
    let controller = AlertController(theme: AlertControllerTheme(presentationData: presentationData), contentNode: contentNode)
    let presentationDataDisposable = context.sharedContext.presentationData.start(next: { [weak controller] presentationData in
        controller?.theme = AlertControllerTheme(presentationData: presentationData)
    })
    controller.dismissed = { _ in
        presentationDataDisposable.dispose()
        disposable.dispose()
    }
    dismissImpl = { [weak controller] in
        controller?.dismissAnimated()
    }
    return controller
}
