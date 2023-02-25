import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext
import TelegramCore
import MultilineTextComponent
import EmojiStatusComponent
import Postbox
import TelegramStringFormatting
import CheckNode
import AvatarNode

private let avatarFont = avatarPlaceholderFont(size: 15.0)

private final class PeerListItemComponent: Component {
    enum SelectionState: Equatable {
        case none
        case editing(isSelected: Bool)
    }
    
    let context: AccountContext
    let theme: PresentationTheme
    let sideInset: CGFloat
    let title: String
    let peer: EnginePeer?
    let label: String
    let selectionState: SelectionState
    let hasNext: Bool
    let action: (EnginePeer) -> Void
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        sideInset: CGFloat,
        title: String,
        peer: EnginePeer?,
        label: String,
        selectionState: SelectionState,
        hasNext: Bool,
        action: @escaping (EnginePeer) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.sideInset = sideInset
        self.title = title
        self.peer = peer
        self.label = label
        self.selectionState = selectionState
        self.hasNext = hasNext
        self.action = action
    }
    
    static func ==(lhs: PeerListItemComponent, rhs: PeerListItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.sideInset != rhs.sideInset {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.label != rhs.label {
            return false
        }
        if lhs.selectionState != rhs.selectionState {
            return false
        }
        if lhs.hasNext != rhs.hasNext {
            return false
        }
        return true
    }
    
    final class View: HighlightTrackingButton {
        private let title = ComponentView<Empty>()
        private let label = ComponentView<Empty>()
        private let separatorLayer: SimpleLayer
        private let avatarNode: AvatarNode
        
        private var checkLayer: CheckLayer?
        
        private var highlightBackgroundFrame: CGRect?
        private var highlightBackgroundLayer: SimpleLayer?
        
        private var component: PeerListItemComponent?
        
        override init(frame: CGRect) {
            self.separatorLayer = SimpleLayer()
            self.avatarNode = AvatarNode(font: avatarFont)
            self.avatarNode.isLayerBacked = true
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.separatorLayer)
            self.layer.addSublayer(self.avatarNode.layer)
            
            self.highligthedChanged = { [weak self] isHighlighted in
                guard let self, let component = self.component, let highlightBackgroundFrame = self.highlightBackgroundFrame else {
                    return
                }
                
                if isHighlighted, case .none = component.selectionState {
                    self.superview?.bringSubviewToFront(self)
                    
                    let highlightBackgroundLayer: SimpleLayer
                    if let current = self.highlightBackgroundLayer {
                        highlightBackgroundLayer = current
                    } else {
                        highlightBackgroundLayer = SimpleLayer()
                        self.highlightBackgroundLayer = highlightBackgroundLayer
                        self.layer.insertSublayer(highlightBackgroundLayer, above: self.separatorLayer)
                        highlightBackgroundLayer.backgroundColor = component.theme.list.itemHighlightedBackgroundColor.cgColor
                    }
                    highlightBackgroundLayer.frame = highlightBackgroundFrame
                    highlightBackgroundLayer.opacity = 1.0
                } else {
                    if let highlightBackgroundLayer = self.highlightBackgroundLayer {
                        self.highlightBackgroundLayer = nil
                        highlightBackgroundLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak highlightBackgroundLayer] _ in
                            highlightBackgroundLayer?.removeFromSuperlayer()
                        })
                    }
                }
            }
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            guard let component = self.component, let peer = component.peer else {
                return
            }
            component.action(peer)
        }
        
        func update(component: PeerListItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            
            var hasSelectionUpdated = false
            if let previousComponent = self.component {
                switch previousComponent.selectionState {
                case .none:
                    if case .none = component.selectionState {
                    } else {
                        hasSelectionUpdated = true
                    }
                case .editing:
                    if case .editing = component.selectionState {
                    } else {
                        hasSelectionUpdated = true
                    }
                }
            }
            
            self.component = component
            
            let height: CGFloat = 52.0
            var leftInset: CGFloat = 62.0 + component.sideInset
            var avatarLeftInset: CGFloat = component.sideInset + 10.0
            
            if case let .editing(isSelected) = component.selectionState {
                leftInset += 48.0
                avatarLeftInset += 48.0
                
                let checkSize: CGFloat = 22.0
                
                let checkLayer: CheckLayer
                if let current = self.checkLayer {
                    checkLayer = current
                    if themeUpdated {
                        checkLayer.theme = CheckNodeTheme(theme: component.theme, style: .plain)
                    }
                    checkLayer.setSelected(isSelected, animated: !transition.animation.isImmediate)
                } else {
                    checkLayer = CheckLayer(theme: CheckNodeTheme(theme: component.theme, style: .plain))
                    self.checkLayer = checkLayer
                    self.layer.addSublayer(checkLayer)
                    checkLayer.frame = CGRect(origin: CGPoint(x: -checkSize, y: floor((height - checkSize) / 2.0)), size: CGSize(width: checkSize, height: checkSize))
                    checkLayer.setSelected(isSelected, animated: false)
                    checkLayer.setNeedsDisplay()
                }
                transition.setFrame(layer: checkLayer, frame: CGRect(origin: CGPoint(x: component.sideInset + 20.0, y: floor((height - checkSize) / 2.0)), size: CGSize(width: checkSize, height: checkSize)))
            } else {
                if let checkLayer = self.checkLayer {
                    self.checkLayer = nil
                    transition.setPosition(layer: checkLayer, position: CGPoint(x: -checkLayer.bounds.width * 0.5, y: checkLayer.position.y), completion: { [weak checkLayer] _ in
                        checkLayer?.removeFromSuperlayer()
                    })
                }
            }
            
            let rightInset: CGFloat = 16.0 + component.sideInset
            
            let avatarSize: CGFloat = 40.0
            
            let avatarFrame = CGRect(origin: CGPoint(x: avatarLeftInset, y: floor((height - avatarSize) / 2.0)), size: CGSize(width: avatarSize, height: avatarSize))
            if self.avatarNode.bounds.isEmpty {
                self.avatarNode.frame = avatarFrame
            } else {
                transition.setFrame(layer: self.avatarNode.layer, frame: avatarFrame)
            }
            if let peer = component.peer {
                let clipStyle: AvatarNodeClipStyle
                if case let .channel(channel) = peer, channel.flags.contains(.isForum) {
                    clipStyle = .roundedRect
                } else {
                    clipStyle = .round
                }
                self.avatarNode.setPeer(context: component.context, theme: component.theme, peer: peer, clipStyle: clipStyle, displayDimensions: CGSize(width: avatarSize, height: avatarSize))
            }
            
            let labelSize = self.label.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.label, font: Font.regular(17.0), textColor: component.theme.list.itemSecondaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset - rightInset, height: 100.0)
            )
            
            let previousTitleFrame = self.title.view?.frame
            var previousTitleContents: UIView?
            if hasSelectionUpdated {
                previousTitleContents = self.title.view?.snapshotView(afterScreenUpdates: false)
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.semibold(17.0), textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset - rightInset - labelSize.width - 4.0, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: floor((height - titleSize.height) / 2.0)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.addSubview(titleView)
                }
                titleView.frame = titleFrame
                if let previousTitleFrame, previousTitleFrame.origin.x != titleFrame.origin.x {
                    transition.animatePosition(view: titleView, from: CGPoint(x: previousTitleFrame.origin.x - titleFrame.origin.x, y: 0.0), to: CGPoint(), additive: true)
                }
                
                if let previousTitleFrame, let previousTitleContents, previousTitleFrame.size != titleSize {
                    previousTitleContents.frame = CGRect(origin: previousTitleFrame.origin, size: previousTitleFrame.size)
                    self.addSubview(previousTitleContents)
                    
                    transition.setFrame(view: previousTitleContents, frame: CGRect(origin: titleFrame.origin, size: previousTitleFrame.size))
                    transition.setAlpha(view: previousTitleContents, alpha: 0.0, completion: { [weak previousTitleContents] _ in
                        previousTitleContents?.removeFromSuperview()
                    })
                    transition.animateAlpha(view: titleView, from: 0.0, to: 1.0)
                }
            }
            if let labelView = self.label.view {
                if labelView.superview == nil {
                    labelView.isUserInteractionEnabled = false
                    self.addSubview(labelView)
                }
                transition.setFrame(view: labelView, frame: CGRect(origin: CGPoint(x: availableSize.width - rightInset - labelSize.width, y: floor((height - labelSize.height) / 2.0)), size: labelSize))
            }
            
            if themeUpdated {
                self.separatorLayer.backgroundColor = component.theme.list.itemPlainSeparatorColor.cgColor
            }
            transition.setFrame(layer: self.separatorLayer, frame: CGRect(origin: CGPoint(x: leftInset, y: height), size: CGSize(width: availableSize.width - leftInset, height: UIScreenPixel)))
            self.separatorLayer.isHidden = !component.hasNext
            
            self.highlightBackgroundFrame = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: height + ((component.hasNext) ? UIScreenPixel : 0.0)))
            
            return CGSize(width: availableSize.width, height: height)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class StoragePeerListPanelComponent: Component {    
    typealias EnvironmentType = StorageUsagePanelEnvironment
    
    final class Item: Equatable {
        let peer: EnginePeer
        let size: Int64
        
        init(
            peer: EnginePeer,
            size: Int64
        ) {
            self.peer = peer
            self.size = size
        }
        
        static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.peer != rhs.peer {
                return false
            }
            if lhs.size != rhs.size {
                return false
            }
            return true
        }
    }
    
    final class Items: Equatable {
        let items: [Item]
        
        init(items: [Item]) {
            self.items = items
        }
        
        static func ==(lhs: Items, rhs: Items) -> Bool {
            if lhs === rhs {
                return true
            }
            return lhs.items == rhs.items
        }
    }
    
    let context: AccountContext
    let items: Items?
    let selectionState: StorageUsageScreenComponent.SelectionState?
    let peerAction: (EnginePeer) -> Void

    init(
        context: AccountContext,
        items: Items?,
        selectionState: StorageUsageScreenComponent.SelectionState?,
        peerAction: @escaping (EnginePeer) -> Void
    ) {
        self.context = context
        self.items = items
        self.selectionState = selectionState
        self.peerAction = peerAction
    }
    
    static func ==(lhs: StoragePeerListPanelComponent, rhs: StoragePeerListPanelComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.selectionState != rhs.selectionState {
            return false
        }
        return true
    }
    
    private struct ItemLayout: Equatable {
        let containerInsets: UIEdgeInsets
        let containerWidth: CGFloat
        let itemHeight: CGFloat
        let itemCount: Int
        
        let contentHeight: CGFloat
        
        init(
            containerInsets: UIEdgeInsets,
            containerWidth: CGFloat,
            itemHeight: CGFloat,
            itemCount: Int
        ) {
            self.containerInsets = containerInsets
            self.containerWidth = containerWidth
            self.itemHeight = itemHeight
            self.itemCount = itemCount
            
            self.contentHeight = containerInsets.top + containerInsets.bottom + CGFloat(itemCount) * itemHeight
        }
        
        func visibleItems(for rect: CGRect) -> Range<Int>? {
            let offsetRect = rect.offsetBy(dx: -self.containerInsets.left, dy: -self.containerInsets.top)
            var minVisibleRow = Int(floor((offsetRect.minY) / (self.itemHeight)))
            minVisibleRow = max(0, minVisibleRow)
            let maxVisibleRow = Int(ceil((offsetRect.maxY) / (self.itemHeight)))
            
            let minVisibleIndex = minVisibleRow
            let maxVisibleIndex = maxVisibleRow
            
            if maxVisibleIndex >= minVisibleIndex {
                return minVisibleIndex ..< (maxVisibleIndex + 1)
            } else {
                return nil
            }
        }
        
        func itemFrame(for index: Int) -> CGRect {
            return CGRect(origin: CGPoint(x: 0.0, y: self.containerInsets.top + CGFloat(index) * self.itemHeight), size: CGSize(width: self.containerWidth, height: self.itemHeight))
        }
    }
    
    class View: UIView, UIScrollViewDelegate {
        private let scrollView: UIScrollView
        
        private let measureItem = ComponentView<Empty>()
        private var visibleItems: [EnginePeer.Id: ComponentView<Empty>] = [:]
        
        private var ignoreScrolling: Bool = false
        
        private var component: StoragePeerListPanelComponent?
        private var environment: StorageUsagePanelEnvironment?
        private var itemLayout: ItemLayout?
        
        override init(frame: CGRect) {
            self.scrollView = UIScrollView()
            
            super.init(frame: frame)
            
            self.scrollView.delaysContentTouches = true
            self.scrollView.canCancelContentTouches = true
            self.scrollView.clipsToBounds = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
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
        
        private func updateScrolling(transition: Transition) {
            guard let component = self.component, let environment = self.environment, let items = component.items, let itemLayout = self.itemLayout else {
                return
            }
            
            let visibleBounds = self.scrollView.bounds.insetBy(dx: 0.0, dy: -100.0)
            
            let dataSizeFormatting = DataSizeStringFormatting(strings: environment.strings, decimalSeparator: ".")
            
            var validIds = Set<EnginePeer.Id>()
            if let visibleItems = itemLayout.visibleItems(for: visibleBounds) {
                for index in visibleItems.lowerBound ..< visibleItems.upperBound {
                    if index >= items.items.count {
                        continue
                    }
                    let item = items.items[index]
                    let id = item.peer.id
                    validIds.insert(id)
                    
                    var itemTransition = transition
                    let itemView: ComponentView<Empty>
                    if let current = self.visibleItems[id] {
                        itemView = current
                    } else {
                        itemTransition = .immediate
                        itemView = ComponentView()
                        self.visibleItems[id] = itemView
                    }
                    
                    let itemSelectionState: PeerListItemComponent.SelectionState
                    if let selectionState = component.selectionState {
                        itemSelectionState = .editing(isSelected: selectionState.selectedPeers.contains(id))
                    } else {
                        itemSelectionState = .none
                    }
                    
                    let _ = itemView.update(
                        transition: itemTransition,
                        component: AnyComponent(PeerListItemComponent(
                            context: component.context,
                            theme: environment.theme,
                            sideInset: environment.containerInsets.left,
                            title: item.peer.displayTitle(strings: environment.strings, displayOrder: .firstLast),
                            peer: item.peer,
                            label: dataSizeString(item.size, formatting: dataSizeFormatting),
                            selectionState: itemSelectionState,
                            hasNext: index != items.items.count - 1,
                            action: component.peerAction
                        )),
                        environment: {},
                        containerSize: CGSize(width: itemLayout.containerWidth, height: itemLayout.itemHeight)
                    )
                    let itemFrame = itemLayout.itemFrame(for: index)
                    if let itemComponentView = itemView.view {
                        if itemComponentView.superview == nil {
                            self.scrollView.addSubview(itemComponentView)
                        }
                        itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
                    }
                }
            }
            
            var removeIds: [EnginePeer.Id] = []
            for (id, itemView) in self.visibleItems {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    if let itemComponentView = itemView.view {
                        transition.setAlpha(view: itemComponentView, alpha: 0.0, completion: { [weak itemComponentView] _ in
                            itemComponentView?.removeFromSuperview()
                        })
                    }
                }
            }
            for id in removeIds {
                self.visibleItems.removeValue(forKey: id)
            }
        }
        
        func update(component: StoragePeerListPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<StorageUsagePanelEnvironment>, transition: Transition) -> CGSize {
            self.component = component
            
            let environment = environment[StorageUsagePanelEnvironment.self].value
            self.environment = environment
            
            let measureItemSize = self.measureItem.update(
                transition: .immediate,
                component: AnyComponent(PeerListItemComponent(
                    context: component.context,
                    theme: environment.theme,
                    sideInset: environment.containerInsets.left,
                    title: "ABCDEF",
                    peer: nil,
                    label: "1000",
                    selectionState: .none,
                    hasNext: false,
                    action: { _ in
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 1000.0)
            )
            
            let itemLayout = ItemLayout(
                containerInsets: environment.containerInsets,
                containerWidth: availableSize.width,
                itemHeight: measureItemSize.height,
                itemCount: component.items?.items.count ?? 0
            )
            self.itemLayout = itemLayout
            
            self.ignoreScrolling = true
            let contentOffset = self.scrollView.bounds.minY
            transition.setPosition(view: self.scrollView, position: CGRect(origin: CGPoint(), size: availableSize).center)
            var scrollBounds = self.scrollView.bounds
            scrollBounds.size = availableSize
            if !environment.isScrollable {
                scrollBounds.origin = CGPoint()
            }
            transition.setBounds(view: self.scrollView, bounds: scrollBounds)
            self.scrollView.isScrollEnabled = environment.isScrollable
            let contentSize = CGSize(width: availableSize.width, height: itemLayout.contentHeight)
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            self.scrollView.scrollIndicatorInsets = environment.containerInsets
            if !transition.animation.isImmediate && self.scrollView.bounds.minY != contentOffset {
                let deltaOffset = self.scrollView.bounds.minY - contentOffset
                transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: -deltaOffset), to: CGPoint(), additive: true)
            }
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<StorageUsagePanelEnvironment>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
