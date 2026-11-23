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
import ChatListUI

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
        
        self.listNode = ListViewImpl()
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
