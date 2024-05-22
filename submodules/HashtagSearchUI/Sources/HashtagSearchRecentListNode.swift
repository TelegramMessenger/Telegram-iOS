import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import TelegramCore
import TelegramPresentationData
import ItemListUI
import MergeLists
import AccountContext

final class HashtagSearchInteraction {
    let setSearchQuery: (String) -> Void
    let deleteRecentQuery: (String) -> Void
    let clearRecentQueries: () -> Void
    
    init(setSearchQuery: @escaping (String) -> Void, deleteRecentQuery: @escaping (String) -> Void, clearRecentQueries: @escaping () -> Void) {
        self.setSearchQuery = setSearchQuery
        self.deleteRecentQuery = deleteRecentQuery
        self.clearRecentQueries = clearRecentQueries
    }
}

private enum HashtagSearchRecentQueryStableId: Hashable {
    case query(String)
    case clear
}

private enum HashtagSearchRecentQueryEntry: Comparable, Identifiable {
    case query(index: Int, text: String)
    case clear
        
    var stableId: HashtagSearchRecentQueryStableId {
        switch self {
        case let .query(_, text):
            return .query(text)
        case .clear:
            return .clear
        }
    }
    
    static func ==(lhs: HashtagSearchRecentQueryEntry, rhs: HashtagSearchRecentQueryEntry) -> Bool {
        switch lhs {
        case let .query(lhsIndex, lhsText):
            if case let .query(rhsIndex, rhsText) = rhs {
                return lhsIndex == rhsIndex && lhsText == rhsText
            } else {
                return false
            }
        case .clear:
            if case .clear = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: HashtagSearchRecentQueryEntry, rhs: HashtagSearchRecentQueryEntry) -> Bool {
        switch lhs {
        case let .query(lhsIndex, _):
            switch rhs {
            case let .query(rhsIndex, _):
                return lhsIndex < rhsIndex
            case .clear:
                return true
            }
        case .clear:
            switch rhs {
            case .query:
                return false
            case .clear:
                return true
            }
        }
    }
    
    func item(account: Account, theme: PresentationTheme, strings: PresentationStrings, interaction: HashtagSearchInteraction) -> ListViewItem {
        var isClear = false
        let text: String
        switch self {
        case let .query(_, value):
            text = value
        case .clear:
            isClear = true
            text = strings.HashtagSearch_ClearRecent
        }
        return HashtagSearchRecentQueryItem(account: account, theme: theme, strings: strings, query: text, clear: isClear, tapped: { query in
            if isClear {
                interaction.clearRecentQueries()
            } else {
                interaction.setSearchQuery(text)
            }
        }, deleted: { query in
            interaction.deleteRecentQuery(query)
        })
    }
}

private struct HashtagSearchRecentTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let isEmpty: Bool
}

private func preparedHashtagSearchRecentTransition(from fromEntries: [HashtagSearchRecentQueryEntry], to toEntries: [HashtagSearchRecentQueryEntry], account: Account, theme: PresentationTheme, strings: PresentationStrings, interaction: HashtagSearchInteraction) -> HashtagSearchRecentTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, theme: theme, strings: strings, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, theme: theme, strings: strings, interaction: interaction), directionHint: nil) }
    
    return HashtagSearchRecentTransition(deletions: deletions, insertions: insertions, updates: updates, isEmpty: toEntries.isEmpty)
}

private enum RevealOptionKey: Int32 {
    case delete
}

public class HashtagSearchRecentQueryItem: ListViewItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let account: Account
    let query: String
    let clear: Bool
    let tapped: (String) -> Void
    let deleted: (String) -> Void
    
    let header: ListViewItemHeader? = nil
    
    public init(account: Account, theme: PresentationTheme, strings: PresentationStrings, query: String, clear: Bool, tapped: @escaping (String) -> Void, deleted: @escaping (String) -> Void) {
        self.theme = theme
        self.strings = strings
        self.account = account
        self.query = query
        self.clear = clear
        self.tapped = tapped
        self.deleted = deleted
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = HashtagSearchRecentQueryItemNode()
            let makeLayout = node.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(self, params, nextItem == nil, !(previousItem is HashtagSearchRecentQueryItem))
            node.contentSize = nodeLayout.contentSize
            node.insets = nodeLayout.insets
            
            completion(node, nodeApply)
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? HashtagSearchRecentQueryItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params, nextItem == nil, !(previousItem is HashtagSearchRecentQueryItem))
                    Queue.mainQueue().async {
                        completion(nodeLayout, { info in
                            apply().1(info)
                        })
                    }
                }
            }
        }
    }
    
    public var selectable: Bool {
        return true
    }
    
    public func selected(listView: ListView) {
        listView.clearHighlightAnimated(true)
        self.tapped(self.query)
    }
}

final class HashtagSearchRecentQueryItemNode: ItemListRevealOptionsItemNode {
    private let backgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private var textNode: TextNode?
    private let iconNode: ASImageNode
    
    private var item: HashtagSearchRecentQueryItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    required init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.iconNode)
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = self.item {
            let makeLayout = self.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(item, params, nextItem == nil, previousItem == nil)
            self.contentSize = nodeLayout.contentSize
            self.insets = nodeLayout.insets
            let _ = nodeApply()
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        if highlighted {
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: self.separatorNode)
            }
        } else {
            if self.highlightedBackgroundNode.supernode != nil {
                if animated {
                    self.highlightedBackgroundNode.layer.animateAlpha(from: self.highlightedBackgroundNode.alpha, to: 0.0, duration: 0.4, completion: { [weak self] completed in
                        if let strongSelf = self {
                            if completed {
                                strongSelf.highlightedBackgroundNode.removeFromSupernode()
                            }
                        }
                    })
                    self.highlightedBackgroundNode.alpha = 0.0
                } else {
                    self.highlightedBackgroundNode.removeFromSupernode()
                }
            }
        }
    }
    
    func asyncLayout() -> (_ item: HashtagSearchRecentQueryItem, _ params: ListViewItemLayoutParams, _ last: Bool, _ firstWithHeader: Bool) -> (ListViewItemNodeLayout, () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) {
        let currentItem = self.item
        
        let textLayout = TextNode.asyncLayout(self.textNode)
        
        return { [weak self] item, params, last, firstWithHeader in
            
            let leftInset: CGFloat = 62.0 + params.leftInset
            let rightInset: CGFloat = params.rightInset
            
            let attributedString = NSAttributedString(string: item.query, font: Font.regular(17.0), textColor: item.clear ? item.theme.list.itemAccentColor : item.theme.list.itemPrimaryTextColor)
            let textApply = textLayout(TextNodeLayoutArguments(attributedString: attributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset - 15.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: 44.0), insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0))
            
            return (nodeLayout, { [weak self] in
                var updatedTheme: PresentationTheme?
                if currentItem?.theme !== item.theme {
                    updatedTheme = item.theme
                }
                
                return (nil, { _ in
                    if let strongSelf = self {
                        strongSelf.item = item
                        strongSelf.layoutParams = params
                        
                        if let _ = updatedTheme {
                            strongSelf.separatorNode.backgroundColor = item.theme.list.itemPlainSeparatorColor
                            strongSelf.backgroundNode.backgroundColor = item.theme.list.plainBackgroundColor
                            strongSelf.highlightedBackgroundNode.backgroundColor = item.theme.list.itemHighlightedBackgroundColor
                            if item.clear {
                                strongSelf.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Hashtag/ClearRecent"), color: item.theme.list.itemAccentColor)
                            } else {
                                strongSelf.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Hashtag/RecentHashtag"), color: item.theme.list.itemSecondaryTextColor)
                            }
                        }
                        
                        let (textLayout, textApply) = textApply
                        let textNode = textApply()
                        if strongSelf.textNode == nil {
                            strongSelf.textNode = textNode
                            strongSelf.addSubnode(textNode)
                        }
                        
                        let textFrame = CGRect(origin: CGPoint(x: leftInset + strongSelf.revealOffset, y: floorToScreenPixels((nodeLayout.contentSize.height - textLayout.size.height) / 2.0)), size: textLayout.size)
                        textNode.frame = textFrame
                        
                        if let icon = strongSelf.iconNode.image {
                            strongSelf.iconNode.frame = CGRect(origin: CGPoint(x: textFrame.minX - icon.size.width - 16.0 + strongSelf.revealOffset, y: floorToScreenPixels((nodeLayout.contentSize.height - icon.size.height) / 2.0)), size: icon.size)
                        }
                        
                        let separatorHeight = UIScreenPixel
                        let topHighlightInset: CGFloat = separatorHeight
                        
                        strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: nodeLayout.contentSize.width, height: nodeLayout.contentSize.height))
                        strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -nodeLayout.insets.top - topHighlightInset), size: CGSize(width: nodeLayout.size.width, height: nodeLayout.size.height + topHighlightInset))
                        strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset, y: nodeLayout.contentSize.height - separatorHeight), size: CGSize(width: nodeLayout.size.width, height: separatorHeight))
                        strongSelf.separatorNode.isHidden = last
                        
                        strongSelf.updateLayout(size: nodeLayout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                        
                        if item.clear {
                            strongSelf.setRevealOptions((left: [], right: []))
                        } else {
                            strongSelf.setRevealOptions((left: [], right: [ItemListRevealOption(key: RevealOptionKey.delete.rawValue, title: item.strings.Common_Delete, icon: .none, color: item.theme.list.itemDisclosureActions.destructive.fillColor, textColor: item.theme.list.itemDisclosureActions.destructive.foregroundColor)]))
                        }
                    }
                })
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.5, removeOnCompletion: false)
    }
    
    override public func headers() -> [ListViewItemHeader]? {
        if let item = self.item {
            return item.header.flatMap { [$0] }
        } else {
            return nil
        }
    }
    
    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        if let params = self.layoutParams, let textNode = self.textNode {
            let leftInset: CGFloat = 62.0 + params.leftInset
            
            var textFrame = textNode.frame
            textFrame.origin.x = leftInset + offset
            transition.updateFrame(node: textNode, frame: textFrame)
            
            var iconFrame = self.iconNode.frame
            iconFrame.origin.x = textFrame.minX - iconFrame.width - 16.0
            transition.updateFrame(node: self.iconNode, frame: iconFrame)
        }
    }
    
    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        if let item = self.item {
            switch option.key {
                case RevealOptionKey.delete.rawValue:
                    item.deleted(item.query)
                default:
                    break
            }
        }
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
    }
}

final class HashtagSearchRecentListNode: ASDisplayNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    
    private let listNode: ListView
    
    private let emptyIconNode: ASImageNode
    private let emptyTextNode: ImmediateTextNode
    
    private var enqueuedRecentTransitions: [(HashtagSearchRecentTransition, Bool)] = []
    private var recentDisposable: Disposable?
    
    private var validLayout: ContainerViewLayout?
    
    private var interaction: HashtagSearchInteraction?
        
    var setSearchQuery: (String) -> Void = { _ in }
    
    init(context: AccountContext) {
        self.context = context
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        
        self.listNode = ListView()
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        self.emptyIconNode = ASImageNode()
        self.emptyIconNode.displaysAsynchronously = false
        
        self.emptyTextNode = ImmediateTextNode()
        self.emptyTextNode.displaysAsynchronously = false
        self.emptyTextNode.maximumNumberOfLines = 0
        self.emptyTextNode.textAlignment = .center
        
        super.init()
                
        self.addSubnode(self.listNode)
        self.addSubnode(self.emptyIconNode)
        self.addSubnode(self.emptyTextNode)
        
        self.interaction = HashtagSearchInteraction(
            setSearchQuery: { [weak self] query in
                self?.setSearchQuery(query)
            },
            deleteRecentQuery: { query in
                let _ = removeRecentHashtagSearchQuery(engine: context.engine, string: query).startStandalone()
            },
            clearRecentQueries: {
                let _ = clearRecentHashtagSearchQueries(engine: context.engine).startStandalone()
            }
        )
        
        self.listNode.beganInteractiveDragging = { [weak self] _ in
            self?.view.window?.endEditing(true)
        }
        
        let previousRecentItems = Atomic<[HashtagSearchRecentQueryEntry]?>(value: nil)
        self.recentDisposable = (hashtagSearchRecentQueries(engine: self.context.engine)
        |> deliverOnMainQueue).start(next: { [weak self] queries in
            guard let self else {
                return
            }
            var entries: [HashtagSearchRecentQueryEntry] = []
            for i in 0 ..< queries.count {
                entries.append(.query(index: i, text: queries[i]))
            }
            
            if !entries.isEmpty {
                entries.append(.clear)
            }
            
            let previousEntries = previousRecentItems.swap(entries)
        
            let transition = preparedHashtagSearchRecentTransition(from: previousEntries ?? [], to: entries, account: context.account, theme: self.presentationData.theme, strings: self.presentationData.strings, interaction: self.interaction!)
            self.enqueueRecentTransition(transition, firstTime: previousEntries == nil)
        })
        
        self.updatePresentationData(self.presentationData)
    }
    
    deinit {
        self.recentDisposable?.dispose()
    }
    
    private func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        self.listNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.emptyIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Hashtag/EmptyHashtag"), color: self.presentationData.theme.list.freeMonoIconColor)
        self.emptyTextNode.attributedText = NSAttributedString(string: self.presentationData.strings.HashtagSearch_NoRecentQueries, font: Font.regular(15.0), textColor: self.presentationData.theme.list.freeTextColor)
    }
    
    private func enqueueRecentTransition(_ transition: HashtagSearchRecentTransition, firstTime: Bool) {
        enqueuedRecentTransitions.append((transition, firstTime))
        
        if let _ = self.validLayout {
            while !self.enqueuedRecentTransitions.isEmpty {
                self.dequeueRecentTransition()
            }
        }
    }
    
    private func dequeueRecentTransition() {
        if let (transition, firstTime) = self.enqueuedRecentTransitions.first {
            self.enqueuedRecentTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            if firstTime {
                options.insert(.PreferSynchronousDrawing)
            } else {
                options.insert(.AnimateInsertion)
            }
            
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                guard let self else {
                    return
                }
                
                self.emptyIconNode.isHidden = !transition.isEmpty
                self.emptyTextNode.isHidden = !transition.isEmpty
            })
        }
    }
    
    func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        let insets: UIEdgeInsets = layout.insets(options: [.input])
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
            
        if let emptyIconSize = self.emptyIconNode.image?.size {
            let topInset: CGFloat = insets.top
            let bottomInset: CGFloat = insets.bottom
            
            let sideInset: CGFloat = 0.0
            let padding: CGFloat = 16.0
            let emptyTextSize = self.emptyTextNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0 - padding * 2.0, height: CGFloat.greatestFiniteMagnitude))
            
            let emptyTextSpacing: CGFloat = 6.0
            let emptyTotalHeight = emptyIconSize.height + emptyTextSpacing + emptyTextSize.height
            let emptyOriginY = topInset + floorToScreenPixels((layout.size.height - topInset - bottomInset - emptyTotalHeight) / 2.0)
            
            transition.updateFrame(node: self.emptyIconNode, frame: CGRect(origin: CGPoint(x: sideInset + padding + (layout.size.width - sideInset * 2.0 - padding * 2.0 - emptyIconSize.width) / 2.0, y: emptyOriginY), size: emptyIconSize))
            transition.updateFrame(node: self.emptyTextNode, frame: CGRect(origin: CGPoint(x: sideInset + padding + (layout.size.width - sideInset * 2.0 - padding * 2.0 - emptyTextSize.width) / 2.0, y: emptyOriginY + emptyIconSize.height + emptyTextSpacing), size: emptyTextSize))
        }
    }
}
