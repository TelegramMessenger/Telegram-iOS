import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import ItemListVenueItem
import ItemListUI
import MapKit

private struct LocationSearchEntry: Identifiable, Comparable {
    let index: Int
    let theme: PresentationTheme
    let venue: TelegramMediaMap

    var stableId: String {
        return self.venue.venue?.id ?? ""
    }
    
    static func ==(lhs: LocationSearchEntry, rhs: LocationSearchEntry) -> Bool {
        if lhs.index != rhs.index {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.venue.venue?.id != rhs.venue.venue?.id {
            return false
        }
        return true
    }
    
    static func <(lhs: LocationSearchEntry, rhs: LocationSearchEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(account: Account, presentationData: PresentationData, sendVenue: @escaping (TelegramMediaMap) -> Void) -> ListViewItem {
        let venue = self.venue
        return ItemListVenueItem(presentationData: ItemListPresentationData(presentationData), account: account, venue: self.venue, sectionId: 0, style: .plain, action: {
            sendVenue(venue)
        })
    }
}

struct LocationSearchContainerTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let isSearching: Bool
}

private func locationSearchContainerPreparedTransition(from fromEntries: [LocationSearchEntry], to toEntries: [LocationSearchEntry], isSearching: Bool, account: Account, presentationData: PresentationData, sendVenue: @escaping (TelegramMediaMap) -> Void) -> LocationSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, presentationData: presentationData, sendVenue: sendVenue), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, presentationData: presentationData, sendVenue: sendVenue), directionHint: nil) }
    
    return LocationSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, isSearching: isSearching)
}

final class LocationSearchContainerNode: ASDisplayNode {
    private let context: AccountContext
    private let interaction: LocationPickerInteraction
    
    private let dimNode: ASDisplayNode
    public let listNode: ListView
    
    private let searchQuery = Promise<String?>()
    private let searchDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private let themeAndStringsPromise: Promise<(PresentationTheme, PresentationStrings)>
    
    private var containerViewLayout: (ContainerViewLayout, CGFloat)?
    private var enqueuedTransitions: [LocationSearchContainerTransition] = []
    
    public init(context: AccountContext, coordinate: CLLocationCoordinate2D, interaction: LocationPickerInteraction) {
        self.context = context
        self.interaction = interaction
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.themeAndStringsPromise = Promise((self.presentationData.theme, self.presentationData.strings))
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        self.listNode = ListView()
        self.listNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        self.listNode.isHidden = true
        
        super.init()
        
        self.backgroundColor = nil
        self.isOpaque = false
        
        self.addSubnode(self.dimNode)
        self.addSubnode(self.listNode)
        
        self.listNode.isHidden = true
        
        let themeAndStringsPromise = self.themeAndStringsPromise
        
        let searchItems = self.searchQuery.get()
        |> mapToSignal { query -> Signal<String?, NoError> in
            if let query = query, !query.isEmpty {
                return (.complete() |> delay(0.6, queue: Queue.mainQueue()))
                |> then(.single(query))
            } else {
                return .single(query)
            }
        }
        |> mapToSignal { query -> Signal<[LocationSearchEntry]?, NoError> in
            if let query = query, !query.isEmpty {
                let foundVenues = nearbyVenues(account: context.account, latitude: coordinate.latitude, longitude: coordinate.longitude, query: query)
                return combineLatest(foundVenues, themeAndStringsPromise.get())
                |> delay(0.1, queue: Queue.concurrentDefaultQueue())
                |> map { venues, themeAndStrings -> [LocationSearchEntry] in
                    var entries: [LocationSearchEntry] = []
                    var index: Int = 0
                    for venue in venues {
                        entries.append(LocationSearchEntry(index: index, theme: themeAndStrings.0, venue: venue))
                        index += 1
                    }
                    return entries
                }
            } else {
                return .single(nil)
            }
        }
        
        let previousSearchItems = Atomic<[LocationSearchEntry]>(value: [])
        self.searchDisposable.set((searchItems
        |> deliverOnMainQueue).start(next: { [weak self] items in
            if let strongSelf = self {
                let previousItems = previousSearchItems.swap(items ?? [])
                let transition = locationSearchContainerPreparedTransition(from: previousItems, to: items ?? [], isSearching: items != nil, account: context.account, presentationData: strongSelf.presentationData, sendVenue: { venue in self?.listNode.clearHighlightAnimated(true)
                    self?.interaction.sendVenue(venue)
                })
                strongSelf.enqueueTransition(transition)
            }
        }))
        
        self.listNode.beganInteractiveDragging = { [weak self] in
            self?.interaction.dismissInput()
        }
    }
    
    deinit {
        self.searchDisposable.dispose()
    }
    
    func scrollToTop() {
        if !self.listNode.isHidden {
            self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.themeAndStringsPromise.set(.single((presentationData.theme, presentationData.strings)))
        self.listNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
    }
    
    func searchTextUpdated(text: String) {
        if text.isEmpty {
            self.searchQuery.set(.single(nil))
        } else {
            self.searchQuery.set(.single(text))
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let hadValidLayout = self.containerViewLayout != nil
        self.containerViewLayout = (layout, navigationBarHeight)
        
        let topInset = navigationBarHeight
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: layout.size.width, height: layout.size.height - topInset)))
        
        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: topInset, left: 0.0, bottom: layout.intrinsicInsets.bottom, right: 0.0), duration: 0.0, curve: .Default(duration: nil)), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !hadValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func enqueueTransition(_ transition: LocationSearchContainerTransition) {
        self.enqueuedTransitions.append(transition)
        
        if self.containerViewLayout != nil {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let transition = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            options.insert(.PreferSynchronousDrawing)
            options.insert(.PreferSynchronousResourceLoading)
            
            let isSearching = transition.isSearching
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                self?.listNode.isHidden = !isSearching
                self?.dimNode.isHidden = isSearching
            })
        }
    }
    
    @objc private func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.interaction.dismissSearch()
        }
    }
}
