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
    let members: PresentationGroupCallMembers?
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
        members: PresentationGroupCallMembers?,
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
        self.members = members
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
        if lhs.members != rhs.members {
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
        let sideInset: CGFloat
        let grid: Grid
        let expandedGrid: ExpandedGrid
        let list: List
        let spacing: CGFloat
        let gridOffsetY: CGFloat
        let listOffsetY: CGFloat

        init(containerSize: CGSize, sideInset: CGFloat, collapsedContainerInsets: UIEdgeInsets, expandedContainerInsets: UIEdgeInsets, gridItemCount: Int, listItemCount: Int, listItemHeight: CGFloat, listTrailingItemHeight: CGFloat) {
            self.containerSize = containerSize
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
            var result: CGFloat = 0.0
            if self.grid.itemCount != 0 {
                result += self.grid.contentHeight()
                result += self.spacing
            }
            result += self.list.contentHeight()
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

    final class View: UIView, UIScrollViewDelegate {
        private let scollViewClippingContainer: UIView
        private let scrollView: ScrollView
        
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
        private var expandedGridItemView: GridItem?
        
        private var listItemViews: [EnginePeer.Id: ComponentView<Empty>] = [:]
        private let listItemViewContainer: UIView
        private let listItemsBackround = ComponentView<Empty>()
        
        private var itemLayout: ItemLayout?
        
        private var appliedGridIsEmpty: Bool = true
        
        override init(frame: CGRect) {
            self.scollViewClippingContainer = UIView()
            self.scollViewClippingContainer.clipsToBounds = true
            
            self.scrollView = ScrollView()
            
            self.gridItemViewContainer = UIView()
            self.gridItemViewContainer.layer.anchorPoint = CGPoint(x: 0.5, y: 0.0)
            
            self.listItemViewContainer = UIView()
            self.listItemViewContainer.clipsToBounds = true
            
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
            
            self.scollViewClippingContainer.addSubview(self.scrollView)
            self.addSubview(self.scollViewClippingContainer)
            
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
                if let result = self.scollViewClippingContainer.hitTest(self.convert(point, to: self.scollViewClippingContainer), with: event) {
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
                
                var expandedItemState: VideoChatParticipantVideoComponent.ExpandedState?
                if let expandedVideoState = component.expandedVideoState, expandedVideoState.mainParticipant == videoParticipantKey {
                    expandedItemState = VideoChatParticipantVideoComponent.ExpandedState(isPinned: expandedVideoState.isMainParticipantPinned)
                }
                
                let itemFrame: CGRect
                if expandedItemState != nil {
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
                        expandedState: expandedItemState,
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
                        if expandedItemState != nil {
                            self.expandedGridItemContainer.addSubview(itemComponentView)
                        } else {
                            self.gridItemViewContainer.addSubview(itemComponentView)
                        }
                        
                        itemComponentView.frame = itemFrame
                        
                        if !commonGridItemTransition.animation.isImmediate {
                            commonGridItemTransition.animateScale(view: itemComponentView, from: 0.001, to: 1.0)
                        }
                        if !transition.animation.isImmediate {
                            itemComponentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                        }
                    } else if expandedItemState != nil && itemComponentView.superview != self.expandedGridItemContainer {
                        let fromFrame = itemComponentView.convert(itemComponentView.bounds, to: self.expandedGridItemContainer)
                        itemComponentView.center = fromFrame.center
                        self.expandedGridItemContainer.addSubview(itemComponentView)
                    } else if expandedItemState == nil && itemComponentView.superview != self.gridItemViewContainer {
                        if !itemView.isCollapsing {
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
                        commonGridItemTransition.setPosition(view: itemComponentView, position: itemFrame.center)
                        commonGridItemTransition.setBounds(view: itemComponentView, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
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
                    let itemView: ComponentView<Empty>
                    if let current = self.listItemViews[participant.peer.id] {
                        itemView = current
                    } else {
                        itemTransition = itemTransition.withAnimation(.none)
                        itemView = ComponentView()
                        self.listItemViews[participant.peer.id] = itemView
                    }
                    
                    let itemFrame = itemLayout.listItemFrame(at: i)
                    
                    let subtitle: PeerListItemComponent.Subtitle
                    if participant.peer.id == component.call.accountContext.account.peerId {
                        subtitle = PeerListItemComponent.Subtitle(text: "this is you", color: .accent)
                    } else {
                        subtitle = PeerListItemComponent.Subtitle(text: "listening", color: .neutral)
                    }
                    
                    let _ = itemView.update(
                        transition: itemTransition,
                        component: AnyComponent(PeerListItemComponent(
                            context: component.call.accountContext,
                            theme: component.theme,
                            strings: component.strings,
                            style: .generic,
                            sideInset: 0.0,
                            title: EnginePeer(participant.peer).displayTitle(strings: component.strings, displayOrder: .firstLast),
                            peer: EnginePeer(participant.peer),
                            subtitle: subtitle,
                            subtitleAccessory: .none,
                            presence: nil,
                            selectionState: .none,
                            hasNext: true,
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
                    if let itemComponentView = itemView.view {
                        if itemComponentView.superview == nil {
                            itemComponentView.clipsToBounds = true
                            
                            self.listItemViewContainer.addSubview(itemComponentView)
                            
                            if !transition.animation.isImmediate {
                                itemComponentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                                itemComponentView.frame = CGRect(origin: itemFrame.origin, size: CGSize(width: itemFrame.width, height: 0.0))
                            }
                        }
                        transition.setFrame(view: itemComponentView, frame: itemFrame)
                    }
                }
            }
            
            var removedListItemIds: [EnginePeer.Id] = []
            for (itemId, itemView) in self.listItemViews {
                if !validListItemIds.contains(itemId) {
                    removedListItemIds.append(itemId)
                    
                    if let itemComponentView = itemView.view {
                        if !transition.animation.isImmediate {
                            itemComponentView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak itemComponentView] _ in
                                itemComponentView?.removeFromSuperview()
                            })
                        } else {
                            itemComponentView.removeFromSuperview()
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
            
            transition.setFrame(view: self.expandedGridItemContainer, frame: expandedGridItemContainerFrame)
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
            if let members = component.members {
                for participant in members.participants {
                    var hasVideo = false
                    if participant.videoDescription != nil {
                        hasVideo = true
                        let videoParticipant = VideoParticipant(participant: participant, isPresentation: false)
                        if participant.peer.id == component.call.accountContext.account.peerId {
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
            
            let listItemsBackroundSize = self.listItemsBackround.update(
                transition: transition,
                component: AnyComponent(RoundedRectangle(
                    color: UIColor(white: 1.0, alpha: 0.1),
                    cornerRadius: 10.0
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - itemLayout.sideInset * 2.0, height: itemLayout.list.contentHeight())
            )
            let listItemsBackroundFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: listItemsBackroundSize)
            if let listItemsBackroundView = self.listItemsBackround.view {
                if listItemsBackroundView.superview == nil {
                    self.listItemViewContainer.addSubview(listItemsBackroundView)
                }
                transition.setFrame(view: listItemsBackroundView, frame: listItemsBackroundFrame)
            }
            
            var requestedVideo: [PresentationGroupCallRequestedVideo] = []
            if let members = component.members {
                for participant in members.participants {
                    var maxVideoQuality: PresentationGroupCallRequestedVideo.Quality = .medium
                    if let expandedVideoState = component.expandedVideoState, expandedVideoState.mainParticipant.id == participant.peer.id, !expandedVideoState.mainParticipant.isPresentation {
                        maxVideoQuality = .full
                    }
                    
                    var maxPresentationQuality: PresentationGroupCallRequestedVideo.Quality = .medium
                    if let expandedVideoState = component.expandedVideoState, expandedVideoState.mainParticipant.id == participant.peer.id, expandedVideoState.mainParticipant.isPresentation {
                        maxPresentationQuality = .full
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
            
            let scrollClippingFrame = CGRect(origin: CGPoint(x: 0.0, y: component.collapsedContainerInsets.top), size: CGSize(width: availableSize.width, height: availableSize.height - component.collapsedContainerInsets.top - component.collapsedContainerInsets.bottom))
            transition.setPosition(view: self.scollViewClippingContainer, position: scrollClippingFrame.center)
            transition.setBounds(view: self.scollViewClippingContainer, bounds: CGRect(origin: CGPoint(x: scrollClippingFrame.minX, y: scrollClippingFrame.minY), size: scrollClippingFrame.size))
            
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
