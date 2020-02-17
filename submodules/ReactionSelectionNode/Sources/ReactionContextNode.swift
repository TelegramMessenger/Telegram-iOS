import Foundation
import AsyncDisplayKit
import Display
import AnimatedStickerNode
import TelegramCore
import SyncCore
import TelegramPresentationData

public final class ReactionContextItem {
    public let value: String
    public let text: String
    public let path: String
    
    public init(value: String, text: String, path: String) {
        self.value = value
        self.text = text
        self.path = path
    }
}

private let largeCircleSize: CGFloat = 16.0
private let smallCircleSize: CGFloat = 8.0

private func generateBackgroundImage(foreground: UIColor, diameter: CGFloat, shadowBlur: CGFloat) -> UIImage? {
    return generateImage(CGSize(width: diameter * 2.0 + shadowBlur * 2.0, height: diameter + shadowBlur * 2.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setBlendMode(.copy)
        context.setFillColor(foreground.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
        context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur + diameter, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
        context.fill(CGRect(origin: CGPoint(x: shadowBlur + diameter / 2.0, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
    })?.stretchableImage(withLeftCapWidth: Int(diameter + shadowBlur / 2.0), topCapHeight: Int(diameter / 2.0 + shadowBlur / 2.0))
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

public final class ReactionContextNode: ASDisplayNode {
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
    private var itemNodes: [ReactionNode] = []
    private let disclosureButton: HighlightTrackingButtonNode
    
    private var isExpanded: Bool = false
    private var highlightedReaction: String?
    private var validLayout: (CGSize, UIEdgeInsets, CGRect)?
    
    public var reactionSelected: ((ReactionGestureItem) -> Void)?
    
    private let hapticFeedback = HapticFeedback()
    
    public init(account: Account, theme: PresentationTheme, items: [ReactionContextItem]) {
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
        
        self.contentContainer = ASDisplayNode()
        self.contentContainer.clipsToBounds = true
        
        self.disclosureButton = HighlightTrackingButtonNode()
        self.disclosureButton.hitTestSlop = UIEdgeInsets(top: -6.0, left: -6.0, bottom: -6.0, right: -6.0)
        let buttonImage = generateImage(CGSize(width: 30.0, height: 30.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(theme.contextMenu.dimColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
            context.setBlendMode(.copy)
            context.setStrokeColor(UIColor.clear.cgColor)
            context.setLineWidth(2.0)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.beginPath()
            context.move(to: CGPoint(x: 8.0, y: size.height / 2.0 + 3.0))
            context.addLine(to: CGPoint(x: size.width / 2.0, y: 11.0))
            context.addLine(to: CGPoint(x: size.width - 8.0, y: size.height / 2.0 + 3.0))
            context.strokePath()
        })
        self.disclosureButton.setImage(buttonImage, for: [])
        
        super.init()
        
        self.addSubnode(self.smallCircleShadowNode)
        self.addSubnode(self.largeCircleShadowNode)
        self.addSubnode(self.backgroundShadowNode)
        
        self.backgroundContainerNode.addSubnode(self.smallCircleNode)
        self.backgroundContainerNode.addSubnode(self.largeCircleNode)
        self.backgroundContainerNode.addSubnode(self.backgroundNode)
        self.addSubnode(self.backgroundContainerNode)
        
        self.contentContainer.addSubnode(self.disclosureButton)
        
        self.itemNodes = self.items.map { item in
            return ReactionNode(account: account, theme: theme, reaction: .reaction(value: item.value, text: item.text, path: item.path), maximizedReactionSize: 30.0 - 18.0, loadFirstFrame: true)
        }
        self.itemNodes.forEach(self.contentContainer.addSubnode)
        
        self.addSubnode(self.contentContainer)
        
        self.disclosureButton.addTarget(self, action: #selector(self.disclosurePressed), forControlEvents: .touchUpInside)
        self.disclosureButton.highligthedChanged = { [weak self] highlighted in
            if highlighted {
                self?.disclosureButton.layer.animateScale(from: 1.0, to: 0.8, duration: 0.15, removeOnCompletion: false)
            } else {
                self?.disclosureButton.layer.animateScale(from: 0.8, to: 1.0, duration: 0.25)
            }
        }
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    public func updateLayout(size: CGSize, insets: UIEdgeInsets, anchorRect: CGRect, transition: ContainedViewLayoutTransition) {
        self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, transition: transition, animateInFromAnchorRect: nil, animateOutToAnchorRect: nil)
    }
    
    private func calculateBackgroundFrame(containerSize: CGSize, insets: UIEdgeInsets, anchorRect: CGRect, contentSize: CGSize) -> (CGRect, Bool) {
        let sideInset: CGFloat = 12.0
        let backgroundOffset: CGPoint = CGPoint(x: 22.0, y: -7.0)
        
        var rect: CGRect
        let isLeftAligned: Bool
        if anchorRect.maxX < containerSize.width - backgroundOffset.x - sideInset {
            rect = CGRect(origin: CGPoint(x: anchorRect.maxX - contentSize.width + backgroundOffset.x, y: anchorRect.minY - contentSize.height + backgroundOffset.y), size: contentSize)
            isLeftAligned = true
        } else {
            rect = CGRect(origin: CGPoint(x: anchorRect.minX - backgroundOffset.x, y: anchorRect.minY - contentSize.height + backgroundOffset.y), size: contentSize)
            isLeftAligned = false
        }
        rect.origin.x = max(sideInset, rect.origin.x)
        rect.origin.y = max(insets.top + sideInset, rect.origin.y)
        rect.origin.x = min(containerSize.width - contentSize.width - sideInset, rect.origin.x)
        return (rect, isLeftAligned)
    }
    
    private func updateLayout(size: CGSize, insets: UIEdgeInsets, anchorRect: CGRect, transition: ContainedViewLayoutTransition, animateInFromAnchorRect: CGRect?, animateOutToAnchorRect: CGRect?, animateReactionHighlight: Bool = false) {
        self.validLayout = (size, insets, anchorRect)
        
        let sideInset: CGFloat = 10.0
        let itemSpacing: CGFloat = 6.0
        let minimizedItemSize: CGFloat = 30.0
        let maximizedItemSize: CGFloat = 30.0 - 18.0
        let shadowBlur: CGFloat = 5.0
        let verticalInset: CGFloat = 11.0
        let rowHeight: CGFloat = 30.0
        let rowSpacing: CGFloat = itemSpacing
        
        let columnCount = min(6, self.items.count)
        let contentWidth = CGFloat(columnCount) * minimizedItemSize + (CGFloat(columnCount) - 1.0) * itemSpacing + sideInset * 2.0
        let rowCount = self.items.count / columnCount + (self.items.count % columnCount == 0 ? 0 : 1)
        
        let expandedRowCount = self.isExpanded ? rowCount : 1
        
        let contentHeight = verticalInset * 2.0 + rowHeight * CGFloat(expandedRowCount) + CGFloat(expandedRowCount - 1) * rowSpacing
        
        let (backgroundFrame, isLeftAligned) = self.calculateBackgroundFrame(containerSize: size, insets: insets, anchorRect: anchorRect, contentSize: CGSize(width: contentWidth, height: contentHeight))
        
        transition.updateFrame(node: self.contentContainer, frame: backgroundFrame)
        
        for i in 0 ..< self.items.count {
            let rowIndex = i / columnCount
            let columnIndex = i % columnCount
            let row = CGFloat(rowIndex)
            let column = CGFloat(columnIndex)
            
            var reactionValue: String?
            switch self.itemNodes[i].reaction {
            case let .reaction(value, _, _):
                reactionValue = value
            default:
                break
            }
            
            let isHighlighted = reactionValue != nil && self.highlightedReaction == reactionValue
            
            var itemSize: CGFloat = minimizedItemSize
            var itemOffset: CGFloat = 0.0
            if isHighlighted {
                let updatedSize = itemSize * 1.15
                itemOffset = (updatedSize - itemSize) / 2.0
                itemSize = updatedSize
            }
            
            let itemFrame = CGRect(origin: CGPoint(x: sideInset + column * (minimizedItemSize + itemSpacing) - itemOffset, y: verticalInset + row * (rowHeight + rowSpacing) + floor((rowHeight - minimizedItemSize) / 2.0) - itemOffset), size: CGSize(width: itemSize, height: itemSize))
            transition.updateFrame(node: self.itemNodes[i], frame: itemFrame, beginWithCurrentState: true)
            self.itemNodes[i].updateLayout(size: CGSize(width: itemSize, height: itemSize), scale: itemSize / (maximizedItemSize + 18.0), transition: transition, displayText: false)
            self.itemNodes[i].updateIsAnimating(false, animated: false)
            if rowIndex != 0 || columnIndex == columnCount - 1 {
                if self.isExpanded {
                    if self.itemNodes[i].alpha.isZero {
                        self.itemNodes[i].alpha = 1.0
                        if transition.isAnimated {
                            let delayOffset: Double = 1.0 - Double(columnIndex) / Double(columnCount - 1)
                            self.itemNodes[i].layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4 + delayOffset * 0.32, initialVelocity: 0.0, damping: 95.0)
                            self.itemNodes[i].layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.05)
                        }
                    }
                } else {
                    self.itemNodes[i].alpha = 0.0
                }
            } else {
                self.itemNodes[i].alpha = 1.0
            }
            
            if rowIndex == 0 && columnIndex == columnCount - 1 {
                transition.updateFrame(node: self.disclosureButton, frame: itemFrame)
                if self.isExpanded {
                    if self.disclosureButton.alpha.isEqual(to: 1.0) {
                        self.disclosureButton.alpha = 0.0
                        if transition.isAnimated {
                            self.disclosureButton.layer.animateScale(from: 0.8, to: 0.1, duration: 0.2, removeOnCompletion: false)
                            self.disclosureButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak self] _ in
                                self?.disclosureButton.layer.removeAnimation(forKey: "scale")
                            })
                        }
                    }
                } else {
                    self.disclosureButton.alpha = 1.0
                }
            }
        }
     
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
            largeCircleFrame = CGRect(origin: CGPoint(x: anchorRect.maxX + 16.0 - rowHeight + floor((rowHeight - largeCircleSize) / 2.0), y: backgroundFrame.maxY - largeCircleSize / 2.0), size: CGSize(width: largeCircleSize, height: largeCircleSize))
            smallCircleFrame = CGRect(origin: CGPoint(x: largeCircleFrame.maxX - 3.0, y: largeCircleFrame.maxY + 2.0), size: CGSize(width: smallCircleSize, height: smallCircleSize))
        } else {
            largeCircleFrame = CGRect(origin: CGPoint(x: anchorRect.minX - 18.0 + floor((rowHeight - largeCircleSize) / 2.0), y: backgroundFrame.maxY - largeCircleSize / 2.0), size: CGSize(width: largeCircleSize, height: largeCircleSize))
            smallCircleFrame = CGRect(origin: CGPoint(x: largeCircleFrame.minX + 3.0 - smallCircleSize, y: largeCircleFrame.maxY + 2.0), size: CGSize(width: smallCircleSize, height: smallCircleSize))
        }
        
        transition.updateFrame(node: self.largeCircleNode, frame: largeCircleFrame.insetBy(dx: -shadowBlur, dy: -shadowBlur))
        transition.updateFrame(node: self.largeCircleShadowNode, frame: largeCircleFrame.insetBy(dx: -shadowBlur, dy: -shadowBlur))
        transition.updateFrame(node: self.smallCircleNode, frame: smallCircleFrame.insetBy(dx: -shadowBlur, dy: -shadowBlur))
        transition.updateFrame(node: self.smallCircleShadowNode, frame: smallCircleFrame.insetBy(dx: -shadowBlur, dy: -shadowBlur))
        
        if let animateInFromAnchorRect = animateInFromAnchorRect {
            let springDuration: Double = 0.42
            let springDamping: CGFloat = 104.0
            
            let sourceBackgroundFrame = self.calculateBackgroundFrame(containerSize: size, insets: insets, anchorRect: animateInFromAnchorRect, contentSize: CGSize(width: contentWidth, height: contentHeight)).0
            
            self.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: sourceBackgroundFrame.minX - backgroundFrame.minX, y: sourceBackgroundFrame.minY - backgroundFrame.minY)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: springDuration, initialVelocity: 0.0, damping: springDamping, additive: true)
        } else if let animateOutToAnchorRect = animateOutToAnchorRect {
            let targetBackgroundFrame = self.calculateBackgroundFrame(containerSize: size, insets: insets, anchorRect: animateOutToAnchorRect, contentSize: CGSize(width: contentWidth, height: contentHeight)).0
            
            self.layer.animatePosition(from: CGPoint(), to: CGPoint(x: targetBackgroundFrame.minX - backgroundFrame.minX, y: targetBackgroundFrame.minY - backgroundFrame.minY), duration: 0.2, removeOnCompletion: false, additive: true)
        }
    }
    
    public func animateIn(from sourceAnchorRect: CGRect) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        
        if let (size, insets, anchorRect) = self.validLayout {
            self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, transition: .immediate, animateInFromAnchorRect: sourceAnchorRect, animateOutToAnchorRect: nil)
        }
    }
    
    public func animateOut(to targetAnchorRect: CGRect?, animatingOutToReaction: Bool) {
        self.backgroundNode.layer.animateAlpha(from: self.backgroundNode.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.backgroundShadowNode.layer.animateAlpha(from: self.backgroundShadowNode.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.largeCircleNode.layer.animateAlpha(from: self.largeCircleNode.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.largeCircleShadowNode.layer.animateAlpha(from: self.largeCircleShadowNode.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.smallCircleNode.layer.animateAlpha(from: self.smallCircleNode.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.smallCircleShadowNode.layer.animateAlpha(from: self.smallCircleShadowNode.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
        for itemNode in self.itemNodes {
            itemNode.layer.animateAlpha(from: itemNode.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
        }
        self.disclosureButton.layer.animateAlpha(from: self.disclosureButton.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
        
        if let targetAnchorRect = targetAnchorRect, let (size, insets, anchorRect) = self.validLayout {
            self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, transition: .immediate, animateInFromAnchorRect: nil, animateOutToAnchorRect: targetAnchorRect)
        }
    }
    
    public func animateOutToReaction(value: String, targetNode: ASDisplayNode, hideNode: Bool, completion: @escaping () -> Void) {
        for itemNode in self.itemNodes {
            switch itemNode.reaction {
            case let .reaction(itemValue, _, _):
                if itemValue == value {
                    if let snapshotView = itemNode.view.snapshotContentTree(keepTransform: true), let targetSnapshotView = targetNode.view.snapshotContentTree() {
                        targetSnapshotView.frame = self.view.convert(targetNode.bounds, from: targetNode.view)
                        itemNode.isHidden = true
                        self.view.addSubview(targetSnapshotView)
                        self.view.addSubview(snapshotView)
                        
                        var completedTarget = false
                        let intermediateCompletion: () -> Void = {
                            if completedTarget {
                                completion()
                            }
                        }
                        
                        let targetPosition = self.view.convert(targetNode.bounds.center, from: targetNode.view)
                        let duration: Double = 0.3
                        if hideNode {
                            targetNode.isHidden = true
                        }
                        
                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
                        targetSnapshotView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        targetSnapshotView.layer.animateScale(from: snapshotView.bounds.width / targetSnapshotView.bounds.width, to: 0.5, duration: 0.3, removeOnCompletion: false)
                        
                        let sourcePoint = snapshotView.center
                        let midPoint = CGPoint(x: (sourcePoint.x + targetPosition.x) / 2.0, y: sourcePoint.y - 30.0)
                        
                        let x1 = sourcePoint.x
                        let y1 = sourcePoint.y
                        let x2 = midPoint.x
                        let y2 = midPoint.y
                        let x3 = targetPosition.x
                        let y3 = targetPosition.y
                        
                        let a = (x3 * (y2 - y1) + x2 * (y1 - y3) + x1 * (y3 - y2)) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
                        let b = (x1 * x1 * (y2 - y3) + x3 * x3 * (y1 - y2) + x2 * x2 * (y3 - y1)) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
                        let c = (x2 * x2 * (x3 * y1 - x1 * y3) + x2 * (x1 * x1 * y3 - x3 * x3 * y1) + x1 * x3 * (x3 - x1) * y2) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
                        
                        var keyframes: [AnyObject] = []
                        for i in 0 ..< 10 {
                            let k = CGFloat(i) / CGFloat(10 - 1)
                            let x = sourcePoint.x * (1.0 - k) + targetPosition.x * k
                            let y = a * x * x + b * x + c
                            keyframes.append(NSValue(cgPoint: CGPoint(x: x, y: y)))
                        }
                        
                        snapshotView.layer.animateKeyframes(values: keyframes, duration: 0.3, keyPath: "position", removeOnCompletion: false, completion: { [weak self] _ in
                            if let strongSelf = self {
                                strongSelf.hapticFeedback.tap()
                            }
                            completedTarget = true
                            if hideNode {
                                targetNode.isHidden = false
                                targetNode.layer.animateSpring(from: 0.5 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: duration, initialVelocity: 0.0, damping: 90.0)
                            }
                            intermediateCompletion()
                        })
                        targetSnapshotView.layer.animateKeyframes(values: keyframes, duration: 0.3, keyPath: "position", removeOnCompletion: false)
                        
                        snapshotView.layer.animateScale(from: 1.0, to: (targetSnapshotView.bounds.width * 0.5) / snapshotView.bounds.width, duration: 0.3, removeOnCompletion: false)
                    } else {
                        completion()
                    }
                    return
                }
            default:
                break
            }
        }
        completion()
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let contentPoint = self.contentContainer.view.convert(point, from: self.view)
        if !self.disclosureButton.alpha.isZero {
            if let result = self.disclosureButton.hitTest(self.disclosureButton.view.convert(point, from: self.view), with: event) {
                return result
            }
        }
        for itemNode in self.itemNodes {
            if !itemNode.alpha.isZero && itemNode.frame.contains(contentPoint) {
                return self.view
            }
        }
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
    
    public func reaction(at point: CGPoint) -> ReactionGestureItem? {
        let contentPoint = self.contentContainer.view.convert(point, from: self.view)
        for itemNode in self.itemNodes {
            if !itemNode.alpha.isZero && itemNode.frame.contains(contentPoint) {
                return itemNode.reaction
            }
        }
        for itemNode in self.itemNodes {
            if !itemNode.alpha.isZero && itemNode.frame.insetBy(dx: -8.0, dy: -8.0).contains(contentPoint) {
                return itemNode.reaction
            }
        }
        return nil
    }
    
    public func setHighlightedReaction(_ value: String?) {
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
