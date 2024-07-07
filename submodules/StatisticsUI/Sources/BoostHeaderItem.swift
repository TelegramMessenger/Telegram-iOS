import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import Markdown
import ComponentFlow
import PremiumUI
import MultilineTextComponent
import BundleIconComponent
import PlainButtonComponent
import AccountContext

final class BoostHeaderItem: ItemListControllerHeaderItem {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let status: ChannelBoostStatus?
    let title: String
    let text: String
    let openBoost: () -> Void
    let createGiveaway: () -> Void
    let openFeatures: () -> Void
    let back: () -> Void
    let updateStatusBar: (StatusBarStyle) -> Void
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, status: ChannelBoostStatus?, title: String, text: String, openBoost: @escaping () -> Void, createGiveaway: @escaping () -> Void, openFeatures: @escaping () -> Void, back: @escaping () -> Void, updateStatusBar: @escaping (StatusBarStyle) -> Void) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.status = status
        self.title = title
        self.text = text
        self.openBoost = openBoost
        self.createGiveaway = createGiveaway
        self.openFeatures = openFeatures
        self.back = back
        self.updateStatusBar = updateStatusBar
    }
    
    func isEqual(to: ItemListControllerHeaderItem) -> Bool {
        if let item = to as? BoostHeaderItem {
            return self.theme === item.theme && self.title == item.title && self.text == item.text && self.status == item.status
        } else {
            return false
        }
    }
    
    func node(current: ItemListControllerHeaderItemNode?) -> ItemListControllerHeaderItemNode {
        if let current = current as? BoostHeaderItemNode {
            current.item = self
            return current
        } else {
            return BoostHeaderItemNode(item: self)
        }
    }
}

private let titleFont = Font.semibold(17.0)

final class BoostHeaderItemNode: ItemListControllerHeaderItemNode {
    private let backgroundNode: NavigationBackgroundNode
    private let separatorNode: ASDisplayNode
    private let whiteTitleNode: ImmediateTextNode
    private let titleNode: ImmediateTextNode
    private let backButton = PeerInfoHeaderNavigationButton()
    
    private var hostView: ComponentHostView<Empty>?
    
    private var component: AnyComponent<Empty>?
    private var validLayout: ContainerViewLayout?
        
    fileprivate var item: BoostHeaderItem {
        didSet {
            self.updateItem()
            if let layout = self.validLayout {
                let _ = self.updateLayout(layout: layout, transition: .animated(duration: 0.2, curve: .easeInOut))
            }
        }
    }
    
    init(item: BoostHeaderItem) {
        self.item = item
        
        self.backgroundNode = NavigationBackgroundNode(color: item.theme.rootController.navigationBar.blurredBackgroundColor)
        self.backgroundNode.alpha = 0.0
        self.separatorNode = ASDisplayNode()
        self.separatorNode.alpha = 0.0
        
        self.whiteTitleNode = ImmediateTextNode()
        self.whiteTitleNode.isUserInteractionEnabled = false
        self.whiteTitleNode.contentMode = .left
        self.whiteTitleNode.contentsScale = UIScreen.main.scale
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.alpha = 0.0
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale

        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.whiteTitleNode)
        self.addSubnode(self.backButton)
                
        self.updateItem()
        
        self.backButton.action = { [weak self] _, _ in
            if let self {
                self.item.back()
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        let hostView = ComponentHostView<Empty>()
        self.hostView = hostView
        self.view.insertSubview(hostView, at: 0)
        
        if let layout = self.validLayout, let component = self.component {
            let navigationBarHeight: CGFloat = 44.0
            let statusBarHeight = layout.statusBarHeight ?? 0.0
            let containerSize = CGSize(width: layout.size.width, height: navigationBarHeight + statusBarHeight + 266.0)
            
            let size = hostView.update(
                transition: .immediate,
                component: component,
                environment: {},
                containerSize: containerSize
            )
            hostView.frame = CGRect(origin: CGPoint(x: 0.0, y: -self.contentOffset), size: size)
        }
    }
    
    func updateItem() {
        self.backgroundNode.updateColor(color: self.item.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
        self.separatorNode.backgroundColor = self.item.theme.rootController.navigationBar.separatorColor
        
        self.titleNode.attributedText = NSAttributedString(string: self.item.title, font: titleFont, textColor: self.item.theme.list.itemPrimaryTextColor, paragraphAlignment: .center)
        self.whiteTitleNode.attributedText = NSAttributedString(string: self.item.title, font: titleFont, textColor: .white, paragraphAlignment: .center)
    }
    
    private var contentOffset: CGFloat = 0.0
    override func updateContentOffset(_ contentOffset: CGFloat, transition: ContainedViewLayoutTransition) {
        guard let layout = self.validLayout else {
            return
        }
        self.contentOffset = contentOffset
        
        let topPanelAlpha = min(20.0, max(0.0, contentOffset - 44.0)) / 20.0
        transition.updateAlpha(node: self.backgroundNode, alpha: topPanelAlpha)
        transition.updateAlpha(node: self.separatorNode, alpha: topPanelAlpha)
        
        transition.updateAlpha(node: self.titleNode, alpha: topPanelAlpha)
        transition.updateAlpha(node: self.whiteTitleNode, alpha: 1.0 - topPanelAlpha)
        
        let scrolledUp = topPanelAlpha < 0.5
        self.backButton.updateContentsColor(backgroundColor: scrolledUp ? UIColor(white: 1.0, alpha: 0.2) : .clear, contentsColor: scrolledUp ? .white : self.item.theme.rootController.navigationBar.accentTextColor, canBeExpanded: !scrolledUp, transition: .animated(duration: 0.2, curve: .easeInOut))
        
        if scrolledUp {
            self.item.updateStatusBar(.White)
        } else {
            self.item.updateStatusBar(.Ignore)
        }
        
        if let hostView = self.hostView {
            hostView.center = CGPoint(x: layout.size.width / 2.0, y: hostView.frame.height / 2.0 - contentOffset)
        }
    }
    
    override func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) -> CGFloat {
        let isFirstTime = self.validLayout == nil
        let leftInset: CGFloat = 24.0
        
        let navigationBarHeight: CGFloat = 44.0
        let statusBarHeight = layout.statusBarHeight ?? 0.0
        
        let constrainedSize = CGSize(width: layout.size.width - leftInset * 2.0, height: CGFloat.greatestFiniteMagnitude)
        let titleSize = self.titleNode.updateLayout(constrainedSize)
        let _ = self.whiteTitleNode.updateLayout(constrainedSize)
       
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: .zero, size: CGSize(width: layout.size.width, height: statusBarHeight + navigationBarHeight)))
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: statusBarHeight + navigationBarHeight), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
        
        self.backgroundNode.update(size: CGSize(width: layout.size.width, height: statusBarHeight + navigationBarHeight), transition: transition)
               
        let component = AnyComponent(BoostHeaderComponent(
            strings: self.item.strings, 
            text: self.item.text,
            status: self.item.status,
            insets: layout.safeInsets,
            openBoost: self.item.openBoost,
            createGiveaway: self.item.createGiveaway,
            openFeatures: self.item.openFeatures
        ))
        let containerSize = CGSize(width: layout.size.width, height: navigationBarHeight + statusBarHeight + 266.0)
        
        if let hostView = self.hostView {
            let size = hostView.update(
                transition: ComponentTransition(transition),
                component: component,
                environment: {},
                containerSize: containerSize
            )
            hostView.frame = CGRect(origin: CGPoint(x: 0.0, y: -self.contentOffset), size: size)
        }

        self.titleNode.bounds = CGRect(origin: .zero, size: titleSize)
        self.titleNode.position = CGPoint(x: layout.size.width / 2.0, y: statusBarHeight + navigationBarHeight / 2.0)
       
        self.whiteTitleNode.bounds = self.titleNode.bounds
        self.whiteTitleNode.position = self.titleNode.position
                
        let backSize = self.backButton.update(key: .back, presentationData: self.item.context.sharedContext.currentPresentationData.with { $0 }, height: 44.0)
        self.backButton.frame = CGRect(origin: CGPoint(x: layout.safeInsets.left + 16.0, y: statusBarHeight), size: backSize)
        
        self.component = component
        self.validLayout = layout
        
        if isFirstTime {
            self.backButton.updateContentsColor(backgroundColor: UIColor(white: 1.0, alpha: 0.2), contentsColor: .white, canBeExpanded: false, transition: .immediate)
        }
        
        return containerSize.height
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if let hostView = self.hostView, hostView.frame.contains(point) {
            return true
        } else {
            return super.point(inside: point, with: event)
        }
    }
}

private final class BoostHeaderComponent: CombinedComponent {
    let strings: PresentationStrings
    let text: String
    let status: ChannelBoostStatus?
    let insets: UIEdgeInsets
    let openBoost: () -> Void
    let createGiveaway: () -> Void
    let openFeatures: () -> Void
    
    public init(
        strings: PresentationStrings,
        text: String,
        status: ChannelBoostStatus?,
        insets: UIEdgeInsets,
        openBoost: @escaping () -> Void,
        createGiveaway: @escaping () -> Void,
        openFeatures: @escaping () -> Void
    ) {
        self.strings = strings
        self.text = text
        self.status = status
        self.insets = insets
        self.openBoost = openBoost
        self.createGiveaway = createGiveaway
        self.openFeatures = openFeatures
    }

    public static func ==(lhs: BoostHeaderComponent, rhs: BoostHeaderComponent) -> Bool {
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.status != rhs.status {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        return true
    }

    public static var body: Body {
        let background = Child(PremiumGradientBackgroundComponent.self)
        let stars = Child(BoostHeaderBackgroundComponent.self)
        let progress = Child(PremiumLimitDisplayComponent.self)
        let text = Child(MultilineTextComponent.self)
        
        let boostButton = Child(PlainButtonComponent.self)
        let giveawayButton = Child(PlainButtonComponent.self)
        let featuresButton = Child(PlainButtonComponent.self)

        return { context in
            let size = context.availableSize
            
            let component = context.component
            let sideInset: CGFloat = 16.0 + component.insets.left
            
            let background = background.update(
                component: PremiumGradientBackgroundComponent(
                    colors: [
                        UIColor(rgb: 0x0077ff),
                        UIColor(rgb: 0x6b93ff),
                        UIColor(rgb: 0x8878ff),
                        UIColor(rgb: 0xe46ace)
                    ],
                    cornerRadius: 0.0,
                    topOverscroll: true
                ),
                availableSize: size,
                transition: context.transition
            )
            context.add(background
                .position(CGPoint(x: size.width / 2.0, y: size.height / 2.0))
            )
            
            let stars = stars.update(
                component: BoostHeaderBackgroundComponent(
                    isVisible: true,
                    hasIdleAnimations: true
                ),
                availableSize: size,
                transition: context.transition
            )
            context.add(stars
                .position(CGPoint(x: size.width / 2.0, y: size.height / 2.0 + 10.0))
            )
            
            let boosts: Int
            let level = component.status?.level ?? 0
            let position: CGFloat
            if let status = component.status {
                if let nextLevelBoosts = status.nextLevelBoosts {
                    position = CGFloat(status.boosts - status.currentLevelBoosts) / CGFloat(nextLevelBoosts - status.currentLevelBoosts)
                } else {
                    position = 1.0
                }
                boosts = status.boosts
            } else {
                boosts = 0
                position = 0.0
            }
            
            let inactiveText = component.strings.ChannelBoost_Level("\(level)").string
            let activeText = component.strings.ChannelBoost_Level("\(level + 1)").string
            
            let progress = progress.update(
                component: PremiumLimitDisplayComponent(
                    inactiveColor: UIColor.white.withAlphaComponent(0.2),
                    activeColors: [.white, .white],
                    inactiveTitle: inactiveText,
                    inactiveValue: "",
                    inactiveTitleColor: .white,
                    activeTitle: "",
                    activeValue: activeText,
                    activeTitleColor: UIColor(rgb: 0x6f8fff),
                    badgeIconName: "Premium/Boost",
                    badgeText: "\(boosts)",
                    badgePosition: position,
                    badgeGraphPosition: position,
                    invertProgress: true,
                    isPremiumDisabled: false
                ),
                availableSize: CGSize(width: size.width - sideInset * 2.0, height: size.height),
                transition: context.transition
            )

            context.add(progress
                .position(CGPoint(x: size.width / 2.0, y: size.height / 2.0 - 36.0))
            )

            let font = Font.regular(15.0)
            let boldFont = Font.semibold(15.0)
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: font, textColor: .white), bold: MarkdownAttributeSet(font: boldFont, textColor: .white), link: MarkdownAttributeSet(font: font, textColor: .white), linkAttribute: { _ in return nil})
            
            let text = text.update(
                component: MultilineTextComponent(
                    text: .markdown(text: component.text, attributes: markdownAttributes),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: size.width - sideInset * 3.0, height: size.height),
                transition: context.transition
            )
            context.add(text
                .position(CGPoint(x: size.width / 2.0, y: size.height - 114.0))
            )
            
            let minButtonWidth: CGFloat = 112.0
//            let buttonSpacing = (size.width - sideInset * 2.0 - minButtonWidth * 3.0) / 2.0
            let buttonHeight: CGFloat = 58.0
             
            let boostButton = boostButton.update(
                component: PlainButtonComponent(
                    content: AnyComponent(
                        BoostButtonComponent(
                            iconName: "Premium/Boosts/Boost",
                            title: component.strings.ChannelBoost_Header_Boost
                        )
                    ),
                    effectAlignment: .center,
                    action: {
                        component.openBoost()
                    }
                ),
                availableSize: CGSize(width: minButtonWidth, height: buttonHeight),
                transition: context.transition
            )
            context.add(boostButton
                .position(CGPoint(x: sideInset + minButtonWidth / 2.0, y: size.height - 45.0))
            )
            
            let giveawayButton = giveawayButton.update(
                component: PlainButtonComponent(
                    content: AnyComponent(
                        BoostButtonComponent(
                            iconName: "Premium/Boosts/Giveaway",
                            title: component.strings.ChannelBoost_Header_Giveaway
                        )
                    ),
                    effectAlignment: .center,
                    action: {
                        component.createGiveaway()
                    }
                ),
                availableSize: CGSize(width: minButtonWidth, height: buttonHeight),
                transition: context.transition
            )
            context.add(giveawayButton
                .position(CGPoint(x: context.availableSize.width / 2.0, y: size.height - 45.0))
            )
            
            let featuresButton = featuresButton.update(
                component: PlainButtonComponent(
                    content: AnyComponent(
                        BoostButtonComponent(
                            iconName: "Premium/Boosts/Features",
                            title: component.strings.ChannelBoost_Header_Features
                        )
                    ),
                    effectAlignment: .center,
                    action: {
                        component.openFeatures()
                    }
                ),
                availableSize: CGSize(width: minButtonWidth, height: buttonHeight),
                transition: context.transition
            )
            context.add(featuresButton
                .position(CGPoint(x: context.availableSize.width - sideInset - minButtonWidth / 2.0, y: size.height - 45.0))
            )
            
            return background.size
        }
    }
}

private final class BoostButtonComponent: CombinedComponent {
    let iconName: String
    let title: String
    
    public init(
        iconName: String,
        title: String
    ) {
        self.iconName = iconName
        self.title = title
    }

    public static func ==(lhs: BoostButtonComponent, rhs: BoostButtonComponent) -> Bool {
        if lhs.iconName != rhs.iconName {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        return true
    }

    public static var body: Body {
        let background = Child(RoundedRectangle.self)
        let icon = Child(BundleIconComponent.self)
        let title = Child(MultilineTextComponent.self)

        return { context in
            let size = context.availableSize
            let component = context.component
            
            let background = background.update(
                component: RoundedRectangle(
                    color: UIColor.white.withAlphaComponent(0.2),
                    cornerRadius: 10.0
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            let icon = icon.update(
                component: BundleIconComponent(
                    name: component.iconName,
                    tintColor: .white
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
            context.add(icon
                .position(CGPoint(x: size.width / 2.0, y: 21.0))
            )
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.title,
                        font: Font.regular(11.0),
                        textColor: .white
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: size.width - 16.0, height: size.height),
                transition: context.transition
            )
            context.add(title
                .position(CGPoint(x: size.width / 2.0, y: size.height - 16.0))
            )
            
            return background.size
        }
    }
}
