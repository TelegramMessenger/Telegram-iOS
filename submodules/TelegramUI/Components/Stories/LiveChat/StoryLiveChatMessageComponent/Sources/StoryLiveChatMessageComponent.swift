import Foundation
import UIKit
import ComponentFlow
import Display
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import TelegramPresentationData
import TelegramCore
import AvatarNode
import AccountContext
import StarsParticleEffect
import AppBundle
import TextFormat
import PeerNameTextComponent

private func generateStarsAmountImage() -> UIImage {
    return UIImage(bundleImageName: "Chat/Message/StarsCount")!.precomposed().withRenderingMode(.alwaysTemplate)
}

public final class StoryLiveChatMessageComponent: Component {
    public struct Layout: Equatable {
        public var isFlipped: Bool
        public var insets: UIEdgeInsets
        public var fitToWidth: Bool
        public var transparentBackground: Bool
        
        public init(isFlipped: Bool, insets: UIEdgeInsets, fitToWidth: Bool, transparentBackground: Bool) {
            self.isFlipped = isFlipped
            self.insets = insets
            self.fitToWidth = fitToWidth
            self.transparentBackground = transparentBackground
        }
    }
    
    let context: AccountContext
    let strings: PresentationStrings
    let theme: PresentationTheme
    let layout: Layout
    let message: GroupCallMessagesContext.Message
    let topPlace: Int?
    let contextGesture: ((ContextGesture, ContextExtractedContentContainingNode) -> Void)?
    
    public init(
        context: AccountContext,
        strings: PresentationStrings,
        theme: PresentationTheme,
        layout: Layout,
        message: GroupCallMessagesContext.Message,
        topPlace: Int?,
        contextGesture: ((ContextGesture, ContextExtractedContentContainingNode) -> Void)?
    ) {
        self.context = context
        self.strings = strings
        self.theme = theme
        self.layout = layout
        self.message = message
        self.topPlace = topPlace
        self.contextGesture = contextGesture
    }
    
    public static func ==(lhs: StoryLiveChatMessageComponent, rhs: StoryLiveChatMessageComponent) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.layout != rhs.layout {
            return false
        }
        if lhs.message != rhs.message {
            return false
        }
        if lhs.topPlace != rhs.topPlace {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let extractedContainerNode: ContextExtractedContentContainingNode
        private let containerNode: ContextControllerSourceNode
        
        private let contentContainer: UIView
        private var avatarNode: AvatarNode?
        private let textExternal = MultilineTextWithEntitiesComponent.External()
        private let authorTitle = ComponentView<Empty>()
        private var adminBadgeText: ComponentView<Empty>?
        private let text = ComponentView<Empty>()
        private var crownIcon: UIImageView?
        private var backgroundView: UIImageView?
        private var effectLayer: StarsParticleEffectLayer?
        private var starsAmountBackgroundView: UIImageView?
        private var starsAmountIcon: UIImageView?
        private var starsAmountText: ComponentView<Empty>?

        private var component: StoryLiveChatMessageComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        static let starsAmountImage: UIImage = generateStarsAmountImage()
        
        override public init(frame: CGRect) {
            self.contentContainer = UIView()
            
            self.extractedContainerNode = ContextExtractedContentContainingNode()
            self.containerNode = ContextControllerSourceNode()
            
            super.init(frame: frame)
            
            self.addSubview(self.contentContainer)
            
            self.containerNode.addSubnode(self.extractedContainerNode)
            self.containerNode.targetNodeForActivationProgress = self.extractedContainerNode.contentNode
            self.contentContainer.addSubview(self.containerNode.view)
            
            self.containerNode.activated = { [weak self] gesture, _ in
                guard let self, let component = self.component else {
                    return
                }
                component.contextGesture?(gesture, self.extractedContainerNode)
            }
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            
            guard let result = super.hitTest(point, with: event) else {
                return nil
            }
            
            return result
        }
        
        public func flashHighlight() {
            if let backgroundView = self.backgroundView, backgroundView.alpha != 1.0 {
                let initialAlpha = backgroundView.alpha
                backgroundView.layer.animateAlpha(from: initialAlpha, to: 1.0, duration: 0.2, removeOnCompletion: false, completion: { [weak self] _ in
                    guard let self, let backgroundView = self.backgroundView else {
                        return
                    }
                    backgroundView.layer.animateAlpha(from: 1.0, to: initialAlpha, duration: 0.2, delay: 2.0)
                })
            }
        }
        
        func update(component: StoryLiveChatMessageComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            self.contentContainer.transform = component.layout.isFlipped ? CGAffineTransformMakeRotation(-CGFloat.pi) : .identity
            
            self.containerNode.isGestureEnabled = component.contextGesture != nil
            
            let insets = component.layout.insets
            let avatarSize: CGFloat = 24.0
            let avatarSpacing: CGFloat = 6.0
            let avatarBackgroundInset: CGFloat = 4.0
            
            let primaryTextColor = UIColor(white: 1.0, alpha: 1.0)
            let secondaryTextColor = UIColor(white: 1.0, alpha: 0.8)
            
            var displayStarsAmountBackground = false
            var starsAmountTextSize: CGSize?
            if let paidStars = component.message.paidStars {
                displayStarsAmountBackground = component.message.text.isEmpty
                
                let starsAmountIcon: UIImageView
                if let current = self.starsAmountIcon {
                    starsAmountIcon = current
                } else {
                    starsAmountIcon = UIImageView()
                    self.starsAmountIcon = starsAmountIcon
                    self.extractedContainerNode.contentNode.view.addSubview(starsAmountIcon)
                    starsAmountIcon.image = View.starsAmountImage
                }
                starsAmountIcon.tintColor = secondaryTextColor
                
                let starsAmountText: ComponentView<Empty>
                if let current = self.starsAmountText {
                    starsAmountText = current
                } else {
                    starsAmountText = ComponentView()
                    self.starsAmountText = starsAmountText
                }
                
                starsAmountTextSize = starsAmountText.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: "\(paidStars)", font: Font.semibold(11.0), textColor: displayStarsAmountBackground ? primaryTextColor : secondaryTextColor))
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
            } else {
                if let starsAmountIcon = self.starsAmountIcon {
                    self.starsAmountIcon = nil
                    starsAmountIcon.removeFromSuperview()
                }
                if let starsAmountText = self.starsAmountText {
                    self.starsAmountText = nil
                    starsAmountText.view?.removeFromSuperview()
                }
            }
            
            if displayStarsAmountBackground, let paidStars = component.message.paidStars, let baseColor = GroupCallMessagesContext.getStarAmountParamMapping(params: LiveChatMessageParams(appConfig: component.context.currentAppConfiguration.with({ $0 })), value: paidStars).color {
                let starsAmountBackgroundView: UIImageView
                if let current = self.starsAmountBackgroundView {
                    starsAmountBackgroundView = current
                } else {
                    starsAmountBackgroundView = UIImageView()
                    starsAmountBackgroundView.image = generateStretchableFilledCircleImage(diameter: 20.0, color: .white)?.withRenderingMode(.alwaysTemplate)
                    self.starsAmountBackgroundView = starsAmountBackgroundView
                    
                    if let starsAmountIconView = self.starsAmountIcon {
                        self.extractedContainerNode.contentNode.view.insertSubview(starsAmountBackgroundView, belowSubview: starsAmountIconView)
                    } else {
                        self.extractedContainerNode.contentNode.view.addSubview(starsAmountBackgroundView)
                    }
                }
                starsAmountBackgroundView.tintColor = StoryLiveChatMessageComponent.getMessageColor(color: baseColor).withMultipliedBrightnessBy(0.7).withMultipliedAlpha(0.5)
            } else {
                if let starsAmountBackgroundView = self.starsAmountBackgroundView {
                    self.starsAmountBackgroundView = nil
                    starsAmountBackgroundView.removeFromSuperview()
                }
            }
            
            var textString = NSAttributedString()
            if !component.message.text.isEmpty {
                var underlineLinks = true
                if !primaryTextColor.isEqual(component.theme.list.itemAccentColor) {
                    underlineLinks = false
                }
                
                let codeBlockTitleColor: UIColor
                let codeBlockAccentColor: UIColor
                let codeBlockBackgroundColor: UIColor
                
                codeBlockTitleColor = primaryTextColor
                codeBlockAccentColor = component.theme.list.itemAccentColor
                    
                if component.theme.overallDarkAppearance {
                    codeBlockBackgroundColor = UIColor(white: 0.0, alpha: 0.65)
                } else {
                    codeBlockBackgroundColor = UIColor(white: 0.0, alpha: 0.05)
                }
                
                //let codeHighlightSpecs = extractMessageSyntaxHighlightSpecs(text: component.message.text, entities: component.message.entities)
                
                let textFont = Font.regular(15.0)
                let messageBoldFont = Font.semibold(15.0)
                let messageItalicFont = Font.italic(15.0)
                let messageBoldItalicFont = Font.semiboldItalic(15.0)
                let messageFixedFont = Font.monospace(15.0)
                let messageBlockQuoteFont = Font.regular(14.0)
                
                textString = stringWithAppliedEntities(component.message.text, entities: component.message.entities, baseColor: primaryTextColor, linkColor: component.theme.list.itemAccentColor, baseQuoteTintColor: primaryTextColor, baseQuoteSecondaryTintColor: secondaryTextColor, baseQuoteTertiaryTintColor: secondaryTextColor, codeBlockTitleColor: codeBlockTitleColor, codeBlockAccentColor: codeBlockAccentColor, codeBlockBackgroundColor: codeBlockBackgroundColor, baseFont: textFont, linkFont: textFont, boldFont: messageBoldFont, italicFont: messageItalicFont, boldItalicFont: messageBoldItalicFont, fixedFont: messageFixedFont, blockQuoteFont: messageBlockQuoteFont, underlineLinks: underlineLinks, message: nil, adjustQuoteFontSize: true, cachedMessageSyntaxHighlight: nil)
            }
            
            var textTopLeftCutout: CGFloat = 0.0
            if let topPlace = component.topPlace {
                let crownIcon: UIImageView
                if let current = self.crownIcon {
                    crownIcon = current
                } else {
                    crownIcon = UIImageView()
                    self.crownIcon = crownIcon
                    self.extractedContainerNode.contentNode.view.addSubview(crownIcon)
                }
                if topPlace != previousComponent?.topPlace {
                    crownIcon.image = generateCrownImage(place: topPlace, backgroundColor: .white, foregroundColor: .clear, borderColor: nil)
                }
                crownIcon.tintColor = secondaryTextColor
                
                if let image = crownIcon.image {
                    if !component.message.isFromAdmin {
                        textTopLeftCutout = image.size.width + 4.0
                    }
                }
            } else {
                if let crownIcon = self.crownIcon {
                    self.crownIcon = nil
                    crownIcon.removeFromSuperview()
                }
            }
            
            var textBottomRightCutout: CGFloat?
            if let starsAmountTextSize, !displayStarsAmountBackground {
                textBottomRightCutout = starsAmountTextSize.width + 20.0
            }
            
            var maxTextWidth: CGFloat = availableSize.width - insets.left - insets.right - avatarSize - avatarSpacing
            if let starsAmountTextSize, displayStarsAmountBackground {
                var cutoutWidth: CGFloat = starsAmountTextSize.width + 20.0
                cutoutWidth += 30.0
                maxTextWidth -= cutoutWidth
            }
            
            let textIconsForegroundColor: UIColor
            if let paidStars = component.message.paidStars, let baseColor = GroupCallMessagesContext.getStarAmountParamMapping(params: LiveChatMessageParams(appConfig: component.context.currentAppConfiguration.with({ $0 })), value: paidStars).color {
                textIconsForegroundColor = StoryLiveChatMessageComponent.getMessageColor(color: baseColor).withAlphaComponent(component.layout.transparentBackground ? 0.7 : 1.0)
            } else {
                textIconsForegroundColor = .black
            }
            
            let authorTitleSize = self.authorTitle.update(
                transition: .immediate,
                component: AnyComponent(PeerNameTextComponent(
                    context: component.context,
                    peer: component.message.author,
                    text: .name,
                    font: Font.semibold(15.0),
                    textColor: secondaryTextColor,
                    iconBackgroundColor: .white,
                    iconForegroundColor: textIconsForegroundColor,
                    strings: component.strings
                )),
                environment: {},
                containerSize: CGSize(width: min(maxTextWidth - 80.0, 180.0), height: 100000.0)
            )
            
            if !component.message.isFromAdmin {
                textTopLeftCutout += authorTitleSize.width + 6.0
            }
            
            var adminBadgeTextSize: CGSize?
            if component.message.isFromAdmin && !displayStarsAmountBackground {
                let adminBadgeText: ComponentView<Empty>
                if let current = self.adminBadgeText {
                    adminBadgeText = current
                } else {
                    adminBadgeText = ComponentView()
                    self.adminBadgeText = adminBadgeText
                }
                adminBadgeTextSize = adminBadgeText.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: component.strings.ChatAdmins_AdminLabel, font: Font.regular(11.0), textColor: secondaryTextColor))
                    )),
                    environment: {},
                    containerSize: CGSize(width: 200.0, height: 100.0)
                )
            } else {
                if let adminBadgeText = self.adminBadgeText {
                    self.adminBadgeText = nil
                    adminBadgeText.view?.removeFromSuperview()
                }
            }
            
            let textCutout = TextNodeCutout(topLeft: CGSize(width: textTopLeftCutout, height: 8.0), bottomRight: textBottomRightCutout.flatMap({ CGSize(width: $0, height: 8.0) }))
            
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextWithEntitiesComponent(
                    external: self.textExternal,
                    context: component.context,
                    animationCache: component.context.animationCache,
                    animationRenderer: component.context.animationRenderer,
                    placeholderColor: .gray,
                    text: .plain(textString),
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.1,
                    cutout: textCutout,
                    handleSpoilers: true,
                    manualVisibilityControl: true
                )),
                environment: {},
                containerSize: CGSize(width: maxTextWidth, height: 100000.0)
            )
            
            var avatarFrame = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: CGSize(width: avatarSize, height: avatarSize))
            if component.message.paidStars != nil {
                avatarFrame.origin.y += avatarBackgroundInset
                if component.layout.fitToWidth {
                    avatarFrame.origin.x += avatarBackgroundInset
                }
            }
            do {
                let avatarNode: AvatarNode
                if let current = self.avatarNode {
                    avatarNode = current
                } else {
                    avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 10.0))
                    self.avatarNode = avatarNode
                    self.extractedContainerNode.contentNode.view.addSubview(avatarNode.view)
                }
                transition.setFrame(view: avatarNode.view, frame: avatarFrame)
                avatarNode.updateSize(size: avatarFrame.size)
                if let peer = component.message.author {
                    if peer.smallProfileImage != nil {
                        avatarNode.setPeerV2(context: component.context, theme: component.theme, peer: peer, displayDimensions: CGSize(width: avatarSize, height: avatarSize))
                    } else {
                        avatarNode.setPeer(context: component.context, theme: component.theme, peer: peer, displayDimensions: CGSize(width: avatarSize, height: avatarSize))
                    }
                    if component.message.isFromAdmin {
                        avatarNode.setStoryStats(storyStats: AvatarNode.StoryStats(totalCount: 1, unseenCount: 1, hasUnseenCloseFriendsItems: false, hasLiveItems: true), presentationParams: AvatarNode.StoryPresentationParams(colors: AvatarNode.Colors(theme: component.theme), lineWidth: 1.0, inactiveLineWidth: 1.0), transition: .immediate)
                    } else {
                        avatarNode.setStoryStats(storyStats: nil, presentationParams: AvatarNode.StoryPresentationParams(colors: AvatarNode.Colors(theme: component.theme), lineWidth: 1.0, inactiveLineWidth: 1.0), transition: .immediate)
                    }
                } else {
                    avatarNode.setCustomLetters([" "])
                    avatarNode.setStoryStats(storyStats: nil, presentationParams: AvatarNode.StoryPresentationParams(colors: AvatarNode.Colors(theme: component.theme), lineWidth: 2.0, inactiveLineWidth: 2.0), transition: .immediate)
                }
            }
            
            var authorTitleFrame = CGRect(origin: CGPoint(x: insets.left + avatarSize + avatarSpacing, y: avatarFrame.minY + 3.0), size: authorTitleSize)
            if component.layout.fitToWidth {
                authorTitleFrame.origin.x += 4.0
            }
            if let image = self.crownIcon?.image {
                authorTitleFrame.origin.x += image.size.width + 4.0
            }
            if let authorTitleView = self.authorTitle.view {
                if authorTitleView.superview == nil {
                    authorTitleView.layer.anchorPoint = CGPoint()
                    self.extractedContainerNode.contentNode.view.addSubview(authorTitleView)
                }
                transition.setPosition(view: authorTitleView, position: authorTitleFrame.origin)
                authorTitleView.bounds = CGRect(origin: CGPoint(), size: authorTitleFrame.size)
            }
            
            var textFrame = CGRect(origin: CGPoint(x: insets.left + avatarSize + avatarSpacing, y: avatarFrame.minY + 3.0), size: textSize)
            if component.layout.fitToWidth {
                textFrame.origin.x += 4.0
            }
            if component.message.isFromAdmin {
                textFrame.origin.y = authorTitleFrame.maxY
                textFrame.size.width = max(textFrame.width, authorTitleFrame.maxX - textFrame.minX)
                textFrame.size.height = max(textFrame.height, authorTitleFrame.height)
            }
            textFrame.size.width = max(textFrame.width, textTopLeftCutout + (textBottomRightCutout ?? 0.0))
            if let textView = self.text.view as? MultilineTextWithEntitiesComponent.View {
                if textView.superview == nil {
                    textView.layer.anchorPoint = CGPoint()
                    self.extractedContainerNode.contentNode.view.addSubview(textView)
                }
                transition.setPosition(view: textView, position: textFrame.origin)
                textView.bounds = CGRect(origin: CGPoint(), size: textSize)
                
                textView.updateVisibility(true)
            }
            
            if let crownIcon = self.crownIcon, let image = crownIcon.image {
                crownIcon.frame = CGRect(origin: CGPoint(x: authorTitleFrame.minX - 4.0 - image.size.width, y: authorTitleFrame.minY - 1.0), size: image.size)
            }
            
            let backgroundOrigin = CGPoint(x: avatarFrame.minX - avatarBackgroundInset, y: avatarFrame.minY - avatarBackgroundInset)
            var backgroundFrame = CGRect(origin: backgroundOrigin, size: CGSize(width: textFrame.maxX + 8.0 - backgroundOrigin.x, height: avatarFrame.maxY + avatarBackgroundInset - backgroundOrigin.y))
            if let starsAmountTextSize, displayStarsAmountBackground {
                backgroundFrame.size.width += starsAmountTextSize.width + 30.0
            }
            if let adminBadgeTextSize {
                backgroundFrame.size.width = max(backgroundFrame.width, authorTitleFrame.maxX + 4.0 + adminBadgeTextSize.width + 10.0)
            }
            if let textLayout = self.textExternal.layout {
                if textLayout.numberOfLines > 1 || (component.message.isFromAdmin && !displayStarsAmountBackground) {
                    backgroundFrame.size.height = max(backgroundFrame.size.height, textFrame.maxY + 8.0 - backgroundOrigin.y)
                }
                
                if let starsAmountTextSize, !displayStarsAmountBackground, let lastLineRect = textLayout.linesRects().last, textFrame.minX + lastLineRect.maxX > backgroundFrame.width - 8.0 - starsAmountTextSize.width {
                    backgroundFrame.size.height += starsAmountTextSize.height + 2.0
                }
            }
            
            if let starsAmountTextSize, let starsAmountTextView = self.starsAmountText?.view, let starsAmountIcon = self.starsAmountIcon {
                let starsAmountTextFrame: CGRect
                
                if displayStarsAmountBackground, let starsAmountBackgroundView = self.starsAmountBackgroundView {
                    let starsAmountBackgroundSize = CGSize(width: starsAmountTextSize.width + 5.0 + 20.0, height: 20.0)
                    let starsAmountBackgroundFrame = CGRect(origin: CGPoint(x: backgroundFrame.maxX - 6.0 - starsAmountBackgroundSize.width, y: backgroundFrame.minY + floor((backgroundFrame.height - starsAmountBackgroundSize.height) * 0.5)), size: starsAmountBackgroundSize)
                    transition.setFrame(view: starsAmountBackgroundView, frame: starsAmountBackgroundFrame)
                    
                    starsAmountTextFrame = CGRect(origin: CGPoint(x: starsAmountBackgroundFrame.maxX - starsAmountTextSize.width - 5.0, y: starsAmountBackgroundFrame.minY + UIScreenPixel + floor((starsAmountBackgroundFrame.height - starsAmountTextSize.height) * 0.5)), size: starsAmountTextSize)
                } else {
                    starsAmountTextFrame = CGRect(origin: CGPoint(x: backgroundFrame.maxX - 8.0 - starsAmountTextSize.width, y: backgroundFrame.maxY - starsAmountTextSize.height - 8.0), size: starsAmountTextSize)
                }
                
                if starsAmountTextView.superview == nil {
                    starsAmountTextView.layer.anchorPoint = CGPoint(x: 1.0, y: 1.0)
                    self.extractedContainerNode.contentNode.view.addSubview(starsAmountTextView)
                }
                transition.setPosition(view: starsAmountTextView, position: CGPoint(x: starsAmountTextFrame.maxX, y: starsAmountTextFrame.maxY))
                starsAmountTextView.bounds = CGRect(origin: CGPoint(), size: starsAmountTextFrame.size)
                
                if let image = starsAmountIcon.image {
                    let starsAmountIconFrame = CGRect(origin: CGPoint(x: starsAmountTextFrame.minX - 2.0 - image.size.width, y: starsAmountTextFrame.minY + UIScreenPixel), size: image.size)
                    transition.setFrame(view: starsAmountIcon, frame: starsAmountIconFrame)
                }
            }
            
            let size = CGSize(width: component.layout.fitToWidth ? backgroundFrame.maxX : availableSize.width, height: backgroundFrame.maxY)
            
            let backgroundCornerRadius = (avatarSize + avatarBackgroundInset * 2.0) * 0.5
            
            var displayBackground = false
            if component.message.paidStars != nil {
                displayBackground = true
            } else if component.message.isFromAdmin {
                displayBackground = true
            }
            
            if displayBackground {
                let backgroundView: UIImageView
                if let current = self.backgroundView {
                    backgroundView = current
                } else {
                    backgroundView = UIImageView()
                    self.backgroundView = backgroundView
                    self.extractedContainerNode.contentNode.view.insertSubview(backgroundView, at: 0)
                    backgroundView.image = generateStretchableFilledCircleImage(diameter: backgroundCornerRadius * 2.0, color: .white)?.withRenderingMode(.alwaysTemplate)
                }
                transition.setFrame(view: backgroundView, frame: backgroundFrame)
                
                if let paidStars = component.message.paidStars, let baseColor = GroupCallMessagesContext.getStarAmountParamMapping(params: LiveChatMessageParams(appConfig: component.context.currentAppConfiguration.with({ $0 })), value: paidStars).color {
                    backgroundView.tintColor = StoryLiveChatMessageComponent.getMessageColor(color: baseColor)
                    backgroundView.alpha = component.layout.transparentBackground ? 0.5 : 1.0
                } else {
                    backgroundView.tintColor = UIColor(white: 0.0, alpha: 0.3)
                    backgroundView.alpha = 1.0
                }
                
                if component.message.paidStars != nil {
                    let effectLayer: StarsParticleEffectLayer
                    if let current = self.effectLayer {
                        effectLayer = current
                    } else {
                        effectLayer = StarsParticleEffectLayer()
                        self.effectLayer = effectLayer
                        backgroundView.layer.addSublayer(effectLayer)
                    }
                    
                    transition.setFrame(layer: effectLayer, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
                    effectLayer.update(color: UIColor(white: 1.0, alpha: 0.5), size: backgroundFrame.size, cornerRadius: backgroundCornerRadius, transition: transition)
                } else {
                    if let effectLayer = self.effectLayer {
                        self.effectLayer = nil
                        effectLayer.removeFromSuperlayer()
                    }
                }
            } else if let backgroundView = self.backgroundView {
                self.backgroundView = nil
                backgroundView.removeFromSuperview()
                
                if let effectLayer = self.effectLayer {
                    self.effectLayer = nil
                    effectLayer.removeFromSuperlayer()
                }
            }
            
            if let adminBadgeTextView = self.adminBadgeText?.view, let adminBadgeTextSize {
                let adminBadgeTextFrame = CGRect(origin: CGPoint(x: backgroundFrame.maxX - 10.0 - adminBadgeTextSize.width, y: backgroundFrame.minY + 9.0), size: adminBadgeTextSize)
                if adminBadgeTextView.superview == nil {
                    self.extractedContainerNode.contentNode.view.addSubview(adminBadgeTextView)
                }
                transition.setFrame(view: adminBadgeTextView, frame: adminBadgeTextFrame)
            }
            
            let contentFrame = CGRect(origin: CGPoint(), size: size)
            transition.setPosition(view: self.contentContainer, position: contentFrame.center)
            transition.setBounds(view: self.contentContainer, bounds: CGRect(origin: CGPoint(), size: contentFrame.size))
            
            self.extractedContainerNode.frame = CGRect(origin: CGPoint(), size: size)
            self.extractedContainerNode.contentNode.frame = CGRect(origin: CGPoint(), size: size)
            self.extractedContainerNode.contentRect = backgroundFrame.insetBy(dx: -2.0, dy: 0.0)
            self.containerNode.frame = CGRect(origin: CGPoint(), size: size)
            
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }

    public static func getMessageColor(color: GroupCallMessagesContext.Message.Color) -> UIColor {
        return UIColor(rgb: color.rawValue)
    }
    
    private static let crownTemplateImage: UIImage = {
        return generateTintedImage(image: UIImage(bundleImageName: "Stories/LiveChatCrown"), color: .white)!
    }()
    
    private static let crownFont: UIFont = {
        let weight: CGFloat = UIFont.Weight.semibold.rawValue
        let width: CGFloat = -0.1
        let descriptor: UIFontDescriptor
        if #available(iOS 14.0, *) {
            descriptor = UIFont.systemFont(ofSize: 10.0).fontDescriptor
        } else {
            descriptor = UIFont.systemFont(ofSize: 10.0, weight: UIFont.Weight.semibold).fontDescriptor
        }
        let symbolicTraits = descriptor.symbolicTraits
        var updatedDescriptor: UIFontDescriptor? = descriptor.withSymbolicTraits(symbolicTraits)
        updatedDescriptor = updatedDescriptor?.withDesign(.default)
        if #available(iOS 14.0, *) {
            updatedDescriptor = updatedDescriptor?.addingAttributes([
                UIFontDescriptor.AttributeName.traits: [UIFontDescriptor.TraitKey.weight: weight]
            ])
        }
        if #available(iOS 16.0, *) {
            updatedDescriptor = updatedDescriptor?.addingAttributes([
                UIFontDescriptor.AttributeName.traits: [UIFontDescriptor.TraitKey.width: width]
            ])
        }
        
        let font: UIFont
        if let updatedDescriptor {
            font = UIFont(descriptor: updatedDescriptor, size: 9.0)
        } else {
            font = UIFont(descriptor: descriptor, size: 9.0)
        }
        return font
    }()
    
    public static func generateCrownImage(place: Int, backgroundColor: UIColor, foregroundColor: UIColor, borderColor: UIColor?) -> UIImage {
        let baseSize = crownTemplateImage.size
        var borderWidth: CGFloat = 0.0
        if borderColor != nil {
            borderWidth = 2.0
        }
        
        var size = baseSize
        size.width += borderWidth * 2.0
        size.height += borderWidth * 2.0
        
        let image = generateImage(size, rotatedContext: { size, context in
            UIGraphicsPushContext(context)
            defer {
                UIGraphicsPopContext()
            }
            
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            if let borderColor {
                generateTintedImage(image: UIImage(bundleImageName: "Stories/LiveChatCrown"), color: borderColor)!.draw(in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
            }
            
            if backgroundColor != .white {
                generateTintedImage(image: UIImage(bundleImageName: "Stories/LiveChatCrown"), color: backgroundColor)!.draw(in: CGRect(origin: CGPoint(x: borderWidth, y: borderWidth), size: baseSize))
            } else {
                crownTemplateImage.draw(in: CGRect(origin: CGPoint(x: borderWidth, y: borderWidth), size: baseSize))
            }
            
            if foregroundColor.alpha < 1.0 {
                context.setBlendMode(.copy)
            }
            
            let string = NSAttributedString(string: "\(place + 1)", font: crownFont, textColor: foregroundColor)
            let stringSize = string.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
            
            let stringOffsets: [CGPoint] = [
                CGPoint(x: 0.25, y: -0.33),
                CGPoint(x: 0.24749999999999983, y: -0.495),
                CGPoint(x: 0.0, y: -1.4025),
            ]
            var stringPosition = CGPoint(x: borderWidth + floorToScreenPixels((baseSize.width - stringSize.width) * 0.5), y: borderWidth + floorToScreenPixels((baseSize.height - stringSize.height) * 0.5) + 1.0)
            if place < stringOffsets.count {
                stringPosition.x += stringOffsets[place].x * 0.8
                stringPosition.y += stringOffsets[place].y * 0.8
            }
            string.draw(at: stringPosition)
        })!
        
        if backgroundColor == .white && foregroundColor == .clear && borderColor == nil {
            return image.withRenderingMode(.alwaysTemplate)
        } else {
            return image
        }
    }
}
