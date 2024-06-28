import Foundation
import UIKit
import AsyncDisplayKit
import TelegramPresentationData
import ChatPresentationInterfaceState
import ComponentFlow
import AccountContext
import ViewControllerComponent
import TelegramCore
import SwiftSignalKit
import Display
import MultilineTextComponent
import ButtonComponent
import PlainButtonComponent
import Markdown
import EmojiStatusComponent
import SliderComponent
import RoundedRectWithTailPath
import AvatarNode
import BundleIconComponent

private final class BalanceComponent: CombinedComponent {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let balance: Int64?
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        balance: Int64?
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.balance = balance
    }
    
    static func ==(lhs: BalanceComponent, rhs: BalanceComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.balance != rhs.balance {
            return false
        }
        return true
    }
    
    static var body: Body {
        let title = Child(MultilineTextComponent.self)
        let balance = Child(MultilineTextComponent.self)
        let icon = Child(EmojiStatusComponent.self)
        
        return { context in
            var size = CGSize(width: 0.0, height: 0.0)
            
            //TODO:localize
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: "Balance", font: Font.regular(14.0), textColor: context.component.theme.list.itemPrimaryTextColor))
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )
            
            size.width = max(size.width, title.size.width)
            size.height += title.size.height
            
            let balanceText: String
            if let value = context.component.balance {
                balanceText = "\(value)"
            } else {
                balanceText = "..."
            }
            let balance = balance.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: balanceText, font: Font.medium(15.0), textColor: context.component.theme.list.itemPrimaryTextColor))
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )
            
            let iconSize = CGSize(width: 18.0, height: 18.0)
            let icon = icon.update(
                component: EmojiStatusComponent(
                    context: context.component.context,
                    animationCache: context.component.context.animationCache,
                    animationRenderer: context.component.context.animationRenderer,
                    content: .animation(
                        content: .customEmoji(fileId: MessageReaction.starsReactionId),
                        size: iconSize,
                        placeholderColor: .gray,
                        themeColor: nil,
                        loopMode: .count(0)
                    ),
                    isVisibleForAnimations: true,
                    action: nil
                ),
                availableSize: iconSize,
                transition: context.transition
            )
            
            let titleSpacing: CGFloat = 1.0
            let iconSpacing: CGFloat = 2.0
            
            size.height += titleSpacing
            
            size.width = max(size.width, icon.size.width + iconSpacing + balance.size.width)
            size.height += balance.size.height
            
            context.add(
                title.position(
                    title.size.centered(in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: title.size)).center
                )
            )
            context.add(
                balance.position(
                    balance.size.centered(in: CGRect(origin: CGPoint(x: icon.size.width + iconSpacing, y: title.size.height + titleSpacing), size: balance.size)).center
                )
            )
            context.add(
                icon.position(
                    icon.size.centered(in: CGRect(origin: CGPoint(x: 0.0, y: title.size.height + titleSpacing), size: icon.size)).center
                )
            )

            return size
        }
    }
}

private final class BadgeComponent: Component {
    let theme: PresentationTheme
    let title: String
    
    init(
        theme: PresentationTheme,
        title: String
    ) {
        self.theme = theme
        self.title = title
    }
    
    static func ==(lhs: BadgeComponent, rhs: BadgeComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let badgeView: UIView
        private let badgeMaskView: UIView
        private let badgeShapeLayer = SimpleShapeLayer()
        
        private let badgeForeground: SimpleLayer
        private let badgeIcon: UIImageView
        private let badgeLabel: BadgeLabelView
        private let badgeLabelMaskView = UIImageView()
        
        private var badgeTailPosition: CGFloat = 0.0
        private var badgeShapeArguments: (Double, Double, CGSize, CGFloat, CGFloat)?
        
        private var component: BadgeComponent?
        
        private var previousAvailableSize: CGSize?
        
        override init(frame: CGRect) {
            self.badgeView = UIView()
            self.badgeView.alpha = 0.0
            
            self.badgeShapeLayer.fillColor = UIColor.white.cgColor
            self.badgeShapeLayer.transform = CATransform3DMakeScale(1.0, -1.0, 1.0)
            
            self.badgeMaskView = UIView()
            self.badgeMaskView.layer.addSublayer(self.badgeShapeLayer)
            self.badgeView.mask = self.badgeMaskView
            
            self.badgeForeground = SimpleLayer()
            
            self.badgeIcon = UIImageView()
            self.badgeIcon.contentMode = .center
                        
            self.badgeLabel = BadgeLabelView()
            let _ = self.badgeLabel.update(value: "0", transition: .immediate)
            self.badgeLabel.mask = self.badgeLabelMaskView
            
            super.init(frame: frame)
            
            self.addSubview(self.badgeView)
            self.badgeView.layer.addSublayer(self.badgeForeground)
            self.badgeView.addSubview(self.badgeIcon)
            self.badgeView.addSubview(self.badgeLabel)
            
            self.badgeLabelMaskView.contentMode = .scaleToFill
            self.badgeLabelMaskView.image = generateImage(CGSize(width: 2.0, height: 36.0), rotatedContext: { size, context in
                let bounds = CGRect(origin: .zero, size: size)
                context.clear(bounds)
                
                let colorsArray: [CGColor] = [
                    UIColor(rgb: 0xffffff, alpha: 0.0).cgColor,
                    UIColor(rgb: 0xffffff).cgColor,
                    UIColor(rgb: 0xffffff).cgColor,
                    UIColor(rgb: 0xffffff, alpha: 0.0).cgColor,
                ]
                var locations: [CGFloat] = [0.0, 0.24, 0.76, 1.0]
                let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray as CFArray, locations: &locations)!

                context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
            })
            
            self.isUserInteractionEnabled = false
        }
        
        required init(coder: NSCoder) {
            preconditionFailure()
        }
        
        func update(component: BadgeComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            
            if self.component == nil {
                self.badgeIcon.image = UIImage(bundleImageName: "Premium/SendStarsStarSliderIcon")?.withRenderingMode(.alwaysTemplate)
            }
             
            self.component = component
            self.badgeIcon.tintColor = .white
            
            self.badgeLabel.color = .white
                
            let countWidth: CGFloat
            switch component.title.count {
            case 1:
                countWidth = 20.0
            case 2:
                countWidth = 35.0
            case 3:
                countWidth = 51.0
            case 4:
                countWidth = 60.0
            case 5:
                countWidth = 74.0
            case 6:
                countWidth = 88.0
            default:
                countWidth = 51.0
            }
            let badgeWidth: CGFloat = countWidth + 54.0
            
            let badgeSize = CGSize(width: badgeWidth, height: 48.0)
            let badgeFullSize = CGSize(width: badgeWidth, height: 48.0 + 12.0)
            self.badgeMaskView.frame = CGRect(origin: .zero, size: badgeFullSize)
            self.badgeShapeLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: -4.0), size: badgeFullSize)
            
            self.badgeView.bounds = CGRect(origin: .zero, size: badgeFullSize)
            
            transition.setAnchorPoint(layer: self.badgeView.layer, anchorPoint: CGPoint(x: 0.5, y: 1.0))
            
            self.badgeForeground.bounds = CGRect(origin: CGPoint(), size: CGSize(width: badgeFullSize.width * 3.0, height: badgeFullSize.height))
            if self.badgeForeground.animation(forKey: "movement") == nil {
                self.badgeForeground.position = CGPoint(x: badgeSize.width * 3.0 / 2.0 - self.badgeForeground.frame.width * 0.35, y: badgeFullSize.height / 2.0)
            }
    
            self.badgeIcon.frame = CGRect(x: 10.0, y: 9.0, width: 30.0, height: 30.0)
            self.badgeLabelMaskView.frame = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 36.0)
            
            self.badgeView.alpha = 1.0
            
            let size = badgeSize
            
            let badgeLabelSize = self.badgeLabel.update(value: component.title, transition: .easeInOut(duration: 0.12))
            transition.setFrame(view: self.badgeLabel, frame: CGRect(origin: CGPoint(x: 14.0 + floorToScreenPixels((badgeFullSize.width - badgeLabelSize.width) / 2.0), y: 5.0), size: badgeLabelSize))
            
            if self.previousAvailableSize != availableSize {
                self.previousAvailableSize = availableSize
                
                let activeColors: [UIColor] = [
                    UIColor(rgb: 0xFFAB03),
                    UIColor(rgb: 0xFFCB37)
                ]
                
                var locations: [CGFloat] = []
                let delta = 1.0 / CGFloat(activeColors.count - 1)
                for i in 0 ..< activeColors.count {
                    locations.append(delta * CGFloat(i))
                }
                
                let gradient = generateGradientImage(size: CGSize(width: 200.0, height: 60.0), colors: activeColors, locations: locations, direction: .horizontal)
                self.badgeForeground.contentsGravity = .resizeAspectFill
                self.badgeForeground.contents = gradient?.cgImage
                
                self.setupGradientAnimations()
            }
            
            return size
        }
        
        func adjustTail(size: CGSize, overflowWidth: CGFloat) {
            var tailPosition = size.width * 0.5
            tailPosition += overflowWidth
            tailPosition = max(0.0, min(size.width, tailPosition))
            
            self.badgeShapeLayer.path = generateRoundedRectWithTailPath(rectSize: size, tailPosition: tailPosition / size.width).cgPath
        }
        
        private func setupGradientAnimations() {
            guard let _ = self.component else {
                return
            }
            if let _ = self.badgeForeground.animation(forKey: "movement") {
            } else {
                CATransaction.begin()
                
                let badgeOffset = (self.badgeForeground.frame.width - self.badgeView.bounds.width) / 2.0
                let badgePreviousValue = self.badgeForeground.position.x
                var badgeNewValue: CGFloat = badgeOffset
                if badgeOffset - badgePreviousValue < self.badgeForeground.frame.width * 0.25 {
                    badgeNewValue -= self.badgeForeground.frame.width * 0.35
                }
                self.badgeForeground.position = CGPoint(x: badgeNewValue, y: self.badgeForeground.bounds.size.height / 2.0)
                
                let badgeAnimation = CABasicAnimation(keyPath: "position.x")
                badgeAnimation.duration = 4.5
                badgeAnimation.fromValue = badgePreviousValue
                badgeAnimation.toValue = badgeNewValue
                badgeAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                
                CATransaction.setCompletionBlock { [weak self] in
                    self?.setupGradientAnimations()
                }
                self.badgeForeground.add(badgeAnimation, forKey: "movement")
                
                CATransaction.commit()
            }
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class PeerBadgeComponent: Component {
    let theme: PresentationTheme
    let title: String
    
    init(
        theme: PresentationTheme,
        title: String
    ) {
        self.theme = theme
        self.title = title
    }
    
    static func ==(lhs: PeerBadgeComponent, rhs: PeerBadgeComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let backgroundMaskLayer = SimpleLayer()
        private let backgroundLayer = SimpleLayer()
        private let title = ComponentView<Empty>()
        private let icon = ComponentView<Empty>()

        private var component: PeerBadgeComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.layer.addSublayer(self.backgroundMaskLayer)
            self.layer.addSublayer(self.backgroundLayer)
        }
        
        required init(coder: NSCoder) {
            preconditionFailure()
        }
        
        func update(component: PeerBadgeComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(BundleIconComponent(
                    name: "Premium/SendStarsPeerBadgeStarIcon",
                    tintColor: .white)
                ),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            
            let sideInset: CGFloat = 3.0
            let titleSpacing: CGFloat = 1.0
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.bold(9.0), textColor: .white))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - titleSpacing - iconSize.width, height: 100.0)
            )
            
            let contentSize = CGSize(width: iconSize.width + titleSpacing + titleSize.width, height: titleSize.height)
            let size = CGSize(width: contentSize.width + sideInset * 2.0, height: contentSize.height + 3.0 * 2.0)
            
            self.backgroundMaskLayer.backgroundColor = component.theme.list.plainBackgroundColor.cgColor
            self.backgroundLayer.backgroundColor = UIColor(rgb: 0xFFB10D).cgColor
            
            let backgroundFrame = CGRect(origin: CGPoint(), size: size)
            self.backgroundLayer.frame = backgroundFrame
            
            let badkgroundMaskFrame = backgroundFrame.insetBy(dx: -1.0 - UIScreenPixel, dy: -1.0 - UIScreenPixel)
            self.backgroundMaskLayer.frame = badkgroundMaskFrame
            
            self.backgroundLayer.cornerRadius = backgroundFrame.height * 0.5
            self.backgroundMaskLayer.cornerRadius = badkgroundMaskFrame.height * 0.5
            
            let titleFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX + sideInset + iconSize.width + titleSpacing, y: floor((backgroundFrame.height - titleSize.height) * 0.5)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            
            let iconFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX + sideInset + 1.0, y: floor((backgroundFrame.height - iconSize.height) * 0.5)), size: iconSize)
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    self.addSubview(iconView)
                }
                iconView.frame = iconFrame
            }
            
            return size
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class PeerComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let peer: EnginePeer
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        peer: EnginePeer
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.peer = peer
    }
    
    static func ==(lhs: PeerComponent, rhs: PeerComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private var avatarNode: AvatarNode?
        private let badge = ComponentView<Empty>()
        private let title = ComponentView<Empty>()

        private var component: PeerComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init(coder: NSCoder) {
            preconditionFailure()
        }
        
        func update(component: PeerComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let avatarNode: AvatarNode
            if let current = self.avatarNode {
                avatarNode = current
            } else {
                avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 24.0))
                self.avatarNode = avatarNode
                self.addSubview(avatarNode.view)
            }
            
            let avatarSize = CGSize(width: 60.0, height: 60.0)
            let avatarFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: avatarSize)
            avatarNode.frame = avatarFrame
            avatarNode.setPeer(context: component.context, theme: component.theme, peer: component.peer)
            avatarNode.updateSize(size: avatarFrame.size)
            
            let badgeSize = self.badge.update(
                transition: .immediate,
                component: AnyComponent(PeerBadgeComponent(
                    theme: component.theme,
                    title: "800"
                )),
                environment: {},
                containerSize: CGSize(width: 200.0, height: 200.0)
            )
            let badgeFrame = CGRect(origin: CGPoint(x: avatarFrame.minX + floor((avatarFrame.width - badgeSize.width) * 0.5), y: avatarFrame.maxY - badgeSize.height + 3.0), size: badgeSize)
            if let badgeView = self.badge.view {
                if badgeView.superview == nil {
                    self.addSubview(badgeView)
                }
                badgeView.frame = badgeFrame
            }
            
            let titleSpacing: CGFloat = 8.0
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.peer.compactDisplayTitle, font: Font.regular(11.0), textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: avatarSize.width + 10.0 * 2.0, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floor((avatarSize.width - titleSize.width) * 0.5), y: avatarSize.height + titleSpacing), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            
            return CGSize(width: avatarSize.width, height: avatarSize.height + titleSpacing + titleSize.height)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class ChatSendStarsScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let peer: EnginePeer
    let balance: Int64?
    let topPeers: [EnginePeer]
    let completion: (Int64) -> Void
    
    init(
        context: AccountContext,
        peer: EnginePeer,
        balance: Int64?,
        topPeers: [EnginePeer],
        completion: @escaping (Int64) -> Void
    ) {
        self.context = context
        self.peer = peer
        self.balance = balance
        self.topPeers = topPeers
        self.completion = completion
    }
    
    static func ==(lhs: ChatSendStarsScreenComponent, rhs: ChatSendStarsScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.balance != rhs.balance {
            return false
        }
        if lhs.topPeers != rhs.topPeers {
            return false
        }
        return true
    }
    
    private struct ItemLayout: Equatable {
        var containerSize: CGSize
        var containerInset: CGFloat
        var bottomInset: CGFloat
        var topInset: CGFloat
        
        init(containerSize: CGSize, containerInset: CGFloat, bottomInset: CGFloat, topInset: CGFloat) {
            self.containerSize = containerSize
            self.containerInset = containerInset
            self.bottomInset = bottomInset
            self.topInset = topInset
        }
    }
    
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let dimView: UIView
        private let backgroundLayer: SimpleLayer
        private let navigationBarContainer: SparseContainerView
        private let scrollView: ScrollView
        private let scrollContentClippingView: SparseContainerView
        private let scrollContentView: UIView
        
        private let leftButton = ComponentView<Empty>()
        private let closeButton = ComponentView<Empty>()
        
        private let title = ComponentView<Empty>()
        private let descriptionText = ComponentView<Empty>()
        
        private let slider = ComponentView<Empty>()
        private let sliderBackground = UIView()
        private let sliderForeground = UIView()
        private let badge = ComponentView<Empty>()
        
        private var topPeersLeftSeparator: SimpleLayer?
        private var topPeersRightSeparator: SimpleLayer?
        private var topPeersTitleBackground: SimpleLayer?
        private var topPeersTitle: ComponentView<Empty>?
        
        private var topPeerItems: [EnginePeer.Id: ComponentView<Empty>] = [:]
        
        private let actionButton = ComponentView<Empty>()
        private let buttonDescriptionText = ComponentView<Empty>()
        
        private let bottomOverscrollLimit: CGFloat
        
        private var ignoreScrolling: Bool = false
        
        private var component: ChatSendStarsScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        private var itemLayout: ItemLayout?
        
        private var topOffsetDistance: CGFloat?
        
        private var amount: Int64 = 1
        private var cachedStarImage: (UIImage, PresentationTheme)?
        private var cachedCloseImage: UIImage?
        
        override init(frame: CGRect) {
            self.bottomOverscrollLimit = 200.0
            
            self.dimView = UIView()
            
            self.backgroundLayer = SimpleLayer()
            self.backgroundLayer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            self.backgroundLayer.cornerRadius = 10.0
            
            self.navigationBarContainer = SparseContainerView()
            
            self.scrollView = ScrollView()
            
            self.scrollContentClippingView = SparseContainerView()
            self.scrollContentClippingView.clipsToBounds = true
            
            self.scrollContentView = UIView()
            
            super.init(frame: frame)
            
            self.addSubview(self.dimView)
            self.layer.addSublayer(self.backgroundLayer)
            
            self.addSubview(self.navigationBarContainer)
            
            self.scrollView.delaysContentTouches = true
            self.scrollView.canCancelContentTouches = true
            self.scrollView.clipsToBounds = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            
            self.addSubview(self.scrollContentClippingView)
            self.scrollContentClippingView.addSubview(self.scrollView)
            
            self.scrollView.addSubview(self.scrollContentView)
            
            self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            guard let itemLayout = self.itemLayout, let topOffsetDistance = self.topOffsetDistance else {
                return
            }
            
            var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
            topOffset = max(0.0, topOffset)
            
            if topOffset < topOffsetDistance {
                targetContentOffset.pointee.y = scrollView.contentOffset.y
                scrollView.setContentOffset(CGPoint(x: 0.0, y: itemLayout.topInset), animated: true)
            }
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            if !self.backgroundLayer.frame.contains(point) {
                return self.dimView
            }
            
            if let result = self.navigationBarContainer.hitTest(self.convert(point, to: self.navigationBarContainer), with: event) {
                return result
            }
            
            let result = super.hitTest(point, with: event)
            return result
        }
        
        @objc private func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                guard let environment = self.environment, let controller = environment.controller() else {
                    return
                }
                controller.dismiss()
            }
        }
        
        private func updateScrolling(transition: ComponentTransition) {
            guard let environment = self.environment, let controller = environment.controller(), let itemLayout = self.itemLayout else {
                return
            }
            var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
            topOffset = max(0.0, topOffset)
            transition.setTransform(layer: self.backgroundLayer, transform: CATransform3DMakeTranslation(0.0, topOffset + itemLayout.containerInset, 0.0))
            
            transition.setPosition(view: self.navigationBarContainer, position: CGPoint(x: 0.0, y: topOffset + itemLayout.containerInset))
            
            let topOffsetDistance: CGFloat = min(200.0, floor(itemLayout.containerSize.height * 0.25))
            self.topOffsetDistance = topOffsetDistance
            var topOffsetFraction = topOffset / topOffsetDistance
            topOffsetFraction = max(0.0, min(1.0, topOffsetFraction))
            
            let transitionFactor: CGFloat = 1.0 - topOffsetFraction
            controller.updateModalStyleOverlayTransitionFactor(transitionFactor, transition: transition.containedViewLayoutTransition)
        }
        
        func animateIn() {
            self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            let animateOffset: CGFloat = self.bounds.height - self.backgroundLayer.frame.minY
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.backgroundLayer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.navigationBarContainer.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            if let actionButtonView = self.actionButton.view {
                actionButtonView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            }
            if let buttonDescriptionTextView = self.buttonDescriptionText.view {
                buttonDescriptionTextView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            }
        }
        
        func animateOut(completion: @escaping () -> Void) {
            let animateOffset: CGFloat = self.bounds.height - self.backgroundLayer.frame.minY
            
            self.dimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true, completion: { _ in
                completion()
            })
            self.backgroundLayer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            self.navigationBarContainer.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            if let actionButtonView = self.actionButton.view {
                actionButtonView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            }
            if let buttonDescriptionTextView = self.buttonDescriptionText.view {
                buttonDescriptionTextView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            }
        }
        
        func update(component: ChatSendStarsScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            
            let resetScrolling = self.scrollView.bounds.width != availableSize.width
            
            let sideInset: CGFloat = 16.0
            
            if self.component == nil {
                self.amount = 1
            }
            
            self.component = component
            self.state = state
            self.environment = environment
            
            if themeUpdated {
                self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
                self.backgroundLayer.backgroundColor = environment.theme.list.plainBackgroundColor.cgColor
                
                var locations: [NSNumber] = []
                var colors: [CGColor] = []
                let numStops = 6
                for i in 0 ..< numStops {
                    let step = CGFloat(i) / CGFloat(numStops - 1)
                    locations.append(step as NSNumber)
                    colors.append(environment.theme.list.blocksBackgroundColor.withAlphaComponent(1.0 - step * step).cgColor)
                }
            }
            
            transition.setFrame(view: self.dimView, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            var contentHeight: CGFloat = 0.0
            
            let sliderInset: CGFloat = sideInset + 8.0
            let sliderSize = self.slider.update(
                transition: transition,
                component: AnyComponent(SliderComponent(
                    valueCount: 1000,
                    value: 0,
                    markPositions: false,
                    trackBackgroundColor: .clear,
                    trackForegroundColor: .clear,
                    knobSize: 26.0,
                    knobColor: .white,
                    valueUpdated: { [weak self] value in
                        guard let self else {
                            return
                        }
                        self.amount = 1 + Int64(value)
                        self.state?.updated(transition: .immediate)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sliderInset * 2.0, height: 30.0)
            )
            let sliderFrame = CGRect(origin: CGPoint(x: sliderInset, y: contentHeight + 127.0), size: sliderSize)
            if let sliderView = self.slider.view {
                if sliderView.superview == nil {
                    self.scrollContentView.addSubview(self.sliderBackground)
                    self.scrollContentView.addSubview(self.sliderForeground)
                    self.scrollContentView.addSubview(sliderView)
                }
                transition.setFrame(view: sliderView, frame: sliderFrame)
                
                self.sliderBackground.backgroundColor = UIColor(rgb: 0xEEEEEF)
                self.sliderForeground.backgroundColor = UIColor(rgb: 0xFFB10D)
                
                let sliderBackgroundFrame = CGRect(origin: CGPoint(x: sliderFrame.minX - 8.0, y: sliderFrame.minY + 7.0), size: CGSize(width: sliderFrame.width + 16.0, height: sliderFrame.height - 14.0))
                transition.setFrame(view: self.sliderBackground, frame: sliderBackgroundFrame)
                
                let progressFraction: CGFloat = CGFloat(self.amount) / CGFloat(1000 - 1)
                let sliderMinWidth = sliderBackgroundFrame.height
                let sliderAreaWidth: CGFloat = sliderBackgroundFrame.width - sliderMinWidth
                let sliderForegroundFrame = CGRect(origin: CGPoint(x: sliderBackgroundFrame.minX, y: sliderBackgroundFrame.minY), size: CGSize(width: sliderMinWidth + floorToScreenPixels(sliderAreaWidth * progressFraction), height: sliderBackgroundFrame.height))
                transition.setFrame(view: self.sliderForeground, frame: sliderForegroundFrame)
                
                self.sliderBackground.layer.cornerRadius = sliderBackgroundFrame.height * 0.5
                self.sliderForeground.layer.cornerRadius = sliderBackgroundFrame.height * 0.5
                
                self.sliderForeground.isHidden = sliderForegroundFrame.width <= sliderMinWidth
                
                let badgeSize = self.badge.update(
                    transition: transition,
                    component: AnyComponent(BadgeComponent(
                        theme: environment.theme, title: "\(self.amount)")
                    ),
                    environment: {},
                    containerSize: CGSize(width: 200.0, height: 200.0)
                )
                var badgeFrame = CGRect(origin: CGPoint(x: sliderForegroundFrame.minX + sliderForegroundFrame.width - floorToScreenPixels(sliderMinWidth * 0.5), y: sliderForegroundFrame.minY - 8.0), size: badgeSize)
                if let badgeView = self.badge.view as? BadgeComponent.View {
                    if badgeView.superview == nil {
                        self.scrollContentView.addSubview(badgeView)
                    }
                    
                    let badgeSideInset = sideInset + 15.0
                    
                    let badgeOverflowWidth: CGFloat
                    if badgeFrame.minX - badgeSize.width * 0.5 < badgeSideInset {
                        badgeOverflowWidth = badgeSideInset - (badgeFrame.minX - badgeSize.width * 0.5)
                    } else if badgeFrame.minX + badgeSize.width * 0.5 > availableSize.width - badgeSideInset {
                        badgeOverflowWidth = availableSize.width - badgeSideInset - (badgeFrame.minX + badgeSize.width * 0.5)
                    } else {
                        badgeOverflowWidth = 0.0
                    }
                    
                    badgeFrame.origin.x += badgeOverflowWidth
                    
                    badgeView.frame = badgeFrame
                    
                    badgeView.adjustTail(size: badgeSize, overflowWidth: -badgeOverflowWidth)
                }
            }
            
            contentHeight += 123.0
            
            let leftButtonSize = self.leftButton.update(
                transition: transition,
                component: AnyComponent(BalanceComponent(
                    context: component.context,
                    theme: environment.theme,
                    strings: environment.strings,
                    balance: component.balance
                )),
                environment: {},
                containerSize: CGSize(width: 120.0, height: 100.0)
            )
            let leftButtonFrame = CGRect(origin: CGPoint(x: 16.0, y: floor((56.0 - leftButtonSize.height) * 0.5)), size: leftButtonSize)
            if let leftButtonView = self.leftButton.view {
                if leftButtonView.superview == nil {
                    self.navigationBarContainer.addSubview(leftButtonView)
                }
                transition.setFrame(view: leftButtonView, frame: leftButtonFrame)
            }
            
            if themeUpdated {
                self.cachedCloseImage = nil
            }
            let closeImage: UIImage
            if let current = self.cachedCloseImage {
                closeImage = current
            } else {
                closeImage = generateCloseButtonImage(backgroundColor: UIColor(rgb: 0x808084, alpha: 0.1), foregroundColor: environment.theme.actionSheet.inputClearButtonColor)!
                self.cachedCloseImage = closeImage
            }
            let closeButtonSize = self.closeButton.update(
                transition: .immediate,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(Image(image: closeImage)),
                    effectAlignment: .center,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.environment?.controller()?.dismiss()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 30.0, height: 30.0)
            )
            let closeButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - sideInset - closeButtonSize.width, y: floor((56.0 - leftButtonSize.height) * 0.5)), size: closeButtonSize)
            if let closeButtonView = self.closeButton.view {
                if closeButtonView.superview == nil {
                    self.navigationBarContainer.addSubview(closeButtonView)
                }
                transition.setFrame(view: closeButtonView, frame: closeButtonFrame)
            }
            
            let containerInset: CGFloat = environment.statusBarHeight + 10.0
            
            var initialContentHeight = contentHeight
            let clippingY: CGFloat
            
            let title = self.title
            let descriptionText = self.descriptionText
            let actionButton = self.actionButton
                
            let titleSize = title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: "React with Stars", font: Font.semibold(17.0), textColor: environment.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftButtonFrame.maxX * 2.0, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: floor((56.0 - titleSize.height) * 0.5)), size: titleSize)
            if let titleView = title.view {
                if titleView.superview == nil {
                    self.navigationBarContainer.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
                
            contentHeight += 56.0
            contentHeight += 8.0
                
            let text = "Choose how many stars you want to send to **\(component.peer.debugDisplayTitle)** to support this post."
                
            let body = MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.itemPrimaryTextColor)
            let bold = MarkdownAttributeSet(font: Font.semibold(15.0), textColor: environment.theme.list.itemPrimaryTextColor)
            
            let descriptionTextSize = descriptionText.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .markdown(text: text, attributes: MarkdownAttributes(
                        body: body,
                        bold: bold,
                        link: body,
                        linkAttribute: { _ in nil }
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - 16.0 * 2.0, height: 1000.0)
            )
            let descriptionTextFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - descriptionTextSize.width) * 0.5), y: contentHeight), size: descriptionTextSize)
            if let descriptionTextView = descriptionText.view {
                if descriptionTextView.superview == nil {
                    self.scrollContentView.addSubview(descriptionTextView)
                }
                transition.setFrame(view: descriptionTextView, frame: descriptionTextFrame)
            }
                
            contentHeight += descriptionTextFrame.height
            contentHeight += 22.0
            contentHeight += 2.0
            
            if !component.topPeers.isEmpty {
                contentHeight += 3.0
                
                let topPeersLeftSeparator: SimpleLayer
                if let current = self.topPeersLeftSeparator {
                    topPeersLeftSeparator = current
                } else {
                    topPeersLeftSeparator = SimpleLayer()
                    self.topPeersLeftSeparator = topPeersLeftSeparator
                    self.scrollContentView.layer.addSublayer(topPeersLeftSeparator)
                }
                
                let topPeersRightSeparator: SimpleLayer
                if let current = self.topPeersRightSeparator {
                    topPeersRightSeparator = current
                } else {
                    topPeersRightSeparator = SimpleLayer()
                    self.topPeersRightSeparator = topPeersRightSeparator
                    self.scrollContentView.layer.addSublayer(topPeersRightSeparator)
                }
                
                let topPeersTitleBackground: SimpleLayer
                if let current = self.topPeersTitleBackground {
                    topPeersTitleBackground = current
                } else {
                    topPeersTitleBackground = SimpleLayer()
                    self.topPeersTitleBackground = topPeersTitleBackground
                    self.scrollContentView.layer.addSublayer(topPeersTitleBackground)
                }
                
                let topPeersTitle: ComponentView<Empty>
                if let current = self.topPeersTitle {
                    topPeersTitle = current
                } else {
                    topPeersTitle = ComponentView()
                    self.topPeersTitle = topPeersTitle
                }
                
                topPeersLeftSeparator.backgroundColor = environment.theme.list.itemPlainSeparatorColor.cgColor
                topPeersRightSeparator.backgroundColor = environment.theme.list.itemPlainSeparatorColor.cgColor
                
                //TODO:localize
                let topPeersTitleSize = topPeersTitle.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: "Top Senders", font: Font.semibold(15.0), textColor: .white))
                    )),
                    environment: {},
                    containerSize: CGSize(width: 300.0, height: 100.0)
                )
                let topPeersBackgroundSize = CGSize(width: topPeersTitleSize.width + 16.0 * 2.0, height: topPeersTitleSize.height + 9.0 * 2.0)
                let topPeersBackgroundFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - topPeersBackgroundSize.width) * 0.5), y: contentHeight), size: topPeersBackgroundSize)
                
                topPeersTitleBackground.backgroundColor = UIColor(rgb: 0xFFB10D).cgColor
                topPeersTitleBackground.cornerRadius = topPeersBackgroundFrame.height * 0.5
                transition.setFrame(layer: topPeersTitleBackground, frame: topPeersBackgroundFrame)
                
                let topPeersTitleFrame = CGRect(origin: CGPoint(x: topPeersBackgroundFrame.minX + floor((topPeersBackgroundFrame.width - topPeersTitleSize.width) * 0.5), y: topPeersBackgroundFrame.minY + floor((topPeersBackgroundFrame.height - topPeersTitleSize.height) * 0.5)), size: topPeersTitleSize)
                if let topPeersTitleView = topPeersTitle.view {
                    if topPeersTitleView.superview == nil {
                        self.scrollContentView.addSubview(topPeersTitleView)
                    }
                    transition.setFrame(view: topPeersTitleView, frame: topPeersTitleFrame)
                }
                
                let separatorY = topPeersBackgroundFrame.midY
                let separatorSpacing: CGFloat = 10.0
                transition.setFrame(layer: topPeersLeftSeparator, frame: CGRect(origin: CGPoint(x: sideInset, y: separatorY), size: CGSize(width: max(0.0, topPeersBackgroundFrame.minX - separatorSpacing - sideInset), height: UIScreenPixel)))
                transition.setFrame(layer: topPeersRightSeparator, frame: CGRect(origin: CGPoint(x: topPeersBackgroundFrame.maxX + separatorSpacing, y: separatorY), size: CGSize(width: max(0.0, availableSize.width - sideInset - (topPeersBackgroundFrame.maxX + separatorSpacing)), height: UIScreenPixel)))
                
                var validIds: [EnginePeer.Id] = []
                var items: [(itemView: ComponentView<Empty>, size: CGSize)] = []
                for topPeer in component.topPeers {
                    validIds.append(topPeer.id)
                    
                    let itemView: ComponentView<Empty>
                    if let current = self.topPeerItems[topPeer.id] {
                        itemView = current
                    } else {
                        itemView = ComponentView()
                        self.topPeerItems[topPeer.id] = itemView
                    }
                    
                    let itemSize = itemView.update(
                        transition: .immediate,
                        component: AnyComponent(PeerComponent(
                            context: component.context,
                            theme: environment.theme,
                            strings: environment.strings,
                            peer: topPeer
                        )),
                        environment: {},
                        containerSize: CGSize(width: 200.0, height: 200.0)
                    )
                    items.append((itemView, itemSize))
                }
                var removedIds: [EnginePeer.Id] = []
                for (id, itemView) in self.topPeerItems {
                    if !validIds.contains(id) {
                        removedIds.append(id)
                        itemView.view?.removeFromSuperview()
                    }
                }
                for id in removedIds {
                    self.topPeerItems.removeValue(forKey: id)
                }
                
                var itemsWidth: CGFloat = 0.0
                for (_, itemSize) in items {
                    itemsWidth += itemSize.width
                }
                
                let maxItemSpacing = 48.0
                var itemSpacing = floor((availableSize.width - itemsWidth) / CGFloat(items.count + 1))
                itemSpacing = min(itemSpacing, maxItemSpacing)
                
                let totalWidth = itemsWidth + itemSpacing * CGFloat(items.count + 1)
                var itemX: CGFloat = floor((availableSize.width - totalWidth) * 0.5) + itemSpacing
                for (itemView, itemSize) in items {
                    if let itemComponentView = itemView.view {
                        if itemComponentView.superview == nil {
                            self.scrollContentView.addSubview(itemComponentView)
                        }
                        itemComponentView.frame = CGRect(origin: CGPoint(x: itemX, y: contentHeight + 56.0), size: itemSize)
                    }
                    itemX += itemSize.width + itemSpacing
                }
                
                contentHeight += 161.0
            }
            
            initialContentHeight = contentHeight
            
            if self.cachedStarImage == nil || self.cachedStarImage?.1 !== environment.theme {
                self.cachedStarImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/PremiumIcon"), color: .white)!, environment.theme)
            }
            
            let buttonString = "Send  # \(self.amount)"
            let buttonAttributedString = NSMutableAttributedString(string: buttonString, font: Font.semibold(17.0), textColor: .white, paragraphAlignment: .center)
            if let range = buttonAttributedString.string.range(of: "#"), let starImage = self.cachedStarImage?.0 {
                buttonAttributedString.addAttribute(.attachment, value: starImage, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.foregroundColor, value: UIColor(rgb: 0xffffff), range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.baselineOffset, value: 1.0, range: NSRange(range, in: buttonAttributedString.string))
            }
            
            let actionButtonSize = actionButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 10.0
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(MultilineTextComponent(text: .plain(buttonAttributedString)))
                    ),
                    isEnabled: true,
                    displaysProgress: false,
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.completion(self.amount)
                        self.environment?.controller()?.dismiss()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50.0)
            )
            
            let buttonDescriptionTextSize = self.buttonDescriptionText.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .markdown(text: "By sending Stars you agree to the [Terms of Service]()", attributes: MarkdownAttributes(
                        body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.itemSecondaryTextColor),
                        bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: environment.theme.list.itemSecondaryTextColor),
                        link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.itemAccentColor),
                        linkAttribute: { url in
                            return ("URL", url)
                        }
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset, height: 1000.0)
            )
            let buttonDescriptionSpacing: CGFloat = 14.0
            
            let bottomPanelHeight = 13.0 + environment.safeInsets.bottom + actionButtonSize.height + buttonDescriptionSpacing + buttonDescriptionTextSize.height
            let actionButtonFrame = CGRect(origin: CGPoint(x: sideInset, y: availableSize.height - bottomPanelHeight), size: actionButtonSize)
            if let actionButtonView = actionButton.view {
                if actionButtonView.superview == nil {
                    self.addSubview(actionButtonView)
                }
                transition.setFrame(view: actionButtonView, frame: actionButtonFrame)
            }
            
            let buttonDescriptionTextFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - buttonDescriptionTextSize.width) * 0.5), y: actionButtonFrame.maxY + buttonDescriptionSpacing), size: buttonDescriptionTextSize)
            if let buttonDescriptionTextView = buttonDescriptionText.view {
                if buttonDescriptionTextView.superview == nil {
                    self.addSubview(buttonDescriptionTextView)
                }
                transition.setFrame(view: buttonDescriptionTextView, frame: buttonDescriptionTextFrame)
            }
            
            contentHeight += bottomPanelHeight
            initialContentHeight += bottomPanelHeight
            
            clippingY = actionButtonFrame.minY - 24.0
            
            let topInset: CGFloat = max(0.0, availableSize.height - containerInset - initialContentHeight)
            
            let scrollContentHeight = max(topInset + contentHeight + containerInset, availableSize.height - containerInset)
            
            self.scrollContentClippingView.layer.cornerRadius = 10.0
            
            self.itemLayout = ItemLayout(containerSize: availableSize, containerInset: containerInset, bottomInset: environment.safeInsets.bottom, topInset: topInset)
            
            transition.setFrame(view: self.scrollContentView, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset + containerInset), size: CGSize(width: availableSize.width, height: contentHeight)))
            
            transition.setPosition(layer: self.backgroundLayer, position: CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0))
            transition.setBounds(layer: self.backgroundLayer, bounds: CGRect(origin: CGPoint(), size: availableSize))
            
            let scrollClippingFrame = CGRect(origin: CGPoint(x: 0.0, y: containerInset), size: CGSize(width: availableSize.width, height: clippingY - containerInset))
            transition.setPosition(view: self.scrollContentClippingView, position: scrollClippingFrame.center)
            transition.setBounds(view: self.scrollContentClippingView, bounds: CGRect(origin: CGPoint(x: scrollClippingFrame.minX, y: scrollClippingFrame.minY), size: scrollClippingFrame.size))
            
            self.ignoreScrolling = true
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: availableSize.height)))
            let contentSize = CGSize(width: availableSize.width, height: scrollContentHeight)
            if contentSize != self.scrollView.contentSize {
                self.scrollView.contentSize = contentSize
            }
            if resetScrolling {
                self.scrollView.bounds = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: availableSize)
            }
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class ChatSendStarsScreen: ViewControllerComponentContainer {
    public final class InitialData {
        let peer: EnginePeer
        let balance: Int64?
        let topPeers: [EnginePeer]
        
        fileprivate init(
            peer: EnginePeer,
            balance: Int64?,
            topPeers: [EnginePeer]
        ) {
            self.peer = peer
            self.balance = balance
            self.topPeers = topPeers
        }
    }
    
    private let context: AccountContext
    
    private var isDismissed: Bool = false
    
    private var presenceDisposable: Disposable?
    
    public init(context: AccountContext, initialData: InitialData, completion: @escaping (Int64) -> Void) {
        self.context = context
        
        super.init(context: context, component: ChatSendStarsScreenComponent(
            context: context,
            peer: initialData.peer,
            balance: initialData.balance,
            topPeers: initialData.topPeers,
            completion: completion
        ), navigationBarAppearance: .none)
        
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presenceDisposable?.dispose()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.disablesInteractiveModalDismiss = true
        
        if let componentView = self.node.hostView.componentView as? ChatSendStarsScreenComponent.View {
            componentView.animateIn()
        }
    }
    
    public static func initialData(context: AccountContext, peerId: EnginePeer.Id) -> Signal<InitialData?, NoError> {
        let balance: Signal<Int64?, NoError>
        if let starsContext = context.starsContext {
            balance = starsContext.state
            |> map { state in
                return state?.balance
            }
            |> take(1)
        } else {
            balance = .single(nil)
        }
        
        return combineLatest(
            context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)),
            context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)),
            balance
        )
        |> map { peer, accountPeer, balance -> InitialData? in
            guard let peer, let accountPeer else {
                return nil
            }
            
            return InitialData(
                peer: peer,
                balance: balance,
                topPeers: [accountPeer, peer]
            )
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            
            if let componentView = self.node.hostView.componentView as? ChatSendStarsScreenComponent.View {
                componentView.animateOut(completion: { [weak self] in
                    completion?()
                    self?.dismiss(animated: false)
                })
            } else {
                self.dismiss(animated: false)
            }
        }
    }
}

private func generateCloseButtonImage(backgroundColor: UIColor, foregroundColor: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(backgroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setStrokeColor(foregroundColor.cgColor)
        
        context.move(to: CGPoint(x: 10.0, y: 10.0))
        context.addLine(to: CGPoint(x: 20.0, y: 20.0))
        context.strokePath()
        
        context.move(to: CGPoint(x: 20.0, y: 10.0))
        context.addLine(to: CGPoint(x: 10.0, y: 20.0))
        context.strokePath()
    })
}
