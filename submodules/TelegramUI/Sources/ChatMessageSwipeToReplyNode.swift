import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AppBundle
import WallpaperBackgroundNode

private let size = CGSize(width: 33.0, height: 33.0)

final class ChatMessageSwipeToReplyNode: ASDisplayNode {
    enum Action {
        case reply
        case like
        case unlike
    }
    
    private var backgroundContent: WallpaperBubbleBackgroundNode?
    
    private let backgroundNode: NavigationBackgroundNode
    private let foregroundNode: ASImageNode
    
    private let maskNode: ASDisplayNode
    private let progressLayer: SimpleShapeLayer
    private let fillLayer: SimpleShapeLayer
    private let semiFillLayer: SimpleShapeLayer
    
    private var absolutePosition: (CGRect, CGSize)?
    
    init(fillColor: UIColor, enableBlur: Bool, foregroundColor: UIColor, backgroundNode: WallpaperBackgroundNode?, action: ChatMessageSwipeToReplyNode.Action) {
        self.backgroundNode = NavigationBackgroundNode(color: fillColor, enableBlur: enableBlur)
        self.backgroundNode.isUserInteractionEnabled = false

        self.foregroundNode = ASImageNode()
        self.foregroundNode.isUserInteractionEnabled = false

        self.foregroundNode.image = generateImage(CGSize(width: 33.0, height: 33.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            switch action {
            case .reply:
                if let image = UIImage(bundleImageName: "Chat/Message/ShareIcon") {
                    let imageRect = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0)), size: image.size)
                    
                    context.translateBy(x: imageRect.midX, y: imageRect.midY)
                    context.scaleBy(x: -1.0, y: -1.0)
                    context.translateBy(x: -imageRect.midX, y: -imageRect.midY)
                    context.clip(to: imageRect, mask: image.cgImage!)
                    context.setFillColor(foregroundColor.cgColor)
                    context.fill(imageRect)
                }
            case .like, .unlike:
                if let image = UIImage(bundleImageName: action == .like ? "Chat/Reactions/SwipeActionHeartFilled" : "Chat/Reactions/SwipeActionHeartBroken") {
                    let imageRect = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0)), size: image.size)
                    
                    context.translateBy(x: imageRect.midX, y: imageRect.midY)
                    context.scaleBy(x: 1.0, y: -1.0)
                    context.translateBy(x: -imageRect.midX, y: -imageRect.midY)
                    if case .like = action {
                        context.translateBy(x: 0.0, y: -1.0)
                    } else {
                        context.translateBy(x: 0.5, y: -1.0)
                    }
                    context.clip(to: imageRect, mask: image.cgImage!)
                    context.setFillColor(foregroundColor.cgColor)
                    context.fill(imageRect)
                }
            }
        })
        
        self.maskNode = ASDisplayNode()
        self.progressLayer = SimpleShapeLayer()
        self.fillLayer = SimpleShapeLayer()
        self.semiFillLayer = SimpleShapeLayer()
    
        super.init()
        
        self.allowsGroupOpacity = true
        
        self.addSubnode(self.backgroundNode)
        
        self.maskNode.layer.addSublayer(self.progressLayer)
        self.maskNode.layer.addSublayer(self.fillLayer)
        self.maskNode.layer.addSublayer(self.semiFillLayer)
        
        self.addSubnode(self.foregroundNode)
        
        let backgroundFrame = CGRect(origin: CGPoint(), size: size).insetBy(dx: -22.0, dy: -22.0)
        
        self.backgroundNode.frame = backgroundFrame
        self.backgroundNode.update(size: self.backgroundNode.bounds.size, cornerRadius: self.backgroundNode.bounds.height / 2.0, transition: .immediate)
        self.foregroundNode.frame = CGRect(origin: CGPoint(), size: size)
                
        self.progressLayer.strokeColor = UIColor.white.cgColor
        self.progressLayer.fillColor = UIColor.clear.cgColor
        self.progressLayer.lineCap = .round
        self.progressLayer.lineWidth = 2.0 - UIScreenPixel
        
        self.fillLayer.strokeColor = UIColor.white.cgColor
        self.fillLayer.fillColor = UIColor.clear.cgColor
        self.fillLayer.isHidden = true
        
        self.semiFillLayer.fillColor = UIColor(rgb: 0xffffff, alpha: 0.6).cgColor
           
        self.maskNode.frame = CGRect(origin: CGPoint(x: 22.0, y: 22.0), size: backgroundFrame.size)
        self.progressLayer.frame = CGRect(origin: .zero, size: size).insetBy(dx: -20.0, dy: -20.0)
        self.fillLayer.frame = CGRect(origin: .zero, size: size)
        
        self.semiFillLayer.frame = self.fillLayer.frame
        self.semiFillLayer.path = UIBezierPath(ovalIn: self.semiFillLayer.bounds).cgPath
        
        let path = UIBezierPath(arcCenter: CGPoint(x: self.progressLayer.frame.width / 2.0, y: self.progressLayer.frame.height / 2.0), radius: size.width / 2.0, startAngle: CGFloat(-0.5 * .pi), endAngle: CGFloat(1.5 * .pi), clockwise: true)
        self.progressLayer.path = path.cgPath
                
        if backgroundNode?.hasExtraBubbleBackground() == true {
            if let backgroundContent = backgroundNode?.makeBubbleBackground(for: .free) {
                backgroundContent.clipsToBounds = true
                backgroundContent.allowsGroupOpacity = true
                self.backgroundContent = backgroundContent
                self.insertSubnode(backgroundContent, at: 0)
            }
        } else {
            self.backgroundContent?.removeFromSupernode()
            self.backgroundContent = nil
        }
        
        if let backgroundContent = self.backgroundContent {
            self.backgroundNode.isHidden = true
            backgroundContent.frame = backgroundFrame
            if let (rect, containerSize) = self.absolutePosition {
                var backgroundFrame = backgroundContent.frame
                backgroundFrame.origin.x += rect.minX
                backgroundFrame.origin.y += containerSize.height - rect.minY
                backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
            }
        } else {
            self.backgroundNode.isHidden = false
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        if let backgroundContent = self.backgroundContent {
            backgroundContent.view.mask = self.maskNode.view
        } else {
            self.backgroundNode.view.mask = self.maskNode.view
        }
    }
    
    private var animatedWave = false
    func updateProgress(_ progress: CGFloat) {
        let progress = max(0.0, min(1.0, progress))
        var foregroundProgress = min(1.0, progress * 1.2)
        var scaleProgress = 0.65 + foregroundProgress * 0.35
        
        if !self.animatedWave {
            let path = UIBezierPath(arcCenter: CGPoint(x: self.progressLayer.frame.width / 2.0, y: self.progressLayer.frame.height / 2.0), radius: size.width / 2.0, startAngle: CGFloat(-0.5 * .pi), endAngle: CGFloat(-0.5 * .pi + progress * 2.0 * .pi), clockwise: true)
            self.progressLayer.path = path.cgPath
        } else {
            foregroundProgress = progress
            scaleProgress = progress
            self.maskNode.alpha = progress
        }
        
        self.semiFillLayer.opacity = Float(progress)
        
        self.layer.sublayerTransform = CATransform3DMakeScale(scaleProgress, scaleProgress, 1.0)
        
        self.foregroundNode.alpha = foregroundProgress
        self.foregroundNode.transform = CATransform3DMakeScale(foregroundProgress, foregroundProgress, 1.0)
        
        if progress == 1.0 {
            self.playSuccessAnimation()
        }
    }
    
    func playSuccessAnimation() {
        guard !self.animatedWave else {
            return
        }
        self.layer.transform = CATransform3DMakeScale(1.1, 1.1, 1.0)
        self.layer.animateScale(from: 1.0, to: 1.1, duration: 0.2, completion: { [weak self] _ in
            self?.layer.transform = CATransform3DMakeScale(1.0, 1.0, 1.0)
            self?.layer.animateScale(from: 1.1, to: 1.0, duration: 0.15)
        })
        
        self.animatedWave = true
        
        var lineWidth = self.progressLayer.lineWidth
        self.progressLayer.lineWidth = 0.0
        self.progressLayer.animate(from: lineWidth as NSNumber, to: 0.0 as NSNumber, keyPath: "lineWidth", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.3, completion: { _ in
            
        })
        
        var path = self.progressLayer.path
        var targetPath = UIBezierPath(arcCenter: CGPoint(x: self.progressLayer.frame.width / 2.0, y: self.progressLayer.frame.height / 2.0), radius: 35.0, startAngle: CGFloat(-0.5 * .pi), endAngle: CGFloat(-0.5 * .pi + 2.0 * .pi), clockwise: true).cgPath
        self.progressLayer.path = targetPath
        self.progressLayer.animate(from: path, to: targetPath, keyPath: "path", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.3)
        
        self.progressLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
        
        self.fillLayer.isHidden = false
        self.fillLayer.path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).cgPath
        self.fillLayer.lineWidth = 2.0 - UIScreenPixel
                
        lineWidth = self.fillLayer.lineWidth
        self.fillLayer.lineWidth = 18.0
        self.fillLayer.animate(from: lineWidth as NSNumber, to: 18.0 as NSNumber, keyPath: "lineWidth", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.3)
        
        path = self.fillLayer.path
        targetPath = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size).insetBy(dx: 9.0, dy: 9.0)).cgPath
        self.fillLayer.path = targetPath
        self.fillLayer.animate(from: path, to: targetPath, keyPath: "path", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.3)
    }
    
    func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absolutePosition = (rect, containerSize)
        if let backgroundContent = self.backgroundContent {
            var backgroundFrame = backgroundContent.frame
            backgroundFrame.origin.x += rect.minX
            backgroundFrame.origin.y += containerSize.height - rect.minY
            backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
        }
    }
}

extension ChatMessageSwipeToReplyNode.Action {
    init(_ action: ChatControllerInteractionSwipeAction?) {
        if let action = action {
            switch action {
            case .none:
                self = .reply
            case .reply:
                self = .reply
            }
        } else {
            self = .reply
        }
    }
}
