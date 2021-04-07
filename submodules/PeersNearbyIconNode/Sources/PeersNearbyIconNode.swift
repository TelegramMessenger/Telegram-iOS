import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import LegacyComponents

private final class PeersNearbyIconWavesNodeParams: NSObject {
    let color: UIColor
    let progress: CGFloat
    
    init(color: UIColor, progress: CGFloat) {
        self.color = color
        self.progress = progress
        
        super.init()
    }
}

private func degToRad(_ degrees: CGFloat) -> CGFloat {
    return degrees * CGFloat.pi / 180.0
}

public final class PeersNearbyIconWavesNode: ASDisplayNode {
    public var color: UIColor {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    private var effectiveProgress: CGFloat = 0.0 {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    public init(color: UIColor) {
        self.color = color
        
        super.init()
        
        self.isLayerBacked = true
        self.isOpaque = false
    }
    
    override public func willEnterHierarchy() {
        super.willEnterHierarchy()
        
        self.pop_removeAnimation(forKey: "indefiniteProgress")
        
        let animation = POPBasicAnimation()
        animation.property = (POPAnimatableProperty.property(withName: "progress", initializer: { property in
            property?.readBlock = { node, values in
                values?.pointee = (node as! PeersNearbyIconWavesNode).effectiveProgress
            }
            property?.writeBlock = { node, values in
                (node as! PeersNearbyIconWavesNode).effectiveProgress = values!.pointee
            }
            property?.threshold = 0.01
        }) as! POPAnimatableProperty)
        animation.fromValue = CGFloat(0.0) as NSNumber
        animation.toValue = CGFloat(1.0) as NSNumber
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        animation.duration = 3.5
        animation.repeatForever = true
        self.pop_add(animation, forKey: "indefiniteProgress")
    }
    
    override public func didExitHierarchy() {
        super.didExitHierarchy()
        
        self.pop_removeAnimation(forKey: "indefiniteProgress")
    }
    
    override public func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        let t = CACurrentMediaTime()
        let value: CGFloat = CGFloat(t.truncatingRemainder(dividingBy: 2.0)) / 2.0
        return PeersNearbyIconWavesNodeParams(color: self.color, progress: value)
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        if let parameters = parameters as? PeersNearbyIconWavesNodeParams {
            let center = CGPoint(x: bounds.width / 2.0, y: bounds.height / 2.0)
            let radius: CGFloat = bounds.width * 0.3333
            let range: CGFloat = (bounds.width - radius * 2.0) / 2.0
            
            context.setFillColor(parameters.color.cgColor)
            
            let draw: (CGContext, CGFloat) -> Void = { context, pos in
                let path = CGMutablePath()
            
                let pathRadius: CGFloat = bounds.width * 0.3333 + range * pos
                path.addEllipse(in: CGRect(x: center.x - pathRadius, y: center.y - pathRadius, width: pathRadius * 2.0, height: pathRadius * 2.0))
                
                let strokedPath = path.copy(strokingWithWidth: 1.0, lineCap: .round, lineJoin: .miter, miterLimit: 10.0)
                context.addPath(strokedPath)
                context.fillPath()
            }
            
            let position = parameters.progress
            var alpha = position / 0.5
            if alpha > 1.0 {
                alpha = 2.0 - alpha
            }
            context.setAlpha(alpha * 0.7)
            
            draw(context, position)
            
            var progress = parameters.progress + 0.3333
            if progress > 1.0 {
                progress = progress - 1.0
            }
            
            var largerPos = progress
            var largerAlpha = largerPos / 0.5
            if largerAlpha > 1.0 {
                largerAlpha = 2.0 - largerAlpha
            }
            context.setAlpha(largerAlpha * 0.7)
            
            draw(context, largerPos)
            
            progress = parameters.progress + 0.6666
            if progress > 1.0 {
                progress = progress - 1.0
            }
            
            largerPos = progress
            largerAlpha = largerPos / 0.5
            if largerAlpha > 1.0 {
                largerAlpha = 2.0 - largerAlpha
            }
            context.setAlpha(largerAlpha * 0.7)
            
            draw(context, largerPos)
        }
    }
}

private func generateIcon(size: CGSize, color: UIColor, contentColor: UIColor) -> UIImage {
    return generateImage(size, rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: bounds)
        
        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        context.scaleBy(x: size.width / 120.0, y: size.height / 120.0)
        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
        context.translateBy(x: 0.0, y: 6.0)
        context.setFillColor(contentColor.cgColor)
        
        if size.width == 120.0 {
            context.translateBy(x: 30.0, y: 30.0)
        }
        
        let _ = try? drawSvgPath(context, path: "M27.8628211,52.2347452 L27.8628211,27.1373017 L2.76505663,27.1373017 C1.55217431,27.1373017 0.568938916,26.1540663 0.568938916,24.941184 C0.568938916,24.0832172 1.06857435,23.3038117 1.84819149,22.9456161 L51.2643819,0.241311309 C52.586928,-0.366333451 54.1516568,0.213208572 54.7593016,1.53575465 C55.0801868,2.23416513 55.080181,3.03785964 54.7592857,3.7362655 L32.0544935,53.1516391 C31.548107,54.2537536 30.2441593,54.7366865 29.1420449,54.2302999 C28.3624433,53.8720978 27.8628211,53.0927006 27.8628211,52.2347452 Z ")
    })!
}

public final class PeersNearbyIconNode: ASDisplayNode {
    private var theme: PresentationTheme
    
    private var iconNode: ASImageNode
    private var wavesNode: PeersNearbyIconWavesNode
    
    public init(theme: PresentationTheme) {
        self.theme = theme
        
        self.iconNode = ASImageNode()
        self.iconNode.isOpaque = false
        self.wavesNode = PeersNearbyIconWavesNode(color: theme.list.itemAccentColor)
        
        super.init()
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.wavesNode)
    }
    
    public func updateTheme(_ theme: PresentationTheme) {
        guard self.theme !== theme else {
            return
        }
        self.theme = theme
        
        self.iconNode.image = generateIcon(size: self.bounds.size, color: self.theme.list.itemAccentColor, contentColor: self.theme.list.itemCheckColors.foregroundColor)
        self.wavesNode.color = theme.list.itemAccentColor
    }
    
    override public func layout() {
        super.layout()
        
        if let image = self.iconNode.image, image.size.width == self.bounds.width {
        } else {
            self.iconNode.image = generateIcon(size: self.bounds.size, color: self.theme.list.itemAccentColor, contentColor: self.theme.list.itemCheckColors.foregroundColor)
        }
        self.iconNode.frame = self.bounds
        self.wavesNode.frame = self.bounds.insetBy(dx: -self.bounds.width * 0.3, dy: -self.bounds.height * 0.3)
    }
}
