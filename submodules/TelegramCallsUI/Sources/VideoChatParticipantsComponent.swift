import Foundation
import UIKit
import Display
import ComponentFlow
import Postbox
import TelegramCore
import AccountContext
import PlainButtonComponent
import SwiftSignalKit
import MultilineTextComponent
import TelegramPresentationData
import PeerListItemComponent

final class VideoChatParticipantsComponent: Component {
    final class Participants: Equatable {
        let myPeerId: EnginePeer.Id
        let participants: [GroupCallParticipantsContext.Participant]
        let totalCount: Int
        let loadMoreToken: String?
        
        init(myPeerId: EnginePeer.Id, participants: [GroupCallParticipantsContext.Participant], totalCount: Int, loadMoreToken: String?) {
            self.myPeerId = myPeerId
            self.participants = participants
            self.totalCount = totalCount
            self.loadMoreToken = loadMoreToken
        }
        
        static func ==(lhs: Participants, rhs: Participants) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.myPeerId != rhs.myPeerId {
                return false
            }
            if lhs.participants != rhs.participants {
                return false
            }
            if lhs.totalCount != rhs.totalCount {
                return false
            }
            if lhs.loadMoreToken != rhs.loadMoreToken {
                return false
            }
            return true
        }
    }
    
    struct VideoParticipantKey: Hashable {
        var id: EnginePeer.Id
        var isPresentation: Bool
        
        init(id: EnginePeer.Id, isPresentation: Bool) {
            self.id = id
            self.isPresentation = isPresentation
        }
    }
    
    final class ExpandedVideoState: Equatable {
        let mainParticipant: VideoParticipantKey
        let isMainParticipantPinned: Bool
        
        init(mainParticipant: VideoParticipantKey, isMainParticipantPinned: Bool) {
            self.mainParticipant = mainParticipant
            self.isMainParticipantPinned = isMainParticipantPinned
        }
        
        static func ==(lhs: ExpandedVideoState, rhs: ExpandedVideoState) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.mainParticipant != rhs.mainParticipant {
                return false
            }
            if lhs.isMainParticipantPinned != rhs.isMainParticipantPinned {
                return false
            }
            return true
        }
    }
    
    let call: PresentationGroupCall
    let participants: Participants?
    let speakingParticipants: Set<EnginePeer.Id>
    let expandedVideoState: ExpandedVideoState?
    let theme: PresentationTheme
    let strings: PresentationStrings
    let collapsedContainerInsets: UIEdgeInsets
    let expandedContainerInsets: UIEdgeInsets
    let sideInset: CGFloat
    let updateMainParticipant: (VideoParticipantKey?) -> Void
    let updateIsMainParticipantPinned: (Bool) -> Void

    init(
        call: PresentationGroupCall,
        participants: Participants?,
        speakingParticipants: Set<EnginePeer.Id>,
        expandedVideoState: ExpandedVideoState?,
        theme: PresentationTheme,
        strings: PresentationStrings,
        collapsedContainerInsets: UIEdgeInsets,
        expandedContainerInsets: UIEdgeInsets,
        sideInset: CGFloat,
        updateMainParticipant: @escaping (VideoParticipantKey?) -> Void,
        updateIsMainParticipantPinned: @escaping (Bool) -> Void
    ) {
        self.call = call
        self.participants = participants
        self.speakingParticipants = speakingParticipants
        self.expandedVideoState = expandedVideoState
        self.theme = theme
        self.strings = strings
        self.collapsedContainerInsets = collapsedContainerInsets
        self.expandedContainerInsets = expandedContainerInsets
        self.sideInset = sideInset
        self.updateMainParticipant = updateMainParticipant
        self.updateIsMainParticipantPinned = updateIsMainParticipantPinned
    }

    static func ==(lhs: VideoChatParticipantsComponent, rhs: VideoChatParticipantsComponent) -> Bool {
        if lhs.participants != rhs.participants {
            return false
        }
        if lhs.speakingParticipants != rhs.speakingParticipants {
            return false
        }
        if lhs.expandedVideoState != rhs.expandedVideoState {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.collapsedContainerInsets != rhs.collapsedContainerInsets {
            return false
        }
        if lhs.expandedContainerInsets != rhs.expandedContainerInsets {
            return false
        }
        if lhs.sideInset != rhs.sideInset {
            return false
        }
        return true
    }
    
    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    private final class ItemLayout {
        struct Grid {
            let containerSize: CGSize
            let sideInset: CGFloat
            let itemCount: Int
            let itemSize: CGSize
            let itemSpacing: CGFloat
            let lastItemSize: CGFloat
            let itemsPerRow: Int
            
            init(containerSize: CGSize, sideInset: CGFloat, itemCount: Int) {
                self.containerSize = containerSize
                self.sideInset = sideInset
                self.itemCount = itemCount
                
                let width: CGFloat = containerSize.width - sideInset * 2.0
                
                self.itemSpacing = 4.0

                let itemsPerRow: Int
                if itemCount == 1 {
                    itemsPerRow = 1
                } else {
                    itemsPerRow = 2
                }
                self.itemsPerRow = Int(itemsPerRow)
                
                let itemWidth = floorToScreenPixels((width - (self.itemSpacing * CGFloat(self.itemsPerRow - 1))) / CGFloat(itemsPerRow))
                let itemHeight = min(180.0, itemWidth)
                self.itemSize = CGSize(width: itemWidth, height: itemHeight)

                self.lastItemSize = width - (self.itemSize.width + self.itemSpacing) * CGFloat(self.itemsPerRow - 1)
            }
            
            func frame(at index: Int) -> CGRect {
                let row = index / self.itemsPerRow
                let column = index % self.itemsPerRow
                
                let frame = CGRect(origin: CGPoint(x: self.sideInset + CGFloat(column) * (self.itemSize.width + self.itemSpacing), y: CGFloat(row) * (self.itemSize.height + self.itemSpacing)), size: CGSize(width: column == (self.itemsPerRow - 1) ? self.lastItemSize : itemSize.width, height: itemSize.height))
                return frame
            }

            func contentHeight() -> CGFloat {
                return self.frame(at: self.itemCount - 1).maxY
            }

            func visibleItemRange(for rect: CGRect) -> (minIndex: Int, maxIndex: Int) {
                if self.itemCount == 0 {
                    return (0, -1)
                }
                let offsetRect = rect.offsetBy(dx: 0.0, dy: 0.0)
                var minVisibleRow = Int(floor((offsetRect.minY - self.itemSpacing) / (self.itemSize.height + self.itemSpacing)))
                minVisibleRow = max(0, minVisibleRow)
                let maxVisibleRow = Int(ceil((offsetRect.maxY - self.itemSpacing) / (self.itemSize.height + itemSpacing)))

                let minVisibleIndex = minVisibleRow * self.itemsPerRow
                let maxVisibleIndex = min(self.itemCount - 1, (maxVisibleRow + 1) * self.itemsPerRow - 1)

                return (minVisibleIndex, maxVisibleIndex)
            }
        }
        
        struct ExpandedGrid {
            let containerSize: CGSize
            let containerInsets: UIEdgeInsets
            
            init(containerSize: CGSize, containerInsets: UIEdgeInsets) {
                self.containerSize = containerSize
                self.containerInsets = containerInsets
            }
            
            func itemContainerFrame() -> CGRect {
                return CGRect(origin: CGPoint(x: self.containerInsets.left, y: self.containerInsets.top), size: CGSize(width: self.containerSize.width - self.containerInsets.left - self.containerInsets.right, height: self.containerSize.height - self.containerInsets.top - containerInsets.bottom))
            }
        }
        
        struct List {
            let containerSize: CGSize
            let sideInset: CGFloat
            let itemCount: Int
            let itemHeight: CGFloat
            let trailingItemHeight: CGFloat
            
            init(containerSize: CGSize, sideInset: CGFloat, itemCount: Int, itemHeight: CGFloat, trailingItemHeight: CGFloat) {
                self.containerSize = containerSize
                self.sideInset = sideInset
                self.itemCount = itemCount
                self.itemHeight = itemHeight
                self.trailingItemHeight = trailingItemHeight
            }
            
            func frame(at index: Int) -> CGRect {
                let frame = CGRect(origin: CGPoint(x: self.sideInset, y: CGFloat(index) * self.itemHeight), size: CGSize(width: self.containerSize.width - self.sideInset * 2.0, height: self.itemHeight))
                return frame
            }
            
            func trailingItemFrame() -> CGRect {
                return CGRect(origin: CGPoint(x: self.sideInset, y: CGFloat(self.itemCount) * self.itemHeight), size: CGSize(width: self.containerSize.width - self.sideInset * 2.0, height: self.trailingItemHeight))
            }

            func contentHeight() -> CGFloat {
                var result: CGFloat = 0.0
                if self.itemCount != 0 {
                    result = self.frame(at: self.itemCount - 1).maxY
                }
                result += self.trailingItemHeight
                return result
            }
            
            func visibleItemRange(for rect: CGRect) -> (minIndex: Int, maxIndex: Int) {
                if self.itemCount == 0 {
                    return (0, -1)
                }
                let offsetRect = rect.offsetBy(dx: 0.0, dy: 0.0)
                var minVisibleRow = Int(floor((offsetRect.minY) / (self.itemHeight)))
                minVisibleRow = max(0, minVisibleRow)
                let maxVisibleRow = Int(ceil((offsetRect.maxY) / (self.itemHeight)))

                let minVisibleIndex = minVisibleRow
                let maxVisibleIndex = min(self.itemCount - 1, (maxVisibleRow + 1) - 1)

                return (minVisibleIndex, maxVisibleIndex)
            }
        }
        
        let containerSize: CGSize
        let collapsedContainerInsets: UIEdgeInsets
        let sideInset: CGFloat
        let grid: Grid
        let expandedGrid: ExpandedGrid
        let list: List
        let spacing: CGFloat
        let gridOffsetY: CGFloat
        let listOffsetY: CGFloat

        init(containerSize: CGSize, sideInset: CGFloat, collapsedContainerInsets: UIEdgeInsets, expandedContainerInsets: UIEdgeInsets, gridItemCount: Int, listItemCount: Int, listItemHeight: CGFloat, listTrailingItemHeight: CGFloat) {
            self.containerSize = containerSize
            self.collapsedContainerInsets = collapsedContainerInsets
            self.sideInset = sideInset
            
            self.grid = Grid(containerSize: CGSize(width: containerSize.width - sideInset * 2.0, height: containerSize.height), sideInset: 0.0, itemCount: gridItemCount)
            self.expandedGrid = ExpandedGrid(containerSize: containerSize, containerInsets: expandedContainerInsets)
            self.list = List(containerSize: CGSize(width: containerSize.width - sideInset * 2.0, height: containerSize.height), sideInset: 0.0, itemCount: listItemCount, itemHeight: listItemHeight, trailingItemHeight: listTrailingItemHeight)
            self.spacing = 4.0
            
            self.gridOffsetY = collapsedContainerInsets.top
            
            var listOffsetY: CGFloat = self.gridOffsetY
            if self.grid.itemCount != 0 {
                listOffsetY += self.grid.contentHeight()
                listOffsetY += self.spacing
            }
            self.listOffsetY = listOffsetY
        }

        func contentHeight() -> CGFloat {
            var result: CGFloat = self.gridOffsetY
            if self.grid.itemCount != 0 {
                result += self.grid.contentHeight()
                result += self.spacing
            }
            result += self.list.contentHeight()
            result += self.collapsedContainerInsets.bottom
            result += 32.0
            return result
        }
        
        func visibleGridItemRange(for rect: CGRect) -> (minIndex: Int, maxIndex: Int) {
            return self.grid.visibleItemRange(for: rect.offsetBy(dx: 0.0, dy: -self.gridOffsetY))
        }
        
        func gridItemFrame(at index: Int) -> CGRect {
            return self.grid.frame(at: index)
        }
        
        func gridItemContainerFrame() -> CGRect {
            return CGRect(origin: CGPoint(x: self.sideInset, y: self.gridOffsetY), size: CGSize(width: self.containerSize.width - self.sideInset * 2.0, height: self.grid.contentHeight()))
        }
        
        func visibleListItemRange(for rect: CGRect) -> (minIndex: Int, maxIndex: Int) {
            return self.list.visibleItemRange(for: rect.offsetBy(dx: 0.0, dy: -self.listOffsetY))
        }
        
        func listItemFrame(at index: Int) -> CGRect {
            return self.list.frame(at: index)
        }
        
        func listItemContainerFrame() -> CGRect {
            return CGRect(origin: CGPoint(x: self.sideInset, y: self.listOffsetY), size: CGSize(width: self.containerSize.width - self.sideInset * 2.0, height: self.list.contentHeight()))
        }
        
        func listTrailingItemFrame() -> CGRect {
            return self.list.trailingItemFrame()
        }
    }
    
    private final class VideoParticipant: Equatable {
        let participant: GroupCallParticipantsContext.Participant
        let isPresentation: Bool
        
        var key: VideoParticipantKey {
            return VideoParticipantKey(id: self.participant.peer.id, isPresentation: self.isPresentation)
        }
        
        init(participant: GroupCallParticipantsContext.Participant, isPresentation: Bool) {
            self.participant = participant
            self.isPresentation = isPresentation
        }
        
        static func ==(lhs: VideoParticipant, rhs: VideoParticipant) -> Bool {
            if lhs.participant != rhs.participant {
                return false
            }
            if lhs.isPresentation != rhs.isPresentation {
                return false
            }
            return true
        }
    }
    
    private final class GridItem {
        let key: VideoParticipantKey
        let view = ComponentView<Empty>()
        var isCollapsing: Bool = false
        
        init(key: VideoParticipantKey) {
            self.key = key
        }
    }
    
    private final class ListItem {
        let view = ComponentView<Empty>()
        let separatorLayer = SimpleLayer()
        
        init() {
        }
    }

    final class View: UIView, UIScrollViewDelegate {
        private let scrollViewClippingContainer: SolidRoundedCornersContainer
        private let scrollView: ScrollView
        private let scrollViewClippingShadowView: UIImageView
        
        private var component: VideoChatParticipantsComponent?
        private var isUpdating: Bool = false
        
        private var ignoreScrolling: Bool = false
        
        private var gridParticipants: [VideoParticipant] = []
        private var listParticipants: [GroupCallParticipantsContext.Participant] = []
        
        private let measureListItemView = ComponentView<Empty>()
        private let inviteListItemView = ComponentView<Empty>()
        
        private var gridItemViews: [VideoParticipantKey: GridItem] = [:]
        private let gridItemViewContainer: UIView
        
        private let expandedGridItemContainer: UIView
        private var expandedControlsView: ComponentView<Empty>?
        private var expandedThumbnailsView: ComponentView<Empty>?
        
        private var listItemViews: [EnginePeer.Id: ListItem] = [:]
        private let listItemViewContainer: UIView
        private let listItemViewSeparatorContainer: SimpleLayer
        private let listItemsBackground = ComponentView<Empty>()
        
        private var itemLayout: ItemLayout?
        
        private var appliedGridIsEmpty: Bool = true
        
        override init(frame: CGRect) {
            self.scrollViewClippingContainer = SolidRoundedCornersContainer()
            self.scrollViewClippingShadowView = UIImageView()
            
            self.scrollView = ScrollView()
            
            self.gridItemViewContainer = UIView()
            self.gridItemViewContainer.layer.anchorPoint = CGPoint(x: 0.5, y: 0.0)
            
            self.listItemViewContainer = UIView()
            self.listItemViewContainer.clipsToBounds = true
            self.listItemViewSeparatorContainer = SimpleLayer()
            
            self.expandedGridItemContainer = UIView()
            self.expandedGridItemContainer.clipsToBounds = true
            
            super.init(frame: frame)
            
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.clipsToBounds = false
            self.scrollView.contentInsetAdjustmentBehavior = .never
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.alwaysBounceVertical = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            
            self.scrollViewClippingContainer.addSubview(self.scrollView)
            self.addSubview(self.scrollViewClippingContainer)
            self.addSubview(self.scrollViewClippingContainer.cornersView)
            self.addSubview(self.scrollViewClippingShadowView)
            
            self.scrollView.addSubview(self.listItemViewContainer)
            self.scrollView.addSubview(self.gridItemViewContainer)
            self.addSubview(self.expandedGridItemContainer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard let component = self.component else {
                return nil
            }
            
            if component.expandedVideoState != nil {
                if let result = self.expandedGridItemContainer.hitTest(self.convert(point, to: self.expandedGridItemContainer), with: event) {
                    return result
                } else {
                    return self
                }
            } else {
                if let result = self.scrollViewClippingContainer.hitTest(self.convert(point, to: self.scrollViewClippingContainer), with: event) {
                    return result
                } else {
                    return nil
                }
            }
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        private func updateScrolling(transition: ComponentTransition) {
            guard let component = self.component, let itemLayout = self.itemLayout else {
                return
            }
            
            let gridWasEmpty = self.appliedGridIsEmpty
            let gridIsEmpty = self.gridParticipants.isEmpty
            self.appliedGridIsEmpty = gridIsEmpty
            
            var previousExpandedItemId: VideoParticipantKey?
            for (key, item) in self.gridItemViews {
                if item.view.view?.superview == self.expandedGridItemContainer {
                    previousExpandedItemId = key
                    break
                }
            }
            
            let previousExpandedGridItemContainerFrame = self.expandedGridItemContainer.frame
            var expandedGridItemContainerFrame: CGRect
            if component.expandedVideoState != nil {
                expandedGridItemContainerFrame = itemLayout.expandedGrid.itemContainerFrame()
            } else {
                expandedGridItemContainerFrame = itemLayout.gridItemContainerFrame().offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                if expandedGridItemContainerFrame.origin.y < component.collapsedContainerInsets.top {
                    expandedGridItemContainerFrame.size.height -= component.collapsedContainerInsets.top - expandedGridItemContainerFrame.origin.y
                    expandedGridItemContainerFrame.origin.y = component.collapsedContainerInsets.top
                }
                if expandedGridItemContainerFrame.origin.y + expandedGridItemContainerFrame.height > itemLayout.containerSize.height - component.collapsedContainerInsets.bottom {
                    expandedGridItemContainerFrame.size.height -= (expandedGridItemContainerFrame.origin.y + expandedGridItemContainerFrame.height) - (itemLayout.containerSize.height - component.collapsedContainerInsets.bottom)
                }
                if expandedGridItemContainerFrame.size.height < 0.0 {
                    expandedGridItemContainerFrame.size.height = 0.0
                }
            }
            
            let commonGridItemTransition: ComponentTransition = (gridIsEmpty == gridWasEmpty) ? transition : .immediate
            
            var validGridItemIds: [VideoParticipantKey] = []
            var validGridItemIndices: [Int] = []
            
            let visibleGridItemRange = itemLayout.visibleGridItemRange(for: self.scrollView.bounds)
            if visibleGridItemRange.maxIndex >= visibleGridItemRange.minIndex {
                for index in visibleGridItemRange.minIndex ... visibleGridItemRange.maxIndex {
                    let videoParticipant = self.gridParticipants[index]
                    let videoParticipantKey = videoParticipant.key
                    validGridItemIds.append(videoParticipantKey)
                    validGridItemIndices.append(index)
                }
            }
            if let expandedVideoState = component.expandedVideoState {
                if !validGridItemIds.contains(expandedVideoState.mainParticipant), let index = self.gridParticipants.firstIndex(where: { $0.key == expandedVideoState.mainParticipant }) {
                    validGridItemIds.append(expandedVideoState.mainParticipant)
                    validGridItemIndices.append(index)
                }
            }
             
            for index in validGridItemIndices {
                let videoParticipant = self.gridParticipants[index]
                let videoParticipantKey = videoParticipant.key
                validGridItemIds.append(videoParticipantKey)
                
                var itemTransition = commonGridItemTransition
                let itemView: GridItem
                if let current = self.gridItemViews[videoParticipantKey] {
                    itemView = current
                } else {
                    itemTransition = itemTransition.withAnimation(.none)
                    itemView = GridItem(key: videoParticipant.key)
                    self.gridItemViews[videoParticipantKey] = itemView
                }
                
                var isItemExpanded = false
                if let expandedVideoState = component.expandedVideoState, expandedVideoState.mainParticipant == videoParticipantKey {
                    isItemExpanded = true
                }
                
                var suppressItemExpansionCollapseAnimation = false
                if isItemExpanded {
                    if let previousExpandedItemId, previousExpandedItemId != videoParticipantKey {
                        suppressItemExpansionCollapseAnimation = true
                    }
                } else if component.expandedVideoState != nil {
                    if let previousExpandedItemId, previousExpandedItemId == videoParticipantKey {
                        suppressItemExpansionCollapseAnimation = true
                    }
                }
                var resultingItemTransition = commonGridItemTransition
                if suppressItemExpansionCollapseAnimation {
                    itemTransition = itemTransition.withAnimation(.none)
                    resultingItemTransition = commonGridItemTransition.withAnimation(.none)
                }
                
                let itemFrame: CGRect
                if isItemExpanded {
                    itemFrame = CGRect(origin: CGPoint(), size: itemLayout.expandedGrid.itemContainerFrame().size)
                } else {
                    itemFrame = itemLayout.gridItemFrame(at: index)
                }
                
                let _ = itemView.view.update(
                    transition: itemTransition,
                    component: AnyComponent(VideoChatParticipantVideoComponent(
                        call: component.call,
                        participant: videoParticipant.participant,
                        isPresentation: videoParticipant.isPresentation,
                        isSpeaking: component.speakingParticipants.contains(videoParticipant.participant.peer.id),
                        isExpanded: isItemExpanded,
                        bottomInset: isItemExpanded ? 96.0 : 0.0,
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            if component.expandedVideoState?.mainParticipant == videoParticipantKey {
                                component.updateMainParticipant(nil)
                            } else {
                                component.updateMainParticipant(videoParticipantKey)
                            }
                        }
                    )),
                    environment: {},
                    containerSize: itemFrame.size
                )
                if let itemComponentView = itemView.view.view {
                    if itemComponentView.superview == nil {
                        if isItemExpanded {
                            if let expandedThumbnailsView = self.expandedThumbnailsView?.view {
                                self.expandedGridItemContainer.insertSubview(itemComponentView, belowSubview: expandedThumbnailsView)
                            } else {
                                self.expandedGridItemContainer.addSubview(itemComponentView)
                            }
                        } else {
                            self.gridItemViewContainer.addSubview(itemComponentView)
                        }
                        
                        itemComponentView.frame = itemFrame
                        
                        if !resultingItemTransition.animation.isImmediate {
                            resultingItemTransition.animateScale(view: itemComponentView, from: 0.001, to: 1.0)
                        }
                        if !resultingItemTransition.animation.isImmediate {
                            itemComponentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                        }
                    } else if isItemExpanded && itemComponentView.superview != self.expandedGridItemContainer {
                        let fromFrame = itemComponentView.convert(itemComponentView.bounds, to: self.expandedGridItemContainer)
                        itemComponentView.center = fromFrame.center
                        if let expandedThumbnailsView = self.expandedThumbnailsView?.view {
                            self.expandedGridItemContainer.insertSubview(itemComponentView, belowSubview: expandedThumbnailsView)
                        } else {
                            self.expandedGridItemContainer.addSubview(itemComponentView)
                        }
                    } else if !isItemExpanded && itemComponentView.superview != self.gridItemViewContainer {
                        if suppressItemExpansionCollapseAnimation {
                            self.gridItemViewContainer.addSubview(itemComponentView)
                        } else if !itemView.isCollapsing {
                            itemView.isCollapsing = true
                            let targetLocalItemFrame = itemLayout.gridItemFrame(at: index)
                            var targetItemFrame = self.gridItemViewContainer.convert(targetLocalItemFrame, to: self)
                            targetItemFrame.origin.y -= expandedGridItemContainerFrame.minY
                            targetItemFrame.origin.x -= expandedGridItemContainerFrame.minX
                            commonGridItemTransition.setPosition(view: itemComponentView, position: targetItemFrame.center)
                            commonGridItemTransition.setBounds(view: itemComponentView, bounds: CGRect(origin: CGPoint(), size: targetItemFrame.size), completion: { [weak self, weak itemView, weak itemComponentView] _ in
                                guard let self, let itemView, let itemComponentView else {
                                    return
                                }
                                itemView.isCollapsing = false
                                self.gridItemViewContainer.addSubview(itemComponentView)
                                itemComponentView.center = targetLocalItemFrame.center
                                itemComponentView.bounds = CGRect(origin: CGPoint(), size: targetLocalItemFrame.size)
                            })
                        }
                    }
                    if !itemView.isCollapsing {
                        resultingItemTransition.setPosition(view: itemComponentView, position: itemFrame.center)
                        resultingItemTransition.setBounds(view: itemComponentView, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
                    }
                }
            }
            
            var removedGridItemIds: [VideoParticipantKey] = []
            for (itemId, itemView) in self.gridItemViews {
                if !validGridItemIds.contains(itemId) {
                    removedGridItemIds.append(itemId)
                    
                    if let itemComponentView = itemView.view.view {
                        if !transition.animation.isImmediate {
                            if commonGridItemTransition.animation.isImmediate == transition.animation.isImmediate {
                                transition.setScale(view: itemComponentView, scale: 0.001)
                            }
                            itemComponentView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak itemComponentView] _ in
                                itemComponentView?.removeFromSuperview()
                            })
                        } else {
                            itemComponentView.removeFromSuperview()
                        }
                    }
                }
            }
            for itemId in removedGridItemIds {
                self.gridItemViews.removeValue(forKey: itemId)
            }
            
            var validListItemIds: [EnginePeer.Id] = []
            let visibleListItemRange = itemLayout.visibleListItemRange(for: self.scrollView.bounds)
            if visibleListItemRange.maxIndex >= visibleListItemRange.minIndex {
                for i in visibleListItemRange.minIndex ... visibleListItemRange.maxIndex {
                    let participant = self.listParticipants[i]
                    validListItemIds.append(participant.peer.id)
                    
                    var itemTransition = transition
                    let itemView: ListItem
                    if let current = self.listItemViews[participant.peer.id] {
                        itemView = current
                    } else {
                        itemTransition = itemTransition.withAnimation(.none)
                        itemView = ListItem()
                        self.listItemViews[participant.peer.id] = itemView
                    }
                    
                    let itemFrame = itemLayout.listItemFrame(at: i)
                    
                    let subtitle: PeerListItemComponent.Subtitle
                    if participant.peer.id == component.call.accountContext.account.peerId {
                        subtitle = PeerListItemComponent.Subtitle(text: "this is you", color: .accent)
                    } else if component.speakingParticipants.contains(participant.peer.id) {
                        subtitle = PeerListItemComponent.Subtitle(text: "speaking", color: .constructive)
                    } else {
                        subtitle = PeerListItemComponent.Subtitle(text: participant.about ?? "listening", color: .neutral)
                    }
                    
                    let rightAccessoryComponent: AnyComponent<Empty> = AnyComponent(VideoChatParticipantStatusComponent(
                        isMuted: participant.muteState != nil,
                        isSpeaking: component.speakingParticipants.contains(participant.peer.id),
                        theme: component.theme
                    ))
                    
                    let _ = itemView.view.update(
                        transition: itemTransition,
                        component: AnyComponent(PeerListItemComponent(
                            context: component.call.accountContext,
                            theme: component.theme,
                            strings: component.strings,
                            style: .generic,
                            sideInset: 0.0,
                            title: EnginePeer(participant.peer).displayTitle(strings: component.strings, displayOrder: .firstLast),
                            avatarComponent: AnyComponent(VideoChatParticipantAvatarComponent(
                                call: component.call,
                                peer: EnginePeer(participant.peer),
                                isSpeaking: component.speakingParticipants.contains(participant.peer.id),
                                theme: component.theme
                            )),
                            peer: EnginePeer(participant.peer),
                            subtitle: subtitle,
                            subtitleAccessory: .none,
                            presence: nil,
                            rightAccessoryComponent: rightAccessoryComponent,
                            selectionState: .none,
                            hasNext: false,
                            action: { [weak self] peer, _, _ in
                                guard let self else {
                                    return
                                }
                                let _ = self
                                let _ = peer
                            }
                        )),
                        environment: {},
                        containerSize: itemFrame.size
                    )
                    let itemSeparatorFrame = CGRect(origin: CGPoint(x: itemFrame.minX + 63.0, y: itemFrame.maxY - UIScreenPixel), size: CGSize(width: itemFrame.width - 63.0, height: UIScreenPixel))
                    if let itemComponentView = itemView.view.view {
                        if itemComponentView.superview == nil {
                            itemComponentView.clipsToBounds = true
                            
                            itemView.separatorLayer.backgroundColor = component.theme.list.itemBlocksSeparatorColor.blitOver(UIColor(white: 0.1, alpha: 1.0), alpha: 1.0).cgColor
                            
                            self.listItemViewContainer.addSubview(itemComponentView)
                            self.listItemViewSeparatorContainer.addSublayer(itemView.separatorLayer)
                            
                            if !transition.animation.isImmediate {
                                itemComponentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                                itemComponentView.frame = CGRect(origin: itemFrame.origin, size: CGSize(width: itemFrame.width, height: 0.0))
                                
                                var startingItemSeparatorFrame = itemSeparatorFrame
                                startingItemSeparatorFrame.origin.y = itemFrame.minY - UIScreenPixel
                                itemView.separatorLayer.frame = startingItemSeparatorFrame
                            }
                        }
                        transition.setFrame(view: itemComponentView, frame: itemFrame)
                        transition.setFrame(layer: itemView.separatorLayer, frame: itemSeparatorFrame)
                    }
                }
            }
            
            var removedListItemIds: [EnginePeer.Id] = []
            for (itemId, itemView) in self.listItemViews {
                if !validListItemIds.contains(itemId) {
                    removedListItemIds.append(itemId)
                    
                    if let itemComponentView = itemView.view.view {
                        let itemSeparatorLayer = itemView.separatorLayer
                        
                        if !transition.animation.isImmediate {
                            var itemFrame = itemComponentView.frame
                            itemFrame.size.height = 0.0
                            transition.setFrame(view: itemComponentView, frame: itemFrame)
                            var itemSeparatorFrame = itemSeparatorLayer.frame
                            itemSeparatorFrame.origin.y = itemFrame.minY - UIScreenPixel
                            transition.setFrame(layer: itemSeparatorLayer, frame: itemSeparatorFrame, completion: { [weak itemSeparatorLayer] _ in
                                itemSeparatorLayer?.removeFromSuperlayer()
                            })
                            itemComponentView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak itemComponentView] _ in
                                itemComponentView?.removeFromSuperview()
                            })
                        } else {
                            itemComponentView.removeFromSuperview()
                            itemSeparatorLayer.removeFromSuperlayer()
                        }
                    }
                }
            }
            for itemId in removedListItemIds {
                self.listItemViews.removeValue(forKey: itemId)
            }
            
            do {
                var itemTransition = transition
                let itemView = self.inviteListItemView
                
                let itemFrame = itemLayout.listTrailingItemFrame()
                
                if let itemComponentView = itemView.view {
                    if itemComponentView.superview == nil {
                        itemTransition = itemTransition.withAnimation(.none)
                        self.listItemViewContainer.addSubview(itemComponentView)
                    }
                    itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
                }
            }
            
            transition.setScale(view: self.gridItemViewContainer, scale: gridIsEmpty ? 0.001 : 1.0)
            transition.setPosition(view: self.gridItemViewContainer, position: CGPoint(x: itemLayout.gridItemContainerFrame().midX, y: itemLayout.gridItemContainerFrame().minY))
            transition.setBounds(view: self.gridItemViewContainer, bounds: CGRect(origin: CGPoint(), size: itemLayout.gridItemContainerFrame().size))
            transition.setFrame(view: self.listItemViewContainer, frame: itemLayout.listItemContainerFrame())
            transition.setFrame(layer: self.listItemViewSeparatorContainer, frame: CGRect(origin: CGPoint(), size: itemLayout.listItemContainerFrame().size))
            
            if self.expandedGridItemContainer.frame != expandedGridItemContainerFrame {
                self.expandedGridItemContainer.layer.cornerRadius = 10.0
                
                transition.setFrame(view: self.expandedGridItemContainer, frame: expandedGridItemContainerFrame, completion: { [weak self] completed in
                    guard let self, completed else {
                        return
                    }
                    self.expandedGridItemContainer.layer.cornerRadius = 0.0
                })
            }
            
            if let expandedVideoState = component.expandedVideoState {
                var thumbnailParticipants: [VideoChatExpandedParticipantThumbnailsComponent.Participant] = []
                for participant in self.gridParticipants {
                    thumbnailParticipants.append(VideoChatExpandedParticipantThumbnailsComponent.Participant(
                        participant: participant.participant,
                        isPresentation: participant.isPresentation
                    ))
                }
                /*for participant in self.listParticipants {
                    thumbnailParticipants.append(VideoChatExpandedParticipantThumbnailsComponent.Participant(
                        participant: participant,
                        isPresentation: false
                    ))
                }*/
                
                var expandedThumbnailsTransition = transition
                let expandedThumbnailsView: ComponentView<Empty>
                if let current = self.expandedThumbnailsView {
                    expandedThumbnailsView = current
                } else {
                    expandedThumbnailsTransition = expandedThumbnailsTransition.withAnimation(.none)
                    expandedThumbnailsView = ComponentView()
                    self.expandedThumbnailsView = expandedThumbnailsView
                }
                let expandedThumbnailsSize = expandedThumbnailsView.update(
                    transition: expandedThumbnailsTransition,
                    component: AnyComponent(VideoChatExpandedParticipantThumbnailsComponent(
                        call: component.call,
                        theme: component.theme,
                        participants: thumbnailParticipants,
                        selectedParticipant: component.expandedVideoState.flatMap { expandedVideoState in
                            return VideoChatExpandedParticipantThumbnailsComponent.Participant.Key(id: expandedVideoState.mainParticipant.id, isPresentation: expandedVideoState.mainParticipant.isPresentation)
                        },
                        speakingParticipants: component.speakingParticipants,
                        updateSelectedParticipant: { [weak self] key in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.updateMainParticipant(VideoParticipantKey(id: key.id, isPresentation: key.isPresentation))
                        }
                    )),
                    environment: {},
                    containerSize: itemLayout.expandedGrid.itemContainerFrame().size
                )
                let expandedThumbnailsFrame = CGRect(origin: CGPoint(x: 0.0, y: expandedGridItemContainerFrame.height - expandedThumbnailsSize.height), size: expandedThumbnailsSize)
                if let expandedThumbnailsComponentView = expandedThumbnailsView.view {
                    if expandedThumbnailsComponentView.superview == nil {
                        self.expandedGridItemContainer.addSubview(expandedThumbnailsComponentView)
                        
                        let fromReferenceFrame: CGRect
                        if let index = self.gridParticipants.firstIndex(where: { $0.participant.peer.id ==  expandedVideoState.mainParticipant.id && $0.isPresentation == expandedVideoState.mainParticipant.isPresentation }) {
                            fromReferenceFrame = self.gridItemViewContainer.convert(itemLayout.gridItemFrame(at: index), to: self.expandedGridItemContainer)
                        } else {
                            fromReferenceFrame = previousExpandedGridItemContainerFrame
                        }
                        
                        expandedThumbnailsComponentView.frame = CGRect(origin: CGPoint(x: fromReferenceFrame.minX - previousExpandedGridItemContainerFrame.minX, y: fromReferenceFrame.maxY - expandedThumbnailsSize.height), size: expandedThumbnailsFrame.size)
                        
                        if !transition.animation.isImmediate {
                            expandedThumbnailsComponentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                        }
                    }
                    transition.setFrame(view: expandedThumbnailsComponentView, frame: expandedThumbnailsFrame)
                }
                
                var expandedControlsTransition = transition
                let expandedControlsView: ComponentView<Empty>
                if let current = self.expandedControlsView {
                    expandedControlsView = current
                } else {
                    expandedControlsTransition = expandedControlsTransition.withAnimation(.none)
                    expandedControlsView = ComponentView()
                    self.expandedControlsView = expandedControlsView
                }
                let expandedControlsSize = expandedControlsView.update(
                    transition: expandedControlsTransition,
                    component: AnyComponent(VideoChatExpandedControlsComponent(
                        theme: component.theme,
                        strings: component.strings,
                        backAction: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.updateMainParticipant(nil)
                        }
                    )),
                    environment: {},
                    containerSize: itemLayout.expandedGrid.itemContainerFrame().size
                )
                let expandedControlsFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: expandedControlsSize)
                if let expandedControlsComponentView = expandedControlsView.view {
                    if expandedControlsComponentView.superview == nil {
                        self.expandedGridItemContainer.addSubview(expandedControlsComponentView)
                        
                        let fromReferenceFrame: CGRect
                        if let index = self.gridParticipants.firstIndex(where: { $0.participant.peer.id ==  expandedVideoState.mainParticipant.id && $0.isPresentation == expandedVideoState.mainParticipant.isPresentation }) {
                            fromReferenceFrame = self.gridItemViewContainer.convert(itemLayout.gridItemFrame(at: index), to: self.expandedGridItemContainer)
                        } else {
                            fromReferenceFrame = previousExpandedGridItemContainerFrame
                        }
                        
                        expandedControlsComponentView.frame = CGRect(origin: CGPoint(x: fromReferenceFrame.minX - previousExpandedGridItemContainerFrame.minX, y: fromReferenceFrame.minY - previousExpandedGridItemContainerFrame.minY), size: expandedControlsFrame.size)
                        
                        if !transition.animation.isImmediate {
                            expandedControlsComponentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                        }
                    }
                    transition.setFrame(view: expandedControlsComponentView, frame: expandedControlsFrame)
                }
            } else {
                if let expandedThumbnailsView = self.expandedThumbnailsView {
                    self.expandedThumbnailsView = nil
                    
                    if transition.containedViewLayoutTransition.isAnimated, let expandedThumbnailsComponentView = expandedThumbnailsView.view {
                        if let collapsingItemView = self.gridItemViews.values.first(where: { $0.isCollapsing }), let index = self.gridParticipants.firstIndex(where: { $0.participant.peer.id ==  collapsingItemView.key.id && $0.isPresentation == collapsingItemView.key.isPresentation }) {
                            let targetLocalItemFrame = itemLayout.gridItemFrame(at: index)
                            var targetItemFrame = self.gridItemViewContainer.convert(targetLocalItemFrame, to: self)
                            targetItemFrame.origin.y -= expandedGridItemContainerFrame.minY
                            targetItemFrame.origin.x -= expandedGridItemContainerFrame.minX
                            
                            let targetThumbnailsFrame = CGRect(origin: CGPoint(x: targetItemFrame.minX, y: targetItemFrame.maxY - expandedThumbnailsComponentView.bounds.height), size: expandedThumbnailsComponentView.bounds.size)
                            transition.setFrame(view: expandedThumbnailsComponentView, frame: targetThumbnailsFrame)
                        }
                        expandedThumbnailsComponentView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.12, removeOnCompletion: false, completion: { [weak expandedThumbnailsComponentView] _ in
                            expandedThumbnailsComponentView?.removeFromSuperview()
                        })
                    } else {
                        expandedThumbnailsView.view?.removeFromSuperview()
                    }
                }
                
                if let expandedControlsView = self.expandedControlsView {
                    self.expandedControlsView = nil
                    
                    if transition.containedViewLayoutTransition.isAnimated, let expandedControlsComponentView = expandedControlsView.view {
                        if let collapsingItemView = self.gridItemViews.values.first(where: { $0.isCollapsing }), let index = self.gridParticipants.firstIndex(where: { $0.participant.peer.id ==  collapsingItemView.key.id && $0.isPresentation == collapsingItemView.key.isPresentation }) {
                            let targetLocalItemFrame = itemLayout.gridItemFrame(at: index)
                            var targetItemFrame = self.gridItemViewContainer.convert(targetLocalItemFrame, to: self)
                            targetItemFrame.origin.y -= expandedGridItemContainerFrame.minY
                            targetItemFrame.origin.x -= expandedGridItemContainerFrame.minX
                            
                            let targetThumbnailsFrame = CGRect(origin: CGPoint(x: targetItemFrame.minX, y: targetItemFrame.minY), size: expandedControlsComponentView.bounds.size)
                            transition.setFrame(view: expandedControlsComponentView, frame: targetThumbnailsFrame)
                        }
                        expandedControlsComponentView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.12, removeOnCompletion: false, completion: { [weak expandedControlsComponentView] _ in
                            expandedControlsComponentView?.removeFromSuperview()
                        })
                    } else {
                        expandedControlsView.view?.removeFromSuperview()
                    }
                }
            }
        }
        
        func update(component: VideoChatParticipantsComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            
            let measureListItemSize = self.measureListItemView.update(
                transition: .immediate,
                component: AnyComponent(PeerListItemComponent(
                    context: component.call.accountContext,
                    theme: component.theme,
                    strings: component.strings,
                    style: .generic,
                    sideInset: 0.0,
                    title: "AAA",
                    peer: nil,
                    subtitle: PeerListItemComponent.Subtitle(text: "bbb", color: .neutral),
                    subtitleAccessory: .none,
                    presence: nil,
                    selectionState: .none,
                    hasNext: true,
                    action: { _, _, _ in
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 1000.0)
            )
            
            let inviteListItemSize = self.inviteListItemView.update(
                transition: transition,
                component: AnyComponent(VideoChatListInviteComponent(
                    title: "Invite Members",
                    theme: component.theme
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 1000.0)
            )
            
            var gridParticipants: [VideoParticipant] = []
            var listParticipants: [GroupCallParticipantsContext.Participant] = []
            if let participants = component.participants {
                for participant in participants.participants {
                    var hasVideo = false
                    if participant.videoDescription != nil {
                        hasVideo = true
                        let videoParticipant = VideoParticipant(participant: participant, isPresentation: false)
                        if participant.peer.id == component.call.accountContext.account.peerId || participant.peer.id == participants.myPeerId {
                            gridParticipants.insert(videoParticipant, at: 0)
                        } else {
                            gridParticipants.append(videoParticipant)
                        }
                    }
                    if participant.presentationDescription != nil {
                        hasVideo = true
                        let videoParticipant = VideoParticipant(participant: participant, isPresentation: true)
                        if participant.peer.id == component.call.accountContext.account.peerId {
                            gridParticipants.insert(videoParticipant, at: 0)
                        } else {
                            gridParticipants.append(videoParticipant)
                        }
                    }
                    if !hasVideo {
                        if participant.peer.id == component.call.accountContext.account.peerId {
                            listParticipants.insert(participant, at: 0)
                        } else {
                            listParticipants.append(participant)
                        }
                    }
                }
            }
            self.gridParticipants = gridParticipants
            self.listParticipants = listParticipants
            
            let itemLayout = ItemLayout(
                containerSize: availableSize,
                sideInset: component.sideInset,
                collapsedContainerInsets: component.collapsedContainerInsets,
                expandedContainerInsets: component.expandedContainerInsets,
                gridItemCount: gridParticipants.count,
                listItemCount: listParticipants.count,
                listItemHeight: measureListItemSize.height,
                listTrailingItemHeight: inviteListItemSize.height
            )
            self.itemLayout = itemLayout
            
            let listItemsBackgroundSize = self.listItemsBackground.update(
                transition: transition,
                component: AnyComponent(RoundedRectangle(
                    color: UIColor(white: 0.1, alpha: 1.0),
                    cornerRadius: 10.0
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - itemLayout.sideInset * 2.0, height: itemLayout.list.contentHeight())
            )
            let listItemsBackgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: listItemsBackgroundSize)
            if let listItemsBackgroundView = self.listItemsBackground.view {
                if listItemsBackgroundView.superview == nil {
                    self.listItemViewContainer.addSubview(listItemsBackgroundView)
                    self.listItemViewContainer.layer.addSublayer(self.listItemViewSeparatorContainer)
                }
                transition.setFrame(view: listItemsBackgroundView, frame: listItemsBackgroundFrame)
            }
            
            var requestedVideo: [PresentationGroupCallRequestedVideo] = []
            if let participants = component.participants {
                for participant in participants.participants {
                    var maxVideoQuality: PresentationGroupCallRequestedVideo.Quality = .medium
                    if let expandedVideoState = component.expandedVideoState {
                        if expandedVideoState.mainParticipant.id == participant.peer.id, !expandedVideoState.mainParticipant.isPresentation {
                            maxVideoQuality = .full
                        } else {
                            maxVideoQuality = .thumbnail
                        }
                    }
                    
                    var maxPresentationQuality: PresentationGroupCallRequestedVideo.Quality = .medium
                    if let expandedVideoState = component.expandedVideoState {
                        if expandedVideoState.mainParticipant.id == participant.peer.id, expandedVideoState.mainParticipant.isPresentation {
                            maxPresentationQuality = .full
                        } else {
                            maxPresentationQuality = .thumbnail
                        }
                    }
                    
                    if let videoChannel = participant.requestedVideoChannel(minQuality: .thumbnail, maxQuality: maxVideoQuality) {
                        if !requestedVideo.contains(videoChannel) {
                            requestedVideo.append(videoChannel)
                        }
                    }
                    if let videoChannel = participant.requestedPresentationVideoChannel(minQuality: .thumbnail, maxQuality: maxPresentationQuality) {
                        if !requestedVideo.contains(videoChannel) {
                            requestedVideo.append(videoChannel)
                        }
                    }
                }
            }
            (component.call as! PresentationGroupCallImpl).setRequestedVideoList(items: requestedVideo)
            
            let scrollClippingFrame = CGRect(origin: CGPoint(x: itemLayout.sideInset, y: component.collapsedContainerInsets.top), size: CGSize(width: availableSize.width - itemLayout.sideInset * 2.0, height: availableSize.height - component.collapsedContainerInsets.top - component.collapsedContainerInsets.bottom))
            transition.setPosition(view: self.scrollViewClippingContainer, position: scrollClippingFrame.center)
            transition.setBounds(view: self.scrollViewClippingContainer, bounds: CGRect(origin: CGPoint(x: scrollClippingFrame.minX, y: scrollClippingFrame.minY), size: scrollClippingFrame.size))
            transition.setFrame(view: self.scrollViewClippingContainer.cornersView, frame: scrollClippingFrame)
            self.scrollViewClippingContainer.update(params: SolidRoundedCornersContainer.Params(
                size: scrollClippingFrame.size,
                color: .black,
                cornerRadius: 10.0,
                smoothCorners: false
            ), transition: transition)
            
            if self.scrollViewClippingShadowView.image == nil {
                let height: CGFloat = 24.0
                let baseGradientAlpha: CGFloat = 1.0
                let numSteps = 8
                let firstStep = 0
                let firstLocation = 0.0
                let colors = (0 ..< numSteps).map { i -> UIColor in
                    if i < firstStep {
                        return UIColor(white: 1.0, alpha: 1.0)
                    } else {
                        let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                        let value: CGFloat = 1.0 - bezierPoint(0.42, 0.0, 0.58, 1.0, step)
                        return UIColor(white: 0.0, alpha: baseGradientAlpha * value)
                    }
                }
                let locations = (0 ..< numSteps).map { i -> CGFloat in
                    if i < firstStep {
                        return 0.0
                    } else {
                        let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                        return (firstLocation + (1.0 - firstLocation) * step)
                    }
                }
                
                self.scrollViewClippingShadowView.image = generateGradientImage(size: CGSize(width: 8.0, height: height), colors: colors.reversed(), locations: locations.reversed().map { 1.0 - $0 })!.withRenderingMode(.alwaysTemplate).stretchableImage(withLeftCapWidth: 0, topCapHeight: Int(height - 1.0))
                self.scrollViewClippingShadowView.tintColor = .black
            }
            let scrollViewClippingShadowHeight: CGFloat = 24.0
            let scrollViewClippingShadowOffset: CGFloat = 0.0
            transition.setFrame(view: self.scrollViewClippingShadowView, frame: CGRect(origin: CGPoint(x: scrollClippingFrame.minX, y: scrollClippingFrame.maxY + scrollViewClippingShadowOffset - scrollViewClippingShadowHeight), size: CGSize(width: scrollClippingFrame.width, height: scrollViewClippingShadowHeight)))
            
            self.ignoreScrolling = true
            if self.scrollView.bounds.size != availableSize {
                transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(), size: availableSize))
            }
            let contentSize = CGSize(width: availableSize.width, height: itemLayout.contentHeight())
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            self.ignoreScrolling = false
            
            self.updateScrolling(transition: transition)
            
            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
