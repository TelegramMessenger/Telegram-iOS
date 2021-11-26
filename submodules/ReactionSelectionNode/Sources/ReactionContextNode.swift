import Foundation
import AsyncDisplayKit
import Display
import AnimatedStickerNode
import TelegramCore
import TelegramPresentationData
import AccountContext
import TelegramAnimatedStickerNode

public enum ReactionGestureItem {
    case like
    case unlike
}

public final class ReactionContextItem {
    public struct Reaction {
        public var rawValue: String
        
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
    
    public let reaction: ReactionContextItem.Reaction
    public let listAnimation: TelegramMediaFile
    public let applicationAnimation: TelegramMediaFile
    
    public init(
        reaction: ReactionContextItem.Reaction,
        listAnimation: TelegramMediaFile,
        applicationAnimation: TelegramMediaFile
    ) {
        self.reaction = reaction
        self.listAnimation = listAnimation
        self.applicationAnimation = applicationAnimation
    }
}

private let largeCircleSize: CGFloat = 16.0
private let smallCircleSize: CGFloat = 8.0

private func generateBackgroundImage(foreground: UIColor, diameter: CGFloat, shadowBlur: CGFloat) -> UIImage? {
    return generateImage(CGSize(width: diameter + shadowBlur * 2.0, height: diameter + shadowBlur * 2.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(foreground.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
    })?.stretchableImage(withLeftCapWidth: Int(shadowBlur + diameter / 2.0), topCapHeight: Int(shadowBlur + diameter / 2.0))
}

private func generateBackgroundShadowImage(shadow: UIColor, diameter: CGFloat, shadowBlur: CGFloat) -> UIImage? {
    return generateImage(CGSize(width: diameter * 2.0 + shadowBlur * 2.0, height: diameter + shadowBlur * 2.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(shadow.cgColor)
        context.setShadow(offset: CGSize(), blur: shadowBlur, color: shadow.cgColor)
        
        context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
        context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur + diameter, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
        context.fill(CGRect(origin: CGPoint(x: shadowBlur + diameter / 2.0, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
        
        context.setFillColor(UIColor.clear.cgColor)
        context.setBlendMode(.copy)
        
        context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
        context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur + diameter, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
        context.fill(CGRect(origin: CGPoint(x: shadowBlur + diameter / 2.0, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
    })?.stretchableImage(withLeftCapWidth: Int(diameter + shadowBlur / 2.0), topCapHeight: Int(diameter / 2.0 + shadowBlur / 2.0))
}

private func generateBubbleImage(foreground: UIColor, diameter: CGFloat, shadowBlur: CGFloat) -> UIImage? {
    return generateImage(CGSize(width: diameter + shadowBlur * 2.0, height: diameter + shadowBlur * 2.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(foreground.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
    })?.stretchableImage(withLeftCapWidth: Int(diameter / 2.0 + shadowBlur / 2.0), topCapHeight: Int(diameter / 2.0 + shadowBlur / 2.0))
}

private func generateBubbleShadowImage(shadow: UIColor, diameter: CGFloat, shadowBlur: CGFloat) -> UIImage? {
    return generateImage(CGSize(width: diameter + shadowBlur * 2.0, height: diameter + shadowBlur * 2.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(shadow.cgColor)
        context.setShadow(offset: CGSize(), blur: shadowBlur, color: shadow.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
        context.setShadow(offset: CGSize(), blur: 1.0, color: shadow.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
        context.setFillColor(UIColor.clear.cgColor)
        context.setBlendMode(.copy)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
    })?.stretchableImage(withLeftCapWidth: Int(diameter / 2.0 + shadowBlur / 2.0), topCapHeight: Int(diameter / 2.0 + shadowBlur / 2.0))
}

public final class ReactionContextNode: ASDisplayNode, UIScrollViewDelegate {
    private let theme: PresentationTheme
    private let items: [ReactionContextItem]
    
    private let backgroundNode: ASImageNode
    private let backgroundShadowNode: ASImageNode
    private let backgroundContainerNode: ASDisplayNode
    
    private let largeCircleNode: ASImageNode
    private let largeCircleShadowNode: ASImageNode
    
    private let smallCircleNode: ASImageNode
    private let smallCircleShadowNode: ASImageNode
    
    private let contentContainer: ASDisplayNode
    private let contentContainerMask: UIImageView
    private let scrollNode: ASScrollNode
    private var itemNodes: [ReactionNode] = []
    
    private var isExpanded: Bool = true
    private var highlightedReaction: ReactionContextItem.Reaction?
    private var validLayout: (CGSize, UIEdgeInsets, CGRect)?
    private var isLeftAligned: Bool = true
    
    public var reactionSelected: ((ReactionContextItem) -> Void)?
    
    private let hapticFeedback = HapticFeedback()
    
    public init(context: AccountContext, theme: PresentationTheme, items: [ReactionContextItem]) {
        self.theme = theme
        self.items = items
        
        let shadowBlur: CGFloat = 5.0
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.displaysAsynchronously = false
        
        self.backgroundShadowNode = ASImageNode()
        self.backgroundShadowNode.displayWithoutProcessing = true
        self.backgroundShadowNode.displaysAsynchronously = false
        
        self.backgroundContainerNode = ASDisplayNode()
        self.backgroundContainerNode.allowsGroupOpacity = true
        
        self.largeCircleNode = ASImageNode()
        self.largeCircleNode.displayWithoutProcessing = true
        self.largeCircleNode.displaysAsynchronously = false
        
        self.largeCircleShadowNode = ASImageNode()
        self.largeCircleShadowNode.displayWithoutProcessing = true
        self.largeCircleShadowNode.displaysAsynchronously = false
        
        self.smallCircleNode = ASImageNode()
        self.smallCircleNode.displayWithoutProcessing = true
        self.smallCircleNode.displaysAsynchronously = false
        
        self.smallCircleShadowNode = ASImageNode()
        self.smallCircleShadowNode.displayWithoutProcessing = true
        self.smallCircleShadowNode.displaysAsynchronously = false
        
        self.backgroundNode.image = generateBackgroundImage(foreground: theme.contextMenu.backgroundColor.withAlphaComponent(1.0), diameter: 52.0, shadowBlur: shadowBlur)
        
        self.backgroundShadowNode.image = generateBackgroundShadowImage(shadow: UIColor(white: 0.0, alpha: 0.2), diameter: 52.0, shadowBlur: shadowBlur)
        
        self.largeCircleNode.image = generateBubbleImage(foreground: theme.contextMenu.backgroundColor.withAlphaComponent(1.0), diameter: largeCircleSize, shadowBlur: shadowBlur)
        self.smallCircleNode.image = generateBubbleImage(foreground: theme.contextMenu.backgroundColor.withAlphaComponent(1.0), diameter: smallCircleSize, shadowBlur: shadowBlur)
        
        self.largeCircleShadowNode.image = generateBubbleShadowImage(shadow: UIColor(white: 0.0, alpha: 0.2), diameter: largeCircleSize, shadowBlur: shadowBlur)
        self.smallCircleShadowNode.image = generateBubbleShadowImage(shadow: UIColor(white: 0.0, alpha: 0.2), diameter: smallCircleSize, shadowBlur: shadowBlur)
        
        self.scrollNode = ASScrollNode()
        self.scrollNode.view.disablesInteractiveTransitionGestureRecognizer = true
        self.scrollNode.view.showsVerticalScrollIndicator = false
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.scrollsToTop = false
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.view.canCancelContentTouches = true
        if #available(iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        
        self.contentContainer = ASDisplayNode()
        self.contentContainer.clipsToBounds = true
        self.contentContainer.addSubnode(self.scrollNode)
        
        self.contentContainerMask = UIImageView()
        let maskGradientWidth: CGFloat = 10.0
        self.contentContainerMask.image = generateImage(CGSize(width: maskGradientWidth * 2.0 + 1.0, height: 8.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            let shadowColor = UIColor.black

            let stepCount = 10
            var colors: [CGColor] = []
            var locations: [CGFloat] = []

            for i in 0 ... stepCount {
                let t = CGFloat(i) / CGFloat(stepCount)
                colors.append(shadowColor.withAlphaComponent(t * t).cgColor)
                locations.append(t)
            }

            let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colors as CFArray, locations: &locations)!
            context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: maskGradientWidth, y: 0.0), options: CGGradientDrawingOptions())
            context.drawLinearGradient(gradient, start: CGPoint(x: size.width, y: 0.0), end: CGPoint(x: maskGradientWidth + 1.0, y: 0.0), options: CGGradientDrawingOptions())
            context.setFillColor(shadowColor.cgColor)
            context.fill(CGRect(origin: CGPoint(x: maskGradientWidth, y: 0.0), size: CGSize(width: 1.0, height: size.height)))
        })?.stretchableImage(withLeftCapWidth: Int(maskGradientWidth), topCapHeight: 0)
        self.contentContainer.view.mask = self.contentContainerMask
        //self.contentContainer.view.addSubview(self.contentContainerMask)
        
        super.init()
        
        self.addSubnode(self.smallCircleShadowNode)
        self.addSubnode(self.largeCircleShadowNode)
        self.addSubnode(self.backgroundShadowNode)
        
        self.backgroundContainerNode.addSubnode(self.smallCircleNode)
        self.backgroundContainerNode.addSubnode(self.largeCircleNode)
        self.backgroundContainerNode.addSubnode(self.backgroundNode)
        self.addSubnode(self.backgroundContainerNode)
        
        self.scrollNode.view.delegate = self
        
        self.itemNodes = self.items.map { item in
            return ReactionNode(context: context, theme: theme, item: item)
        }
        self.itemNodes.forEach(self.scrollNode.addSubnode)
        
        self.addSubnode(self.contentContainer)
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    public func updateLayout(size: CGSize, insets: UIEdgeInsets, anchorRect: CGRect, transition: ContainedViewLayoutTransition) {
        self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, transition: transition, animateInFromAnchorRect: nil, animateOutToAnchorRect: nil)
    }
    
    private func calculateBackgroundFrame(containerSize: CGSize, insets: UIEdgeInsets, anchorRect: CGRect, contentSize: CGSize) -> (backgroundFrame: CGRect, isLeftAligned: Bool, cloudSourcePoint: CGFloat) {
        var contentSize = contentSize
        contentSize.width = max(52.0, contentSize.width)
        contentSize.height = 52.0
        
        let sideInset: CGFloat = 12.0
        let backgroundOffset: CGPoint = CGPoint(x: 22.0, y: -7.0)
        
        var rect: CGRect
        let isLeftAligned: Bool
        if anchorRect.maxX < containerSize.width - backgroundOffset.x - sideInset {
            rect = CGRect(origin: CGPoint(x: anchorRect.maxX - contentSize.width + backgroundOffset.x, y: anchorRect.minY - contentSize.height + backgroundOffset.y), size: contentSize)
            isLeftAligned = true
        } else {
            rect = CGRect(origin: CGPoint(x: anchorRect.minX - backgroundOffset.x - 4.0, y: anchorRect.minY - contentSize.height + backgroundOffset.y), size: contentSize)
            isLeftAligned = false
        }
        rect.origin.x = max(sideInset, rect.origin.x)
        rect.origin.y = max(insets.top + sideInset, rect.origin.y)
        rect.origin.x = min(containerSize.width - contentSize.width - sideInset, rect.origin.x)
        
        let cloudSourcePoint: CGFloat
        if isLeftAligned {
            cloudSourcePoint = min(rect.maxX - rect.height / 2.0, anchorRect.maxX - 4.0)
        } else {
            cloudSourcePoint = max(rect.minX + rect.height / 2.0, anchorRect.minX)
        }
        
        return (rect, isLeftAligned, cloudSourcePoint)
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateScrolling(transition: .immediate)
    }
    
    private func updateScrolling(transition: ContainedViewLayoutTransition) {
        let sideInset: CGFloat = 14.0
        let minScale: CGFloat = 0.6
        let scaleDistance: CGFloat = 30.0
        let visibleBounds = self.scrollNode.view.bounds
        
        for itemNode in self.itemNodes {
            if itemNode.isExtracted {
                continue
            }
            let itemScale: CGFloat
            let itemFrame = itemNode.frame.offsetBy(dx: -visibleBounds.minX, dy: 0.0)
            if itemFrame.minX < sideInset || itemFrame.maxX > visibleBounds.width - sideInset {
                let edgeDistance: CGFloat
                if itemFrame.minX < sideInset {
                    edgeDistance = sideInset - itemFrame.minX
                } else {
                    edgeDistance = itemFrame.maxX - (visibleBounds.width - sideInset)
                }
                let edgeFactor: CGFloat = min(1.0, edgeDistance / scaleDistance)
                itemScale = edgeFactor * minScale + (1.0 - edgeFactor) * 1.0
            } else {
                itemScale = 1.0
            }
            transition.updateSublayerTransformScale(node: itemNode, scale: itemScale)
        }
    }
    
    private func updateLayout(size: CGSize, insets: UIEdgeInsets, anchorRect: CGRect, transition: ContainedViewLayoutTransition, animateInFromAnchorRect: CGRect?, animateOutToAnchorRect: CGRect?, animateReactionHighlight: Bool = false) {
        self.validLayout = (size, insets, anchorRect)
        
        let sideInset: CGFloat = 14.0
        let itemSpacing: CGFloat = 9.0
        let itemSize: CGFloat = 40.0
        let shadowBlur: CGFloat = 5.0
        let verticalInset: CGFloat = 13.0
        let rowHeight: CGFloat = 30.0
        
        let completeContentWidth = CGFloat(self.items.count) * itemSize + (CGFloat(self.items.count) - 1.0) * itemSpacing + sideInset * 2.0
        let minVisibleItemCount: CGFloat = min(CGFloat(self.items.count), 6.5)
        let visibleContentWidth = floor(minVisibleItemCount * itemSize + (minVisibleItemCount - 1.0) * itemSpacing + sideInset * 2.0)
        
        let contentHeight = verticalInset * 2.0 + rowHeight
        
        let (backgroundFrame, isLeftAligned, cloudSourcePoint) = self.calculateBackgroundFrame(containerSize: size, insets: insets, anchorRect: anchorRect, contentSize: CGSize(width: visibleContentWidth, height: contentHeight))
        self.isLeftAligned = isLeftAligned
        
        transition.updateFrame(node: self.contentContainer, frame: backgroundFrame)
        transition.updateFrame(view: self.contentContainerMask, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        self.scrollNode.view.contentSize = CGSize(width: completeContentWidth, height: backgroundFrame.size.height)
        
        for i in 0 ..< self.items.count {
            let columnIndex = i
            let column = CGFloat(columnIndex)
            
            let itemOffsetY: CGFloat = -1.0
            
            let itemFrame = CGRect(origin: CGPoint(x: sideInset + column * (itemSize + itemSpacing), y: verticalInset + floor((rowHeight - itemSize) / 2.0) + itemOffsetY), size: CGSize(width: itemSize, height: itemSize))
            if !self.itemNodes[i].isExtracted {
                transition.updateFrame(node: self.itemNodes[i], frame: itemFrame, beginWithCurrentState: true)
                self.itemNodes[i].updateLayout(size: CGSize(width: itemSize, height: itemSize), isExpanded: false, transition: transition)
            }
        }
        
        self.updateScrolling(transition: transition)
     
        let isInOverflow = backgroundFrame.maxY > anchorRect.minY
        let backgroundAlpha: CGFloat = isInOverflow ? 1.0 : 0.8
        let shadowAlpha: CGFloat = isInOverflow ? 1.0 : 0.0
        transition.updateAlpha(node: self.backgroundContainerNode, alpha: backgroundAlpha)
        transition.updateAlpha(node: self.backgroundShadowNode, alpha: shadowAlpha)
        transition.updateAlpha(node: self.largeCircleShadowNode, alpha: shadowAlpha)
        transition.updateAlpha(node: self.smallCircleShadowNode, alpha: shadowAlpha)
        
        transition.updateFrame(node: self.backgroundContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
        
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame.insetBy(dx: -shadowBlur, dy: -shadowBlur))
        transition.updateFrame(node: self.backgroundShadowNode, frame: backgroundFrame.insetBy(dx: -shadowBlur, dy: -shadowBlur))
        
        let largeCircleFrame: CGRect
        let smallCircleFrame: CGRect
        if isLeftAligned {
            largeCircleFrame = CGRect(origin: CGPoint(x: cloudSourcePoint - floor(largeCircleSize / 2.0), y: backgroundFrame.maxY - largeCircleSize / 2.0), size: CGSize(width: largeCircleSize, height: largeCircleSize))
            smallCircleFrame = CGRect(origin: CGPoint(x: largeCircleFrame.maxX - 3.0, y: largeCircleFrame.maxY + 2.0), size: CGSize(width: smallCircleSize, height: smallCircleSize))
        } else {
            largeCircleFrame = CGRect(origin: CGPoint(x: cloudSourcePoint - floor(largeCircleSize / 2.0), y: backgroundFrame.maxY - largeCircleSize / 2.0), size: CGSize(width: largeCircleSize, height: largeCircleSize))
            smallCircleFrame = CGRect(origin: CGPoint(x: largeCircleFrame.minX + 3.0 - smallCircleSize, y: largeCircleFrame.maxY + 2.0), size: CGSize(width: smallCircleSize, height: smallCircleSize))
        }
        
        transition.updateFrame(node: self.largeCircleNode, frame: largeCircleFrame.insetBy(dx: -shadowBlur, dy: -shadowBlur))
        transition.updateFrame(node: self.largeCircleShadowNode, frame: largeCircleFrame.insetBy(dx: -shadowBlur, dy: -shadowBlur))
        transition.updateFrame(node: self.smallCircleNode, frame: smallCircleFrame.insetBy(dx: -shadowBlur, dy: -shadowBlur))
        transition.updateFrame(node: self.smallCircleShadowNode, frame: smallCircleFrame.insetBy(dx: -shadowBlur, dy: -shadowBlur))
        
        if let animateInFromAnchorRect = animateInFromAnchorRect {
            let springDuration: Double = 0.42
            let springDamping: CGFloat = 104.0
            let springDelay: Double = 0.22
            
            let sourceBackgroundFrame = self.calculateBackgroundFrame(containerSize: size, insets: insets, anchorRect: animateInFromAnchorRect, contentSize: CGSize(width: backgroundFrame.height, height: contentHeight)).0
            
            self.backgroundNode.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: sourceBackgroundFrame.midX - backgroundFrame.midX, y: 0.0)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: springDuration, delay: springDelay, initialVelocity: 0.0, damping: springDamping, additive: true)
            self.backgroundNode.layer.animateSpring(from: NSValue(cgRect: CGRect(origin: CGPoint(), size: sourceBackgroundFrame.size).insetBy(dx: -shadowBlur, dy: -shadowBlur)), to: NSValue(cgRect: CGRect(origin: CGPoint(), size: backgroundFrame.size).insetBy(dx: -shadowBlur, dy: -shadowBlur)), keyPath: "bounds", duration: springDuration, delay: springDelay, initialVelocity: 0.0, damping: springDamping)
            
            self.contentContainer.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: sourceBackgroundFrame.midX - backgroundFrame.midX, y: 0.0)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: springDuration, delay: springDelay, initialVelocity: 0.0, damping: springDamping, additive: true)
            self.contentContainer.layer.animateSpring(from: NSValue(cgRect: CGRect(origin: CGPoint(), size: sourceBackgroundFrame.size)), to: NSValue(cgRect: CGRect(origin: CGPoint(), size: backgroundFrame.size)), keyPath: "bounds", duration: springDuration, delay: springDelay, initialVelocity: 0.0, damping: springDamping)
            
            //self.contentContainerMask.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: sourceBackgroundFrame.midX - backgroundFrame.midX, y: 0.0)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: springDuration, delay: springDelay, initialVelocity: 0.0, damping: springDamping, additive: true)
            //self.contentContainerMask.layer.animateSpring(from: NSValue(cgRect: CGRect(origin: CGPoint(), size: sourceBackgroundFrame.size)), to: NSValue(cgRect: CGRect(origin: CGPoint(), size: backgroundFrame.size)), keyPath: "bounds", duration: springDuration, delay: springDelay, initialVelocity: 0.0, damping: springDamping)
        } else if let animateOutToAnchorRect = animateOutToAnchorRect {
            let targetBackgroundFrame = self.calculateBackgroundFrame(containerSize: size, insets: insets, anchorRect: animateOutToAnchorRect, contentSize: CGSize(width: visibleContentWidth, height: contentHeight)).0
            
            let offset = CGPoint(x: -(targetBackgroundFrame.minX - backgroundFrame.minX), y: -(targetBackgroundFrame.minY - backgroundFrame.minY))
            self.position = CGPoint(x: self.position.x - offset.x, y: self.position.y - offset.y)
            self.layer.animatePosition(from: offset, to: CGPoint(), duration: 0.2, removeOnCompletion: true, additive: true)
        }
    }
    
    public func animateIn(from sourceAnchorRect: CGRect) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
        
        if let (size, insets, anchorRect) = self.validLayout {
            self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, transition: .immediate, animateInFromAnchorRect: sourceAnchorRect, animateOutToAnchorRect: nil)
        }
        
        let smallCircleDuration: Double = 0.5
        let largeCircleDuration: Double = 0.5
        let largeCircleDelay: Double = 0.08
        let mainCircleDuration: Double = 0.5
        let mainCircleDelay: Double = 0.1
        
        self.smallCircleNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: smallCircleDuration)
        self.smallCircleShadowNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: smallCircleDuration)
        
        self.largeCircleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: largeCircleDelay)
        self.largeCircleNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: largeCircleDuration, delay: largeCircleDelay)
        self.largeCircleShadowNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: largeCircleDuration, delay: largeCircleDelay)
        
        self.backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: mainCircleDelay)
        self.backgroundNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: mainCircleDuration, delay: mainCircleDelay)
        self.backgroundShadowNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: mainCircleDuration, delay: mainCircleDelay)
        
        for i in 0 ..< self.itemNodes.count {
            let itemNode = self.itemNodes[i]
            let itemDelay = mainCircleDelay + 0.1 + Double(i) * 0.03
            itemNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: itemDelay)
            itemNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: mainCircleDuration, delay: itemDelay, initialVelocity: 0.0)
        }
        
        /*if let itemNode = self.itemNodes.first {
            itemNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: mainCircleDelay)
            itemNode.didAppear()
            itemNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: mainCircleDuration, delay: mainCircleDelay, completion: { _ in
            })
        }*/
    }
    
    public func animateOut(to targetAnchorRect: CGRect?, animatingOutToReaction: Bool) {
        self.backgroundNode.layer.animateAlpha(from: self.backgroundNode.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.backgroundShadowNode.layer.animateAlpha(from: self.backgroundShadowNode.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.largeCircleNode.layer.animateAlpha(from: self.largeCircleNode.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.largeCircleShadowNode.layer.animateAlpha(from: self.largeCircleShadowNode.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.smallCircleNode.layer.animateAlpha(from: self.smallCircleNode.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.smallCircleShadowNode.layer.animateAlpha(from: self.smallCircleShadowNode.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
        for itemNode in self.itemNodes {
            if itemNode.isExtracted {
                continue
            }
            itemNode.layer.animateAlpha(from: itemNode.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
        }
        
        if let targetAnchorRect = targetAnchorRect, let (size, insets, anchorRect) = self.validLayout {
            self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, transition: .immediate, animateInFromAnchorRect: nil, animateOutToAnchorRect: targetAnchorRect)
        }
    }
    
    private func generateParabollicMotionKeyframes(from sourcePoint: CGPoint, to targetPosition: CGPoint, elevation: CGFloat) -> [AnyObject] {
        let midPoint = CGPoint(x: (sourcePoint.x + targetPosition.x) / 2.0, y: sourcePoint.y - elevation)
        
        let x1 = sourcePoint.x
        let y1 = sourcePoint.y
        let x2 = midPoint.x
        let y2 = midPoint.y
        let x3 = targetPosition.x
        let y3 = targetPosition.y
        
        var keyframes: [AnyObject] = []
        if abs(y1 - y3) < 5.0 || abs(x1 - x3) < 5.0 {
            for i in 0 ..< 10 {
                let k = CGFloat(i) / CGFloat(10 - 1)
                let x = sourcePoint.x * (1.0 - k) + targetPosition.x * k
                let y = sourcePoint.y * (1.0 - k) + targetPosition.y * k
                keyframes.append(NSValue(cgPoint: CGPoint(x: x, y: y)))
            }
        } else {
            let a = (x3 * (y2 - y1) + x2 * (y1 - y3) + x1 * (y3 - y2)) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
            let b = (x1 * x1 * (y2 - y3) + x3 * x3 * (y1 - y2) + x2 * x2 * (y3 - y1)) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
            let c = (x2 * x2 * (x3 * y1 - x1 * y3) + x2 * (x1 * x1 * y3 - x3 * x3 * y1) + x1 * x3 * (x3 - x1) * y2) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
            
            for i in 0 ..< 10 {
                let k = CGFloat(i) / CGFloat(10 - 1)
                let x = sourcePoint.x * (1.0 - k) + targetPosition.x * k
                let y = a * x * x + b * x + c
                keyframes.append(NSValue(cgPoint: CGPoint(x: x, y: y)))
            }
        }
        
        return keyframes
    }
    
    private func animateFromItemNodeToReaction(itemNode: ReactionNode, targetFilledNode: ASDisplayNode, targetSnapshotView: UIView, hideNode: Bool, completion: @escaping () -> Void) {
        let itemFrame: CGRect = itemNode.frame
        let _ = itemFrame
        
        let targetFrame = self.view.convert(targetFilledNode.view.convert(targetFilledNode.bounds, to: nil), from: nil)
        
        targetSnapshotView.frame = targetFrame
        self.view.insertSubview(targetSnapshotView, belowSubview: itemNode.view)
        
        var completedTarget = false
        var targetScaleCompleted = false
        let intermediateCompletion: () -> Void = {
            if completedTarget && targetScaleCompleted {
                completion()
            }
        }
        
        let targetPosition = targetFrame.center
        let _ = targetPosition
        let duration: Double = 0.16
        
        itemNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.9, removeOnCompletion: false)
        targetSnapshotView.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.8)
        targetSnapshotView.layer.animateScale(from: itemNode.bounds.width / targetSnapshotView.bounds.width, to: 0.5, duration: duration, removeOnCompletion: false, completion: { [weak self, weak targetSnapshotView] _ in
            if let strongSelf = self {
                strongSelf.hapticFeedback.tap()
            }
            completedTarget = true
            intermediateCompletion()
            
            if hideNode {
                targetFilledNode.isHidden = false
                targetFilledNode.layer.animateSpring(from: 0.5 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: duration, initialVelocity: 0.0, damping: 90.0, completion: { _ in
                    targetSnapshotView?.isHidden = true
                    targetScaleCompleted = true
                    intermediateCompletion()
                })
            } else {
                targetSnapshotView?.isHidden = true
                targetScaleCompleted = true
                intermediateCompletion()
            }
        })
        
        //let keyframes = self.generateParabollicMotionKeyframes(from: targetPosition, to: targetPosition, elevation: 30.0)
        
        /*itemNode.layer.animateKeyframes(values: keyframes, duration: duration, keyPath: "position", removeOnCompletion: false, completion: { _ in
        })
        targetSnapshotView.layer.animateKeyframes(values: keyframes, duration: duration, keyPath: "position", removeOnCompletion: false)*/
        
        itemNode.layer.animateScale(from: 1.0, to: (targetSnapshotView.bounds.width * 0.5) / itemNode.bounds.width, duration: duration, removeOnCompletion: false)
    }
    
    public func willAnimateOutToReaction(value: String) {
        for itemNode in self.itemNodes {
            if itemNode.item.reaction.rawValue != value {
                continue
            }
            itemNode.isExtracted = true
        }
    }
    
    public func animateOutToReaction(value: String, targetEmptyNode: ASDisplayNode, targetFilledNode: ASDisplayNode, hideNode: Bool, completion: @escaping () -> Void) {
        for itemNode in self.itemNodes {
            if itemNode.item.reaction.rawValue != value {
                continue
            }
            if let targetSnapshotView = targetFilledNode.view.snapshotContentTree() {
                if hideNode {
                    targetFilledNode.isHidden = true
                }
                
                itemNode.isExtracted = true
                let selfSourceRect = itemNode.view.convert(itemNode.view.bounds, to: self.view)
                let selfTargetRect = self.view.convert(targetFilledNode.bounds, from: targetFilledNode.view)
                
                let expandedScale: CGFloat = 3.0
                let expandedSize = CGSize(width: floor(selfSourceRect.width * expandedScale), height: floor(selfSourceRect.height * expandedScale))
                
                let expandedFrame = CGRect(origin: CGPoint(x: floor(selfTargetRect.midX - expandedSize.width / 2.0), y: floor(selfTargetRect.midY - expandedSize.height / 2.0)), size: expandedSize)
                
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.3, curve: .linear)
                
                self.addSubnode(itemNode)
                itemNode.frame = selfSourceRect
                itemNode.position = expandedFrame.center
                transition.updateBounds(node: itemNode, bounds: CGRect(origin: CGPoint(), size: expandedFrame.size))
                itemNode.updateLayout(size: expandedFrame.size, isExpanded: true, transition: transition)
                transition.animatePositionWithKeyframes(node: itemNode, keyframes: self.generateParabollicMotionKeyframes(from: selfSourceRect.center, to: expandedFrame.center, elevation: 30.0))
                
                let additionalAnimationNode = AnimatedStickerNode()
                let incomingMessage: Bool = self.isLeftAligned
                let animationFrame = expandedFrame.insetBy(dx: -expandedFrame.width * 0.5, dy: -expandedFrame.height * 0.5)
                    .offsetBy(dx: incomingMessage ? (expandedFrame.width - 50.0) : (-expandedFrame.width + 50.0), dy: 0.0)
                //animationFrame = animationFrame.offsetBy(dx: CGFloat.random(in: -30.0 ... 30.0), dy: CGFloat.random(in: -30.0 ... 30.0))
                additionalAnimationNode.setup(source: AnimatedStickerResourceSource(account: itemNode.context.account, resource: itemNode.item.applicationAnimation.resource), width: Int(animationFrame.width * 2.0), height: Int(animationFrame.height * 2.0), playbackMode: .once, mode: .direct(cachePathPrefix: nil))
                additionalAnimationNode.frame = animationFrame
                if incomingMessage {
                    additionalAnimationNode.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
                }
                additionalAnimationNode.updateLayout(size: animationFrame.size)
                self.addSubnode(additionalAnimationNode)
                
                var mainAnimationCompleted = false
                var additionalAnimationCompleted = false
                let intermediateCompletion: () -> Void = {
                    if mainAnimationCompleted && additionalAnimationCompleted {
                        completion()
                    }
                }
                
                additionalAnimationNode.completed = { _ in
                    additionalAnimationCompleted = true
                    intermediateCompletion()
                }
                
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1 * UIView.animationDurationFactor(), execute: {
                    additionalAnimationNode.visibility = true
                })
                
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2.0 * UIView.animationDurationFactor(), execute: {
                    self.animateFromItemNodeToReaction(itemNode: itemNode, targetFilledNode: targetFilledNode, targetSnapshotView: targetSnapshotView, hideNode: hideNode, completion: {
                        mainAnimationCompleted = true
                        intermediateCompletion()
                    })
                })
                return
            }
        }
        completion()
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let contentPoint = self.contentContainer.view.convert(point, from: self.view)
        if self.contentContainer.bounds.contains(contentPoint) {
            return self.contentContainer.hitTest(contentPoint, with: event)
        }
        /*for itemNode in self.itemNodes {
            if !itemNode.alpha.isZero && itemNode.frame.contains(contentPoint) {
                return self.view
            }
        }*/
        return nil
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            let point = recognizer.location(in: self.view)
            if let reaction = self.reaction(at: point) {
                self.reactionSelected?(reaction)
            }
        }
    }
    
    public func reaction(at point: CGPoint) -> ReactionContextItem? {
        for i in 0 ..< 2 {
            let touchInset: CGFloat = i == 0 ? 0.0 : 8.0
            for itemNode in self.itemNodes {
                let itemPoint = self.view.convert(point, to: itemNode.view)
                if itemNode.bounds.insetBy(dx: -touchInset, dy: -touchInset).contains(itemPoint) {
                    return itemNode.item
                }
            }
        }
        return nil
    }
    
    public func setHighlightedReaction(_ value: ReactionContextItem.Reaction?) {
        self.highlightedReaction = value
        if let (size, insets, anchorRect) = self.validLayout {
            self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, transition: .animated(duration: 0.18, curve: .easeInOut), animateInFromAnchorRect: nil, animateOutToAnchorRect: nil, animateReactionHighlight: true)
        }
    }
    
    @objc private func disclosurePressed() {
        self.isExpanded = true
        if let (size, insets, anchorRect) = self.validLayout {
            self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, transition: .animated(duration: 0.3, curve: .spring), animateInFromAnchorRect: nil, animateOutToAnchorRect: nil, animateReactionHighlight: true)
        }
    }
}

