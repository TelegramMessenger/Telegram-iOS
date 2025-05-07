import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import TelegramPresentationData

private final class SearchShimmerEffectNode: ASDisplayNode {
    private var currentBackgroundColor: UIColor?
    private var currentForegroundColor: UIColor?
    private let imageNodeContainer: ASDisplayNode
    private let imageNode: ASImageNode
    
    private var absoluteLocation: (CGRect, CGSize)?
    private var isCurrentlyInHierarchy = false
    private var shouldBeAnimating = false
    
    override init() {
        self.imageNodeContainer = ASDisplayNode()
        self.imageNodeContainer.isLayerBacked = true
        
        self.imageNode = ASImageNode()
        self.imageNode.isLayerBacked = true
        self.imageNode.displaysAsynchronously = false
        self.imageNode.displayWithoutProcessing = true
        self.imageNode.contentMode = .scaleToFill
        
        super.init()
        
        self.isLayerBacked = true
        self.clipsToBounds = true
        
        self.imageNodeContainer.addSubnode(self.imageNode)
        self.addSubnode(self.imageNodeContainer)
    }
    
    override func didEnterHierarchy() {
        super.didEnterHierarchy()
        
        self.isCurrentlyInHierarchy = true
        self.updateAnimation()
    }
    
    override func didExitHierarchy() {
        super.didExitHierarchy()
        
        self.isCurrentlyInHierarchy = false
        self.updateAnimation()
    }
    
    func update(backgroundColor: UIColor, foregroundColor: UIColor) {
        if let currentBackgroundColor = self.currentBackgroundColor, currentBackgroundColor.argb == backgroundColor.argb, let currentForegroundColor = self.currentForegroundColor, currentForegroundColor.argb == foregroundColor.argb {
            return
        }
        self.currentBackgroundColor = backgroundColor
        self.currentForegroundColor = foregroundColor
        
        self.imageNode.image = generateImage(CGSize(width: 4.0, height: 320.0), opaque: true, scale: 1.0, rotatedContext: { size, context in
            context.setFillColor(backgroundColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: size))
            
            context.clip(to: CGRect(origin: CGPoint(), size: size))
            
            let transparentColor = foregroundColor.withAlphaComponent(0.0).cgColor
            let peakColor = foregroundColor.cgColor
            
            var locations: [CGFloat] = [0.0, 0.5, 1.0]
            let colors: [CGColor] = [transparentColor, peakColor, transparentColor]
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
            
            context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        })
    }
    
    func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        if let absoluteLocation = self.absoluteLocation, absoluteLocation.0 == rect && absoluteLocation.1 == containerSize {
            return
        }
        let sizeUpdated = self.absoluteLocation?.1 != containerSize
        let frameUpdated = self.absoluteLocation?.0 != rect
        self.absoluteLocation = (rect, containerSize)
        
        if sizeUpdated {
            if self.shouldBeAnimating {
                self.imageNode.layer.removeAnimation(forKey: "shimmer")
                self.addImageAnimation()
            }
        }
        
        if frameUpdated {
            self.imageNodeContainer.frame = CGRect(origin: CGPoint(x: -rect.minX, y: -rect.minY), size: containerSize)
        }
        
        self.updateAnimation()
    }
    
    private func updateAnimation() {
        let shouldBeAnimating = self.isCurrentlyInHierarchy && self.absoluteLocation != nil
        if shouldBeAnimating != self.shouldBeAnimating {
            self.shouldBeAnimating = shouldBeAnimating
            if shouldBeAnimating {
                self.addImageAnimation()
            } else {
                self.imageNode.layer.removeAnimation(forKey: "shimmer")
            }
        }
    }
    
    private func addImageAnimation() {
        guard let containerSize = self.absoluteLocation?.1 else {
            return
        }
        let gradientHeight: CGFloat = 250.0
        self.imageNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -gradientHeight), size: CGSize(width: containerSize.width, height: gradientHeight))
        let animation = self.imageNode.layer.makeAnimation(from: 0.0 as NSNumber, to: (containerSize.height + gradientHeight) as NSNumber, keyPath: "position.y", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 1.3 * 1.0, delay: 0.0, mediaTimingFunction: nil, removeOnCompletion: true, additive: true)
        animation.repeatCount = Float.infinity
        animation.beginTime = 1.0
        self.imageNode.layer.add(animation, forKey: "shimmer")
    }
}


final class LoadingShimmerNode: ASDisplayNode {
    private let backgroundColorNode: ASDisplayNode
    private let effectNode: SearchShimmerEffectNode
    private let maskNode: ASImageNode
    private var currentParams: (size: CGSize, theme: PresentationTheme, showFilters: Bool)?
    
    override init() {
        self.backgroundColorNode = ASDisplayNode()
        self.effectNode = SearchShimmerEffectNode()
        self.maskNode = ASImageNode()
        
        super.init()
        
        self.allowsGroupOpacity = true
        self.isUserInteractionEnabled = false
        
        self.addSubnode(self.backgroundColorNode)
        self.addSubnode(self.effectNode)
        self.addSubnode(self.maskNode)
    }
    
    func update(size: CGSize, theme: PresentationTheme, showFilters: Bool, transition: ContainedViewLayoutTransition) {
        let color = theme.list.itemSecondaryTextColor.mixedWith(theme.list.blocksBackgroundColor, alpha: 0.85)
        
        if self.currentParams?.size != size || self.currentParams?.theme !== theme  || self.currentParams?.showFilters != showFilters {
            self.currentParams = (size, theme, showFilters)
            
            self.backgroundColorNode.backgroundColor = color
            
            self.maskNode.image = generateImage(size, rotatedContext: { size, context in
                context.setFillColor(theme.list.blocksBackgroundColor.cgColor)
                context.fill(CGRect(origin: CGPoint(), size: size))
                
                let sideInset: CGFloat = 16.0
                
                if showFilters {
                    let filterSpacing: CGFloat = 6.0
                    let filterWidth = (size.width - sideInset * 2.0 - filterSpacing * 3.0) / 4.0
                    for i in 0 ..< 4 {
                        context.addPath(CGPath(roundedRect: CGRect(origin: CGPoint(x: sideInset + (filterWidth + filterSpacing) * CGFloat(i), y: 0.0), size: CGSize(width: filterWidth, height: 28.0)), cornerWidth: 14.0, cornerHeight: 14.0, transform: nil))
                    }
                }
                
                var currentY: CGFloat = 39.0 + 7.0
                var rowIndex: Int = 0
                
                let optionSpacing: CGFloat = 10.0
                let optionWidth = (size.width - sideInset * 2.0 - optionSpacing * 2.0) / 3.0
                let itemSize = CGSize(width: optionWidth, height: 154.0)
                
                context.setBlendMode(.copy)
                context.setFillColor(UIColor.clear.cgColor)
                
                while currentY < size.height {
                    for i in 0 ..< 3 {
                        let itemOrigin = CGPoint(x: sideInset + CGFloat(i) * (itemSize.width + optionSpacing), y: 39.0 + 9.0 + CGFloat(rowIndex) * (itemSize.height + optionSpacing))
                        context.addPath(CGPath(roundedRect: CGRect(origin: itemOrigin, size: itemSize), cornerWidth: 10.0, cornerHeight: 10.0, transform: nil))
                    }
                    currentY += itemSize.height
                    rowIndex += 1
                }
                context.fillPath()
            })
            
            self.effectNode.update(backgroundColor: color, foregroundColor: theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4))
            self.effectNode.updateAbsoluteRect(CGRect(origin: CGPoint(), size: size), within: size)
        }
        transition.updateFrame(node: self.backgroundColorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
        transition.updateFrame(node: self.maskNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
        transition.updateFrame(node: self.effectNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
    }
}
