import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import AppBundle
import TelegramCore
import TextFormat
import UrlEscaping
import AccountContext
import AvatarNode
import ComponentFlow
import AvatarStoryIndicatorComponent
import AccountContext
import Markdown
import BalancedTextComponent

public enum TooltipActiveTextItem {
    case url(String, Bool)
    case mention(EnginePeer.Id, String)
    case textMention(String)
    case botCommand(String)
    case hashtag(String)
}

public enum TooltipActiveTextAction {
    case tap
    case longTap
}

private func generateArrowImage() -> UIImage? {
    return generateImage(CGSize(width: 14.0, height: 8.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: .zero, size: size)
        context.clear(bounds)
        
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(1.0 + UIScreenPixel)
        context.setLineCap(.round)
        
        let arrowBounds = bounds.insetBy(dx: 1.0, dy: 1.0)
        context.move(to: arrowBounds.origin)
        context.addLine(to: CGPoint(x: arrowBounds.midX, y: arrowBounds.maxY))
        context.addLine(to: CGPoint(x: arrowBounds.maxX, y: arrowBounds.minY))
        context.strokePath()
    })
}

private class DownArrowsIconNode: ASDisplayNode {
    private let topArrow: ASImageNode
    private let bottomArrow: ASImageNode
    
    override init() {
        self.topArrow = ASImageNode()
        self.topArrow.displaysAsynchronously = false
        self.topArrow.image = generateArrowImage()
        
        self.bottomArrow = ASImageNode()
        self.bottomArrow.displaysAsynchronously = false
        self.bottomArrow.image = self.topArrow.image
        
        super.init()
        
        self.addSubnode(self.topArrow)
        self.addSubnode(self.bottomArrow)
        
        if let image = self.topArrow.image {
            self.topArrow.frame = CGRect(origin: .zero, size: image.size)
            self.bottomArrow.frame = CGRect(origin: CGPoint(x: 0.0, y: 7.0), size: image.size)
        }
    }
    
    func setupAnimations() {
        guard self.bottomArrow.layer.animation(forKey: "position") == nil else {
            return
        }
        
        self.supernode?.layer.animateKeyframes(values: [
            NSValue(cgPoint: CGPoint(x: 0.0, y: 0.0)),
            NSValue(cgPoint: CGPoint(x: 0.0, y: 1.0)),
            NSValue(cgPoint: CGPoint(x: 0.0, y: -0.5)),
            NSValue(cgPoint: CGPoint(x: 0.0, y: 1.0)),
            NSValue(cgPoint: CGPoint(x: 0.0, y: 0.0))
        ], duration: 1.1, keyPath: "position", additive: true)
        
        self.bottomArrow.layer.animateKeyframes(values: [
            NSValue(cgPoint: CGPoint(x: 0.0, y: 0.0)),
            NSValue(cgPoint: CGPoint(x: 0.0, y: 4.0)),
            NSValue(cgPoint: CGPoint(x: 0.0, y: -0.5)),
            NSValue(cgPoint: CGPoint(x: 0.0, y: 4.0)),
            NSValue(cgPoint: CGPoint(x: 0.0, y: 0.0))
        ], duration: 1.1, keyPath: "position", additive: true, completion: { [weak self] _ in
            Queue.mainQueue().after(2.9) {
                self?.setupAnimations()
            }
        })
        
        self.topArrow.layer.animateKeyframes(values: [
            NSValue(cgPoint: CGPoint(x: 0.0, y: 0.0)),
            NSValue(cgPoint: CGPoint(x: 0.0, y: 6.0)),
            NSValue(cgPoint: CGPoint(x: 0.0, y: -0.5)),
            NSValue(cgPoint: CGPoint(x: 0.0, y: 6.0)),
            NSValue(cgPoint: CGPoint(x: 0.0, y: 0.0))
        ], duration: 1.1, keyPath: "position", additive: true)
    }
}

private final class TooltipScreenNode: ViewControllerTracingNode {
    private let text: TooltipScreen.Text
    private let textAlignment: TooltipScreen.Alignment
    private let balancedTextLayout: Bool
    private let constrainWidth: CGFloat?
    private let tooltipStyle: TooltipScreen.Style
    private let arrowStyle: TooltipScreen.ArrowStyle
    private let icon: TooltipScreen.Icon?
    private let action: TooltipScreen.Action?
    var location: TooltipScreen.Location {
        didSet {
            if let layout = self.validLayout {
                self.updateLayout(layout: layout, transition: .immediate)
            }
        }
    }
    private let displayDuration: TooltipScreen.DisplayDuration
    private let shouldDismissOnTouch: (CGPoint, CGRect) -> TooltipScreen.DismissOnTouch
    private let requestDismiss: () -> Void
    private let openActiveTextItem: ((TooltipActiveTextItem, TooltipActiveTextAction) -> Void)?
    
    private let scrollingContainer: ASDisplayNode
    private let containerNode: ASDisplayNode
    private let backgroundContainerNode: ASDisplayNode
    private let backgroundClipNode: ASDisplayNode
    private let backgroundMaskNode: ASDisplayNode
    private var effectNode: NavigationBackgroundNode?
    private var gradientNode: ASDisplayNode?
    private var arrowGradientNode: ASDisplayNode?
    private let arrowNode: ASImageNode
    private let arrowContainer: ASDisplayNode
    private let animatedStickerNode: DefaultAnimatedStickerNodeImpl
    private var downArrowsNode: DownArrowsIconNode?
    private var avatarNode: AvatarNode?
    private var avatarStoryIndicator: ComponentView<Empty>?
    private let textView = ComponentView<Empty>()
    private var closeButtonNode: HighlightableButtonNode?
    private var actionButtonNode: HighlightableButtonNode?
    
    private var isArrowInverted: Bool = false
    
    private let fontSize: CGFloat
    private let inset: CGFloat
    
    private var validLayout: ContainerViewLayout?
    
    init(
        context: AccountContext?,
        account: Account,
        sharedContext: SharedAccountContext,
        text: TooltipScreen.Text,
        textAlignment: TooltipScreen.Alignment,
        balancedTextLayout: Bool,
        constrainWidth: CGFloat?,
        style: TooltipScreen.Style,
        arrowStyle: TooltipScreen.ArrowStyle,
        icon: TooltipScreen.Icon? = nil,
        action: TooltipScreen.Action? = nil,
        location: TooltipScreen.Location,
        displayDuration: TooltipScreen.DisplayDuration,
        inset: CGFloat = 12.0,
        cornerRadius: CGFloat? = nil,
        shouldDismissOnTouch: @escaping (CGPoint, CGRect) -> TooltipScreen.DismissOnTouch, requestDismiss: @escaping () -> Void, openActiveTextItem: ((TooltipActiveTextItem, TooltipActiveTextAction) -> Void)?)
    {
        self.tooltipStyle = style
        self.arrowStyle = arrowStyle
        self.icon = icon
        self.action = action
        self.location = location
        self.displayDuration = displayDuration
        self.inset = inset
        self.shouldDismissOnTouch = shouldDismissOnTouch
        self.requestDismiss = requestDismiss
        self.openActiveTextItem = openActiveTextItem
        
        self.containerNode = ASDisplayNode()
        self.backgroundContainerNode = ASDisplayNode()
        self.backgroundMaskNode = ASDisplayNode()
        self.backgroundClipNode = ASDisplayNode()
        self.backgroundClipNode.backgroundColor = .white
        
        let fillColor = UIColor(white: 0.0, alpha: 0.8)
        
        self.scrollingContainer = ASDisplayNode()
        
        let theme = sharedContext.currentPresentationData.with { $0 }.theme
        
        func svgPath(_ path: StaticString, scale: CGPoint = CGPoint(x: 1.0, y: 1.0), offset: CGPoint = CGPoint()) throws -> UIBezierPath {
            var index: UnsafePointer<UInt8> = path.utf8Start
            let end = path.utf8Start.advanced(by: path.utf8CodeUnitCount)
            let path = UIBezierPath()
            while index < end {
                let c = index.pointee
                index = index.successor()
                
                if c == 77 { // M
                    let x = try readCGFloat(&index, end: end, separator: 44) * scale.x + offset.x
                    let y = try readCGFloat(&index, end: end, separator: 32) * scale.y + offset.y
                    
                    path.move(to: CGPoint(x: x, y: y))
                } else if c == 76 { // L
                    let x = try readCGFloat(&index, end: end, separator: 44) * scale.x + offset.x
                    let y = try readCGFloat(&index, end: end, separator: 32) * scale.y + offset.y
                    
                    path.addLine(to: CGPoint(x: x, y: y))
                } else if c == 67 { // C
                    let x1 = try readCGFloat(&index, end: end, separator: 44) * scale.x + offset.x
                    let y1 = try readCGFloat(&index, end: end, separator: 32) * scale.y + offset.y
                    let x2 = try readCGFloat(&index, end: end, separator: 44) * scale.x + offset.x
                    let y2 = try readCGFloat(&index, end: end, separator: 32) * scale.y + offset.y
                    let x = try readCGFloat(&index, end: end, separator: 44) * scale.x + offset.x
                    let y = try readCGFloat(&index, end: end, separator: 32) * scale.y + offset.y
                    path.addCurve(to: CGPoint(x: x, y: y), controlPoint1: CGPoint(x: x1, y: y1), controlPoint2: CGPoint(x: x2, y: y2))
                } else if c == 32 { // space
                    continue
                }
            }
            path.close()
            return path
        }
        
        let arrowSize: CGSize
        switch self.arrowStyle {
        case .default:
            arrowSize = CGSize(width: 29.0, height: 10.0)
            self.arrowNode = ASImageNode()
            self.arrowNode.image = generateImage(arrowSize, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(fillColor.cgColor)
                context.scaleBy(x: 0.333, y: 0.333)
                let _ = try? drawSvgPath(context, path: "M85.882251,0 C79.5170552,0 73.4125613,2.52817247 68.9116882,7.02834833 L51.4264069,24.5109211 C46.7401154,29.1964866 39.1421356,29.1964866 34.4558441,24.5109211 L16.9705627,7.02834833 C12.4696897,2.52817247 6.36519576,0 0,0 L85.882251,0 ")
                context.fillPath()
            })
        case .small:
            arrowSize = CGSize(width: 18.0, height: 7.0)
            self.arrowNode = ASImageNode()
            self.arrowNode.image = generateImage(arrowSize, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(fillColor.cgColor)
                context.scaleBy(x: 0.333, y: 0.333)
                context.scaleBy(x: 0.62, y: 0.62)
                let _ = try? drawSvgPath(context, path: "M85.882251,0 C79.5170552,0 73.4125613,2.52817247 68.9116882,7.02834833 L51.4264069,24.5109211 C46.7401154,29.1964866 39.1421356,29.1964866 34.4558441,24.5109211 L16.9705627,7.02834833 C12.4696897,2.52817247 6.36519576,0 0,0 L85.882251,0 ")
                context.fillPath()
            })
        }
        
        self.arrowContainer = ASDisplayNode()
        
        var hasArrow = true
        if case .top = location {
            hasArrow = false
        } else if case .bottom = location {
            hasArrow = false
        }
        
        let fontSize: CGFloat
        if !hasArrow {
            let backgroundColor: UIColor
            var enableSaturation = true
            if case let .customBlur(color, _) = style {
                backgroundColor = color
                enableSaturation = false
            } else {
                if theme.overallDarkAppearance {
                    backgroundColor = theme.rootController.navigationBar.blurredBackgroundColor
                } else {
                    backgroundColor = UIColor(rgb: 0x000000, alpha: 0.6)
                }
            }
            self.effectNode = NavigationBackgroundNode(color: backgroundColor, enableSaturation: enableSaturation)
            self.backgroundMaskNode.addSubnode(self.backgroundClipNode)
            self.backgroundClipNode.clipsToBounds = true
            if case .bottom = location {
                self.backgroundClipNode.cornerRadius = 8.5
            } else {
                self.backgroundClipNode.cornerRadius = 14.0
            }
            if #available(iOS 13.0, *) {
                self.backgroundClipNode.layer.cornerCurve = .continuous
            }
            fontSize = 14.0
        } else if case let .gradient(leftColor, rightColor) = style {
            self.gradientNode = ASDisplayNode()
            self.gradientNode?.setLayerBlock({
                let layer = CAGradientLayer()
                layer.colors = [leftColor.cgColor, rightColor.cgColor]
                layer.startPoint = CGPoint()
                layer.endPoint = CGPoint(x: 1.0, y: 0.0)
                return layer
            })
            self.arrowGradientNode = ASDisplayNode()
            self.arrowGradientNode?.setLayerBlock({
                let layer = CAGradientLayer()
                layer.colors = [leftColor.cgColor, rightColor.cgColor]
                layer.startPoint = CGPoint()
                layer.endPoint = CGPoint(x: 1.0, y: 0.0)
                return layer
            })
            self.backgroundContainerNode.clipsToBounds = true
            self.backgroundContainerNode.cornerRadius = 14.0
            if #available(iOS 13.0, *) {
                self.backgroundContainerNode.layer.cornerCurve = .continuous
            }
            fontSize = 17.0
            
            self.arrowContainer.addSubnode(self.arrowGradientNode!)
            
            let maskLayer = CAShapeLayer()
            let arrowScale: CGFloat
            switch self.arrowStyle {
            case .default:
                arrowScale = 1.0
            case .small:
                arrowScale = 0.62
            }
            if let path = try? svgPath("M85.882251,0 C79.5170552,0 73.4125613,2.52817247 68.9116882,7.02834833 L51.4264069,24.5109211 C46.7401154,29.1964866 39.1421356,29.1964866 34.4558441,24.5109211 L16.9705627,7.02834833 C12.4696897,2.52817247 6.36519576,0 0,0 L85.882251,0 ", scale: CGPoint(x: 0.333333 * arrowScale, y: 0.333333 * arrowScale), offset: CGPoint()) {
                maskLayer.path = path.cgPath
            }
            maskLayer.frame = CGRect(origin: CGPoint(), size: arrowSize)
            self.arrowContainer.layer.mask = maskLayer
        } else {
            var enableSaturation = true
            let backgroundColor: UIColor
            if case let .customBlur(color, _) = style {
                backgroundColor = color
                enableSaturation = false
            } else if case .light = style {
                backgroundColor = theme.rootController.navigationBar.blurredBackgroundColor
            } else {
                if theme.overallDarkAppearance {
                    backgroundColor = theme.rootController.navigationBar.blurredBackgroundColor
                } else {
                    backgroundColor = UIColor(rgb: 0x000000, alpha: 0.6)
                }
            }
            self.effectNode = NavigationBackgroundNode(color: backgroundColor, enableBlur: true, enableSaturation: enableSaturation)
            
            self.backgroundMaskNode.addSubnode(self.backgroundClipNode)
            self.backgroundClipNode.clipsToBounds = true
            if case let .point(_, arrowPosition) = location, case .right = arrowPosition {
                self.backgroundClipNode.cornerRadius = 8.5
            } else {
                self.backgroundClipNode.cornerRadius = cornerRadius ?? 12.5
            }
            if #available(iOS 13.0, *) {
                self.backgroundClipNode.layer.cornerCurve = .continuous
            }
            self.backgroundMaskNode.addSubnode(self.arrowContainer)
            
            fontSize = 14.0
            
            let maskLayer = CAShapeLayer()
            let arrowScale: CGFloat
            switch self.arrowStyle {
            case .default:
                arrowScale = 1.0
            case .small:
                arrowScale = 0.62
            }
            if let path = try? svgPath("M85.882251,0 C79.5170552,0 73.4125613,2.52817247 68.9116882,7.02834833 L51.4264069,24.5109211 C46.7401154,29.1964866 39.1421356,29.1964866 34.4558441,24.5109211 L16.9705627,7.02834833 C12.4696897,2.52817247 6.36519576,0 0,0 L85.882251,0 ", scale: CGPoint(x: 0.333333 * arrowScale, y: 0.333333 * arrowScale), offset: CGPoint()) {
                maskLayer.path = path.cgPath
            }
            maskLayer.frame = CGRect(origin: CGPoint(), size: arrowSize)
            maskLayer.fillColor = UIColor.white.cgColor
            self.arrowContainer.layer.addSublayer(maskLayer)
            
            self.backgroundMaskNode.layer.shouldRasterize = true
            self.backgroundMaskNode.layer.rasterizationScale = UIScreen.main.scale
        }
        
        self.fontSize = fontSize
        self.text = text
        self.textAlignment = textAlignment
        self.balancedTextLayout = balancedTextLayout
        self.constrainWidth = constrainWidth
        
        self.animatedStickerNode = DefaultAnimatedStickerNodeImpl()
        switch icon {
        case .none:
            break
        case let .animation(animationName, _, animationTintColor):
            self.animatedStickerNode.setup(source: AnimatedStickerNodeLocalFileSource(name: animationName), width: Int(70 * UIScreenScale), height: Int(70 * UIScreenScale), playbackMode: .once, mode: .direct(cachePathPrefix: nil))
            self.animatedStickerNode.automaticallyLoadFirstFrame = true
            self.animatedStickerNode.dynamicColor = animationTintColor
        case .downArrows:
            self.downArrowsNode = DownArrowsIconNode()
        case let .peer(peer, _):
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 15.0))
            if let context {
                self.avatarNode?.setPeer(context: context, theme: defaultDarkPresentationTheme, peer: peer)
            }
        }
        
        if case .manual = displayDuration {
            self.closeButtonNode = HighlightableButtonNode()
            self.closeButtonNode?.setImage(UIImage(bundleImageName: "Components/Close"), for: .normal)
        }
        
        super.init()
        
        self.containerNode.addSubnode(self.backgroundContainerNode)
        if let gradientNode = self.gradientNode {
            self.backgroundContainerNode.addSubnode(gradientNode)
            self.containerNode.addSubnode(self.arrowContainer)
        } else if let effectNode = self.effectNode {
            self.backgroundContainerNode.addSubnode(effectNode)
            self.backgroundContainerNode.layer.mask = self.backgroundMaskNode.layer
        }
        self.containerNode.addSubnode(self.animatedStickerNode)
        
        if let closeButtonNode = self.closeButtonNode {
            self.containerNode.addSubnode(closeButtonNode)
        }
        
        if let downArrowsNode = self.downArrowsNode {
            self.containerNode.addSubnode(downArrowsNode)
        }
        if let avatarNode = self.avatarNode {
            self.containerNode.addSubnode(avatarNode)
        }
        self.scrollingContainer.addSubnode(self.containerNode)
        self.addSubnode(self.scrollingContainer)
        
        if let action {
            let actionColor = theme.list.itemAccentColor.withMultiplied(hue: 1.0, saturation: 0.64, brightness: 1.08)
            let actionButtonNode = HighlightableButtonNode()
            actionButtonNode.hitTestSlop = UIEdgeInsets(top: -16.0, left: -16.0, bottom: -16.0, right: -16.0)
            actionButtonNode.setAttributedTitle(NSAttributedString(string: action.title, font: Font.regular(17.0), textColor: actionColor), for: .normal)
            self.containerNode.addSubnode(actionButtonNode)
            self.actionButtonNode = actionButtonNode
        }
        
        self.actionButtonNode?.addTarget(self, action: #selector(self.actionPressed), forControlEvents: .touchUpInside)
        self.closeButtonNode?.addTarget(self, action: #selector(self.closePressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func actionPressed() {
        if let action = self.action {
            action.action()
            self.requestDismiss()
        }
    }
    
    @objc private func closePressed() {
        self.requestDismiss()
    }
    
    func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        self.scrollingContainer.frame = CGRect(origin: CGPoint(), size: layout.size)
        
        let sideInset: CGFloat = self.inset + layout.safeInsets.left
        let bottomInset: CGFloat = 10.0
        let contentInset: CGFloat = 11.0
        let contentVerticalInset: CGFloat = 8.0
        let animationSize: CGSize
        var animationInset: CGFloat = 0.0
        var animationSpacing: CGFloat = 0.0
        var animationOffset: CGFloat = 0.0
        
        switch self.icon {
        case .none:
            animationSize = CGSize()
        case .downArrows:
            animationSize = CGSize(width: 24.0, height: 32.0)
            animationInset = (40.0 - animationSize.width) / 2.0
        case let .animation(animationName, _, _):
            if animationName == "premium_unlock" {
                animationSize = CGSize(width: 34.0, height: 34.0)
            } else {
                animationSize = CGSize(width: 32.0, height: 32.0)
            }
            if ["anim_autoremove_on", "anim_autoremove_off"].contains(animationName) {
                animationOffset = -3.0
            } else if animationName == "ChatListFoldersTooltip" {
                animationInset = (70.0 - animationSize.width) / 2.0
            } else {
                animationInset = 0.0
            }
            animationSpacing = 8.0
        case .peer:
            animationSize = CGSize(width: 32.0, height: 32.0)
            animationInset = 0.0
            animationSpacing = 8.0
        }
        
        var containerWidth = max(100.0, min(layout.size.width - sideInset * 2.0, 614.0))
        if let constrainWidth = self.constrainWidth, constrainWidth > 100.0 {
            containerWidth = constrainWidth
        }
        
        var actionSize: CGSize = .zero
        
        var buttonInset: CGFloat = 0.0
        if let actionButtonNode = self.actionButtonNode {
            actionSize = actionButtonNode.measure(CGSize(width: containerWidth, height: .greatestFiniteMagnitude))
            buttonInset += actionSize.width + 32.0
        }
        if self.closeButtonNode != nil {
            buttonInset += 24.0
        }
        
        let baseFont = Font.regular(self.fontSize)
        let boldFont = Font.semibold(14.0)
        let italicFont = Font.italic(self.fontSize)
        let boldItalicFont = Font.semiboldItalic(self.fontSize)
        let fixedFont = Font.monospace(self.fontSize)
        
        let textColor: UIColor = .white
        let attributedText: NSAttributedString
        switch self.text {
        case let .plain(text):
            attributedText = NSAttributedString(string: text, font: baseFont, textColor: textColor)
        case let .entities(text, entities):
            attributedText = stringWithAppliedEntities(text, entities: entities, baseColor: textColor, linkColor: textColor, baseFont: baseFont, linkFont: baseFont, boldFont: boldFont, italicFont: italicFont, boldItalicFont: boldItalicFont, fixedFont: fixedFont, blockQuoteFont: baseFont, underlineLinks: true, external: false, message: nil)
        case let .markdown(text):
            let linkColor = UIColor(rgb: 0x64d2ff)
            let markdownAttributes = MarkdownAttributes(
                body: MarkdownAttributeSet(font: baseFont, textColor: textColor),
                bold: MarkdownAttributeSet(font: boldFont, textColor: textColor),
                link: MarkdownAttributeSet(font: boldFont, textColor: linkColor),
                linkAttribute: { _ in
                    return nil
                }
            )
            attributedText = parseMarkdownIntoAttributedString(text, attributes: markdownAttributes)
        }
        
        let highlightColor: UIColor? = UIColor.white.withAlphaComponent(0.5)
        let highlightAction: (([NSAttributedString.Key: Any]) -> NSAttributedString.Key?)? = { attributes in
            let highlightedAttributes = [
                TelegramTextAttributes.URL,
                TelegramTextAttributes.PeerMention,
                TelegramTextAttributes.PeerTextMention,
                TelegramTextAttributes.BotCommand,
                TelegramTextAttributes.Hashtag
            ]
            
            for attribute in highlightedAttributes {
                if let _ = attributes[NSAttributedString.Key(rawValue: attribute)] {
                    return NSAttributedString.Key(rawValue: attribute)
                }
            }
            return nil
        }
        let tapAction: (([NSAttributedString.Key: Any], Int) -> Void)? = { [weak self] attributes, index in
            guard let strongSelf = self else {
                return
            }
            if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                var concealed = true
                if let (attributeText, fullText) = (strongSelf.textView.view as? BalancedTextComponent.View)?.attributeSubstring(name: TelegramTextAttributes.URL, index: index) {
                    concealed = !doesUrlMatchText(url: url, text: attributeText, fullText: fullText)
                }
                strongSelf.openActiveTextItem?(.url(url, concealed), .tap)
            } else if let mention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                strongSelf.openActiveTextItem?(.mention(mention.peerId, mention.mention), .tap)
            } else if let mention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                strongSelf.openActiveTextItem?(.textMention(mention), .tap)
            } else if let command = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.BotCommand)] as? String {
                strongSelf.openActiveTextItem?(.botCommand(command), .tap)
            } else if let hashtag = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                strongSelf.openActiveTextItem?(.hashtag(hashtag.hashtag), .tap)
            }
        }
        let longTapAction: (([NSAttributedString.Key: Any], Int) -> Void)? = { [weak self] attributes, index in
            guard let strongSelf = self else {
                return
            }
            if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                var concealed = true
                if let (attributeText, fullText) = (strongSelf.textView.view as? BalancedTextComponent.View)?.attributeSubstring(name: TelegramTextAttributes.URL, index: index) {
                    concealed = !doesUrlMatchText(url: url, text: attributeText, fullText: fullText)
                }
                strongSelf.openActiveTextItem?(.url(url, concealed), .longTap)
            } else if let mention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                strongSelf.openActiveTextItem?(.mention(mention.peerId, mention.mention), .longTap)
            } else if let mention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                strongSelf.openActiveTextItem?(.textMention(mention), .longTap)
            } else if let command = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.BotCommand)] as? String {
                strongSelf.openActiveTextItem?(.botCommand(command), .longTap)
            } else if let hashtag = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                strongSelf.openActiveTextItem?(.hashtag(hashtag.hashtag), .longTap)
            }
        }
        
        let textSize = self.textView.update(
            transition: .immediate,
            component: AnyComponent(BalancedTextComponent(
                text: .plain(attributedText),
                balanced: self.balancedTextLayout,
                horizontalAlignment: self.textAlignment == .center ? .center : .left,
                maximumNumberOfLines: 0,
                highlightColor: highlightColor,
                highlightAction: highlightAction,
                tapAction: tapAction,
                longTapAction: longTapAction
            )),
            environment: {},
            containerSize: CGSize(width: containerWidth - contentInset * 2.0 - animationSize.width - animationSpacing - buttonInset, height: 1000000.0)
        )
        
        var backgroundFrame: CGRect
        
        var backgroundHeight: CGFloat
        switch self.tooltipStyle {
        case .default, .gradient:
            backgroundHeight = max(animationSize.height, textSize.height) + contentVerticalInset * 2.0
        case .wide:
            backgroundHeight = max(animationSize.height, textSize.height) + contentVerticalInset * 2.0 + 4.0
        case let .customBlur(_, inset):
            backgroundHeight = max(animationSize.height, textSize.height) + contentVerticalInset * 2.0 + inset * 2.0
        case .light:
            backgroundHeight = max(28.0, max(animationSize.height, textSize.height) + 4.0 * 2.0)
        }
        if self.actionButtonNode != nil {
            backgroundHeight += 4.0
        }
                    
        var invertArrow = false
        switch self.location {
        case let .point(rect, arrowPosition):
            var backgroundWidth = textSize.width + contentInset * 2.0 + animationSize.width + animationSpacing
            if self.closeButtonNode != nil || self.actionButtonNode != nil {
                backgroundWidth += buttonInset
            }
            if self.actionButtonNode != nil, case .compact = layout.metrics.widthClass {
                backgroundWidth = containerWidth
            }
            switch arrowPosition {
                case .bottom, .top:
                    backgroundFrame = CGRect(origin: CGPoint(x: rect.midX - backgroundWidth / 2.0, y: rect.minY - bottomInset - backgroundHeight), size: CGSize(width: backgroundWidth, height: backgroundHeight))
                case .right:
                    backgroundFrame = CGRect(origin: CGPoint(x: rect.minX - backgroundWidth - bottomInset, y: rect.midY - backgroundHeight / 2.0), size: CGSize(width: backgroundWidth, height: backgroundHeight))
            }
            
            if backgroundFrame.minX < sideInset {
                backgroundFrame.origin.x = sideInset
            }
            if backgroundFrame.maxX > layout.size.width - sideInset {
                backgroundFrame.origin.x = layout.size.width - sideInset - backgroundFrame.width
            }
            if backgroundFrame.minY < layout.insets(options: .statusBar).top {
                backgroundFrame.origin.y = rect.maxY + bottomInset
                invertArrow = true
            }
            if case .top = arrowPosition, !invertArrow {
                invertArrow = true
                backgroundFrame.origin.y = rect.maxY + bottomInset
            }
            self.isArrowInverted = invertArrow
        case .top:
            let backgroundWidth = containerWidth
            backgroundFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - backgroundWidth) / 2.0), y: layout.insets(options: [.statusBar]).top + 13.0), size: CGSize(width: backgroundWidth, height: backgroundHeight))
        case .bottom:
            let backgroundWidth = containerWidth
            backgroundFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - backgroundWidth) / 2.0), y: layout.size.height - layout.insets(options: []).bottom - 12.0 - backgroundHeight), size: CGSize(width: backgroundWidth, height: backgroundHeight))
        }
        
        transition.updateFrame(node: self.containerNode, frame: backgroundFrame)
        transition.updateFrame(node: self.backgroundContainerNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        transition.updateFrame(node: self.backgroundMaskNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size).insetBy(dx: -10.0, dy: -10.0))
        transition.updateFrame(node: self.backgroundClipNode, frame: CGRect(origin: CGPoint(x: 10.0, y: 10.0), size: backgroundFrame.size))

        if let effectNode = self.effectNode {
            let effectFrame = CGRect(origin: CGPoint(), size: backgroundFrame.size).insetBy(dx: -10.0, dy: -10.0)
            transition.updateFrame(node: effectNode, frame: effectFrame)
            effectNode.update(size: effectFrame.size, transition: transition)
        }
        if let gradientNode = self.gradientNode {
            transition.updateFrame(node: gradientNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        }
        if let image = self.arrowNode.image, case let .point(rect, arrowPosition) = self.location {
            let arrowSize = image.size
            let arrowCenterX = rect.midX
            
            let arrowFrame: CGRect
            
            switch arrowPosition {
            case .bottom, .top:
                if invertArrow {
                    arrowFrame = CGRect(origin: CGPoint(x: floor(arrowCenterX - arrowSize.width / 2.0), y: -arrowSize.height), size: arrowSize)
                } else {
                    arrowFrame = CGRect(origin: CGPoint(x: floor(arrowCenterX - arrowSize.width / 2.0), y: backgroundFrame.height), size: arrowSize)
                }
                ContainedViewLayoutTransition.immediate.updateTransformScale(node: self.arrowContainer, scale: CGPoint(x: 1.0, y: invertArrow ? -1.0 : 1.0))
                
                if case .gradient = self.tooltipStyle {
                    transition.updateFrame(node: self.arrowContainer, frame: arrowFrame.offsetBy(dx: -backgroundFrame.minX, dy: 0.0))
                } else {
                    transition.updateFrame(node: self.arrowContainer, frame: arrowFrame.offsetBy(dx: -backgroundFrame.minX + 10.0, dy: 10.0))
                }
                
                let arrowBounds = CGRect(origin: CGPoint(), size: arrowSize)
                self.arrowNode.frame = arrowBounds
                self.arrowGradientNode?.frame = CGRect(origin: CGPoint(x: -arrowFrame.minX + backgroundFrame.minX, y: 0.0), size: backgroundFrame.size)
            case .right:
                let arrowCenterY = floorToScreenPixels(rect.midY - arrowSize.height / 2.0)
                arrowFrame = CGRect(origin: CGPoint(x: backgroundFrame.width + arrowSize.height, y: self.view.convert(CGPoint(x: 0.0, y: arrowCenterY), to: self.arrowContainer.supernode?.view).y), size: CGSize(width: arrowSize.height, height: arrowSize.width))
                
                ContainedViewLayoutTransition.immediate.updateTransformRotation(node: self.arrowContainer, angle: -CGFloat.pi / 2.0)
                
                transition.updateFrame(node: self.arrowContainer, frame: arrowFrame.offsetBy(dx: 8.0 - UIScreenPixel, dy: 0.0))
                
                let arrowBounds = CGRect(origin: .zero, size: arrowSize)
                self.arrowNode.frame = arrowBounds
                self.arrowGradientNode?.frame = arrowBounds
            }
        } else {
            self.arrowNode.isHidden = true
        }
        
        let textFrame = CGRect(origin: CGPoint(x: contentInset + animationSize.width + animationSpacing, y: floor((backgroundHeight - textSize.height) / 2.0)), size: textSize)
        
        if let textComponentView = self.textView.view {
            if textComponentView.superview == nil {
                textComponentView.layer.anchorPoint = CGPoint()
                self.containerNode.view.addSubview(textComponentView)
            }
            transition.updatePosition(layer: textComponentView.layer, position: textFrame.origin)
            transition.updateBounds(layer: textComponentView.layer, bounds: CGRect(origin: CGPoint(), size: textFrame.size))
        }
        
        if let closeButtonNode = self.closeButtonNode {
            let closeSize = CGSize(width: 44.0, height: 44.0)
            transition.updateFrame(node: closeButtonNode, frame: CGRect(origin: CGPoint(x: textFrame.maxX - 6.0, y: floor((backgroundHeight - closeSize.height) / 2.0)), size: closeSize))
        }
        
        if let actionButtonNode = self.actionButtonNode {
            transition.updateFrame(node: actionButtonNode, frame: CGRect(origin: CGPoint(x: backgroundFrame.width - actionSize.width - 16.0, y: floor((backgroundHeight - actionSize.height) / 2.0)), size: actionSize))
        }
        
        let animationFrame = CGRect(origin: CGPoint(x: contentInset - animationInset, y: floorToScreenPixels((backgroundHeight - animationSize.height - animationInset * 2.0) / 2.0) + animationOffset), size: CGSize(width: animationSize.width + animationInset * 2.0, height: animationSize.height + animationInset * 2.0))
        transition.updateFrame(node: self.animatedStickerNode, frame: animationFrame)
        self.animatedStickerNode.updateLayout(size: CGSize(width: animationSize.width + animationInset * 2.0, height: animationSize.height + animationInset * 2.0))
        
        if let downArrowsNode = self.downArrowsNode {
            let arrowsSize = CGSize(width: 16.0, height: 16.0)
            transition.updateFrame(node: downArrowsNode, frame: CGRect(origin: CGPoint(x: animationFrame.midX - arrowsSize.width / 2.0, y: animationFrame.midY - arrowsSize.height / 2.0), size: arrowsSize))
            downArrowsNode.setupAnimations()
        }
        
        if let avatarNode = self.avatarNode {
            var avatarFrame = animationFrame
            
            if let icon, case let .peer(_, isStory) = icon, isStory {
                let indicatorTransition: Transition = .immediate
                let avatarStoryIndicator: ComponentView<Empty>
                if let current = self.avatarStoryIndicator {
                    avatarStoryIndicator = current
                } else {
                    avatarStoryIndicator = ComponentView()
                    self.avatarStoryIndicator = avatarStoryIndicator
                }
                
                let storyIndicatorScale: CGFloat = 1.0
                var indicatorFrame = CGRect(origin: CGPoint(x: avatarFrame.minX + 4.0, y: avatarFrame.minY + 4.0), size: CGSize(width: avatarFrame.width - 4.0 - 4.0, height: avatarFrame.height - 4.0 - 4.0))
                indicatorFrame.origin.x -= (avatarFrame.width - avatarFrame.width * storyIndicatorScale) * 0.5
                
                let _ = avatarStoryIndicator.update(
                    transition: indicatorTransition,
                    component: AnyComponent(AvatarStoryIndicatorComponent(
                        hasUnseen: true,
                        hasUnseenCloseFriendsItems: false,
                        colors: AvatarStoryIndicatorComponent.Colors(theme: defaultDarkPresentationTheme),
                        activeLineWidth: 1.0 + UIScreenPixel,
                        inactiveLineWidth: 1.0 + UIScreenPixel,
                        counters: nil
                    )),
                    environment: {},
                    containerSize: indicatorFrame.size
                )
                if let avatarStoryIndicatorView = avatarStoryIndicator.view {
                    if avatarStoryIndicatorView.superview == nil {
                        avatarStoryIndicatorView.isUserInteractionEnabled = false
                        self.containerNode.view.addSubview(avatarStoryIndicatorView)
                    }
                    
                    indicatorTransition.setPosition(view: avatarStoryIndicatorView, position: indicatorFrame.center)
                    indicatorTransition.setBounds(view: avatarStoryIndicatorView, bounds: CGRect(origin: CGPoint(), size: indicatorFrame.size))
                    indicatorTransition.setScale(view: avatarStoryIndicatorView, scale: storyIndicatorScale)
                }
                
                avatarFrame = avatarFrame.insetBy(dx: 4.0, dy: 4.0)
            } else {
                if let avatarStoryIndicator = self.avatarStoryIndicator {
                    self.avatarStoryIndicator = nil
                    avatarStoryIndicator.view?.removeFromSuperview()
                }
            }
            
            transition.updateFrame(node: avatarNode, frame: avatarFrame)
            avatarNode.updateSize(size: avatarFrame.size)
        }
    }
    
    private var didRequestDismiss = false
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let event = event {
            if let _ = self.openActiveTextItem, let textComponentView = self.textView.view, let result = textComponentView.hitTest(self.view.convert(point, to: textComponentView), with: event) {
                return result
            }
            
            var eventIsPresses = false
            if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                eventIsPresses = event.type == .presses
            }
            if event.type == .touches || eventIsPresses {
                if let actionButtonNode = self.actionButtonNode, let result = actionButtonNode.hitTest(self.convert(point, to: actionButtonNode), with: event) {
                    return result
                }
                if !self.didRequestDismiss {
                    switch self.shouldDismissOnTouch(point, self.containerNode.frame) {
                    case .ignore:
                        break
                    case let .dismiss(consume):
                        self.requestDismiss()
                        if consume {
                            self.didRequestDismiss = true
                            return self.view
                        }
                    }
                } else {
                    return self.view
                }
                return nil
            }
        }
        return super.hitTest(point, with: event)
    }
    
    func animateIn() {
        switch self.location {
        case .top, .bottom:
            self.containerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            self.containerNode.layer.animateScale(from: 0.96, to: 1.0, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
            
            if let _ = self.validLayout, case .top = self.location {
                let offset: CGFloat
                if case .top = self.location {
                    offset = -13.0 - self.backgroundContainerNode.frame.height
                } else {
                    offset = 13.0 + self.backgroundContainerNode.frame.height
                }
                self.containerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: offset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            }
        case let .point(_, arrowPosition):
            self.containerNode.layer.animateSpring(from: NSNumber(value: Float(0.01)), to: NSNumber(value: Float(1.0)), keyPath: "transform.scale", duration: 0.4, damping: 105.0)
           
            let startPoint: CGPoint
            switch arrowPosition {
                case .bottom, .top:
                    let arrowY: CGFloat = self.isArrowInverted ? self.arrowContainer.frame.minY : self.arrowContainer.frame.maxY
                    startPoint = CGPoint(x: self.arrowContainer.frame.midX - self.containerNode.bounds.width / 2.0, y: arrowY - self.containerNode.bounds.height / 2.0)
                case .right:
                    startPoint = CGPoint(x: self.arrowContainer.frame.maxX - self.containerNode.bounds.width / 2.0, y: self.arrowContainer.frame.minY - self.containerNode.bounds.height / 2.0)
            }
            
            self.containerNode.layer.animateSpring(from: NSValue(cgPoint: startPoint), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: 0.4, damping: 105.0, additive: true)
            self.containerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        }
        
        let animationDelay: Double
        switch self.icon {
        case let .animation(_, delay, _):
            animationDelay = delay
        case .none, .downArrows:
            animationDelay = 0.0
        case .peer:
            animationDelay = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + animationDelay, execute: { [weak self] in
            self?.animatedStickerNode.visibility = true
        })
    }
    
    func animateOut(inPlace: Bool, completion: @escaping () -> Void) {
        switch self.location {
        case .top, .bottom:
            self.containerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { _ in
                completion()
            })
            self.containerNode.layer.animateScale(from: 1.0, to: 0.96, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
            if let _ = self.validLayout, case .top = self.location, !inPlace {
                let offset: CGFloat
                if case .top = self.location {
                    offset = -13.0 - self.backgroundContainerNode.frame.height
                } else {
                    offset = 13.0 + self.backgroundContainerNode.frame.height
                }
                self.containerNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: offset), duration: 0.3, removeOnCompletion: false, additive: true)
            }
        case let .point(_, arrowPosition):
            self.containerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                completion()
            })
            self.containerNode.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
            
            let targetPoint: CGPoint
            switch arrowPosition {
                case .bottom, .top:
                    let arrowY: CGFloat = self.isArrowInverted ? self.arrowContainer.frame.minY : self.arrowContainer.frame.maxY
                    targetPoint = CGPoint(x: self.arrowContainer.frame.midX - self.containerNode.bounds.width / 2.0, y: arrowY - self.containerNode.bounds.height / 2.0)
                case .right:
                    targetPoint = CGPoint(x: self.arrowContainer.frame.maxX - self.containerNode.bounds.width / 2.0, y: self.arrowContainer.frame.minY - self.containerNode.bounds.height / 2.0)
            }
            
            self.containerNode.layer.animatePosition(from: CGPoint(), to: targetPoint, duration: 0.2, removeOnCompletion: false, additive: true)
        }
    }
    
    func addRelativeScrollingOffset(_ value: CGFloat, transition: ContainedViewLayoutTransition) {
        self.scrollingContainer.bounds = self.scrollingContainer.bounds.offsetBy(dx: 0.0, dy: value)
        transition.animateOffsetAdditive(node: self.scrollingContainer, offset: -value)
        
        if let layout = self.validLayout {
            let projectedContainerFrame = self.containerNode.frame.offsetBy(dx: 0.0, dy: -self.scrollingContainer.bounds.origin.y)
            if projectedContainerFrame.minY - 30.0 < layout.insets(options: .statusBar).top {
                self.requestDismiss()
            }
        }
    }
}

public final class TooltipScreen: ViewController {
    public enum Text: Equatable {
        case plain(text: String)
        case entities(text: String, entities: [MessageTextEntity])
        case markdown(text: String)
    }
    
    public class Action {
        public let title: String
        public let action: () -> Void
        
        public init(
            title: String,
            action: @escaping () -> Void
        ) {
            self.title = title
            self.action = action
        }
    }
    
    public enum Icon {
        case animation(name: String, delay: Double, tintColor: UIColor?)
        case peer(peer: EnginePeer, isStory: Bool)
        case downArrows
    }
    
    public enum DismissOnTouch {
        case ignore
        case dismiss(consume: Bool)
    }
    
    public enum ArrowPosition {
        case top
        case right
        case bottom
    }
    
    public enum ArrowStyle {
        case `default`
        case small
    }
    
    public enum Location {
        case point(CGRect, ArrowPosition)
        case top
        case bottom
    }
    
    public enum DisplayDuration {
        case `default`
        case custom(Double)
        case infinite
        case manual
    }
    
    public enum Style {
        case `default`
        case light
        case customBlur(UIColor, CGFloat)
        case gradient(UIColor, UIColor)
        case wide
    }
    
    public enum Alignment {
        case natural
        case center
    }
    
    private let context: AccountContext?
    private let account: Account
    private let sharedContext: SharedAccountContext
    public let text: TooltipScreen.Text
    public let textAlignment: TooltipScreen.Alignment
    private let balancedTextLayout: Bool
    private let constrainWidth: CGFloat?
    private let style: TooltipScreen.Style
    private let arrowStyle: TooltipScreen.ArrowStyle
    private let icon: TooltipScreen.Icon?
    private let action: TooltipScreen.Action?
    public var location: TooltipScreen.Location {
        didSet {
            if self.isNodeLoaded {
                self.controllerNode.location = self.location
            }
        }
    }
    private let displayDuration: DisplayDuration
    private let inset: CGFloat
    private let cornerRadius: CGFloat?
    private let shouldDismissOnTouch: (CGPoint, CGRect) -> TooltipScreen.DismissOnTouch
    private let openActiveTextItem: ((TooltipActiveTextItem, TooltipActiveTextAction) -> Void)?
    
    private var controllerNode: TooltipScreenNode {
        return self.displayNode as! TooltipScreenNode
    }
    
    private var validLayout: ContainerViewLayout?
    private var isDismissed: Bool = false
    
    public var willBecomeDismissed: ((TooltipScreen) -> Void)?
    public var becameDismissed: ((TooltipScreen) -> Void)?
    
    private var dismissTimer: Foundation.Timer?
    
    public var alwaysVisible = false
    
    public init(
        context: AccountContext? = nil,
        account: Account,
        sharedContext: SharedAccountContext,
        text: TooltipScreen.Text,
        textAlignment: TooltipScreen.Alignment = .natural,
        balancedTextLayout: Bool = false,
        constrainWidth: CGFloat? = nil,
        style: TooltipScreen.Style = .default,
        arrowStyle: TooltipScreen.ArrowStyle = .default,
        icon: TooltipScreen.Icon? = nil,
        action: TooltipScreen.Action? = nil,
        location: TooltipScreen.Location,
        displayDuration: DisplayDuration = .default,
        inset: CGFloat = 12.0,
        cornerRadius: CGFloat? = nil,
        shouldDismissOnTouch: @escaping (CGPoint, CGRect) -> TooltipScreen.DismissOnTouch,
        openActiveTextItem: ((TooltipActiveTextItem, TooltipActiveTextAction) -> Void)? = nil
    ) {
        self.context = context
        self.account = account
        self.sharedContext = sharedContext
        self.text = text
        self.textAlignment = textAlignment
        self.balancedTextLayout = balancedTextLayout
        self.constrainWidth = constrainWidth
        self.style = style
        self.arrowStyle = arrowStyle
        self.icon = icon
        self.action = action
        self.location = location
        self.displayDuration = displayDuration
        self.inset = inset
        self.cornerRadius = cornerRadius
        self.shouldDismissOnTouch = shouldDismissOnTouch
        self.openActiveTextItem = openActiveTextItem
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.dismissTimer?.invalidate()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.controllerNode.animateIn()
        self.resetDismissTimeout(duration: self.displayDuration)
    }
    
    public func resetDismissTimeout(duration: TooltipScreen.DisplayDuration? = nil) {
        self.dismissTimer?.invalidate()
        self.dismissTimer = nil
        
        let timeout: Double
        switch duration ?? self.displayDuration {
        case .default:
            timeout = 5.0
        case let .custom(value):
            timeout = value
        case .infinite, .manual:
            return
        }
        
        final class TimerTarget: NSObject {
            private let f: () -> Void
            
            init(_ f: @escaping () -> Void) {
                self.f = f
            }
            
            @objc func timerEvent() {
                self.f()
            }
        }
        let dismissTimer = Foundation.Timer(timeInterval: timeout, target: TimerTarget { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.dismiss()
        }, selector: #selector(TimerTarget.timerEvent), userInfo: nil, repeats: false)
        self.dismissTimer = dismissTimer
        RunLoop.main.add(dismissTimer, forMode: .common)
    }
    
    override public func loadDisplayNode() {
        self.displayNode = TooltipScreenNode(context: self.context, account: self.account, sharedContext: self.sharedContext, text: self.text, textAlignment: self.textAlignment, balancedTextLayout: self.balancedTextLayout, constrainWidth: self.constrainWidth, style: self.style, arrowStyle: self.arrowStyle, icon: self.icon, action: self.action, location: self.location, displayDuration: self.displayDuration, inset: self.inset, cornerRadius: self.cornerRadius, shouldDismissOnTouch: self.shouldDismissOnTouch, requestDismiss: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.dismiss()
        }, openActiveTextItem: self.openActiveTextItem)
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        if let validLayout = self.validLayout, !self.alwaysVisible {
            if validLayout.size.width != layout.size.width {
                self.dismiss()
            }
        }
        self.validLayout = layout
        
        self.controllerNode.updateLayout(layout: layout, transition: transition)
    }
    
    public func addRelativeScrollingOffset(_ value: CGFloat, transition: ContainedViewLayoutTransition) {
        self.controllerNode.addRelativeScrollingOffset(value, transition: transition)
    }
    
    public func dismiss(inPlace: Bool, completion: (() -> Void)? = nil) {
        if self.isDismissed {
            return
        }
        self.isDismissed = true
        self.willBecomeDismissed?(self)
        self.controllerNode.animateOut(inPlace: inPlace, completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            let becameDismissed = strongSelf.becameDismissed
            strongSelf.presentingViewController?.dismiss(animated: false, completion: nil)
            becameDismissed?(strongSelf)
        })
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.dismiss(inPlace: false, completion: completion)
    }
}
