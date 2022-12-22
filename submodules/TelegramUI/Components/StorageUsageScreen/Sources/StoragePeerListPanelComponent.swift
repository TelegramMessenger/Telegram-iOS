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
    let context: AccountContext
    let theme: PresentationTheme
    let sideInset: CGFloat
    let title: String
    let peer: EnginePeer?
    let label: String
    let hasNext: Bool
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        sideInset: CGFloat,
        title: String,
        peer: EnginePeer?,
        label: String,
        hasNext: Bool
    ) {
        self.context = context
        self.theme = theme
        self.sideInset = sideInset
        self.title = title
        self.peer = peer
        self.label = label
        self.hasNext = hasNext
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
        
        private var component: PeerListItemComponent?
        
        override init(frame: CGRect) {
            self.separatorLayer = SimpleLayer()
            self.avatarNode = AvatarNode(font: avatarFont)
            self.avatarNode.isLayerBacked = true
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.separatorLayer)
            self.layer.addSublayer(self.avatarNode.layer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: PeerListItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            self.component = component
            
            let height: CGFloat = 52.0
            let leftInset: CGFloat = 62.0 + component.sideInset
            let rightInset: CGFloat = 16.0 + component.sideInset
            
            let avatarSize: CGFloat = 40.0
            
            self.avatarNode.frame = CGRect(origin: CGPoint(x: component.sideInset + 10.0, y: floor((height - avatarSize) / 2.0)), size: CGSize(width: avatarSize, height: avatarSize))
            if let peer = component.peer {
                self.avatarNode.setPeer(context: component.context, theme: component.theme, peer: peer, displayDimensions: CGSize(width: avatarSize, height: avatarSize))
            }
            
            let labelSize = self.label.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.label, font: Font.regular(17.0), textColor: component.theme.list.itemSecondaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset - rightInset, height: 100.0)
            )
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.semibold(17.0), textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset - rightInset - labelSize.width - 4.0, height: 100.0)
            )
            
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: CGRect(origin: CGPoint(x: leftInset, y: floor((height - titleSize.height) / 2.0)), size: titleSize))
            }
            if let labelView = self.label.view {
                if labelView.superview == nil {
                    self.addSubview(labelView)
                }
                transition.setFrame(view: labelView, frame: CGRect(origin: CGPoint(x: availableSize.width - rightInset - labelSize.width, y: floor((height - labelSize.height) / 2.0)), size: labelSize))
            }
            
            if themeUpdated {
                self.separatorLayer.backgroundColor = component.theme.list.itemPlainSeparatorColor.cgColor
            }
            transition.setFrame(layer: self.separatorLayer, frame: CGRect(origin: CGPoint(x: leftInset, y: height), size: CGSize(width: availableSize.width - leftInset, height: UIScreenPixel)))
            self.separatorLayer.isHidden = !component.hasNext
            
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

    init(
        context: AccountContext,
        items: Items?
    ) {
        self.context = context
        self.items = items
    }
    
    static func ==(lhs: StoragePeerListPanelComponent, rhs: StoragePeerListPanelComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.items != rhs.items {
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
                    
                    let _ = itemView.update(
                        transition: itemTransition,
                        component: AnyComponent(PeerListItemComponent(
                            context: component.context,
                            theme: environment.theme,
                            sideInset: environment.containerInsets.left,
                            title: item.peer.displayTitle(strings: environment.strings, displayOrder: .firstLast),
                            peer: item.peer,
                            label: dataSizeString(item.size, formatting: dataSizeFormatting),
                            hasNext: index != items.items.count - 1
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
                    hasNext: false
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
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(), size: availableSize))
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
            self.updateScrolling(transition: .immediate)
            
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
