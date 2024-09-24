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
    struct Layout: Equatable {
        struct Column: Equatable {
            var width: CGFloat
            var insets: UIEdgeInsets
            
            init(width: CGFloat, insets: UIEdgeInsets) {
                self.width = width
                self.insets = insets
            }
        }
        
        var videoColumn: Column?
        var mainColumn: Column
        var columnSpacing: CGFloat
        var isMainColumnHidden: Bool
        
        init(videoColumn: Column?, mainColumn: Column, columnSpacing: CGFloat, isMainColumnHidden: Bool) {
            self.videoColumn = videoColumn
            self.mainColumn = mainColumn
            self.columnSpacing = columnSpacing
            self.isMainColumnHidden = isMainColumnHidden
        }
    }
    
    final class Participants: Equatable {
        enum InviteType {
            case invite
            case shareLink
        }
        
        let myPeerId: EnginePeer.Id
        let participants: [GroupCallParticipantsContext.Participant]
        let totalCount: Int
        let loadMoreToken: String?
        let inviteType: InviteType?
        
        init(myPeerId: EnginePeer.Id, participants: [GroupCallParticipantsContext.Participant], totalCount: Int, loadMoreToken: String?, inviteType: InviteType?) {
            self.myPeerId = myPeerId
            self.participants = participants
            self.totalCount = totalCount
            self.loadMoreToken = loadMoreToken
            self.inviteType = inviteType
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
            if lhs.inviteType != rhs.inviteType {
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
        let isUIHidden: Bool
        
        init(mainParticipant: VideoParticipantKey, isMainParticipantPinned: Bool, isUIHidden: Bool) {
            self.mainParticipant = mainParticipant
            self.isMainParticipantPinned = isMainParticipantPinned
            self.isUIHidden = isUIHidden
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
            if lhs.isUIHidden != rhs.isUIHidden {
                return false
            }
            return true
        }
    }
    
    final class EventCycleState {
        var ignoreScrolling: Bool = false
        
        init() {
        }
    }
    
    let call: PresentationGroupCall
    let participants: Participants?
    let speakingParticipants: Set<EnginePeer.Id>
    let expandedVideoState: ExpandedVideoState?
    let theme: PresentationTheme
    let strings: PresentationStrings
    let layout: Layout
    let expandedInsets: UIEdgeInsets
    let safeInsets: UIEdgeInsets
    let interfaceOrientation: UIInterfaceOrientation
    let openParticipantContextMenu: (EnginePeer.Id, ContextExtractedContentContainingView, ContextGesture?) -> Void
    let updateMainParticipant: (VideoParticipantKey?, Bool?) -> Void
    let updateIsMainParticipantPinned: (Bool) -> Void
    let updateIsExpandedUIHidden: (Bool) -> Void
    let openInviteMembers: () -> Void
    let visibleParticipantsUpdated: (Set<EnginePeer.Id>) -> Void

    init(
        call: PresentationGroupCall,
        participants: Participants?,
        speakingParticipants: Set<EnginePeer.Id>,
        expandedVideoState: ExpandedVideoState?,
        theme: PresentationTheme,
        strings: PresentationStrings,
        layout: Layout,
        expandedInsets: UIEdgeInsets,
        safeInsets: UIEdgeInsets,
        interfaceOrientation: UIInterfaceOrientation,
        openParticipantContextMenu: @escaping (EnginePeer.Id, ContextExtractedContentContainingView, ContextGesture?) -> Void,
        updateMainParticipant: @escaping (VideoParticipantKey?, Bool?) -> Void,
        updateIsMainParticipantPinned: @escaping (Bool) -> Void,
        updateIsExpandedUIHidden: @escaping (Bool) -> Void,
        openInviteMembers: @escaping () -> Void,
        visibleParticipantsUpdated: @escaping (Set<EnginePeer.Id>) -> Void
    ) {
        self.call = call
        self.participants = participants
        self.speakingParticipants = speakingParticipants
        self.expandedVideoState = expandedVideoState
        self.theme = theme
        self.strings = strings
        self.layout = layout
        self.expandedInsets = expandedInsets
        self.safeInsets = safeInsets
        self.interfaceOrientation = interfaceOrientation
        self.openParticipantContextMenu = openParticipantContextMenu
        self.updateMainParticipant = updateMainParticipant
        self.updateIsMainParticipantPinned = updateIsMainParticipantPinned
        self.updateIsExpandedUIHidden = updateIsExpandedUIHidden
        self.openInviteMembers = openInviteMembers
        self.visibleParticipantsUpdated = visibleParticipantsUpdated
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
        if lhs.layout != rhs.layout {
            return false
        }
        if lhs.expandedInsets != rhs.expandedInsets {
            return false
        }
        if lhs.safeInsets != rhs.safeInsets {
            return false
        }
        if lhs.interfaceOrientation != rhs.interfaceOrientation {
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
            let isDedicatedColumn: Bool
            let itemSize: CGSize
            let itemSpacing: CGFloat
            let lastItemSize: CGFloat
            let lastRowItemCount: Int
            let lastRowItemSize: CGFloat
            let itemsPerRow: Int
            let rowCount: Int
            
            init(containerSize: CGSize, sideInset: CGFloat, itemCount: Int, isDedicatedColumn: Bool) {
                self.containerSize = containerSize
                self.sideInset = sideInset
                self.itemCount = itemCount
                self.isDedicatedColumn = isDedicatedColumn
                
                let width: CGFloat = containerSize.width - sideInset * 2.0
                
                self.itemSpacing = 4.0

                let itemsPerRow: Int
                if isDedicatedColumn {
                    if itemCount <= 2 {
                        itemsPerRow = 1
                    } else {
                        itemsPerRow = 2
                    }
                } else {
                    if itemCount == 1 {
                        itemsPerRow = 1
                    } else {
                        itemsPerRow = 2
                    }
                }
                self.itemsPerRow = Int(itemsPerRow)
                
                let itemWidth = floorToScreenPixels((width - (self.itemSpacing * CGFloat(self.itemsPerRow - 1))) / CGFloat(itemsPerRow))
                let itemHeight = min(180.0, itemWidth)
                var itemSize = CGSize(width: itemWidth, height: itemHeight)
                
                self.rowCount = itemCount / self.itemsPerRow + ((itemCount % self.itemsPerRow) != 0 ? 1 : 0)
                
                if isDedicatedColumn && itemCount != 0 {
                    let contentHeight = itemSize.height * CGFloat(self.rowCount) + self.itemSpacing * CGFloat(max(0, self.rowCount - 1))
                    if contentHeight < containerSize.height {
                        itemSize.height = (containerSize.height - self.itemSpacing * CGFloat(max(0, self.rowCount - 1))) / CGFloat(self.rowCount)
                        itemSize.height = floor(itemSize.height)
                    }
                }
                
                self.itemSize = itemSize

                self.lastItemSize = width - (self.itemSize.width + self.itemSpacing) * CGFloat(self.itemsPerRow - 1)
                var lastRowItemCount = itemCount % self.itemsPerRow
                if lastRowItemCount == 0 {
                    lastRowItemCount = self.itemsPerRow
                }
                self.lastRowItemCount = lastRowItemCount
                self.lastRowItemSize = width - (self.itemSize.width + self.itemSpacing) * CGFloat(lastRowItemCount - 1)
            }
            
            func frame(at index: Int) -> CGRect {
                let row = index / self.itemsPerRow
                let column = index % self.itemsPerRow
                
                let itemWidth: CGFloat
                if row == self.rowCount - 1 && column == self.lastRowItemCount - 1 {
                    itemWidth = self.lastRowItemSize
                } else if column == self.itemsPerRow - 1 {
                    if row == self.rowCount - 1 {
                        itemWidth = self.lastRowItemSize
                    } else {
                        itemWidth = self.lastItemSize
                    }
                } else {
                    itemWidth = self.itemSize.width
                }
                
                let frame = CGRect(origin: CGPoint(x: self.sideInset + CGFloat(column) * (self.itemSize.width + self.itemSpacing), y: CGFloat(row) * (self.itemSize.height + self.itemSpacing)), size: CGSize(width: itemWidth, height: itemSize.height))
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
            let layout: Layout
            let expandedInsets: UIEdgeInsets
            let isUIHidden: Bool
            
            init(containerSize: CGSize, layout: Layout, expandedInsets: UIEdgeInsets, isUIHidden: Bool) {
                self.containerSize = containerSize
                self.layout = layout
                self.expandedInsets = expandedInsets
                self.isUIHidden = isUIHidden
            }
            
            func itemContainerFrame() -> CGRect {
                let containerInsets: UIEdgeInsets
                if self.isUIHidden {
                    containerInsets = UIEdgeInsets()
                } else {
                    containerInsets = self.expandedInsets
                }
                
                if self.layout.videoColumn != nil {
                    return CGRect(origin: CGPoint(x: containerInsets.left, y: containerInsets.top), size: CGSize(width: self.containerSize.width - containerInsets.left - containerInsets.right, height: self.containerSize.height - containerInsets.top - containerInsets.bottom))
                } else {
                    return CGRect(origin: CGPoint(x: containerInsets.left, y: containerInsets.top), size: CGSize(width: self.containerSize.width - containerInsets.left - containerInsets.right, height: self.containerSize.height - containerInsets.top - containerInsets.bottom))
                }
            }
            
            func itemContainerInsets() -> UIEdgeInsets {
                if self.isUIHidden {
                    return self.expandedInsets
                } else {
                    return UIEdgeInsets()
                }
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
        let layout: Layout
        let isUIHidden: Bool
        let expandedInsets: UIEdgeInsets
        let safeInsets: UIEdgeInsets
        let grid: Grid
        let expandedGrid: ExpandedGrid
        let list: List
        let spacing: CGFloat
        let gridOffsetY: CGFloat
        let listOffsetY: CGFloat
        let listFrame: CGRect
        let separateVideoGridFrame: CGRect
        let scrollClippingFrame: CGRect
        let separateVideoScrollClippingFrame: CGRect

        init(containerSize: CGSize, layout: Layout, isUIHidden: Bool, expandedInsets: UIEdgeInsets, safeInsets: UIEdgeInsets, gridItemCount: Int, listItemCount: Int, listItemHeight: CGFloat, listTrailingItemHeight: CGFloat) {
            self.containerSize = containerSize
            self.layout = layout
            self.isUIHidden = isUIHidden
            self.expandedInsets = expandedInsets
            self.safeInsets = safeInsets
            
            let listWidth: CGFloat = layout.mainColumn.width
            let gridWidth: CGFloat
            let gridSideInset: CGFloat
            let gridContainerHeight: CGFloat
            if let videoColumn = layout.videoColumn {
                if layout.isMainColumnHidden {
                    gridWidth = videoColumn.width + layout.columnSpacing + layout.mainColumn.width
                } else {
                    gridWidth = videoColumn.width
                }
                gridSideInset = videoColumn.insets.left
                gridContainerHeight = containerSize.height - videoColumn.insets.top - videoColumn.insets.bottom
            } else {
                gridWidth = listWidth
                gridSideInset = layout.mainColumn.insets.left
                gridContainerHeight = containerSize.height
            }
            
            self.grid = Grid(containerSize: CGSize(width: gridWidth, height: gridContainerHeight), sideInset: gridSideInset, itemCount: gridItemCount, isDedicatedColumn: layout.videoColumn != nil)
            self.list = List(containerSize: CGSize(width: listWidth, height: containerSize.height), sideInset: layout.mainColumn.insets.left, itemCount: listItemCount, itemHeight: listItemHeight, trailingItemHeight: listTrailingItemHeight)
            self.spacing = 4.0
            
            if let videoColumn = layout.videoColumn, !isUIHidden && !layout.isMainColumnHidden {
                self.expandedGrid = ExpandedGrid(containerSize: CGSize(width: videoColumn.width + expandedInsets.left, height: containerSize.height), layout: layout, expandedInsets: UIEdgeInsets(top: expandedInsets.top, left: expandedInsets.left, bottom: expandedInsets.bottom, right: 0.0), isUIHidden: isUIHidden)
            } else {
                self.expandedGrid = ExpandedGrid(containerSize: containerSize, layout: layout, expandedInsets: expandedInsets, isUIHidden: isUIHidden)
            }
            
            self.gridOffsetY = layout.mainColumn.insets.top
            
            var listOffsetY: CGFloat = self.gridOffsetY
            if layout.videoColumn == nil {
                if self.grid.itemCount != 0 {
                    listOffsetY += self.grid.contentHeight()
                    listOffsetY += self.spacing
                }
            }
            self.listOffsetY = listOffsetY
            
            if let videoColumn = layout.videoColumn {
                let columnsWidth: CGFloat = videoColumn.width + layout.columnSpacing + layout.mainColumn.width
                let columnsSideInset: CGFloat = floorToScreenPixels((containerSize.width - columnsWidth) * 0.5)
                
                var separateVideoGridFrame = CGRect(origin: CGPoint(x: floor((containerSize.width - columnsWidth) * 0.5), y: 0.0), size: CGSize(width: gridWidth, height: containerSize.height))
                
                var listFrame = CGRect(origin: CGPoint(x: separateVideoGridFrame.maxX + layout.columnSpacing, y: 0.0), size: CGSize(width: listWidth, height: containerSize.height))
                if isUIHidden || layout.isMainColumnHidden {
                    listFrame.origin.x = containerSize.width + columnsSideInset
                    separateVideoGridFrame = CGRect(origin: CGPoint(x: floor((containerSize.width - columnsWidth) * 0.5), y: 0.0), size: CGSize(width: columnsWidth, height: containerSize.height))
                }
                
                self.separateVideoGridFrame = separateVideoGridFrame
                self.listFrame = listFrame
                
                self.separateVideoScrollClippingFrame = CGRect(origin: CGPoint(x: self.separateVideoGridFrame.minX, y: videoColumn.insets.top), size: CGSize(width: self.separateVideoGridFrame.width, height: containerSize.height - videoColumn.insets.top))
                self.scrollClippingFrame = CGRect(origin: CGPoint(x: self.listFrame.minX, y: layout.mainColumn.insets.top), size: CGSize(width: self.listFrame.width, height: containerSize.height - layout.mainColumn.insets.top))
            } else {
                self.listFrame = CGRect(origin: CGPoint(x: floor((containerSize.width - listWidth) * 0.5), y: 0.0), size: CGSize(width: listWidth, height: containerSize.height))
                self.scrollClippingFrame = CGRect(origin: CGPoint(x: self.listFrame.minX + layout.mainColumn.insets.left, y: layout.mainColumn.insets.top), size: CGSize(width: listWidth - layout.mainColumn.insets.left - layout.mainColumn.insets.right, height: containerSize.height - layout.mainColumn.insets.top))
                
                self.separateVideoGridFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 0.0, height: containerSize.height))
                self.separateVideoScrollClippingFrame = CGRect(origin: CGPoint(x: self.separateVideoGridFrame.minX, y: layout.mainColumn.insets.top), size: CGSize(width: self.separateVideoGridFrame.width, height: containerSize.height - layout.mainColumn.insets.top))
            }
        }

        func contentHeight() -> CGFloat {
            var result: CGFloat = self.gridOffsetY
            if self.layout.videoColumn == nil {
                if self.grid.itemCount != 0 {
                    result += self.grid.contentHeight()
                    result += self.spacing
                }
            }
            result += self.list.contentHeight()
            result += self.layout.mainColumn.insets.bottom
            result += 24.0
            return result
        }
        
        func separateVideoGridContentHeight() -> CGFloat {
            var result: CGFloat = self.gridOffsetY
            if let videoColumn = self.layout.videoColumn {
                if self.grid.itemCount != 0 {
                    result += self.grid.contentHeight()
                }
                result += videoColumn.insets.bottom
            }
            return result
        }
        
        func visibleGridItemRange(for rect: CGRect) -> (minIndex: Int, maxIndex: Int) {
            return self.grid.visibleItemRange(for: rect.offsetBy(dx: 0.0, dy: -self.gridOffsetY))
        }
        
        func gridItemFrame(at index: Int) -> CGRect {
            return self.grid.frame(at: index)
        }
        
        func gridItemContainerFrame() -> CGRect {
            if let _ = self.layout.videoColumn {
                return CGRect(origin: CGPoint(x: 0.0, y: self.gridOffsetY), size: CGSize(width: self.separateVideoGridFrame.width, height: self.grid.contentHeight()))
            } else {
                return CGRect(origin: CGPoint(x: 0.0, y: self.gridOffsetY), size: CGSize(width: self.containerSize.width, height: self.grid.contentHeight()))
            }
        }
        
        func visibleListItemRange(for rect: CGRect) -> (minIndex: Int, maxIndex: Int) {
            return self.list.visibleItemRange(for: rect.offsetBy(dx: 0.0, dy: -self.listOffsetY))
        }
        
        func listItemFrame(at index: Int) -> CGRect {
            return self.list.frame(at: index)
        }
        
        func listItemContainerFrame() -> CGRect {
            if let _ = self.layout.videoColumn {
                return CGRect(origin: CGPoint(x: 0.0, y: self.listOffsetY), size: CGSize(width: self.separateVideoGridFrame.width, height: self.list.contentHeight()))
            } else {
                return CGRect(origin: CGPoint(x: 0.0, y: self.listOffsetY), size: CGSize(width: self.containerSize.width, height: self.list.contentHeight()))
            }
        }
        
        func listTrailingItemFrame() -> CGRect {
            return self.list.trailingItemFrame()
        }
    }
    
    private struct ExpandedGridSwipeState {
        var fraction: CGFloat
        
        init(fraction: CGFloat) {
            self.fraction = fraction
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
        private let scrollViewBottomShadowView: UIImageView
        
        private let separateVideoScrollViewClippingContainer: SolidRoundedCornersContainer
        private let separateVideoScrollView: ScrollView
        
        private(set) var component: VideoChatParticipantsComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private var ignoreScrolling: Bool = false
        
        //TODO:release
        private var gridParticipants: [VideoParticipant] = []
        private var listParticipants: [GroupCallParticipantsContext.Participant] = []
        
        private let measureListItemView = ComponentView<Empty>()
        private let inviteListItemView = ComponentView<Empty>()
        
        private var gridItemViews: [VideoParticipantKey: GridItem] = [:]
        private let gridItemViewContainer: UIView
        
        private let expandedGridItemContainer: UIView
        private var expandedControlsView: ComponentView<Empty>?
        private var expandedThumbnailsView: ComponentView<Empty>?
        private var expandedSpeakingToast: ComponentView<Empty>?
        
        private var listItemViews: [EnginePeer.Id: ListItem] = [:]
        private let listItemViewContainer: UIView
        private let listItemViewSeparatorContainer: SimpleLayer
        private let listItemsBackground = ComponentView<Empty>()
        
        private var itemLayout: ItemLayout?
        private var expandedGridSwipeState: ExpandedGridSwipeState?
        
        private var appliedGridIsEmpty: Bool = true
        
        private var currentLoadMoreToken: String?
        
        private var mainScrollViewEventCycleState: EventCycleState?
        private var separateVideoScrollViewEventCycleState: EventCycleState?
        
        override init(frame: CGRect) {
            self.scrollViewClippingContainer = SolidRoundedCornersContainer()
            self.scrollView = ScrollView()
            self.scrollViewBottomShadowView = UIImageView()
            
            self.separateVideoScrollViewClippingContainer = SolidRoundedCornersContainer()
            self.separateVideoScrollView = ScrollView()
            
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
            
            self.separateVideoScrollView.delaysContentTouches = false
            self.separateVideoScrollView.canCancelContentTouches = true
            self.separateVideoScrollView.clipsToBounds = false
            self.separateVideoScrollView.contentInsetAdjustmentBehavior = .never
            if #available(iOS 13.0, *) {
                self.separateVideoScrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.separateVideoScrollView.showsVerticalScrollIndicator = false
            self.separateVideoScrollView.showsHorizontalScrollIndicator = false
            self.separateVideoScrollView.alwaysBounceHorizontal = false
            self.separateVideoScrollView.alwaysBounceVertical = false
            self.separateVideoScrollView.scrollsToTop = false
            self.separateVideoScrollView.delegate = self
            self.separateVideoScrollView.clipsToBounds = true
            
            self.scrollViewClippingContainer.addSubview(self.scrollView)
            self.addSubview(self.scrollViewClippingContainer)
            self.addSubview(self.scrollViewClippingContainer.cornersView)
            self.addSubview(self.scrollViewBottomShadowView)
            
            self.separateVideoScrollViewClippingContainer.addSubview(self.separateVideoScrollView)
            self.addSubview(self.separateVideoScrollViewClippingContainer)
            self.addSubview(self.separateVideoScrollViewClippingContainer.cornersView)
            
            self.scrollView.addSubview(self.listItemViewContainer)
            self.addSubview(self.expandedGridItemContainer)
            
            self.expandedGridItemContainer.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.expandedGridPanGesture(_:))))
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
                }
                
                if component.layout.videoColumn != nil {
                    if let result = self.scrollViewClippingContainer.hitTest(self.convert(point, to: self.scrollViewClippingContainer), with: event) {
                        return result
                    }
                }
                
                if !self.expandedGridItemContainer.bounds.contains(self.convert(point, to: self.expandedGridItemContainer)) && !self.scrollViewClippingContainer.bounds.contains(self.convert(point, to: self.scrollViewClippingContainer)) {
                    return nil
                }
                
                return self
            } else {
                if let result = self.scrollViewClippingContainer.hitTest(self.convert(point, to: self.scrollViewClippingContainer), with: event) {
                    return result
                } else if let result = self.separateVideoScrollViewClippingContainer.hitTest(self.convert(point, to: self.separateVideoScrollViewClippingContainer), with: event) {
                    return result
                } else {
                    return nil
                }
            }
        }
        
        @objc private func expandedGridPanGesture(_ recognizer: UIPanGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            if self.bounds.height == 0.0 {
                return
            }
            switch recognizer.state {
            case .began, .changed:
                let translation = recognizer.translation(in: self)
                let fraction = translation.y / self.bounds.height
                self.expandedGridSwipeState = ExpandedGridSwipeState(fraction: fraction)
                self.state?.updated(transition: .immediate)
            case .ended, .cancelled:
                let translation = recognizer.translation(in: self)
                let fraction = translation.y / self.bounds.height
                self.expandedGridSwipeState = nil
                
                let velocity = recognizer.velocity(in: self)
                if abs(velocity.y) > 100.0 || abs(fraction) >= 0.5 {
                    component.updateMainParticipant(nil, nil)
                } else {
                    self.state?.updated(transition: .spring(duration: 0.4))
                }
            default:
                break
            }
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                if scrollView == self.scrollView {
                    if let eventCycleState = self.mainScrollViewEventCycleState {
                        if eventCycleState.ignoreScrolling {
                            self.ignoreScrolling = true
                            scrollView.contentOffset = CGPoint()
                            self.ignoreScrolling = false
                            return
                        }
                    }
                } else if scrollView == self.separateVideoScrollView {
                    if let eventCycleState = self.separateVideoScrollViewEventCycleState {
                        if eventCycleState.ignoreScrolling {
                            self.ignoreScrolling = true
                            scrollView.contentOffset = CGPoint()
                            self.ignoreScrolling = false
                            return
                        }
                    }
                }
                
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            if scrollView == self.scrollView {
                if let eventCycleState = self.mainScrollViewEventCycleState {
                    if eventCycleState.ignoreScrolling {
                        targetContentOffset.pointee.y = 0.0
                    }
                }
            } else if scrollView == self.separateVideoScrollView {
                if let eventCycleState = self.separateVideoScrollViewEventCycleState {
                    if eventCycleState.ignoreScrolling {
                        targetContentOffset.pointee.y = 0.0
                    }
                }
            }
        }
        
        private func updateScrolling(transition: ComponentTransition) {
            guard let component = self.component, let itemLayout = self.itemLayout else {
                return
            }
            
            let alphaTransition: ComponentTransition
            if !transition.animation.isImmediate {
                alphaTransition = .easeInOut(duration: 0.2)
            } else {
                alphaTransition = .immediate
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
                if let expandedGridSwipeState = self.expandedGridSwipeState {
                    expandedGridItemContainerFrame.origin.y += expandedGridSwipeState.fraction * itemLayout.containerSize.height
                }
            } else {
                if let videoColumn = itemLayout.layout.videoColumn {
                    expandedGridItemContainerFrame = itemLayout.gridItemContainerFrame().offsetBy(dx: itemLayout.separateVideoScrollClippingFrame.minX, dy: 0.0).offsetBy(dx: 0.0, dy: -self.separateVideoScrollView.bounds.minY)
                    
                    if expandedGridItemContainerFrame.origin.y < videoColumn.insets.top {
                        expandedGridItemContainerFrame.size.height -= videoColumn.insets.top - expandedGridItemContainerFrame.origin.y
                        expandedGridItemContainerFrame.origin.y = videoColumn.insets.top
                    }
                    if expandedGridItemContainerFrame.origin.y + expandedGridItemContainerFrame.height > itemLayout.containerSize.height {
                        expandedGridItemContainerFrame.size.height -= (expandedGridItemContainerFrame.origin.y + expandedGridItemContainerFrame.height) - (itemLayout.containerSize.height)
                    }
                } else {
                    expandedGridItemContainerFrame = itemLayout.gridItemContainerFrame().offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                    
                    if expandedGridItemContainerFrame.origin.y < itemLayout.layout.mainColumn.insets.top {
                        expandedGridItemContainerFrame.size.height -= itemLayout.layout.mainColumn.insets.top - expandedGridItemContainerFrame.origin.y
                        expandedGridItemContainerFrame.origin.y = itemLayout.layout.mainColumn.insets.top
                    }
                    if expandedGridItemContainerFrame.origin.y + expandedGridItemContainerFrame.height > itemLayout.containerSize.height - itemLayout.layout.mainColumn.insets.bottom {
                        expandedGridItemContainerFrame.size.height -= (expandedGridItemContainerFrame.origin.y + expandedGridItemContainerFrame.height) - (itemLayout.containerSize.height - itemLayout.layout.mainColumn.insets.bottom)
                    }
                }
                if expandedGridItemContainerFrame.size.height < 0.0 {
                    expandedGridItemContainerFrame.size.height = 0.0
                }
            }
            
            let commonGridItemTransition: ComponentTransition = (gridIsEmpty == gridWasEmpty) ? transition : .immediate
            
            var validGridItemIds: [VideoParticipantKey] = []
            var validGridItemIndices: [Int] = []
            
            var clippedScrollViewBounds = self.scrollView.bounds
            clippedScrollViewBounds.origin.y += component.layout.mainColumn.insets.top
            clippedScrollViewBounds.size.height -= component.layout.mainColumn.insets.top + component.layout.mainColumn.insets.bottom
            
            let visibleGridItemRange: (minIndex: Int, maxIndex: Int)
            let clippedVisibleGridItemRange: (minIndex: Int, maxIndex: Int)
            if itemLayout.layout.videoColumn == nil {
                visibleGridItemRange = itemLayout.visibleGridItemRange(for: self.scrollView.bounds)
                clippedVisibleGridItemRange = itemLayout.visibleGridItemRange(for: clippedScrollViewBounds)
            } else {
                visibleGridItemRange = itemLayout.visibleGridItemRange(for: self.separateVideoScrollView.bounds)
                clippedVisibleGridItemRange = visibleGridItemRange
            }
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
            
            var visibleParticipants: [EnginePeer.Id] = []
             
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
                var isItemUIHidden = false
                if let expandedVideoState = component.expandedVideoState {
                    if expandedVideoState.mainParticipant == videoParticipantKey {
                        isItemExpanded = true
                    }
                    if expandedVideoState.isUIHidden {
                        isItemUIHidden = true
                    }
                }
                
                if isItemExpanded || (index >= clippedVisibleGridItemRange.minIndex && index <= clippedVisibleGridItemRange.maxIndex) {
                    visibleParticipants.append(videoParticipant.key.id)
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
                
                let itemReferenceX: CGFloat = itemFrame.minX
                let itemContainerWidth: CGFloat
                if isItemExpanded {
                    itemContainerWidth = expandedGridItemContainerFrame.width
                } else {
                    itemContainerWidth = itemLayout.grid.containerSize.width
                }
                
                let itemContentInsets: UIEdgeInsets
                if isItemExpanded {
                    itemContentInsets = itemLayout.expandedGrid.itemContainerInsets()
                } else {
                    itemContentInsets = UIEdgeInsets()
                }
                
                var itemControlInsets: UIEdgeInsets
                if isItemExpanded {
                    itemControlInsets = itemContentInsets
                    itemControlInsets.bottom = max(itemControlInsets.bottom, 96.0)
                } else {
                    itemControlInsets = itemContentInsets
                }
                
                let itemAlpha: CGFloat
                if isItemExpanded {
                    itemAlpha = 1.0
                } else if component.expandedVideoState != nil && itemLayout.layout.videoColumn != nil {
                    itemAlpha = 0.0
                } else {
                    itemAlpha = 1.0
                }
                
                let _ = itemView.view.update(
                    transition: itemTransition,
                    component: AnyComponent(VideoChatParticipantVideoComponent(
                        strings: component.strings,
                        call: component.call,
                        participant: videoParticipant.participant,
                        isMyPeer: videoParticipant.participant.peer.id == component.participants?.myPeerId,
                        isPresentation: videoParticipant.isPresentation,
                        isSpeaking: component.speakingParticipants.contains(videoParticipant.participant.peer.id),
                        isExpanded: isItemExpanded,
                        isUIHidden: isItemUIHidden,
                        contentInsets: itemContentInsets,
                        controlInsets: itemControlInsets,
                        interfaceOrientation: component.interfaceOrientation,
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            
                            if self.gridParticipants.count == 1, component.layout.videoColumn != nil {
                                if let expandedVideoState = component.expandedVideoState, expandedVideoState.mainParticipant == videoParticipantKey {
                                    component.updateMainParticipant(nil, false)
                                } else {
                                    component.updateMainParticipant(videoParticipantKey, true)
                                }
                            } else {
                                if let expandedVideoState = component.expandedVideoState, expandedVideoState.mainParticipant == videoParticipantKey {
                                    component.updateIsExpandedUIHidden(!expandedVideoState.isUIHidden)
                                } else {
                                    component.updateMainParticipant(videoParticipantKey, nil)
                                }
                            }
                        }
                    )),
                    environment: {},
                    containerSize: itemFrame.size
                )
                if let itemComponentView = itemView.view.view as? VideoChatParticipantVideoComponent.View {
                    if itemComponentView.superview == nil {
                        itemComponentView.layer.allowsGroupOpacity = true
                        
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
                        itemComponentView.alpha = itemAlpha
                        itemComponentView.updateHorizontalReferenceLocation(containerWidth: itemContainerWidth, positionX: itemReferenceX, transition: .immediate)
                        
                        if !resultingItemTransition.animation.isImmediate {
                            resultingItemTransition.animateScale(view: itemComponentView, from: 0.001, to: 1.0)
                        }
                        if !resultingItemTransition.animation.isImmediate && itemAlpha != 0.0 {
                            itemComponentView.layer.animateAlpha(from: 0.0, to: itemAlpha, duration: 0.1)
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
                            itemComponentView.updateHorizontalReferenceLocation(containerWidth: itemLayout.containerSize.width, positionX: itemFrame.minX, transition: commonGridItemTransition)
                        }
                    }
                    if !itemView.isCollapsing {
                        resultingItemTransition.setPosition(view: itemComponentView, position: itemFrame.center)
                        resultingItemTransition.setBounds(view: itemComponentView, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
                        itemComponentView.updateHorizontalReferenceLocation(containerWidth: itemLayout.containerSize.width, positionX: itemFrame.minX, transition: resultingItemTransition)
                        
                        let resultingItemAlphaTransition: ComponentTransition
                        if !resultingItemTransition.animation.isImmediate {
                            resultingItemAlphaTransition = alphaTransition
                        } else {
                            resultingItemAlphaTransition = .immediate
                        }
                        resultingItemAlphaTransition.setAlpha(view: itemComponentView, alpha: itemAlpha)
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
            let clippedVisibleListItemRange = itemLayout.visibleListItemRange(for: clippedScrollViewBounds)
            if visibleListItemRange.maxIndex >= visibleListItemRange.minIndex {
                for i in visibleListItemRange.minIndex ... visibleListItemRange.maxIndex {
                    let participant = self.listParticipants[i]
                    validListItemIds.append(participant.peer.id)
                    
                    if i >= clippedVisibleListItemRange.minIndex && i <= clippedVisibleListItemRange.maxIndex {
                        visibleParticipants.append(participant.peer.id)
                    }
                    
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
                        if let volume = participant.volume, volume != 10000 {
                            subtitle = PeerListItemComponent.Subtitle(text: "\(volume / 100)% speaking", color: .constructive)
                        } else {
                            subtitle = PeerListItemComponent.Subtitle(text: "speaking", color: .constructive)
                        }
                    } else if let about = participant.about, !about.isEmpty {
                        subtitle = PeerListItemComponent.Subtitle(text: about, color: .neutral)
                    } else {
                        subtitle = PeerListItemComponent.Subtitle(text: "listening", color: .neutral)
                    }
                    
                    let rightAccessoryComponent: AnyComponent<Empty> = AnyComponent(VideoChatParticipantStatusComponent(
                        muteState: participant.muteState,
                        hasRaiseHand: participant.hasRaiseHand,
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
                                myPeerId: component.participants?.myPeerId ?? component.call.accountContext.account.peerId,
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
                            extractedTheme: PeerListItemComponent.ExtractedTheme(
                                inset: 2.0,
                                background: UIColor(white: 0.1, alpha: 1.0)
                            ),
                            action: { [weak self] peer, _, itemView in
                                guard let self, let component = self.component else {
                                    return
                                }
                                component.openParticipantContextMenu(peer.id, itemView.extractedContainerView, nil)
                            },
                            contextAction: { [weak self] peer, sourceView, gesture in
                                guard let self, let component = self.component else {
                                    return
                                }
                                component.openParticipantContextMenu(peer.id, sourceView, gesture)
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
                
                let expandedControlsAlpha: CGFloat = expandedVideoState.isUIHidden ? 0.0 : 1.0
                let expandedThumbnailsAlpha: CGFloat = expandedControlsAlpha
                /*if itemLayout.layout.videoColumn == nil {
                    if expandedVideoState.isUIHidden {
                        expandedThumbnailsAlpha = 0.0
                    } else {
                        expandedThumbnailsAlpha = 1.0
                    }
                } else {
                    expandedThumbnailsAlpha = 0.0
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
                        interfaceOrientation: component.interfaceOrientation,
                        updateSelectedParticipant: { [weak self] key in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.updateMainParticipant(VideoParticipantKey(id: key.id, isPresentation: key.isPresentation), nil)
                        }
                    )),
                    environment: {},
                    containerSize: itemLayout.expandedGrid.itemContainerFrame().size
                )
                let expandedThumbnailsFrame = CGRect(origin: CGPoint(x: 0.0, y: expandedGridItemContainerFrame.height - expandedThumbnailsSize.height), size: expandedThumbnailsSize)
                if let expandedThumbnailsComponentView = expandedThumbnailsView.view {
                    if expandedThumbnailsComponentView.superview == nil {
                        self.expandedGridItemContainer.addSubview(expandedThumbnailsComponentView)
                        expandedThumbnailsComponentView.alpha = expandedThumbnailsAlpha
                        
                        let fromReferenceFrame: CGRect
                        if let index = self.gridParticipants.firstIndex(where: { $0.participant.peer.id ==  expandedVideoState.mainParticipant.id && $0.isPresentation == expandedVideoState.mainParticipant.isPresentation }) {
                            fromReferenceFrame = self.gridItemViewContainer.convert(itemLayout.gridItemFrame(at: index), to: self.expandedGridItemContainer)
                        } else {
                            fromReferenceFrame = previousExpandedGridItemContainerFrame
                        }
                        
                        expandedThumbnailsComponentView.frame = CGRect(origin: CGPoint(x: fromReferenceFrame.minX - previousExpandedGridItemContainerFrame.minX, y: fromReferenceFrame.maxY - expandedThumbnailsSize.height), size: expandedThumbnailsFrame.size)
                        
                        if !transition.animation.isImmediate && expandedThumbnailsAlpha != 0.0 {
                            expandedThumbnailsComponentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                        }
                    }
                    transition.setFrame(view: expandedThumbnailsComponentView, frame: expandedThumbnailsFrame)
                    alphaTransition.setAlpha(view: expandedThumbnailsComponentView, alpha: expandedThumbnailsAlpha)
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
                        isPinned: expandedVideoState.isMainParticipantPinned,
                        backAction: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.updateMainParticipant(nil, nil)
                        },
                        pinAction: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            guard let expandedVideoState = component.expandedVideoState else {
                                return
                            }
                            
                            component.updateIsMainParticipantPinned(!expandedVideoState.isMainParticipantPinned)
                        }
                    )),
                    environment: {},
                    containerSize: itemLayout.expandedGrid.itemContainerFrame().size
                )
                let expandedControlsFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: expandedControlsSize)
                if let expandedControlsComponentView = expandedControlsView.view {
                    if expandedControlsComponentView.superview == nil {
                        self.expandedGridItemContainer.addSubview(expandedControlsComponentView)
                        
                        expandedControlsComponentView.alpha = expandedControlsAlpha
                        
                        let fromReferenceFrame: CGRect
                        if let index = self.gridParticipants.firstIndex(where: { $0.participant.peer.id ==  expandedVideoState.mainParticipant.id && $0.isPresentation == expandedVideoState.mainParticipant.isPresentation }) {
                            fromReferenceFrame = self.gridItemViewContainer.convert(itemLayout.gridItemFrame(at: index), to: self.expandedGridItemContainer)
                        } else {
                            fromReferenceFrame = previousExpandedGridItemContainerFrame
                        }
                        
                        expandedControlsComponentView.frame = CGRect(origin: CGPoint(x: fromReferenceFrame.minX - previousExpandedGridItemContainerFrame.minX, y: fromReferenceFrame.minY - previousExpandedGridItemContainerFrame.minY), size: expandedControlsFrame.size)
                        
                        if !transition.animation.isImmediate && expandedControlsAlpha != 0.0 {
                            expandedControlsComponentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                        }
                    }
                    transition.setFrame(view: expandedControlsComponentView, frame: expandedControlsFrame)
                    alphaTransition.setAlpha(view: expandedControlsComponentView, alpha: expandedControlsAlpha)
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
                        expandedThumbnailsComponentView.layer.animateAlpha(from: expandedThumbnailsComponentView.alpha, to: 0.0, duration: 0.12, removeOnCompletion: false, completion: { [weak expandedThumbnailsComponentView] _ in
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
                        expandedControlsComponentView.layer.animateAlpha(from: expandedControlsComponentView.alpha, to: 0.0, duration: 0.12, removeOnCompletion: false, completion: { [weak expandedControlsComponentView] _ in
                            expandedControlsComponentView?.removeFromSuperview()
                        })
                    } else {
                        expandedControlsView.view?.removeFromSuperview()
                    }
                }
            }
            
            if let expandedVideoState = component.expandedVideoState, expandedVideoState.isMainParticipantPinned, let participants = component.participants, !component.speakingParticipants.isEmpty, let firstOther = component.speakingParticipants.first(where: { $0 != expandedVideoState.mainParticipant.id }), let speakingPeer = participants.participants.first(where: { $0.peer.id == firstOther })?.peer {
                let expandedSpeakingToast: ComponentView<Empty>
                var expandedSpeakingToastTransition = transition
                if let current = self.expandedSpeakingToast {
                    expandedSpeakingToast = current
                } else {
                    expandedSpeakingToastTransition = expandedSpeakingToastTransition.withAnimation(.none)
                    expandedSpeakingToast = ComponentView()
                    self.expandedSpeakingToast = expandedSpeakingToast
                }
                let expandedSpeakingToastSize = expandedSpeakingToast.update(
                    transition: expandedSpeakingToastTransition,
                    component: AnyComponent(VideoChatExpandedSpeakingToastComponent(
                        context: component.call.accountContext,
                        peer: EnginePeer(speakingPeer),
                        strings: component.strings,
                        theme: component.theme,
                        action: { [weak self] peer in
                            guard let self, let component = self.component, let participants = component.participants else {
                                return
                            }
                            guard let participant = participants.participants.first(where: { $0.peer.id == peer.id }) else {
                                return
                            }
                            var key: VideoParticipantKey?
                            if participant.presentationDescription != nil {
                                key = VideoParticipantKey(id: peer.id, isPresentation: true)
                            } else if participant.videoDescription != nil {
                                key = VideoParticipantKey(id: peer.id, isPresentation: false)
                            }
                            if let key {
                                component.updateMainParticipant(key, nil)
                            }
                        }
                    )),
                    environment: {},
                    containerSize: itemLayout.expandedGrid.itemContainerFrame().size
                )
                let expandedSpeakingToastFrame = CGRect(origin: CGPoint(x: floor((itemLayout.expandedGrid.itemContainerFrame().size.width - expandedSpeakingToastSize.width) * 0.5), y: 44.0), size: expandedSpeakingToastSize)
                if let expandedSpeakingToastView = expandedSpeakingToast.view {
                    var animateIn = false
                    if expandedSpeakingToastView.superview == nil {
                        animateIn = true
                        self.expandedGridItemContainer.addSubview(expandedSpeakingToastView)
                    }
                    expandedSpeakingToastTransition.setFrame(view: expandedSpeakingToastView, frame: expandedSpeakingToastFrame)
                    
                    if animateIn {
                        alphaTransition.animateAlpha(view: expandedSpeakingToastView, from: 0.0, to: 1.0)
                        transition.animateScale(view: expandedSpeakingToastView, from: 0.6, to: 1.0)
                    }
                }
            } else {
                if let expandedSpeakingToast = self.expandedSpeakingToast {
                    self.expandedSpeakingToast = nil
                    if let expandedSpeakingToastView = expandedSpeakingToast.view {
                        alphaTransition.setAlpha(view: expandedSpeakingToastView, alpha: 0.0, completion: { [weak expandedSpeakingToastView] _ in
                            expandedSpeakingToastView?.removeFromSuperview()
                        })
                        transition.setScale(view: expandedSpeakingToastView, scale: 0.6)
                    }
                }
            }
            
            if let participants = component.participants, let loadMoreToken = participants.loadMoreToken, visibleListItemRange.maxIndex >= self.listParticipants.count - 5 {
                if self.currentLoadMoreToken != loadMoreToken {
                    self.currentLoadMoreToken = loadMoreToken
                    component.call.loadMoreMembers(token: loadMoreToken)
                }
            }
            
            component.visibleParticipantsUpdated(Set(visibleParticipants))
        }
        
        func setEventCycleState(scrollView: UIScrollView, eventCycleState: EventCycleState?) {
            if scrollView == self.scrollView {
                self.mainScrollViewEventCycleState = eventCycleState
            } else if scrollView == self.separateVideoScrollView {
                self.separateVideoScrollViewEventCycleState = eventCycleState
            }
        }
        
        func update(component: VideoChatParticipantsComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            self.state = state
            
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
            
            let inviteText: String
            if let participants = component.participants, let inviteType = participants.inviteType {
                switch inviteType {
                case .invite:
                    inviteText = "Invite Members"
                case .shareLink:
                    inviteText = "Share Invite Link"
                }
            } else {
                inviteText = "Invite Members"
            }
            let inviteListItemSize = self.inviteListItemView.update(
                transition: transition,
                component: AnyComponent(VideoChatListInviteComponent(
                    title: inviteText,
                    theme: component.theme,
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.openInviteMembers()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 1000.0)
            )
            
            var gridParticipants: [VideoParticipant] = []
            var listParticipants: [GroupCallParticipantsContext.Participant] = []
            if let participants = component.participants {
                for participant in participants.participants {
                    var isFullyMuted = false
                    if let muteState = participant.muteState, !muteState.canUnmute {
                        isFullyMuted = true
                    }
                    
                    var hasVideo = false
                    if participant.videoDescription != nil {
                        hasVideo = true
                        let videoParticipant = VideoParticipant(participant: participant, isPresentation: false)
                        if participant.peer.id == participants.myPeerId {
                            gridParticipants.insert(videoParticipant, at: 0)
                        } else {
                            gridParticipants.append(videoParticipant)
                        }
                    }
                    if participant.presentationDescription != nil {
                        hasVideo = true
                        let videoParticipant = VideoParticipant(participant: participant, isPresentation: true)
                        if participant.peer.id == participants.myPeerId {
                            gridParticipants.insert(videoParticipant, at: 0)
                        } else {
                            gridParticipants.append(videoParticipant)
                        }
                    }
                    if !hasVideo || component.layout.videoColumn != nil {
                        if participant.peer.id == participants.myPeerId && !isFullyMuted {
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
                layout: component.layout,
                isUIHidden: component.expandedVideoState?.isUIHidden ?? false,
                expandedInsets: component.expandedInsets,
                safeInsets: component.safeInsets,
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
                containerSize: CGSize(width: itemLayout.listFrame.width - itemLayout.layout.mainColumn.insets.left - itemLayout.layout.mainColumn.insets.right, height: itemLayout.list.contentHeight())
            )
            let listItemsBackgroundFrame = CGRect(origin: CGPoint(x: itemLayout.layout.mainColumn.insets.left, y: 0.0), size: listItemsBackgroundSize)
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
                    
                    if component.layout.videoColumn != nil && gridParticipants.count == 1 {
                        maxVideoQuality = .full
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
            
            transition.setPosition(view: self.scrollViewClippingContainer, position: itemLayout.scrollClippingFrame.center)
            transition.setBounds(view: self.scrollViewClippingContainer, bounds: CGRect(origin: CGPoint(x: itemLayout.scrollClippingFrame.minX - itemLayout.listFrame.minX, y: itemLayout.scrollClippingFrame.minY - itemLayout.listFrame.minY), size: itemLayout.scrollClippingFrame.size))
            transition.setFrame(view: self.scrollViewClippingContainer.cornersView, frame: itemLayout.scrollClippingFrame)
            self.scrollViewClippingContainer.update(params: SolidRoundedCornersContainer.Params(
                size: itemLayout.scrollClippingFrame.size,
                color: .black,
                cornerRadius: 10.0,
                smoothCorners: false
            ), transition: transition)
            
            if self.scrollViewBottomShadowView.image == nil {
                let height: CGFloat = 80.0
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
                
                self.scrollViewBottomShadowView.image = generateGradientImage(size: CGSize(width: 8.0, height: height), colors: colors.reversed(), locations: locations.reversed().map { 1.0 - $0 })!.withRenderingMode(.alwaysTemplate).stretchableImage(withLeftCapWidth: 0, topCapHeight: Int(height - 1.0))
                self.scrollViewBottomShadowView.tintColor = .black
            }
            let scrollViewBottomShadowOverflow: CGFloat = 30.0
            let scrollViewBottomShadowFrame = CGRect(origin: CGPoint(x: itemLayout.scrollClippingFrame.minX, y: itemLayout.scrollClippingFrame.maxY - component.layout.mainColumn.insets.bottom - scrollViewBottomShadowOverflow), size: CGSize(width: itemLayout.scrollClippingFrame.width, height: component.layout.mainColumn.insets.bottom + scrollViewBottomShadowOverflow))
            transition.setFrame(view: self.scrollViewBottomShadowView, frame: scrollViewBottomShadowFrame)
            
            transition.setPosition(view: self.separateVideoScrollViewClippingContainer, position: itemLayout.separateVideoScrollClippingFrame.center)
            transition.setBounds(view: self.separateVideoScrollViewClippingContainer, bounds: CGRect(origin: CGPoint(x: itemLayout.separateVideoScrollClippingFrame.minX - itemLayout.separateVideoGridFrame.minX, y: itemLayout.separateVideoScrollClippingFrame.minY - itemLayout.separateVideoGridFrame.minY), size: itemLayout.separateVideoScrollClippingFrame.size))
            transition.setFrame(view: self.separateVideoScrollViewClippingContainer.cornersView, frame: itemLayout.separateVideoScrollClippingFrame)
            self.separateVideoScrollViewClippingContainer.update(params: SolidRoundedCornersContainer.Params(
                size: itemLayout.separateVideoScrollClippingFrame.size,
                color: .black,
                cornerRadius: 10.0,
                smoothCorners: false
            ), transition: transition)
            
            self.ignoreScrolling = true
            if self.scrollView.bounds.size != itemLayout.listFrame.size {
                transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(), size: itemLayout.listFrame.size))
            }
            let contentSize = CGSize(width: itemLayout.listFrame.width, height: itemLayout.contentHeight())
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            
            if self.separateVideoScrollView.bounds.size != itemLayout.separateVideoGridFrame.size {
                transition.setFrame(view: self.separateVideoScrollView, frame: CGRect(origin: CGPoint(), size: itemLayout.separateVideoGridFrame.size))
            }
            let separateVideoContentSize = CGSize(width: itemLayout.separateVideoGridFrame.width, height: itemLayout.separateVideoGridContentHeight())
            if self.separateVideoScrollView.contentSize != separateVideoContentSize {
                self.separateVideoScrollView.contentSize = separateVideoContentSize
            }
            
            self.ignoreScrolling = false
            
            if itemLayout.layout.videoColumn == nil {
                if self.gridItemViewContainer.superview !== self.scrollView {
                    self.scrollView.addSubview(self.gridItemViewContainer)
                }
            } else {
                if self.gridItemViewContainer.superview !== self.separateVideoScrollView {
                    self.separateVideoScrollView.addSubview(self.gridItemViewContainer)
                }
            }
            
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
