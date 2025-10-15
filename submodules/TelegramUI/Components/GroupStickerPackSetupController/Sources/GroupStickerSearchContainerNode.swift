import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import SearchUI
import ItemListUI
import ItemListStickerPackItem

private final class GroupStickerSearchContainerInteraction {
    let packSelected: (StickerPackCollectionInfo) -> Void
    
    init(packSelected: @escaping (StickerPackCollectionInfo) -> Void) {
        self.packSelected = packSelected
    }
}

private final class GroupStickerSearchEntry: Comparable, Identifiable {
    let index: Int
    let pack: StickerPackCollectionInfo
    let topItem: ItemCollectionItem?
    
    init(index: Int, pack: StickerPackCollectionInfo, topItem: ItemCollectionItem?) {
        self.index = index
        self.pack = pack
        self.topItem = topItem
    }
    
    var stableId: ItemCollectionId {
        return self.pack.id
    }
    
    static func ==(lhs: GroupStickerSearchEntry, rhs: GroupStickerSearchEntry) -> Bool {
        return lhs.index == rhs.index && lhs.pack == rhs.pack
    }
    
    static func <(lhs: GroupStickerSearchEntry, rhs: GroupStickerSearchEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(context: AccountContext, presentationData: PresentationData, interaction: GroupStickerSearchContainerInteraction) -> ListViewItem {
        let pack = self.pack
        let count = presentationData.strings.StickerPack_EmojiCount(pack.count)
        
        return ItemListStickerPackItem(presentationData: ItemListPresentationData(presentationData), context: context, packInfo: StickerPackCollectionInfo.Accessor(pack), itemCount: count, topItem: self.topItem as? StickerPackItem, unread: false, control: .none, editing: ItemListStickerPackItemEditing(editable: false, editing: false, revealed: false, reorderable: false, selectable: false), enabled: true, playAnimatedStickers: true, style: .plain, sectionId: 0, action: {
            interaction.packSelected(pack)
        }, setPackIdWithRevealedOptions: { _, _ in
        }, addPack: {
        }, removePack: {
        }, toggleSelected: {
        })
    }
}

struct GroupStickerSearchContainerTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let isSearching: Bool
    let isEmpty: Bool
    let query: String
}

private func groupStickerSearchContainerPreparedRecentTransition(from fromEntries: [GroupStickerSearchEntry], to toEntries: [GroupStickerSearchEntry], isSearching: Bool, isEmpty: Bool, query: String, context: AccountContext, presentationData: PresentationData, interaction: GroupStickerSearchContainerInteraction) -> GroupStickerSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, interaction: interaction), directionHint: nil) }
    
    return GroupStickerSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, isSearching: isSearching, isEmpty: isEmpty, query: query)
}

public final class GroupStickerSearchContainerNode: SearchDisplayControllerContentNode {
    private let context: AccountContext
    private let packSelected: (StickerPackCollectionInfo) -> Void
    
    private let listNode: ListView
    
    private let emptyResultsTitleNode: ImmediateTextNode
    private let emptyResultsTextNode: ImmediateTextNode
    
    private var enqueuedTransitions: [(GroupStickerSearchContainerTransition, Bool)] = []
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    private let searchQuery = Promise<String?>()
    private let searchDisposable = MetaDisposable()
    
    private let forceTheme: PresentationTheme?
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let removeMemberDisposable = MetaDisposable()
    
    private let presentationDataPromise: Promise<PresentationData>
    
    private var _hasDim: Bool = false
    override public var hasDim: Bool {
        return _hasDim
    }
    
    public init(context: AccountContext, forceTheme: PresentationTheme?, packSelected: @escaping (StickerPackCollectionInfo) -> Void, updateActivity: @escaping (Bool) -> Void, pushController: @escaping (ViewController) -> Void) {
        self.context = context
        self.packSelected = packSelected
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        
        self.forceTheme = forceTheme
        if let forceTheme = self.forceTheme {
            self.presentationData = self.presentationData.withUpdated(theme: forceTheme)
        }
        self.presentationDataPromise = Promise(self.presentationData)
        
        self.listNode = ListView()
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        self.emptyResultsTitleNode = ImmediateTextNode()
        self.emptyResultsTitleNode.displaysAsynchronously = false
        self.emptyResultsTitleNode.attributedText = NSAttributedString(string: self.presentationData.strings.ChatList_Search_NoResults, font: Font.semibold(17.0), textColor: self.presentationData.theme.list.freeTextColor)
        self.emptyResultsTitleNode.textAlignment = .center
        self.emptyResultsTitleNode.isHidden = true
        
        self.emptyResultsTextNode = ImmediateTextNode()
        self.emptyResultsTextNode.displaysAsynchronously = false
        self.emptyResultsTextNode.maximumNumberOfLines = 0
        self.emptyResultsTextNode.textAlignment = .center
        self.emptyResultsTextNode.isHidden = true
        
        super.init()
        
        self.listNode.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        self.listNode.isHidden = true
        
        self._hasDim = true
        
        self.addSubnode(self.listNode)
        
        self.addSubnode(self.emptyResultsTitleNode)
        self.addSubnode(self.emptyResultsTextNode)
        
        let interaction = GroupStickerSearchContainerInteraction(packSelected: { [weak self] pack in
            packSelected(pack)
            self?.listNode.clearHighlightAnimated(true)
        })
        
        let foundItems = self.searchQuery.get()
        |> mapToSignal { query -> Signal<[GroupStickerSearchEntry]?, NoError> in
            guard let query, !query.isEmpty else {
                return .single(nil)
            }
            return context.engine.stickers.searchEmojiSets(query: query)
            |> mapToSignal { localResult in
                return context.engine.stickers.searchEmojiSetsRemotely(query: query)
                |> map { remoteResult -> [GroupStickerSearchEntry]? in
                    let mergedResult = localResult.merge(with: remoteResult)
                    var entries: [GroupStickerSearchEntry] = []
                    var index = 0
                    for info in mergedResult.infos {
                        if let pack = info.1 as? StickerPackCollectionInfo {
                            entries.append(GroupStickerSearchEntry(index: index, pack: pack, topItem: info.2))
                            index += 1
                        }
                    }
                    return entries
                }
            }
        }
        
        let previousSearchItems = Atomic<[GroupStickerSearchEntry]?>(value: nil)
        self.searchDisposable.set((combineLatest(self.searchQuery.get(), foundItems, self.presentationDataPromise.get())
        |> deliverOnMainQueue).start(next: { [weak self] query, entries, presentationData in
            if let strongSelf = self {
                let previousEntries = previousSearchItems.swap(entries)
                updateActivity(false)
                let firstTime = previousEntries == nil
                let transition = groupStickerSearchContainerPreparedRecentTransition(from: previousEntries ?? [], to: entries ?? [], isSearching: entries != nil, isEmpty: entries?.isEmpty ?? false, query: query ?? "", context: context, presentationData: presentationData, interaction: interaction)
                strongSelf.enqueueTransition(transition, firstTime: firstTime)
            }
        }))
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                var presentationData = presentationData
                
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                if let forceTheme = strongSelf.forceTheme {
                    presentationData = presentationData.withUpdated(theme: forceTheme)
                }
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings(theme: presentationData.theme, strings: presentationData.strings)
                }
            }
        })
        
        self.listNode.beganInteractiveDragging = { [weak self] _ in
            self?.dismissInput?()
        }
    }
    
    deinit {
        self.searchDisposable.dispose()
        self.presentationDataDisposable?.dispose()
    }
    
    private func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.listNode.backgroundColor = theme.chatList.backgroundColor
    }
    
    override public func searchTextUpdated(text: String) {
        if text.isEmpty {
            self.searchQuery.set(.single(nil))
        } else {
            self.searchQuery.set(.single(text))
        }
    }
    
    private func enqueueTransition(_ transition: GroupStickerSearchContainerTransition, firstTime: Bool) {
        enqueuedTransitions.append((transition, firstTime))
        
        if let _ = self.validLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let (transition, firstTime) = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            options.insert(.PreferSynchronousDrawing)
            options.insert(.PreferSynchronousResourceLoading)
            if firstTime {
            } else {
                //options.insert(.AnimateAlpha)
            }
            
            let isSearching = transition.isSearching
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.listNode.isHidden = !isSearching
                                
                strongSelf.emptyResultsTextNode.attributedText = NSAttributedString(string: strongSelf.presentationData.strings.ChatList_Search_NoResultsQueryDescription(transition.query).string, font: Font.regular(15.0), textColor: strongSelf.presentationData.theme.list.freeTextColor)
                
                let emptyResults = transition.isSearching && transition.isEmpty
                strongSelf.emptyResultsTitleNode.isHidden = !emptyResults
                strongSelf.emptyResultsTextNode.isHidden = !emptyResults
                
                if let (layout, navigationBarHeight) = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                }
            })
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        let hadValidLayout = self.validLayout == nil
        self.validLayout = (layout, navigationBarHeight)
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        insets.left += layout.safeInsets.left
        insets.right += layout.safeInsets.right
        
        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        let padding: CGFloat = 16.0
        let emptyTitleSize = self.emptyResultsTitleNode.updateLayout(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - padding * 2.0, height: CGFloat.greatestFiniteMagnitude))
        let emptyTextSize = self.emptyResultsTextNode.updateLayout(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - padding * 2.0, height: CGFloat.greatestFiniteMagnitude))
        
        let emptyTextSpacing: CGFloat = 8.0
        let emptyTotalHeight = emptyTitleSize.height + emptyTextSize.height + emptyTextSpacing
        let emptyTitleY = navigationBarHeight + floorToScreenPixels((layout.size.height - navigationBarHeight - max(insets.bottom, layout.intrinsicInsets.bottom) - emptyTotalHeight) / 2.0)
        
        transition.updateFrame(node: self.emptyResultsTitleNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + padding + (layout.size.width - layout.safeInsets.left - layout.safeInsets.right - padding * 2.0 - emptyTitleSize.width) / 2.0, y: emptyTitleY), size: emptyTitleSize))
        transition.updateFrame(node: self.emptyResultsTextNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + padding + (layout.size.width - layout.safeInsets.left - layout.safeInsets.right - padding * 2.0 - emptyTextSize.width) / 2.0, y: emptyTitleY + emptyTitleSize.height + emptyTextSpacing), size: emptyTextSize))
        
        if !hadValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    override public func scrollToTop() {
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel?()
        }
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = self.view.hitTest(point, with: event) else {
            return nil
        }
        if result === self.view {
            return nil
        }
        return result
    }
}
