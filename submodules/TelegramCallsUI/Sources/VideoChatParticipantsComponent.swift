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
    let call: PresentationGroupCall
    let members: PresentationGroupCallMembers?
    let theme: PresentationTheme
    let strings: PresentationStrings
    let sideInset: CGFloat

    init(
        call: PresentationGroupCall,
        members: PresentationGroupCallMembers?,
        theme: PresentationTheme,
        strings: PresentationStrings,
        sideInset: CGFloat
    ) {
        self.call = call
        self.members = members
        self.theme = theme
        self.strings = strings
        self.sideInset = sideInset
    }

    static func ==(lhs: VideoChatParticipantsComponent, rhs: VideoChatParticipantsComponent) -> Bool {
        if lhs.members != rhs.members {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
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
        let list: List
        let spacing: CGFloat
        let listOffsetY: CGFloat

        init(containerSize: CGSize, sideInset: CGFloat, gridItemCount: Int, listItemCount: Int, listItemHeight: CGFloat, listTrailingItemHeight: CGFloat) {
            self.containerSize = containerSize
            self.sideInset = sideInset
            
            self.grid = Grid(containerSize: containerSize, sideInset: sideInset, itemCount: gridItemCount)
            self.list = List(containerSize: containerSize, sideInset: sideInset, itemCount: listItemCount, itemHeight: listItemHeight, trailingItemHeight: listTrailingItemHeight)
            self.spacing = 4.0
            
            var listOffsetY: CGFloat = 0.0
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
            return self.grid.visibleItemRange(for: rect)
        }
        
        func gridItemFrame(at index: Int) -> CGRect {
            return self.grid.frame(at: index)
        }
        
        func visibleListItemRange(for rect: CGRect) -> (minIndex: Int, maxIndex: Int) {
            return self.list.visibleItemRange(for: rect.offsetBy(dx: 0.0, dy: -self.listOffsetY))
        }
        
        func listItemFrame(at index: Int) -> CGRect {
            return self.list.frame(at: index).offsetBy(dx: 0.0, dy: self.listOffsetY)
        }
        
        func listTrailingItemFrame() -> CGRect {
            return self.list.trailingItemFrame().offsetBy(dx: 0.0, dy: self.listOffsetY)
        }
    }
    
    private final class VideoParticipant: Equatable {
        struct Key: Hashable {
            var id: EnginePeer.Id
            var isPresentation: Bool
            
            init(id: EnginePeer.Id, isPresentation: Bool) {
                self.id = id
                self.isPresentation = isPresentation
            }
        }
        
        let participant: GroupCallParticipantsContext.Participant
        let isPresentation: Bool
        
        var key: Key {
            return Key(id: self.participant.peer.id, isPresentation: self.isPresentation)
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

    final class View: UIView, UIScrollViewDelegate {
        private let scrollView: ScrollView
        
        private var component: VideoChatParticipantsComponent?
        private var isUpdating: Bool = false
        
        private var ignoreScrolling: Bool = false
        
        private var gridParticipants: [VideoParticipant] = []
        private var listParticipants: [GroupCallParticipantsContext.Participant] = []
        
        private let measureListItemView = ComponentView<Empty>()
        private let inviteListItemView = ComponentView<Empty>()
        
        private var gridItemViews: [VideoParticipant.Key: ComponentView<Empty>] = [:]
        
        private var listItemViews: [EnginePeer.Id: ComponentView<Empty>] = [:]
        private let listItemsBackround = ComponentView<Empty>()
        
        private var itemLayout: ItemLayout?
        
        override init(frame: CGRect) {
            self.scrollView = ScrollView()
            
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
            
            self.addSubview(self.scrollView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
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
            
            var validGridItemIds: [VideoParticipant.Key] = []
            let visibleGridItemRange = itemLayout.visibleGridItemRange(for: self.scrollView.bounds)
            if visibleGridItemRange.maxIndex >= visibleGridItemRange.minIndex {
                for i in visibleGridItemRange.minIndex ... visibleGridItemRange.maxIndex {
                    let videoParticipant = self.gridParticipants[i]
                    validGridItemIds.append(videoParticipant.key)
                    
                    var itemTransition = transition
                    let itemView: ComponentView<Empty>
                    if let current = self.gridItemViews[videoParticipant.key] {
                        itemView = current
                    } else {
                        itemTransition = itemTransition.withAnimation(.none)
                        itemView = ComponentView()
                        self.gridItemViews[videoParticipant.key] = itemView
                    }
                    
                    let itemFrame = itemLayout.gridItemFrame(at: i)
                    
                    let _ = itemView.update(
                        transition: itemTransition,
                        component: AnyComponent(VideoChatParticipantVideoComponent(
                            call: component.call,
                            participant: videoParticipant.participant,
                            isPresentation: videoParticipant.isPresentation
                        )),
                        environment: {},
                        containerSize: itemFrame.size
                    )
                    if let itemComponentView = itemView.view {
                        if itemComponentView.superview == nil {
                            self.scrollView.addSubview(itemComponentView)
                        }
                        itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
                    }
                }
            }
            
            var removedGridItemIds: [VideoParticipant.Key] = []
            for (itemId, itemView) in self.gridItemViews {
                if !validGridItemIds.contains(itemId) {
                    removedGridItemIds.append(itemId)
                    
                    if let itemComponentView = itemView.view {
                        itemComponentView.removeFromSuperview()
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
                            self.scrollView.addSubview(itemComponentView)
                        }
                        itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
                    }
                }
            }
            
            var removedListItemIds: [EnginePeer.Id] = []
            for (itemId, itemView) in self.listItemViews {
                if !validListItemIds.contains(itemId) {
                    removedListItemIds.append(itemId)
                    
                    if let itemComponentView = itemView.view {
                        itemComponentView.removeFromSuperview()
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
                        self.scrollView.addSubview(itemComponentView)
                    }
                    itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
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
            let listItemsBackroundFrame = CGRect(origin: CGPoint(x: itemLayout.sideInset, y: itemLayout.listOffsetY), size: listItemsBackroundSize)
            if let listItemsBackroundView = self.listItemsBackround.view {
                if listItemsBackroundView.superview == nil {
                    self.scrollView.addSubview(listItemsBackroundView)
                }
                transition.setFrame(view: listItemsBackroundView, frame: listItemsBackroundFrame)
            }
            
            var requestedVideo: [PresentationGroupCallRequestedVideo] = []
            if let members = component.members {
                for participant in members.participants {
                    if let videoChannel = participant.requestedVideoChannel(minQuality: .thumbnail, maxQuality: .medium) {
                        requestedVideo.append(videoChannel)
                    }
                    if let videoChannel = participant.requestedPresentationVideoChannel(minQuality: .thumbnail, maxQuality: .medium) {
                        requestedVideo.append(videoChannel)
                    }
                }
            }
            (component.call as! PresentationGroupCallImpl).setRequestedVideoList(items: requestedVideo)
            
            self.ignoreScrolling = true
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(), size: availableSize))
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
