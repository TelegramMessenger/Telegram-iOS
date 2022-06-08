import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import AppBundle
import TelegramCore
import TextFormat
import Postbox
import UrlEscaping

public protocol TooltipCustomContentNode: ASDisplayNode {
    func animateIn()
    func updateLayout(size: CGSize) -> CGSize
}

public enum TooltipActiveTextItem {
    case url(String, Bool)
    case mention(PeerId, String)
    case textMention(String)
    case botCommand(String)
    case hashtag(String)
}

public enum TooltipActiveTextAction {
    case tap
    case longTap
}

private final class TooltipScreenNode: ViewControllerTracingNode {
    private let tooltipStyle: TooltipScreen.Style
    private let icon: TooltipScreen.Icon?
    private let customContentNode: TooltipCustomContentNode?
    private let location: TooltipScreen.Location
    private let displayDuration: TooltipScreen.DisplayDuration
    private let shouldDismissOnTouch: (CGPoint) -> TooltipScreen.DismissOnTouch
    private let requestDismiss: () -> Void
    private let openActiveTextItem: ((TooltipActiveTextItem, TooltipActiveTextAction) -> Void)?
    
    private let scrollingContainer: ASDisplayNode
    private let containerNode: ASDisplayNode
    private let backgroundContainerNode: ASDisplayNode
    private let backgroundNode: ASImageNode
    private var effectView: UIView?
    private var gradientNode: ASDisplayNode?
    private var arrowGradientNode: ASDisplayNode?
    private let arrowNode: ASImageNode
    private let arrowContainer: ASDisplayNode
    private var arrowEffectView: UIView?
    private let animatedStickerNode: AnimatedStickerNode
    private let textNode: ImmediateTextNode
    
    private var isArrowInverted: Bool = false
    
    private let inset: CGFloat
    
    private var validLayout: ContainerViewLayout?
    
    init(account: Account, text: String, textEntities: [MessageTextEntity], style: TooltipScreen.Style, icon: TooltipScreen.Icon?, customContentNode: TooltipCustomContentNode? = nil, location: TooltipScreen.Location, displayDuration: TooltipScreen.DisplayDuration, inset: CGFloat = 13.0, shouldDismissOnTouch: @escaping (CGPoint) -> TooltipScreen.DismissOnTouch, requestDismiss: @escaping () -> Void, openActiveTextItem: ((TooltipActiveTextItem, TooltipActiveTextAction) -> Void)?) {
        self.tooltipStyle = style
        self.icon = icon
        self.customContentNode = customContentNode
        self.location = location
        self.displayDuration = displayDuration
        self.inset = inset
        self.shouldDismissOnTouch = shouldDismissOnTouch
        self.requestDismiss = requestDismiss
        self.openActiveTextItem = openActiveTextItem
        
        self.containerNode = ASDisplayNode()
        self.backgroundContainerNode = ASDisplayNode()
        
        let fillColor = UIColor(white: 0.0, alpha: 0.8)
        
        self.scrollingContainer = ASDisplayNode()
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.image = generateAdjustedStretchableFilledCircleImage(diameter: 15.0, color: fillColor)

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
        
        let arrowSize = CGSize(width: 29.0, height: 10.0)
        self.arrowNode = ASImageNode()
        self.arrowNode.image = generateImage(arrowSize, rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(fillColor.cgColor)
            context.scaleBy(x: 0.333, y: 0.333)
            let _ = try? drawSvgPath(context, path: "M85.882251,0 C79.5170552,0 73.4125613,2.52817247 68.9116882,7.02834833 L51.4264069,24.5109211 C46.7401154,29.1964866 39.1421356,29.1964866 34.4558441,24.5109211 L16.9705627,7.02834833 C12.4696897,2.52817247 6.36519576,0 0,0 L85.882251,0 ")
            context.fillPath()
        })
        
        self.arrowContainer = ASDisplayNode()
        
        let fontSize: CGFloat
        if case .light = style {
            self.effectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
            self.backgroundContainerNode.clipsToBounds = true
            self.backgroundContainerNode.cornerRadius = 14.0
            if #available(iOS 13.0, *) {
                self.backgroundContainerNode.layer.cornerCurve = .continuous
            }
            fontSize = 17.0
            
            self.arrowEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
            self.arrowContainer.view.addSubview(self.arrowEffectView!)
            
            let maskLayer = CAShapeLayer()
            if let path = try? svgPath("M85.882251,0 C79.5170552,0 73.4125613,2.52817247 68.9116882,7.02834833 L51.4264069,24.5109211 C46.7401154,29.1964866 39.1421356,29.1964866 34.4558441,24.5109211 L16.9705627,7.02834833 C12.4696897,2.52817247 6.36519576,0 0,0 L85.882251,0 ", scale: CGPoint(x: 0.333333, y: 0.333333), offset: CGPoint()) {
                maskLayer.path = path.cgPath
            }
            maskLayer.frame = CGRect(origin: CGPoint(), size: arrowSize)
            self.arrowContainer.layer.mask = maskLayer
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
            if let path = try? svgPath("M85.882251,0 C79.5170552,0 73.4125613,2.52817247 68.9116882,7.02834833 L51.4264069,24.5109211 C46.7401154,29.1964866 39.1421356,29.1964866 34.4558441,24.5109211 L16.9705627,7.02834833 C12.4696897,2.52817247 6.36519576,0 0,0 L85.882251,0 ", scale: CGPoint(x: 0.333333, y: 0.333333), offset: CGPoint()) {
                maskLayer.path = path.cgPath
            }
            maskLayer.frame = CGRect(origin: CGPoint(), size: arrowSize)
            self.arrowContainer.layer.mask = maskLayer
        } else if case .top = location {
            self.effectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
            self.containerNode.clipsToBounds = true
            self.containerNode.cornerRadius = 9.0
            if #available(iOS 13.0, *) {
                self.containerNode.layer.cornerCurve = .continuous
            }
            fontSize = 14.0
        } else {
            fontSize = 14.0
        }
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.maximumNumberOfLines = 0
        
        self.textNode.attributedText = stringWithAppliedEntities(text, entities: textEntities, baseColor: .white, linkColor: .white, baseFont: Font.regular(fontSize), linkFont: Font.regular(fontSize), boldFont: Font.semibold(14.0), italicFont: Font.italic(fontSize), boldItalicFont: Font.semiboldItalic(fontSize), fixedFont: Font.monospace(fontSize), blockQuoteFont: Font.regular(fontSize), underlineLinks: true, external: false)
        
        self.animatedStickerNode = DefaultAnimatedStickerNodeImpl()
        switch icon {
        case .none:
            break
        case .chatListPress:
            self.animatedStickerNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "ChatListFoldersTooltip"), width: Int(70 * UIScreenScale), height: Int(70 * UIScreenScale), playbackMode: .once, mode: .direct(cachePathPrefix: nil))
            self.animatedStickerNode.automaticallyLoadFirstFrame = true
        case .info:
            self.animatedStickerNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "anim_infotip"), width: Int(70 * UIScreenScale), height: Int(70 * UIScreenScale), playbackMode: .once, mode: .direct(cachePathPrefix: nil))
            self.animatedStickerNode.automaticallyLoadFirstFrame = true
        }
        
        super.init()
        
        self.containerNode.addSubnode(self.backgroundContainerNode)
        self.arrowContainer.addSubnode(self.arrowNode)
        self.backgroundNode.addSubnode(self.arrowContainer)
        if let gradientNode = self.gradientNode {
            self.backgroundContainerNode.addSubnode(gradientNode)
            self.containerNode.addSubnode(self.arrowContainer)
            self.arrowNode.removeFromSupernode()
        }
        else if let effectView = self.effectView {
            self.backgroundContainerNode.view.addSubview(effectView)
            if let _ = self.arrowEffectView {
                self.containerNode.addSubnode(self.arrowContainer)
                self.arrowNode.removeFromSupernode()
            }
        } else {
            self.backgroundContainerNode.addSubnode(self.backgroundNode)
        }
        self.containerNode.addSubnode(self.textNode)
        self.containerNode.addSubnode(self.animatedStickerNode)
        self.scrollingContainer.addSubnode(self.containerNode)
        self.addSubnode(self.scrollingContainer)
        
        self.textNode.linkHighlightColor = UIColor.white.withAlphaComponent(0.5)
        self.textNode.highlightAttributeAction = { attributes in
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
        self.textNode.tapAttributeAction = { [weak self] attributes, index in
            guard let strongSelf = self else {
                return
            }
            if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                var concealed = true
                if let (attributeText, fullText) = strongSelf.textNode.attributeSubstring(name: TelegramTextAttributes.URL, index: index) {
                    concealed = !doesUrlMatchText(url: url, text: attributeText, fullText: fullText)
                }
                openActiveTextItem?(.url(url, concealed), .tap)
            } else if let mention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                openActiveTextItem?(.mention(mention.peerId, mention.mention), .tap)
            } else if let mention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                openActiveTextItem?(.textMention(mention), .tap)
            } else if let command = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.BotCommand)] as? String {
                openActiveTextItem?(.botCommand(command), .tap)
            } else if let hashtag = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                openActiveTextItem?(.hashtag(hashtag.hashtag), .tap)
            }
        }
        
        self.textNode.longTapAttributeAction = { [weak self] attributes, index in
            guard let strongSelf = self else {
                return
            }
            if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                var concealed = true
                if let (attributeText, fullText) = strongSelf.textNode.attributeSubstring(name: TelegramTextAttributes.URL, index: index) {
                    concealed = !doesUrlMatchText(url: url, text: attributeText, fullText: fullText)
                }
                openActiveTextItem?(.url(url, concealed), .longTap)
            } else if let mention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                openActiveTextItem?(.mention(mention.peerId, mention.mention), .longTap)
            } else if let mention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                openActiveTextItem?(.textMention(mention), .longTap)
            } else if let command = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.BotCommand)] as? String {
                openActiveTextItem?(.botCommand(command), .longTap)
            } else if let hashtag = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                openActiveTextItem?(.hashtag(hashtag.hashtag), .longTap)
            }
        }
    }
    
    func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        self.scrollingContainer.frame = CGRect(origin: CGPoint(), size: layout.size)
        
        let sideInset: CGFloat = self.inset + layout.safeInsets.left
        let bottomInset: CGFloat = 10.0
        let contentInset: CGFloat = 11.0
        let contentVerticalInset: CGFloat = 11.0
        let animationSize: CGSize
        let animationInset: CGFloat
        let animationSpacing: CGFloat
        
        switch self.icon {
        case .none:
            animationSize = CGSize()
            animationInset = 0.0
            animationSpacing = 0.0
        case .chatListPress:
            animationSize = CGSize(width: 32.0, height: 32.0)
            animationInset = (70.0 - animationSize.width) / 2.0
            animationSpacing = 8.0
        case .info:
            animationSize = CGSize(width: 32.0, height: 32.0)
            animationInset = 0.0
            animationSpacing = 8.0
        }
        
        let containerWidth = max(100.0, min(layout.size.width, 614.0) - (sideInset + layout.safeInsets.left) * 2.0)
        
        let textSize = self.textNode.updateLayout(CGSize(width: containerWidth - contentInset * 2.0 - animationSize.width - animationSpacing, height: .greatestFiniteMagnitude))
        
        var backgroundFrame: CGRect
        
        let backgroundHeight: CGFloat
        switch self.tooltipStyle {
            case .default, .gradient:
                backgroundHeight = max(animationSize.height, textSize.height) + contentVerticalInset * 2.0
            case .light:
                backgroundHeight = max(28.0, max(animationSize.height, textSize.height) + 4.0 * 2.0)
        }
                    
        var invertArrow = false
        switch self.location {
        case let .point(rect, arrowPosition):
            let backgroundWidth = textSize.width + contentInset * 2.0 + animationSize.width + animationSpacing
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
        }
        
        transition.updateFrame(node: self.containerNode, frame: backgroundFrame)
        transition.updateFrame(node: self.backgroundContainerNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        if let effectView = self.effectView {
            transition.updateFrame(view: effectView, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
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
                    
                    transition.updateFrame(node: self.arrowContainer, frame: arrowFrame.offsetBy(dx: -backgroundFrame.minX, dy: 0.0))
                    
                    let arrowBounds = CGRect(origin: CGPoint(), size: arrowSize)
                    self.arrowNode.frame = arrowBounds
                    self.arrowEffectView?.frame = arrowBounds
                    self.arrowGradientNode?.frame = CGRect(origin: CGPoint(x: -arrowFrame.minX + backgroundFrame.minX, y: 0.0), size:  backgroundFrame.size)
                case .right:
                    arrowFrame = CGRect(origin: CGPoint(x: backgroundFrame.width + arrowSize.height, y: rect.midY), size: CGSize(width: arrowSize.height, height: arrowSize.width))
                    
                    ContainedViewLayoutTransition.immediate.updateTransformRotation(node: self.arrowContainer, angle: -CGFloat.pi / 2.0)
                    
                    transition.updateFrame(node: self.arrowContainer, frame: arrowFrame.offsetBy(dx: 0.0, dy: -backgroundFrame.minY - floorToScreenPixels((backgroundFrame.height - arrowSize.width) / 2.0)))
                    
                    let arrowBounds = CGRect(origin: CGPoint(x: 0.0, y: -0.5), size: arrowSize)
                    self.arrowNode.frame = arrowBounds
                    self.arrowEffectView?.frame = arrowBounds
                    self.arrowGradientNode?.frame = arrowBounds
            }
        } else {
            self.arrowNode.isHidden = true
            self.arrowEffectView?.isHidden = true
        }
        
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: contentInset + animationSize.width + animationSpacing, y: floor((backgroundHeight - textSize.height) / 2.0)), size: textSize))
        
        transition.updateFrame(node: self.animatedStickerNode, frame: CGRect(origin: CGPoint(x: contentInset - animationInset, y: contentVerticalInset - animationInset), size: CGSize(width: animationSize.width + animationInset * 2.0, height: animationSize.height + animationInset * 2.0)))
        self.animatedStickerNode.updateLayout(size: CGSize(width: animationSize.width + animationInset * 2.0, height: animationSize.height + animationInset * 2.0))
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let event = event {
            if let _ = self.openActiveTextItem, let result = self.textNode.hitTest(self.view.convert(point, to: self.textNode.view), with: event) {
                return result
            }
            
            var eventIsPresses = false
            if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                eventIsPresses = event.type == .presses
            }
            if event.type == .touches || eventIsPresses {
                switch self.shouldDismissOnTouch(point) {
                case .ignore:
                    break
                case let .dismiss(consume):
                    self.requestDismiss()
                    if consume {
                        return self.view
                    }
                }
                return nil
            }
        }
        return super.hitTest(point, with: event)
    }
    
    func animateIn() {
        switch self.location {
        case .top:
            self.containerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.containerNode.layer.animateScale(from: 0.96, to: 1.0, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
            if let _ = self.validLayout {
                self.containerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: -13.0 - self.backgroundNode.frame.height), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
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
        case .chatListPress:
            animationDelay = 0.6
        case .info:
            animationDelay = 0.2
        case .none:
            animationDelay = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + animationDelay, execute: { [weak self] in
            self?.animatedStickerNode.visibility = true
        })
    }
    
    func animateOut(completion: @escaping () -> Void) {
        switch self.location {
        case .top:
            self.containerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
                completion()
            })
            self.containerNode.layer.animateScale(from: 1.0, to: 0.96, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
            if let _ = self.validLayout {
                self.containerNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -13.0 - self.backgroundNode.frame.height), duration: 0.3, removeOnCompletion: false, additive: true)
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
    public enum Icon {
        case info
        case chatListPress
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
    
    public enum Location {
        case point(CGRect, ArrowPosition)
        case top
    }
    
    public enum DisplayDuration {
        case `default`
        case custom(Double)
    }
    
    public enum Style {
        case `default`
        case light
        case gradient(UIColor, UIColor)
    }
    
    private let account: Account
    public let text: String
    public let textEntities: [MessageTextEntity]
    private let style: TooltipScreen.Style
    private let icon: TooltipScreen.Icon?
    private let customContentNode: TooltipCustomContentNode?
    private let location: TooltipScreen.Location
    private let displayDuration: DisplayDuration
    private let inset: CGFloat
    private let shouldDismissOnTouch: (CGPoint) -> TooltipScreen.DismissOnTouch
    private let openActiveTextItem: ((TooltipActiveTextItem, TooltipActiveTextAction) -> Void)?
    
    private var controllerNode: TooltipScreenNode {
        return self.displayNode as! TooltipScreenNode
    }
    
    private var validLayout: ContainerViewLayout?
    private var isDismissed: Bool = false
    
    public var willBecomeDismissed: ((TooltipScreen) -> Void)?
    public var becameDismissed: ((TooltipScreen) -> Void)?
    
    private var dismissTimer: Foundation.Timer?
    
    public init(account: Account, text: String, textEntities: [MessageTextEntity] = [], style: TooltipScreen.Style = .default, icon: TooltipScreen.Icon?, customContentNode: TooltipCustomContentNode? = nil, location: TooltipScreen.Location, displayDuration: DisplayDuration = .default, inset: CGFloat = 13.0, shouldDismissOnTouch: @escaping (CGPoint) -> TooltipScreen.DismissOnTouch, openActiveTextItem: ((TooltipActiveTextItem, TooltipActiveTextAction) -> Void)? = nil) {
        self.account = account
        self.text = text
        self.textEntities = textEntities
        self.style = style
        self.icon = icon
        self.customContentNode = customContentNode
        self.location = location
        self.displayDuration = displayDuration
        self.inset = inset
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
        
        let timeout: Double
        switch duration ?? self.displayDuration {
        case .default:
            timeout = 5.0
        case let .custom(value):
            timeout = value
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
        self.displayNode = TooltipScreenNode(account: self.account, text: self.text, textEntities: self.textEntities, style: self.style, icon: self.icon, customContentNode: self.customContentNode, location: self.location, displayDuration: self.displayDuration, inset: self.inset, shouldDismissOnTouch: self.shouldDismissOnTouch, requestDismiss: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.dismiss()
        }, openActiveTextItem: self.openActiveTextItem)
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        if let validLayout = self.validLayout {
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
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if self.isDismissed {
            return
        }
        self.isDismissed = true
        self.willBecomeDismissed?(self)
        self.controllerNode.animateOut(completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            let becameDismissed = strongSelf.becameDismissed
            strongSelf.presentingViewController?.dismiss(animated: false, completion: nil)
            becameDismissed?(strongSelf)
        })
    }
}
