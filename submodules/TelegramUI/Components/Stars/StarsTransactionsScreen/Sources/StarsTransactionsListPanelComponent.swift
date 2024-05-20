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
import ListActionItemComponent
import TelegramStringFormatting
import AvatarNode
import BundleIconComponent

final class StarsTransactionsListPanelComponent: Component {
    typealias EnvironmentType = StarsTransactionsPanelEnvironment
    
    final class Item: Equatable {
        let transaction: StarsContext.State.Transaction
        
        init(
            transaction: StarsContext.State.Transaction
        ) {
            self.transaction = transaction
        }
        
        static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.transaction != rhs.transaction {
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
    let action: (StarsContext.State.Transaction) -> Void

    init(
        context: AccountContext,
        items: Items?,
        action: @escaping (StarsContext.State.Transaction) -> Void
    ) {
        self.context = context
        self.items = items
        self.action = action
    }
    
    static func ==(lhs: StarsTransactionsListPanelComponent, rhs: StarsTransactionsListPanelComponent) -> Bool {
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
    
    private final class ScrollViewImpl: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    class View: UIView, UIScrollViewDelegate {
        private let scrollView: ScrollViewImpl
        
        private let measureItem = ComponentView<Empty>()
        private var visibleItems: [String: ComponentView<Empty>] = [:]
        private var separatorViews: [String: UIView] = [:]
        
        private var ignoreScrolling: Bool = false
        
        private var component: StarsTransactionsListPanelComponent?
        private var environment: StarsTransactionsPanelEnvironment?
        private var itemLayout: ItemLayout?
        
        override init(frame: CGRect) {
            self.scrollView = ScrollViewImpl()
            
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
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            cancelContextGestures(view: scrollView)
        }
        
        private func updateScrolling(transition: Transition) {
            guard let component = self.component, let environment = self.environment, let items = component.items, let itemLayout = self.itemLayout else {
                return
            }
            
            let visibleBounds = self.scrollView.bounds.insetBy(dx: 0.0, dy: -100.0)
                        
            var validIds = Set<String>()
            if let visibleItems = itemLayout.visibleItems(for: visibleBounds) {
                for index in visibleItems.lowerBound ..< visibleItems.upperBound {
                    if index >= items.items.count {
                        continue
                    }
                    let item = items.items[index]
                    let id = item.transaction.id
                    validIds.insert(id)
                    
                    var itemTransition = transition
                    let itemView: ComponentView<Empty>
                    let separatorView: UIView
                    if let current = self.visibleItems[id], let currentSeparator = self.separatorViews[id] {
                        itemView = current
                        separatorView = currentSeparator
                    } else {
                        itemTransition = .immediate
                        itemView = ComponentView()
                        self.visibleItems[id] = itemView
                        
                        separatorView = UIView()
                        self.separatorViews[id] = separatorView
                        self.addSubview(separatorView)
                    }
                    
                    separatorView.backgroundColor = environment.theme.list.itemBlocksSeparatorColor
                                  
                    let fontBaseDisplaySize = 17.0
                    
                    let itemTitle: String
                    let itemSubtitle: String
                    let itemLabel: NSAttributedString
                    switch item.transaction.peer {
                    case let .peer(peer):
                        itemTitle = peer.displayTitle(strings: environment.strings, displayOrder: .firstLast)
                        itemLabel = NSAttributedString(string: "- \(item.transaction.count * -1)", font: Font.medium(fontBaseDisplaySize), textColor: environment.theme.list.itemDestructiveColor)
                    case .appStore:
                        itemTitle = "In-App Purchase"
                        itemLabel = NSAttributedString(string: "+ \(item.transaction.count)", font: Font.medium(fontBaseDisplaySize), textColor: environment.theme.list.itemDisclosureActions.constructive.fillColor)
                    case .playMarket:
                        itemTitle = "Play Market"
                        itemLabel = NSAttributedString(string: "+ \(item.transaction.count)", font: Font.medium(fontBaseDisplaySize), textColor: environment.theme.list.itemDisclosureActions.constructive.fillColor)
                    case .fragment:
                        itemTitle = "Fragment"
                        itemLabel = NSAttributedString(string: "+ \(item.transaction.count)", font: Font.medium(fontBaseDisplaySize), textColor: environment.theme.list.itemDisclosureActions.constructive.fillColor)
                    }
                    itemSubtitle = stringForMediumCompactDate(timestamp: item.transaction.date, strings: environment.strings, dateTimeFormat: environment.dateTimeFormat)
                    
                    let _ = itemView.update(
                        transition: itemTransition,
                        component: AnyComponent(ListActionItemComponent(
                            theme: environment.theme,
                            title: AnyComponent(VStack([
                                AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: itemTitle,
                                        font: Font.semibold(fontBaseDisplaySize),
                                        textColor: environment.theme.list.itemPrimaryTextColor
                                    )),
                                    maximumNumberOfLines: 0
                                ))),
                                AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: itemSubtitle,
                                        font: Font.regular(floor(fontBaseDisplaySize * 14.0 / 17.0)),
                                        textColor: environment.theme.list.itemSecondaryTextColor
                                    )),
                                    maximumNumberOfLines: 0,
                                    lineSpacing: 0.18
                                )))
                            ], alignment: .left, spacing: 2.0)),
                            contentInsets: UIEdgeInsets(top: 11.0, left: 0.0, bottom: 11.0, right: 0.0),
                            leftIcon: .custom(AnyComponentWithIdentity(id: "avatar", component: AnyComponent(AvatarComponent(context: component.context, theme: environment.theme, peer: item.transaction.peer)))),
                            icon: nil,
                            accessory: .custom(ListActionItemComponent.CustomAccessory(component: AnyComponentWithIdentity(id: "label", component: AnyComponent(LabelComponent(text: itemLabel))), insets: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 16.0))),
                            action: { [weak self] _ in
                                guard let self, let component = self.component else {
                                    return
                                }
                                component.action(item.transaction)
                            }
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
                    let sideInset: CGFloat = 60.0
                    itemTransition.setFrame(view: separatorView, frame: CGRect(x: sideInset, y: itemFrame.maxY, width: itemFrame.width - sideInset, height: UIScreenPixel))
                }
            }
            
            var removeIds: [String] = []
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
            for (id, separatorView) in self.separatorViews {
                if !validIds.contains(id) {
                    transition.setAlpha(view: separatorView, alpha: 0.0, completion: { [weak separatorView] _ in
                        separatorView?.removeFromSuperview()
                    })
                }
            }
            for id in removeIds {
                self.visibleItems.removeValue(forKey: id)
            }
        }
        
        func update(component: StarsTransactionsListPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<StarsTransactionsPanelEnvironment>, transition: Transition) -> CGSize {
            self.component = component
            
            let environment = environment[StarsTransactionsPanelEnvironment.self].value
            self.environment = environment
            
            let fontBaseDisplaySize = 17.0
            let measureItemSize = self.measureItem.update(
                transition: .immediate,
                component: AnyComponent(ListActionItemComponent(
                    theme: environment.theme,
                    title: AnyComponent(VStack([
                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: "ABC",
                                font: Font.regular(fontBaseDisplaySize),
                                textColor: environment.theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 0
                        ))),
                        AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: "abc",
                                font: Font.regular(floor(fontBaseDisplaySize * 13.0 / 17.0)),
                                textColor: environment.theme.list.itemSecondaryTextColor
                            )),
                            maximumNumberOfLines: 0,
                            lineSpacing: 0.18
                        )))
                    ], alignment: .left, spacing: 2.0)),
                    leftIcon: nil,
                    icon: nil,
                    accessory: nil,
                    action: { _ in }
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
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<StarsTransactionsPanelEnvironment>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

func cancelContextGestures(view: UIView) {
    if let gestureRecognizers = view.gestureRecognizers {
        for gesture in gestureRecognizers {
            if let gesture = gesture as? ContextGesture {
                gesture.cancel()
            }
        }
    }
    for subview in view.subviews {
        cancelContextGestures(view: subview)
    }
}

private final class AvatarComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let peer: StarsContext.State.Transaction.Peer

    init(context: AccountContext, theme: PresentationTheme, peer: StarsContext.State.Transaction.Peer) {
        self.context = context
        self.theme = theme
        self.peer = peer
    }

    static func ==(lhs: AvatarComponent, rhs: AvatarComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        return true
    }

    final class View: UIView {
        private let avatarNode: AvatarNode
        private let backgroundView = UIImageView()
        private let iconView = UIImageView()
        
        private var component: AvatarComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 16.0))
            
            super.init(frame: frame)
            
            self.iconView.contentMode = .center
            self.iconView.image = UIImage(bundleImageName: "Premium/Stars/TopUp")
            
            self.addSubnode(self.avatarNode)
            self.addSubview(self.backgroundView)
            self.addSubview(self.iconView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: AvatarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            let size = CGSize(width: 40.0, height: 40.0)

            let gradientImage = generateGradientFilledCircleImage(diameter: size.width, colors: [UIColor(rgb: 0xf67447).cgColor, UIColor(rgb: 0xfdbe1c).cgColor], direction: .mirroredDiagonal)
            
            switch component.peer {
            case let .peer(peer):
                self.avatarNode.setPeer(
                    context: component.context,
                    theme: component.theme,
                    peer: peer,
                    synchronousLoad: true
                )
                self.backgroundView.isHidden = true
                self.iconView.isHidden = true
                self.avatarNode.isHidden = false
            case .appStore:
                self.backgroundView.image = gradientImage
                self.backgroundView.isHidden = false
                self.iconView.isHidden = false
                self.avatarNode.isHidden = true
            case .playMarket:
                self.backgroundView.image = gradientImage
                self.backgroundView.isHidden = false
                self.iconView.isHidden = false
                self.avatarNode.isHidden = true
            case .fragment:
                self.backgroundView.image = gradientImage
                self.backgroundView.isHidden = false
                self.iconView.isHidden = false
                self.avatarNode.isHidden = true
            }
            
            self.avatarNode.frame = CGRect(origin: .zero, size: size)
            self.iconView.frame = CGRect(origin: .zero, size: size)
            self.backgroundView.frame = CGRect(origin: .zero, size: size)

            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class LabelComponent: CombinedComponent {
    let text: NSAttributedString
    
    init(
        text: NSAttributedString
    ) {
        self.text = text
    }
    
    static func ==(lhs: LabelComponent, rhs: LabelComponent) -> Bool {
        if lhs.text != rhs.text {
            return false
        }
        return true
    }
    
    static var body: Body {
        let text = Child(MultilineTextComponent.self)
        let icon = Child(BundleIconComponent.self)

        return { context in
            let component = context.component
        
            let text = text.update(
                component: MultilineTextComponent(text: .plain(component.text)),
                availableSize: CGSize(width: 100.0, height: 40.0),
                transition: context.transition
            )
            
            let iconSize = CGSize(width: 20.0, height: 20.0)
            let icon = icon.update(
                component: BundleIconComponent(
                    name: "Premium/Stars/Star",
                    tintColor: nil
                ),
                availableSize: iconSize,
                transition: context.transition
            )
            
            let spacing: CGFloat = 3.0
            let totalWidth = text.size.width + spacing + iconSize.width
            let size = CGSize(width: totalWidth, height: iconSize.height)
            
            context.add(text
                .position(CGPoint(x: text.size.width / 2.0, y: size.height / 2.0))
            )
            context.add(icon
                .position(CGPoint(x: totalWidth - iconSize.width / 2.0, y: size.height / 2.0))
            )
            return size
        }
    }
}
