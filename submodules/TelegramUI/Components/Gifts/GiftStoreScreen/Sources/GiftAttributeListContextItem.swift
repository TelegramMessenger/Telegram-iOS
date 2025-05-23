import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import TelegramPresentationData
import ContextUI

final class GiftAttributeListContextItem: ContextMenuCustomItem {
    let context: AccountContext
    let attributes: [StarGift.UniqueGift.Attribute]
    let selectedAttributes: [ResaleGiftsContext.Attribute]
    let attributeCount: [ResaleGiftsContext.Attribute: Int32]
    let searchQuery: Signal<String, NoError>
    let attributeSelected: (ResaleGiftsContext.Attribute, Bool) -> Void
    let selectAll: () -> Void
    
    init(
        context: AccountContext,
        attributes: [StarGift.UniqueGift.Attribute],
        selectedAttributes: [ResaleGiftsContext.Attribute],
        attributeCount: [ResaleGiftsContext.Attribute: Int32],
        searchQuery: Signal<String, NoError>,
        attributeSelected: @escaping (ResaleGiftsContext.Attribute, Bool) -> Void,
        selectAll: @escaping () -> Void
    ) {
        self.context = context
        self.attributes = attributes
        self.selectedAttributes = selectedAttributes
        self.attributeCount = attributeCount
        self.searchQuery = searchQuery
        self.attributeSelected = attributeSelected
        self.selectAll = selectAll
    }
    
    func node(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode {
        return GiftAttributeListContextItemNode(
            presentationData: presentationData,
            item: self,
            getController: getController,
            actionSelected: actionSelected
        )
    }
}

private func actionForAttribute(attribute: StarGift.UniqueGift.Attribute, presentationData: PresentationData, selectedAttributes: Set<ResaleGiftsContext.Attribute>, searchQuery: String, item: GiftAttributeListContextItem, getController: @escaping () -> ContextControllerProtocol?) -> ContextMenuActionItem? {
    let searchComponents = searchQuery.lowercased().components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
    switch attribute {
    case let .model(name, file, _), let .pattern(name, file, _):
        let attributeId: ResaleGiftsContext.Attribute
        if case .model = attribute {
            attributeId = .model(file.fileId.id)
        } else {
            attributeId = .pattern(file.fileId.id)
        }
        let isSelected = selectedAttributes.isEmpty || selectedAttributes.contains(attributeId)
        
        var entities: [MessageTextEntity] = []
        var entityFiles: [Int64: TelegramMediaFile] = [:]
        entities = [
            MessageTextEntity(
                range: 0..<1,
                type: .CustomEmoji(stickerPack: nil, fileId: file.fileId.id)
            )
        ]
        entityFiles[file.fileId.id] = file
                                
        var title = "#   \(name)"
        var count = ""
        
        if let counter = item.attributeCount[attributeId] {
            count = "  \(presentationStringsFormattedNumber(counter, presentationData.dateTimeFormat.groupingSeparator))"
            entities.append(
                MessageTextEntity(
                    range: title.count ..< title.count + count.count,
                    type: .Italic
                )
            )
            title += count
        }
      
        
        let words = title.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        var wordStartIndices: [String.Index] = []
        var currentIndex = title.startIndex
        
        for word in words {
            while currentIndex < title.endIndex {
                let range = title.range(of: word, range: currentIndex..<title.endIndex)
                if let range = range {
                    wordStartIndices.append(range.lowerBound)
                    currentIndex = range.upperBound
                    break
                }
                currentIndex = title.index(after: currentIndex)
            }
        }
        
        for (wordIndex, word) in words.enumerated() {
            let lowercaseWord = word.lowercased()
            for component in searchComponents {
                if lowercaseWord.hasPrefix(component) {
                    let startIndex = wordStartIndices[wordIndex]
                    let prefixRange = startIndex..<title.index(startIndex, offsetBy: min(component.count, word.count))
                    
                    entities.append(
                        MessageTextEntity(
                            range: title.distance(from: title.startIndex, to: prefixRange.lowerBound)..<title.distance(from: title.startIndex, to: prefixRange.upperBound),
                            type: .Bold
                        )
                    )
                }
            }
        }
             
        return ContextMenuActionItem(text: title,  entities: entities, entityFiles: entityFiles, enableEntityAnimations: false, parseMarkdown: true, icon: { theme in
            return isSelected ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
        }, action: { _, f in
            getController()?.dismiss(result: .dismissWithoutContent, completion: nil)
            
            item.attributeSelected(attributeId, false)
        }, longPressAction: { _, f in
            getController()?.dismiss(result: .dismissWithoutContent, completion: nil)
            
            item.attributeSelected(attributeId, true)
        })
    case let .backdrop(name, id, innerColor, outerColor, _, _, _):
        let attributeId: ResaleGiftsContext.Attribute = .backdrop(id)
        let isSelected = selectedAttributes.isEmpty || selectedAttributes.contains(attributeId)
        
        var entities: [MessageTextEntity] = []
        var title = "   \(name)"
        var count = ""
        if let counter = item.attributeCount[attributeId] {
            count = "  \(presentationStringsFormattedNumber(counter, presentationData.dateTimeFormat.groupingSeparator))"
            entities.append(
                MessageTextEntity(range: title.count ..< title.count + count.count, type: .Italic)
            )
            title += count
        }
        
        let words = title.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        var wordStartIndices: [String.Index] = []
        var currentIndex = title.startIndex
        
        for word in words {
            while currentIndex < title.endIndex {
                let range = title.range(of: word, range: currentIndex..<title.endIndex)
                if let range = range {
                    wordStartIndices.append(range.lowerBound)
                    currentIndex = range.upperBound
                    break
                }
                currentIndex = title.index(after: currentIndex)
            }
        }
        
        for (wordIndex, word) in words.enumerated() {
            let lowercaseWord = word.lowercased()
            for component in searchComponents {
                if lowercaseWord.hasPrefix(component) {
                    let startIndex = wordStartIndices[wordIndex]
                    let prefixRange = startIndex..<title.index(startIndex, offsetBy: min(component.count, word.count))
                    
                    entities.append(
                        MessageTextEntity(
                            range: title.distance(from: title.startIndex, to: prefixRange.lowerBound)..<title.distance(from: title.startIndex, to: prefixRange.upperBound),
                            type: .Bold
                        )
                    )
                }
            }
        }
        
        return ContextMenuActionItem(text: title, entities: entities, icon: { theme in
            return isSelected ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
        }, additionalLeftIcon: { _ in
            return generateGradientFilledCircleImage(diameter: 24.0, colors: [UIColor(rgb: UInt32(bitPattern: innerColor)).cgColor, UIColor(rgb: UInt32(bitPattern: outerColor)).cgColor])
        }, action: { _, f in
            getController()?.dismiss(result: .dismissWithoutContent, completion: nil)
            
            item.attributeSelected(attributeId, false)
        }, longPressAction: { _, f in
            getController()?.dismiss(result: .dismissWithoutContent, completion: nil)
            
            item.attributeSelected(attributeId, true)
        })
    default:
        return nil
    }
}

private final class GiftAttributeListContextItemNode: ASDisplayNode, ContextMenuCustomNode, ContextActionNodeProtocol, ASScrollViewDelegate {
    private let item: GiftAttributeListContextItem
    private let presentationData: PresentationData
    private let getController: () -> ContextControllerProtocol?
    private let actionSelected: (ContextMenuActionResult) -> Void
    
    private let scrollNode: ASScrollNode
    private var actionNodes: [AnyHashable: ContextControllerActionsListActionItemNode] = [:]
    private var separatorNodes: [AnyHashable: ASDisplayNode] = [:]
    
    private var searchDisposable: Disposable?
    private var searchQuery = ""
    
    private var itemHeights: [AnyHashable: CGFloat] = [:]
    private var totalContentHeight: CGFloat = 0
    private var itemFrames: [AnyHashable: CGRect] = [:]
    
    init(presentationData: PresentationData, item: GiftAttributeListContextItem, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) {
        self.item = item
        self.presentationData = presentationData.withUpdate(listsFontSize: .regular)
        self.getController = getController
        self.actionSelected = actionSelected
        
        self.scrollNode = ASScrollNode()
                                        
        super.init()
        
        self.addSubnode(self.scrollNode)
        
        self.searchDisposable = (item.searchQuery
        |> deliverOnMainQueue).start(next: { [weak self] searchQuery in
            guard let self, self.searchQuery != searchQuery else {
                return
            }
            self.searchQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            self.invalidateLayout()
            self.getController()?.requestLayout(transition: .immediate)
        })
    }
    
    deinit {
        self.searchDisposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.scrollNode.view.delegate = self.wrappedScrollViewDelegate
        self.scrollNode.view.alwaysBounceVertical = false
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.scrollIndicatorInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 5.0, right: 0.0)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let maxWidth = self.maxWidth {
            self.updateScrolling(maxWidth: maxWidth)
        }
    }
    
    enum ItemType {
        case selectAll
        case attribute(StarGift.UniqueGift.Attribute)
        case noResults
        case separator
    }
    
    private func getVisibleItems(in scrollView: UIScrollView, constrainedWidth: CGFloat) -> [(itemId: AnyHashable, itemType: ItemType, frame: CGRect)] {
        let effectiveAttributes: [StarGift.UniqueGift.Attribute]
        if self.searchQuery.isEmpty {
            effectiveAttributes = self.item.attributes
        } else {
            effectiveAttributes = filteredAttributes(attributes: self.item.attributes, query: self.searchQuery)
        }
        
        var items: [(itemId: AnyHashable, itemType: ItemType, frame: CGRect)] = []
        var yOffset: CGFloat = 0
        
        let defaultHeight: CGFloat = 42.0
        if self.searchQuery.isEmpty {
            let selectAllId = AnyHashable("selectAll")
            let height = self.itemHeights[selectAllId] ?? defaultHeight
            let frame = CGRect(x: 0, y: yOffset, width: constrainedWidth, height: height)
            items.append((selectAllId, .selectAll, frame))
            yOffset += height
            
            let separatorId = AnyHashable("separator_selectAll")
            let separatorFrame = CGRect(x: 0, y: yOffset, width: constrainedWidth, height: UIScreenPixel)
            items.append((separatorId, .separator, separatorFrame))
            yOffset += UIScreenPixel
        }
        
        for (index, attribute) in effectiveAttributes.enumerated() {
            let attributeId = self.getAttributeId(from: attribute)
            let height = self.itemHeights[attributeId] ?? defaultHeight
            let frame = CGRect(x: 0, y: yOffset, width: constrainedWidth, height: height)
            items.append((attributeId, .attribute(attribute), frame))
            yOffset += height
            
            if index < effectiveAttributes.count - 1 {
                let separatorId = AnyHashable("separator_\(attributeId)")
                let separatorFrame = CGRect(x: 0, y: yOffset, width: constrainedWidth, height: UIScreenPixel)
                items.append((separatorId, .separator, separatorFrame))
                yOffset += UIScreenPixel
            }
        }
        
        if !self.searchQuery.isEmpty && effectiveAttributes.isEmpty {
            let noResultsId = AnyHashable("noResults")
            let height = self.itemHeights[noResultsId] ?? defaultHeight
            let frame = CGRect(x: 0, y: yOffset, width: constrainedWidth, height: height)
            items.append((noResultsId, .noResults, frame))
            yOffset += height
        }
        
        self.totalContentHeight = yOffset

        for (itemId, _, frame) in items {
            self.itemFrames[itemId] = frame
        }
        
        let visibleBounds = scrollView.bounds.insetBy(dx: 0.0, dy: -100.0)
        return items.filter { visibleBounds.intersects($0.frame) }
    }
    
    private func getAttributeId(from attribute: StarGift.UniqueGift.Attribute) -> AnyHashable {
        switch attribute {
        case let .model(_, file, _):
            return AnyHashable("model_\(file.fileId.id)")
        case let .pattern(_, file, _):
            return AnyHashable("pattern_\(file.fileId.id)")
        case let .backdrop(_, id, _, _, _, _, _):
            return AnyHashable("backdrop_\(id)")
        default:
            return AnyHashable("unknown")
        }
    }
    
    private var maxWidth: CGFloat?
    private func updateScrolling(maxWidth: CGFloat) {
        let scrollView = self.scrollNode.view
        
        let constrainedWidth = scrollView.bounds.width
        let visibleItems = self.getVisibleItems(in: scrollView, constrainedWidth: constrainedWidth)
        
        var validNodeIds: Set<AnyHashable> = []
        
        for (itemId, itemType, frame) in visibleItems {
            validNodeIds.insert(itemId)
            
            switch itemType {
            case .selectAll:
                if self.actionNodes[itemId] == nil {
                    let selectAllAction = ContextMenuActionItem(text: presentationData.strings.Gift_Store_SelectAll, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Select"), color: theme.contextMenu.primaryColor)
                    }, iconPosition: .left, action: { _, f in
                        self.getController()?.dismiss(result: .dismissWithoutContent, completion: nil)
                        self.item.selectAll()
                    })
                    
                    let actionNode = ContextControllerActionsListActionItemNode(
                        context: self.item.context,
                        getController: self.getController,
                        requestDismiss: self.actionSelected,
                        requestUpdateAction: { _, _ in },
                        item: selectAllAction
                    )
                    self.actionNodes[itemId] = actionNode
                    self.scrollNode.addSubnode(actionNode)
                }
                
            case .attribute(let attribute):
                if self.actionNodes[itemId] == nil {
                    let selectedAttributes = Set(self.item.selectedAttributes)
                    guard let action = actionForAttribute(
                        attribute: attribute,
                        presentationData: self.presentationData,
                        selectedAttributes: selectedAttributes,
                        searchQuery: self.searchQuery,
                        item: self.item,
                        getController: self.getController
                    ) else { continue }
                    
                    let actionNode = ContextControllerActionsListActionItemNode(
                        context: self.item.context,
                        getController: self.getController,
                        requestDismiss: self.actionSelected,
                        requestUpdateAction: { _, _ in },
                        item: action
                    )
                    self.actionNodes[itemId] = actionNode
                    self.scrollNode.addSubnode(actionNode)
                } else {
                    let selectedAttributes = Set(self.item.selectedAttributes)
                    if let action = actionForAttribute(
                        attribute: attribute,
                        presentationData: self.presentationData,
                        selectedAttributes: selectedAttributes,
                        searchQuery: self.searchQuery,
                        item: self.item,
                        getController: self.getController
                    ) {
                        self.actionNodes[itemId]?.setItem(item: action)
                    }
                }
                
            case .noResults:
                if self.actionNodes[itemId] == nil {
                    let nopAction: ((ContextControllerProtocol?, @escaping (ContextMenuActionResult) -> Void) -> Void)? = nil
                    let emptyResultsAction = ContextMenuActionItem(
                        text: presentationData.strings.Gift_Store_NoResults,
                        textFont: .small,
                        icon: { _ in return nil },
                        action: nopAction
                    )
                    let actionNode = ContextControllerActionsListActionItemNode(
                        context: self.item.context,
                        getController: self.getController,
                        requestDismiss: self.actionSelected,
                        requestUpdateAction: { _, _ in },
                        item: emptyResultsAction
                    )
                    self.actionNodes[itemId] = actionNode
                    self.scrollNode.addSubnode(actionNode)
                }
            case .separator:
                if self.separatorNodes[itemId] == nil {
                    let separatorNode = ASDisplayNode()
                    separatorNode.backgroundColor = presentationData.theme.contextMenu.itemSeparatorColor
                    self.separatorNodes[itemId] = separatorNode
                    self.scrollNode.addSubnode(separatorNode)
                }
            }
            
            if let actionNode = self.actionNodes[itemId] {
                actionNode.frame = frame

                let (minSize, complete) = actionNode.update(presentationData: self.presentationData, constrainedSize: frame.size)
                self.itemHeights[itemId] = minSize.height
                complete(CGSize(width: maxWidth, height: minSize.height), .immediate)
            } else if let separatorNode = self.separatorNodes[itemId] {
                separatorNode.frame = frame
            }
        }
        
        var nodesToRemove: [AnyHashable] = []
        for (nodeId, node) in self.actionNodes {
            if !validNodeIds.contains(nodeId) {
                nodesToRemove.append(nodeId)
                node.removeFromSupernode()
            }
        }
        for nodeId in nodesToRemove {
            self.actionNodes.removeValue(forKey: nodeId)
        }
        
        var separatorsToRemove: [AnyHashable] = []
        for (separatorId, separatorNode) in self.separatorNodes {
            if !validNodeIds.contains(separatorId) {
                separatorsToRemove.append(separatorId)
                separatorNode.removeFromSupernode()
            }
        }
        for separatorId in separatorsToRemove {
            self.separatorNodes.removeValue(forKey: separatorId)
        }
    }
    
    private func invalidateLayout() {
        self.itemHeights.removeAll()
        self.itemFrames.removeAll()
        self.totalContentHeight = 0.0
    }

    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let minActionsWidth: CGFloat = 250.0
        let maxActionsWidth: CGFloat = 300.0
        let constrainedWidth = min(constrainedWidth, maxActionsWidth)
        let maxWidth = max(constrainedWidth, minActionsWidth)
        
        let maxHeight: CGFloat = min(360.0, constrainedHeight - 108.0)
        
        if self.totalContentHeight == 0 {
            let _ = self.getVisibleItems(in: UIScrollView(), constrainedWidth: constrainedWidth)
        }
        
        return (CGSize(width: maxWidth, height: min(maxHeight, self.totalContentHeight)), { size, transition in
            self.maxWidth = maxWidth
            
            transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: size))
            self.scrollNode.view.contentSize = CGSize(width: size.width, height: self.totalContentHeight)

            self.updateScrolling(maxWidth: maxWidth)
        })
    }
    
    func updateTheme(presentationData: PresentationData) {

    }
    
    var isActionEnabled: Bool {
        return true
    }
    
    func performAction() {
    }
    
    func setIsHighlighted(_ value: Bool) {
    }
    
    func canBeHighlighted() -> Bool {
        return self.isActionEnabled
    }
    
    func updateIsHighlighted(isHighlighted: Bool) {
        self.setIsHighlighted(isHighlighted)
    }
    
    func actionNode(at point: CGPoint) -> ContextActionNodeProtocol {
        return self
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        for (_, actionNode) in self.actionNodes {
            actionNode.updateIsHighlighted(isHighlighted: false)
        }
    }
}


private func stringTokens(_ string: String) -> [ValueBoxKey] {
    let nsString = string.folding(options: .diacriticInsensitive, locale: .current).lowercased() as NSString
    
    let flag = UInt(kCFStringTokenizerUnitWord)
    let tokenizer = CFStringTokenizerCreate(kCFAllocatorDefault, nsString, CFRangeMake(0, nsString.length), flag, CFLocaleCopyCurrent())
    var tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
    var tokens: [ValueBoxKey] = []
    
    var addedTokens = Set<ValueBoxKey>()
    while tokenType != [] {
        let currentTokenRange = CFStringTokenizerGetCurrentTokenRange(tokenizer)
        
        if currentTokenRange.location >= 0 && currentTokenRange.length != 0 {
            let token = ValueBoxKey(length: currentTokenRange.length * 2)
            nsString.getCharacters(token.memory.assumingMemoryBound(to: unichar.self), range: NSMakeRange(currentTokenRange.location, currentTokenRange.length))
            if !addedTokens.contains(token) {
                tokens.append(token)
                addedTokens.insert(token)
            }
        }
        tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
    }
    
    return tokens
}

private func matchStringTokens(_ tokens: [ValueBoxKey], with other: [ValueBoxKey]) -> Bool {
    if other.isEmpty {
        return false
    } else if other.count == 1 {
        let otherToken = other[0]
        for token in tokens {
            if otherToken.isPrefix(to: token) {
                return true
            }
        }
    } else {
        for otherToken in other {
            var found = false
            for token in tokens {
                if otherToken.isPrefix(to: token) {
                    found = true
                    break
                }
            }
            if !found {
                return false
            }
        }
        return true
    }
    return false
}

private func filteredAttributes(attributes: [StarGift.UniqueGift.Attribute], query: String) -> [StarGift.UniqueGift.Attribute] {
    let queryTokens = stringTokens(query.lowercased())
    
    var result: [StarGift.UniqueGift.Attribute] = []
    for attribute in attributes {
        let string: String
        switch attribute {
        case let .model(name, _, _):
            string = name
        case let .pattern(name, _, _):
            string = name
        case let .backdrop(name, _, _, _, _, _, _):
            string = name
        default:
            continue
        }
        let tokens = stringTokens(string)
        if matchStringTokens(tokens, with: queryTokens) {
            result.append(attribute)
        }
    }

    return result
}
