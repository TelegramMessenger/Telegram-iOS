import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import TelegramUIPreferences
import MergeLists
import AccountContext
import ItemListVenueItem
import ItemListUI
import MapKit
import Geocoding
import ChatListSearchItemHeader

private struct LocationSearchEntry: Identifiable, Comparable {
    let index: Int
    let theme: PresentationTheme
    let location: TelegramMediaMap
    let title: String?
    let distance: Double
    
    var stableId: String {
        return self.location.venue?.id ?? ""
    }
    
    static func ==(lhs: LocationSearchEntry, rhs: LocationSearchEntry) -> Bool {
        if lhs.index != rhs.index {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.location.venue?.id != rhs.location.venue?.id {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.distance != rhs.distance {
            return false
        }
        return true
    }
    
    static func <(lhs: LocationSearchEntry, rhs: LocationSearchEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(engine: TelegramEngine, presentationData: PresentationData, sendVenue: @escaping (TelegramMediaMap) -> Void) -> ListViewItem {
        let venue = self.location
        let header: ChatListSearchItemHeader
        let subtitle: String?
        if let _ = venue.venue {
            header = ChatListSearchItemHeader(type: .nearbyVenues, theme: presentationData.theme, strings: presentationData.strings)
            subtitle = nil
        } else {
            header = ChatListSearchItemHeader(type: .mapAddress, theme: presentationData.theme, strings: presentationData.strings)
            subtitle = presentationData.strings.Map_DistanceAway(stringForDistance(strings: presentationData.strings, distance: self.distance)).string
        }
        return ItemListVenueItem(presentationData: ItemListPresentationData(presentationData), engine: engine, venue: self.location, title: self.title, subtitle: subtitle, style: .plain, action: {
            sendVenue(venue)
        }, header: header)
    }
}

struct LocationSearchContainerTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let query: String
    let isSearching: Bool
    let isEmpty: Bool
}

private func locationSearchContainerPreparedTransition(from fromEntries: [LocationSearchEntry], to toEntries: [LocationSearchEntry], query: String, isSearching: Bool, isEmpty: Bool, engine: TelegramEngine, presentationData: PresentationData, sendVenue: @escaping (TelegramMediaMap) -> Void) -> LocationSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(engine: engine, presentationData: presentationData, sendVenue: sendVenue), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(engine: engine, presentationData: presentationData, sendVenue: sendVenue), directionHint: nil) }
    
    return LocationSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, query: query, isSearching: isSearching, isEmpty: isEmpty)
}

final class LocationSearchContainerNode: ASDisplayNode {
    private let context: AccountContext
    private let interaction: LocationPickerInteraction
    
    private let dimNode: ASDisplayNode
    public let listNode: ListView
    private let emptyResultsTitleNode: ImmediateTextNode
    private let emptyResultsTextNode: ImmediateTextNode
    
    private let searchQuery = Promise<String?>()
    private let searchDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private let themeAndStringsPromise: Promise<(PresentationTheme, PresentationStrings)>
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    private var enqueuedTransitions: [LocationSearchContainerTransition] = []
    
    private let _isSearching = ValuePromise<Bool>(false, ignoreRepeated: true)
    var isSearching: Signal<Bool, NoError> {
        return self._isSearching.get()
    }
    
    public init(context: AccountContext, coordinate: CLLocationCoordinate2D, interaction: LocationPickerInteraction) {
        self.context = context
        self.interaction = interaction
                
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        self.themeAndStringsPromise = Promise((self.presentationData.theme, self.presentationData.strings))
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        self.listNode = ListView()
        self.listNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        self.listNode.isHidden = true
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        self.emptyResultsTitleNode = ImmediateTextNode()
        self.emptyResultsTitleNode.attributedText = NSAttributedString(string: self.presentationData.strings.SharedMedia_SearchNoResults, font: Font.semibold(17.0), textColor: self.presentationData.theme.list.freeTextColor)
        self.emptyResultsTitleNode.textAlignment = .center
        self.emptyResultsTitleNode.isHidden = true
        
        self.emptyResultsTextNode = ImmediateTextNode()
        self.emptyResultsTextNode.maximumNumberOfLines = 0
        self.emptyResultsTextNode.textAlignment = .center
        self.emptyResultsTextNode.isHidden = true
        
        super.init()
        
        self.backgroundColor = nil
        self.isOpaque = false
        
        self.addSubnode(self.dimNode)
        self.addSubnode(self.listNode)
        
        self.addSubnode(self.emptyResultsTitleNode)
        self.addSubnode(self.emptyResultsTextNode)
        
        self.listNode.isHidden = true
        
        let currentLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let themeAndStringsPromise = self.themeAndStringsPromise
        
        let isSearching = self._isSearching
        let searchItems = self.searchQuery.get()
        |> mapToSignal { query -> Signal<String?, NoError> in
            if let query = query, !query.isEmpty {
                return (.complete() |> delay(0.6, queue: Queue.mainQueue()))
                |> then(.single(query))
            } else {
                return .single(query)
            }
        }
        |> mapToSignal { query -> Signal<([LocationSearchEntry], String)?, NoError> in
            if let query = query, !query.isEmpty {
                let foundVenues = nearbyVenues(context: context, latitude: coordinate.latitude, longitude: coordinate.longitude, query: query)
                |> afterCompleted {
                    isSearching.set(false)
                }
                let foundPlacemarks = geocodeLocation(address: query)
                return combineLatest(foundVenues, foundPlacemarks, themeAndStringsPromise.get())
                |> delay(0.1, queue: Queue.concurrentDefaultQueue())
                |> beforeStarted {
                    isSearching.set(true)
                }
                |> map { venues, placemarks, themeAndStrings -> ([LocationSearchEntry], String) in
                    var entries: [LocationSearchEntry] = []
                    var index: Int = 0
                    
                    if let placemarks = placemarks {
                        for placemark in placemarks {
                            guard let placemarkLocation = placemark.location else {
                                continue
                            }
                            let location = TelegramMediaMap(latitude: placemarkLocation.coordinate.latitude, longitude: placemarkLocation.coordinate.longitude, heading: nil, accuracyRadius: nil, geoPlace: nil, venue: nil, liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil)
                            
                            entries.append(LocationSearchEntry(index: index, theme: themeAndStrings.0, location: location, title: placemark.name ?? "Name", distance: placemarkLocation.distance(from: currentLocation)))
                            
                            index += 1
                        }
                    }
                    
                    for venue in venues {
                        entries.append(LocationSearchEntry(index: index, theme: themeAndStrings.0, location: venue, title: nil, distance: 0.0))
                        index += 1
                    }
                    return (entries, query)
                }
            } else {
                return .single(nil)
                |> afterCompleted {
                    isSearching.set(true)
                }
            }
        }
        
        let previousSearchItems = Atomic<[LocationSearchEntry]>(value: [])
        self.searchDisposable.set((searchItems
        |> deliverOnMainQueue).start(next: { [weak self] itemsAndQuery in
            if let strongSelf = self {
                let (items, query) = itemsAndQuery ?? (nil, "")
                let previousItems = previousSearchItems.swap(items ?? [])
                let transition = locationSearchContainerPreparedTransition(from: previousItems, to: items ?? [], query: query, isSearching: items != nil, isEmpty: items?.isEmpty ?? false, engine: context.engine, presentationData: strongSelf.presentationData, sendVenue: { venue in self?.listNode.clearHighlightAnimated(true)
                    if let _ = venue.venue {
                        self?.interaction.sendVenue(venue)
                    } else {
                        self?.interaction.goToCoordinate(venue.coordinate)
                        self?.interaction.dismissSearch()
                    }
                })
                strongSelf.enqueueTransition(transition)
            }
        }))
        
        self.listNode.beganInteractiveDragging = { [weak self] _ in
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
        let hadValidLayout = self.validLayout != nil
        self.validLayout = (layout, navigationBarHeight)
        
        let topInset = navigationBarHeight
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: layout.size.width, height: layout.size.height - topInset)))
        
        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: topInset, left: layout.intrinsicInsets.left, bottom: layout.intrinsicInsets.bottom, right: layout.intrinsicInsets.right), duration: 0.0, curve: .Default(duration: nil)), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        let padding: CGFloat = 16.0
        let emptyTitleSize = self.emptyResultsTitleNode.updateLayout(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - padding * 2.0, height: CGFloat.greatestFiniteMagnitude))
        let emptyTextSize = self.emptyResultsTextNode.updateLayout(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - padding * 2.0, height: CGFloat.greatestFiniteMagnitude))
        
        let insets = layout.insets(options: [.input])
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
    
    private func enqueueTransition(_ transition: LocationSearchContainerTransition) {
        self.enqueuedTransitions.append(transition)
        
        if self.validLayout != nil {
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
            
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.listNode.isHidden = !transition.isSearching
                strongSelf.dimNode.isHidden = transition.isSearching
                
                strongSelf.emptyResultsTextNode.attributedText = NSAttributedString(string: strongSelf.presentationData.strings.Map_SearchNoResultsDescription(transition.query).string, font: Font.regular(15.0), textColor: strongSelf.presentationData.theme.list.freeTextColor)
                
                let emptyResults = transition.isSearching && transition.isEmpty
                strongSelf.emptyResultsTitleNode.isHidden = !emptyResults
                strongSelf.emptyResultsTextNode.isHidden = !emptyResults
                
                if let (layout, navigationBarHeight) = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                }
            })
        }
    }
    
    @objc private func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.interaction.dismissSearch()
        }
    }
}
