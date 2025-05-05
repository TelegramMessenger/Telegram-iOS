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
    private let actionNodes: [ContextControllerActionsListActionItemNode]
    private let separatorNodes: [ASDisplayNode]
    
    private var searchDisposable: Disposable?
    private var searchQuery = ""
    
    init(presentationData: PresentationData, item: GiftAttributeListContextItem, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) {
        self.item = item
        self.presentationData = presentationData
        self.getController = getController
        self.actionSelected = actionSelected
        
        self.scrollNode = ASScrollNode()
                                
        var actionNodes: [ContextControllerActionsListActionItemNode] = []
        var separatorNodes: [ASDisplayNode] = []
        
        let selectedAttributes = Set(item.selectedAttributes)
        
        let selectAllAction = ContextMenuActionItem(text: presentationData.strings.Gift_Store_SelectAll, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Select"), color: theme.contextMenu.primaryColor)
        }, iconPosition: .left, action: { _, f in
            getController()?.dismiss(result: .dismissWithoutContent, completion: nil)
            
            item.selectAll()
        })
        
        let selectAllActionNode = ContextControllerActionsListActionItemNode(context: item.context, getController: getController, requestDismiss: actionSelected, requestUpdateAction: { _, _ in }, item: selectAllAction)
        actionNodes.append(selectAllActionNode)
        
        let separatorNode = ASDisplayNode()
        separatorNode.backgroundColor = presentationData.theme.contextMenu.itemSeparatorColor
        separatorNodes.append(separatorNode)
        
        for attribute in item.attributes {
            guard let action = actionForAttribute(attribute: attribute, presentationData: presentationData, selectedAttributes: selectedAttributes, searchQuery: self.searchQuery, item: item, getController: getController) else {
                continue
            }
            let actionNode = ContextControllerActionsListActionItemNode(context: item.context, getController: getController, requestDismiss: actionSelected, requestUpdateAction: { _, _ in }, item: action)
            actionNodes.append(actionNode)
            if actionNodes.count != item.attributes.count {
                let separatorNode = ASDisplayNode()
                separatorNode.backgroundColor = presentationData.theme.contextMenu.itemSeparatorColor
                separatorNodes.append(separatorNode)
            }
        }
        
        let nopAction: ((ContextControllerProtocol?, @escaping (ContextMenuActionResult) -> Void) -> Void)? = nil
        let emptyResultsAction = ContextMenuActionItem(text: presentationData.strings.Gift_Store_NoResults, textFont: .small, icon: { _ in return nil }, action: nopAction)
        let emptyResultsActionNode = ContextControllerActionsListActionItemNode(context: item.context, getController: getController, requestDismiss: actionSelected, requestUpdateAction: { _, _ in }, item: emptyResultsAction)
        actionNodes.append(emptyResultsActionNode)
        
        self.actionNodes = actionNodes
        self.separatorNodes = separatorNodes
        
        super.init()
        
        self.addSubnode(self.scrollNode)
        for separatorNode in self.separatorNodes {
            self.scrollNode.addSubnode(separatorNode)
        }
        for actionNode in self.actionNodes {
            self.scrollNode.addSubnode(actionNode)
        }
        
        self.searchDisposable = (item.searchQuery
        |> deliverOnMainQueue).start(next: { [weak self] searchQuery in
            guard let self, self.searchQuery != searchQuery else {
                return
            }
            self.searchQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            
            var i = 1
            for attribute in item.attributes {
                guard let action = actionForAttribute(attribute: attribute, presentationData: presentationData, selectedAttributes: selectedAttributes, searchQuery: self.searchQuery, item: item, getController: getController) else {
                    continue
                }
                self.actionNodes[i].setItem(item: action)
                i += 1
            }
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

    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let minActionsWidth: CGFloat = 250.0
        let maxActionsWidth: CGFloat = 300.0
        let constrainedWidth = min(constrainedWidth, maxActionsWidth)
        var maxWidth: CGFloat = 0.0
        var contentHeight: CGFloat = 0.0
        var heightsAndCompletions: [(Int, CGFloat, (CGSize, ContainedViewLayoutTransition) -> Void)] = []
        
        
        let effectiveAttributes: [StarGift.UniqueGift.Attribute]
        if self.searchQuery.isEmpty {
            effectiveAttributes = self.item.attributes
        } else {
            effectiveAttributes = filteredAttributes(attributes: self.item.attributes, query: self.searchQuery)
        }
        let visibleAttributes = Set(effectiveAttributes.map { attribute -> AnyHashable in
            switch attribute {
            case let .model(_, file, _):
                return file.fileId.id
            case let .pattern(_, file, _):
                return file.fileId.id
            case let .backdrop(_, id, _, _, _, _, _):
                return id
            default:
                fatalError()
            }
        })
        
        for i in 0 ..< self.actionNodes.count {
            let itemNode = self.actionNodes[i]
            if !self.searchQuery.isEmpty && i == 0 {
                itemNode.isHidden = true
                continue
            }
            
            if i > 0 && i < self.actionNodes.count - 1 {
                let attribute = self.item.attributes[i - 1]
                let attributeId: AnyHashable
                switch attribute {
                case let .model(_, file, _):
                    attributeId = AnyHashable(file.fileId.id)
                case let .pattern(_, file, _):
                    attributeId = AnyHashable(file.fileId.id)
                case let .backdrop(_, id, _, _, _, _, _):
                    attributeId = AnyHashable(id)
                default:
                    fatalError()
                }
                if !visibleAttributes.contains(attributeId) {
                    itemNode.isHidden = true
                    continue
                }
            }
            if i == self.actionNodes.count - 1 {
                if !visibleAttributes.isEmpty {
                    itemNode.isHidden = true
                    continue
                } else {
                }
            }
            itemNode.isHidden = false
            
            let (minSize, complete) = itemNode.update(presentationData: self.presentationData, constrainedSize: CGSize(width: constrainedWidth, height: constrainedHeight))
            maxWidth = max(maxWidth, minSize.width)
            heightsAndCompletions.append((i, minSize.height, complete))
            contentHeight += minSize.height
        }
        
        maxWidth = max(maxWidth, minActionsWidth)
        
        let maxHeight: CGFloat = min(360.0, constrainedHeight - 108.0)
        
        return (CGSize(width: maxWidth, height: min(maxHeight, contentHeight)), { size, transition in
            var verticalOffset: CGFloat = 0.0
            for (i, itemHeight, itemCompletion) in heightsAndCompletions {
                let itemNode = self.actionNodes[i]

                let itemSize = CGSize(width: maxWidth, height: itemHeight)
                transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: verticalOffset), size: itemSize))
                itemCompletion(itemSize, transition)
                verticalOffset += itemHeight
                
                if i < self.actionNodes.count - 2 {
                    let separatorNode = self.separatorNodes[i]
                    separatorNode.frame = CGRect(x: 0, y: verticalOffset, width: size.width, height: UIScreenPixel)
                }
            }
            transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: size))
            self.scrollNode.view.contentSize = CGSize(width: size.width, height: contentHeight)
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
        for actionNode in self.actionNodes {
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
