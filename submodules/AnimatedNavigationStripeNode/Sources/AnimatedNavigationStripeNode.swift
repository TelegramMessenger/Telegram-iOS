import Foundation
import UIKit
import Display
import AsyncDisplayKit

public final class AnimatedNavigationStripeNode: ASDisplayNode {
    public struct Colors: Equatable {
        public var foreground: UIColor
        public var background: UIColor
        public var clearBackground: UIColor
        
        public init(
            foreground: UIColor,
            background: UIColor,
            clearBackground: UIColor
        ) {
            self.foreground = foreground
            self.background = background
            self.clearBackground = clearBackground
        }
        
        public static func ==(lhs: Colors, rhs: Colors) -> Bool {
            if !lhs.foreground.isEqual(rhs.foreground) {
                return false
            }
            if !lhs.background.isEqual(rhs.background) {
                return false
            }
            if !lhs.clearBackground.isEqual(rhs.clearBackground) {
                return false
            }
            return true
        }
    }
    
    public struct Configuration: Equatable {
        public var height: CGFloat
        public var index: Int
        public var count: Int
        
        public init(height: CGFloat, index: Int, count: Int) {
            self.height = height
            self.index = index
            self.count = count
        }
    }
    
    private final class BackgroundLineNode {
        let lineNode: ASImageNode
        let overlayNode: ASImageNode
        
        init() {
            self.lineNode = ASImageNode()
            self.overlayNode = ASImageNode()
        }
    }
    
    private var currentColors: Colors?
    private var currentConfiguration: Configuration?
    
    private let foregroundLineNode: ASImageNode
    private var backgroundLineNodes: [Int: BackgroundLineNode] = [:]
    private var removingBackgroundLineNodes: [BackgroundLineNode] = []

    private let maskContainerNode: ASDisplayNode
    private let topShadowNode: ASImageNode
    private let bottomShadowNode: ASImageNode
    private let middleShadowNode: ASDisplayNode
    
    private var currentForegroundImage: UIImage?
    private var currentBackgroundImage: UIImage?
    private var currentClearBackgroundImage: UIImage?
    
    override public init() {
        self.maskContainerNode = ASDisplayNode()

        self.foregroundLineNode = ASImageNode()
        self.topShadowNode = ASImageNode()
        self.bottomShadowNode = ASImageNode()
        self.middleShadowNode = ASDisplayNode()
        self.middleShadowNode.backgroundColor = .white
        
        super.init()
        
        self.clipsToBounds = true

        self.addSubnode(self.maskContainerNode)
        self.addSubnode(self.foregroundLineNode)
        self.maskContainerNode.addSubnode(self.topShadowNode)
        self.maskContainerNode.addSubnode(self.bottomShadowNode)
        self.maskContainerNode.addSubnode(self.middleShadowNode)
        self.layer.mask = self.maskContainerNode.layer
    }
    
    public func update(colors: Colors, configuration: Configuration, transition: ContainedViewLayoutTransition) {
        var transition = transition
        
        let segmentSpacing: CGFloat = 2.0
        
        if self.currentColors != colors {
            self.currentColors = colors
            self.currentForegroundImage = generateFilledCircleImage(diameter: 2.0, color: colors.foreground)?.resizableImage(withCapInsets: UIEdgeInsets(top: 1.0, left: 0.0, bottom: 1.0, right: 0.0), resizingMode: .stretch)
            self.currentBackgroundImage = generateFilledCircleImage(diameter: 2.0, color: colors.background)?.resizableImage(withCapInsets: UIEdgeInsets(top: 1.0, left: 0.0, bottom: 1.0, right: 0.0), resizingMode: .stretch)
            self.currentClearBackgroundImage = generateImage(CGSize(width: 2.0, height: 4.0 + segmentSpacing * 2.0 + 1.0 * 2.0), contextGenerator: { size, context in
                context.setFillColor(colors.clearBackground.cgColor)
                context.fill(CGRect(origin: CGPoint(), size: size))
                
                context.setFillColor(UIColor.clear.cgColor)
                context.setBlendMode(.copy)
                
                let ellipseFudge: CGFloat = 0.02
                
                let topEllipse = CGRect(origin: CGPoint(x: -ellipseFudge, y: 1.0 + segmentSpacing), size: CGSize(width: 2.0 + ellipseFudge * 2.0, height: 2.0))
                let bottomEllipse = CGRect(origin: CGPoint(x: -ellipseFudge, y: size.height - (1.0 + segmentSpacing) - 2.0), size: CGSize(width: 2.0 + ellipseFudge * 2.0, height: 2.0))
                
                context.fillEllipse(in: topEllipse)
                context.fillEllipse(in: bottomEllipse)
                
                context.fill(CGRect(origin: CGPoint(x: 0.0, y: topEllipse.midY), size: CGSize(width: 2.0, height: bottomEllipse.midY - topEllipse.midY)))
                
                context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: -1.0), size: CGSize(width: 2.0, height: 2.0)))
                context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: size.height - 1.0), size: CGSize(width: 2.0, height: 2.0)))
            })?.resizableImage(withCapInsets: UIEdgeInsets(top: 1.0 + segmentSpacing + 2.0, left: 1.0, bottom: 1.0 + segmentSpacing + 2.0, right: 1.0), resizingMode: .stretch)
            
            self.foregroundLineNode.image = self.currentForegroundImage
            for (_, itemNode) in self.backgroundLineNodes {
                itemNode.lineNode.image = self.currentBackgroundImage
                itemNode.overlayNode.image = self.currentClearBackgroundImage
            }
            
            self.topShadowNode.image = generateImage(CGSize(width: 2.0, height: 7.0), contextGenerator: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                
                var locations: [CGFloat] = [1.0, 0.0]
                let colors: [CGColor] = [UIColor.white.withAlphaComponent(0.0).cgColor, UIColor.white.cgColor]
                
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
                
                context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
            })
            
            self.bottomShadowNode.image = generateImage(CGSize(width: 2.0, height: 7.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                
                var locations: [CGFloat] = [1.0, 0.0]
                let colors: [CGColor] = [UIColor.white.withAlphaComponent(0.0).cgColor, UIColor.white.cgColor]
                
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
                
                context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
            })
        }
        
        if self.currentConfiguration == nil {
            transition = .immediate
        }
        
        if self.currentConfiguration != configuration {
            var isCycledJump = false
            if let currentConfiguration = self.currentConfiguration, currentConfiguration.count == configuration.count, currentConfiguration.index == 0, currentConfiguration.count > 4, configuration.index == configuration.count - 1 {
                isCycledJump = true
            }
            
            self.currentConfiguration = configuration
            
            let defaultVerticalInset: CGFloat = 7.0
            let minSegmentHeight: CGFloat = 8.0
            
            transition.updateFrame(node: self.topShadowNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: 2.0, height: defaultVerticalInset)))
            transition.updateFrame(node: self.bottomShadowNode, frame: CGRect(origin: CGPoint(x: 0.0, y: configuration.height - defaultVerticalInset), size: CGSize(width: 2.0, height: defaultVerticalInset)))
            transition.updateFrame(node: self.middleShadowNode, frame: CGRect(origin: CGPoint(x: 0.0, y: defaultVerticalInset), size: CGSize(width: 2.0, height: configuration.height - defaultVerticalInset * 2.0)))
            transition.updateFrame(node: self.maskContainerNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: 2.0, height: configuration.height)))
            
            let availableVerticalHeight: CGFloat = configuration.height - defaultVerticalInset * 2.0
            
            let proposedSegmentHeight: CGFloat = (availableVerticalHeight - segmentSpacing * CGFloat(configuration.count) + segmentSpacing) / CGFloat(configuration.count)
            let segmentHeight = max(proposedSegmentHeight, minSegmentHeight)
            
            let allItemsHeight = CGFloat(configuration.count) * segmentHeight + max(0.0, CGFloat(configuration.count - 1)) * segmentSpacing
            
            var verticalInset = defaultVerticalInset
            if allItemsHeight > availableVerticalHeight && allItemsHeight - 2.0 <= availableVerticalHeight {
                verticalInset -= 2.0
            }
            
            let topItemsHeight = CGFloat(configuration.index) * (segmentHeight + segmentSpacing)
            let bottomItemsHeight = allItemsHeight - topItemsHeight - segmentHeight
            
            var itemScreenOffset = floorToScreenPixels((configuration.height - segmentHeight) / 2.0)
            
            if itemScreenOffset - topItemsHeight > verticalInset {
                itemScreenOffset = topItemsHeight + verticalInset
            }
            if itemScreenOffset + segmentHeight + bottomItemsHeight < configuration.height - verticalInset {
                itemScreenOffset = configuration.height - verticalInset - (segmentHeight + bottomItemsHeight)
            }
            
            var backgroundItemNodesToOffset: [BackgroundLineNode] = []
            var resolvedOffset: CGFloat = 0.0
            
            func updateBackgroundLine(index: Int) -> Bool {
                let indexDifference = index - configuration.index
                let offsetDistance = CGFloat(indexDifference) * (segmentHeight + segmentSpacing)
                
                let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: itemScreenOffset + offsetDistance), size: CGSize(width: 2.0, height: segmentHeight))
                
                if itemFrame.maxY <= 0.0 || itemFrame.minY > configuration.height {
                    return false
                }
                
                var itemNodeTransition = transition
                let itemNode: BackgroundLineNode
                if let current = self.backgroundLineNodes[index] {
                    itemNode = current
                    let offset = itemFrame.minY - itemNode.lineNode.frame.minY
                    if abs(offset) > abs(resolvedOffset) {
                        resolvedOffset = offset
                    }
                } else {
                    itemNodeTransition = .immediate
                    itemNode = BackgroundLineNode()
                    itemNode.lineNode.image = self.currentBackgroundImage
                    itemNode.overlayNode.image = self.currentClearBackgroundImage
                    self.backgroundLineNodes[index] = itemNode
                    self.insertSubnode(itemNode.lineNode, belowSubnode: self.foregroundLineNode)
                    self.topShadowNode.supernode?.insertSubnode(itemNode.overlayNode, belowSubnode: self.topShadowNode)
                    backgroundItemNodesToOffset.append(itemNode)
                }
                itemNodeTransition.updateFrame(node: itemNode.lineNode, frame: itemFrame, beginWithCurrentState: true)
                itemNodeTransition.updateFrame(node: itemNode.overlayNode, frame: itemFrame.insetBy(dx: 0.0, dy: -(1.0 + segmentSpacing)), beginWithCurrentState: true)
                
                return true
            }
            
            var validIndices = Set<Int>()
            if configuration.index >= 0 {
                for i in (0 ... configuration.index).reversed() {
                    if updateBackgroundLine(index: i) {
                        validIndices.insert(i)
                    } else {
                        break
                    }
                }
            }
            if configuration.index < configuration.count {
                for i in configuration.index + 1 ..< configuration.count {
                    if updateBackgroundLine(index: i) {
                        validIndices.insert(i)
                    } else {
                        break
                    }
                }
            }
            
            if !resolvedOffset.isZero {
                for itemNode in backgroundItemNodesToOffset {
                    transition.animatePositionAdditive(node: itemNode.lineNode, offset: CGPoint(x: 0.0, y: -resolvedOffset))
                    transition.animatePositionAdditive(node: itemNode.overlayNode, offset: CGPoint(x: 0.0, y: -resolvedOffset))
                }
                for itemNode in self.removingBackgroundLineNodes {
                    transition.animatePosition(node: itemNode.lineNode, to: CGPoint(x: 0.0, y: resolvedOffset), removeOnCompletion: false, additive: true)
                    transition.animatePosition(node: itemNode.overlayNode, to: CGPoint(x: 0.0, y: resolvedOffset), removeOnCompletion: false, additive: true)
                }
            }
            
            var removeIndices: [Int] = []
            for (index, itemNode) in self.backgroundLineNodes {
                if !validIndices.contains(index) {
                    removeIndices.append(index)
                    
                    if transition.isAnimated {
                        removingBackgroundLineNodes.append(itemNode)
                        transition.animatePosition(node: itemNode.overlayNode, to: CGPoint(x: 0.0, y: resolvedOffset), removeOnCompletion: false, additive: true)
                        transition.animatePosition(node: itemNode.lineNode, to: CGPoint(x: 0.0, y: resolvedOffset), removeOnCompletion: false, additive: true, completion: { [weak self, weak itemNode] _ in
                            guard let strongSelf = self, let itemNode = itemNode else {
                                return
                            }
                            strongSelf.removingBackgroundLineNodes.removeAll(where: { $0 === itemNode })
                            itemNode.lineNode.removeFromSupernode()
                            itemNode.overlayNode.removeFromSupernode()
                        })
                    } else {
                        itemNode.lineNode.removeFromSupernode()
                        itemNode.overlayNode.removeFromSupernode()
                    }
                }
            }
            for index in removeIndices {
                self.backgroundLineNodes.removeValue(forKey: index)
            }
            
            transition.updateFrame(node: self.foregroundLineNode, frame: CGRect(origin: CGPoint(x: 0.0, y: itemScreenOffset), size: CGSize(width: 2.0, height: segmentHeight)), beginWithCurrentState: true)
            
            if transition.isAnimated && isCycledJump {
                let duration: Double = 0.18
                let maxOffset: CGFloat = -8.0
                let offsetAnimation0 = self.layer.makeAnimation(from: 0.0 as NSNumber, to: maxOffset as NSNumber, keyPath: "bounds.origin.y", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: duration / 2.0, removeOnCompletion: false, additive: true, completion: { [weak self] _ in
                    guard let strongSelf = self else {
                        return
                    }
                    let offsetAnimation1 = strongSelf.layer.makeAnimation(from: maxOffset as NSNumber, to: 0.0 as NSNumber, keyPath: "bounds.origin.y", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: duration / 2.0, additive: true)
                    strongSelf.layer.add(offsetAnimation1, forKey: "cycleShake")
                })
                self.layer.add(offsetAnimation0, forKey: "cycleShake")
            }
        }
    }
}
