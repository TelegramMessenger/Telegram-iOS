import Foundation
import UIKit
import AsyncDisplayKit
import Display
import LegacyComponents
import RadialStatusNode

enum ChatListStatusNodeState: Equatable {
    case none
    case clock(UIImage?, UIImage?)
    case delivered(UIColor)
    case read(UIColor)
    case progress(UIColor, CGFloat)
    case failed(UIColor, UIColor)
    
    func contentNode() -> ChatListStatusContentNode? {
        switch self {
        case .none:
            return nil
        case let .clock(frameImage, minImage):
            return ChatListStatusClockNode(frameImage: frameImage, minImage: minImage)
        case let .delivered(color):
            return ChatListStatusChecksNode(color: color)
        case let .read(color):
            return ChatListStatusChecksNode(color: color)
        case let .progress(color, progress):
            return ChatListStatusProgressNode(color: color, progress: progress)
        case let .failed(fill, foreground):
            return ChatListStatusFailedNode(fill: fill, foreground: foreground)
        }
    }
}

private let transitionDuration = 0.2

class ChatListStatusContentNode: ASDisplayNode {
    var fontSize: CGFloat = 17.0
    
    override init() {
        super.init()
        
        self.isOpaque = false
    }
    
    func updateWithState(_ state: ChatListStatusNodeState, animated: Bool) {
    }
    
    func animateOut(to: ChatListStatusNodeState, completion: @escaping () -> Void) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: transitionDuration, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }
    
    func animateIn(from: ChatListStatusNodeState) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: transitionDuration)
    }
}

final class ChatListStatusNode: ASDisplayNode {
    private(set) var state: ChatListStatusNodeState = .none
    
    var fontSize: CGFloat = 17.0 {
        didSet {
            self.contentNode?.fontSize = self.fontSize
            self.nextContentNode?.fontSize = self.fontSize
        }
    }
    
    private var contentNode: ChatListStatusContentNode?
    private var nextContentNode: ChatListStatusContentNode?
    
    public func transitionToState(_ state: ChatListStatusNodeState, animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        if self.state != state {
            let currentState = self.state
            self.state = state
            
            let contentNode = state.contentNode()
            contentNode?.fontSize = self.fontSize
            if contentNode?.classForCoder != self.contentNode?.classForCoder {
                contentNode?.updateWithState(state, animated: animated)
                self.transitionToContentNode(contentNode, state: state, fromState: currentState, animated: animated, completion: completion)
            } else {
                self.contentNode?.updateWithState(state, animated: animated)
            }
            return true
        } else {
            completion()
            return false
        }
    }
    
    private func transitionToContentNode(_ node: ChatListStatusContentNode?, state: ChatListStatusNodeState, fromState: ChatListStatusNodeState, animated: Bool, completion: @escaping () -> Void) {
        if let previousContentNode = self.contentNode {
            if !animated {
                previousContentNode.removeFromSupernode()
                self.contentNode = node
                if let contentNode = self.contentNode {
                    self.addSubnode(contentNode)
                }
            } else {
                self.contentNode = node
                if let contentNode = self.contentNode {
                    self.addSubnode(contentNode)
                    contentNode.frame = self.bounds
                    if self.isNodeLoaded {
                        contentNode.animateIn(from: fromState)
                        contentNode.layout()
                    }
                }
                previousContentNode.animateOut(to: state) {
                    previousContentNode.removeFromSupernode()
                }
            }
        } else {
            self.contentNode = node
            if let contentNode = self.contentNode {
                contentNode.frame = self.bounds
                self.addSubnode(contentNode)
                if self.isNodeLoaded {
                    contentNode.layout()
                }
            }
        }
    }
    
    override public func layout() {
        if let contentNode = self.contentNode {
            contentNode.frame = self.bounds
        }
    }
}

class ChatListStatusClockNode: ChatListStatusContentNode {
    private var clockFrameNode: ASImageNode
    private var clockMinNode: ASImageNode
    
    init(frameImage: UIImage?, minImage: UIImage?) {
        self.clockFrameNode = ASImageNode()
        self.clockMinNode = ASImageNode()
        
        super.init()
        
        self.clockFrameNode.image = frameImage
        self.clockMinNode.image = minImage
        
        self.addSubnode(self.clockFrameNode)
        self.addSubnode(self.clockMinNode)
    }
    
    override func updateWithState(_ state: ChatListStatusNodeState, animated: Bool) {
        if case let .clock(frameImage, minImage) = state {
            self.clockFrameNode.image = frameImage
            self.clockMinNode.image = minImage
        }
    }
    
    override func didEnterHierarchy() {
        super.didEnterHierarchy()
        
        maybeAddRotationAnimation(self.clockFrameNode.layer, duration: 6.0)
        maybeAddRotationAnimation(self.clockMinNode.layer, duration: 1.0)
    }
    
    override func didExitHierarchy() {
        super.didExitHierarchy()
        
        self.clockFrameNode.layer.removeAllAnimations()
        self.clockMinNode.layer.removeAllAnimations()
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        if let frameImage = self.clockFrameNode.image {
            self.clockFrameNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((bounds.width - frameImage.size.width) / 2.0), y: floorToScreenPixels((bounds.height - frameImage.size.height) / 2.0)), size: frameImage.size)
        }
        if let minImage = self.clockMinNode.image {
            self.clockMinNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((bounds.width - minImage.size.width) / 2.0), y: floorToScreenPixels((bounds.height - minImage.size.height) / 2.0)), size: minImage.size)
        }
    }
}

private func maybeAddRotationAnimation(_ layer: CALayer, duration: Double) {
    if let _ = layer.animation(forKey: "clockFrameAnimation") {
        return
    }
    
    let basicAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
    basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
    basicAnimation.duration = duration
    basicAnimation.fromValue = NSNumber(value: Float(0.0))
    basicAnimation.toValue = NSNumber(value: Float(Double.pi * 2.0))
    basicAnimation.repeatCount = Float.infinity
    basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
    basicAnimation.beginTime = 1.0
    layer.add(basicAnimation, forKey: "clockFrameAnimation")
}

private final class StatusChecksNodeParameters: NSObject {
    let color: UIColor
    let progress: CGFloat
    let fontSize: CGFloat
    
    init(color: UIColor, progress: CGFloat, fontSize: CGFloat) {
        self.color = color
        self.progress = progress
        self.fontSize = fontSize
        
        super.init()
    }
}

private class ChatListStatusChecksNode: ChatListStatusContentNode {
    private var state: ChatListStatusNodeState?
    
    var color: UIColor {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    private var effectiveProgress: CGFloat = 1.0 {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    override var fontSize: CGFloat {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    init(color: UIColor) {
        self.color = color
        
        super.init()
    }
    
    func animateProgress(from: CGFloat, to: CGFloat) {
        self.pop_removeAllAnimations()
        
        let animation = POPBasicAnimation()
        animation.property = (POPAnimatableProperty.property(withName: "progress", initializer: { property in
            property?.readBlock = { node, values in
                values?.pointee = (node as! ChatListStatusChecksNode).effectiveProgress
            }
            property?.writeBlock = { node, values in
                (node as! ChatListStatusChecksNode).effectiveProgress = values!.pointee
            }
            property?.threshold = 0.01
        }) as! POPAnimatableProperty)
        animation.fromValue = from as NSNumber
        animation.toValue = to as NSNumber
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        animation.duration = 0.2
        self.pop_add(animation, forKey: "progress")
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return StatusChecksNodeParameters(color: self.color, progress: self.effectiveProgress, fontSize: self.fontSize)
    }
    
    override func didEnterHierarchy() {
        super.didEnterHierarchy()
    }
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        guard let parameters = parameters as? StatusChecksNodeParameters else {
            return
        }
        
        let scaleFactor = min(1.4, parameters.fontSize / 17.0)
        context.translateBy(x: bounds.width / 2.0, y: bounds.height / 2.0)
        context.scaleBy(x: scaleFactor, y: scaleFactor)
        context.translateBy(x: -bounds.width / 2.0, y: -bounds.height / 2.0)
        
        let progress = parameters.progress
        
        context.setStrokeColor(parameters.color.cgColor)
        context.setLineWidth(1.0 + UIScreenPixel)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setMiterLimit(10.0)
        
        context.saveGState()
        var s1 = CGPoint(x: 9.0, y: 13.0)
        var s2 = CGPoint(x: 5.0, y: 13.0)
        let p1 = CGPoint(x: 3.5, y: 3.5)
        let p2 = CGPoint(x: 7.5 - UIScreenPixel, y: -8.0)
        
        let check1FirstSegment: CGFloat = max(0.0, min(1.0, progress * 3.0))
        let check2FirstSegment: CGFloat = max(0.0, min(1.0, (progress - 1.0) * 3.0))
        
        let firstProgress = max(0.0, min(1.0, progress))
        let secondProgress = max(0.0, min(1.0, progress - 1.0))
        
        let scale: CGFloat = 1.2
        context.translateBy(x: 16.0, y: 13.0)
        context.scaleBy(x: scale - abs((scale - 1.0) * (firstProgress - 0.5) / 0.5), y: scale - abs((scale - 1.0) * (firstProgress - 0.5) / 0.5))
        s1 = s1.offsetBy(dx: -16.0, dy: -13.0)
        
        if !check1FirstSegment.isZero {
            if check1FirstSegment < 1.0 {
                context.move(to: CGPoint(x: s1.x + p1.x * check1FirstSegment, y: s1.y + p1.y * check1FirstSegment))
                context.addLine(to: s1)
            } else {
                let secondSegment = (min(1.0, progress) - 0.33) * 1.5
                context.move(to: CGPoint(x: s1.x + p1.x + p2.x * secondSegment, y: s1.y + p1.y + p2.y * secondSegment))
                context.addLine(to: CGPoint(x: s1.x + p1.x, y: s1.y + p1.y))
                context.addLine(to: CGPoint(x: s1.x + p1.x * min(1.0, check2FirstSegment), y: s1.y + p1.y * min(1.0, check2FirstSegment)))
            }
        }
        context.strokePath()
        
        context.restoreGState()
        
        context.translateBy(x: 12.0, y: 13.0)
        context.scaleBy(x: scale - abs((scale - 1.0) * (secondProgress - 0.5) / 0.5), y: scale - abs((scale - 1.0) * (secondProgress - 0.5) / 0.5))
        s2 = s2.offsetBy(dx: -12.0, dy: -13.0)
        
        if !check2FirstSegment.isZero {
            if check2FirstSegment < 1.0 {
                context.move(to: CGPoint(x: s2.x + p1.x * check2FirstSegment, y: s2.y + p1.y * check2FirstSegment))
                context.addLine(to: s2)
            } else {
                let secondSegment = (max(0.0, (progress - 1.0)) - 0.33) * 1.5
                context.move(to: CGPoint(x: s2.x + p1.x + p2.x * secondSegment, y: s2.y + p1.y + p2.y * secondSegment))
                context.addLine(to: CGPoint(x: s2.x + p1.x, y: s2.y + p1.y))
                context.addLine(to: s2)
            }
        }
        context.strokePath()
    }
    
    override func updateWithState(_ state: ChatListStatusNodeState, animated: Bool) {
        switch state {
            case let .delivered(color), let .read(color):
                self.color = color
            default:
                break
        }
        var animating = false
        if let previousState = self.state, case .delivered = previousState, case .read = state, animated {
            animating = true
            self.animateProgress(from: 1.0, to: 2.0)
        }
        if !animating {
            if case .delivered = state {
                self.effectiveProgress = 1.0
            } else if case .read = state {
                self.effectiveProgress = 2.0
            }
        }
        self.state = state
    }
    
    override func animateIn(from: ChatListStatusNodeState) {
        if let state = self.state, case .delivered = state {
            self.animateProgress(from: 0.0, to: 1.0)
        } else {
            super.animateIn(from: from)
        }
    }
}

private final class ChatListStatusFailedNodeParameters: NSObject {
    let fill: UIColor
    let foreground: UIColor
    
    init(fill: UIColor, foreground: UIColor) {
        self.fill = fill
        self.foreground = foreground
        
        super.init()
    }
}

private class ChatListStatusFailedNode: ChatListStatusContentNode {
    private var state: ChatListStatusNodeState?
    
    var fill: UIColor {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    var foreground: UIColor {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    init(fill: UIColor, foreground: UIColor) {
        self.fill = fill
        self.foreground = foreground
        
        super.init()
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return ChatListStatusFailedNodeParameters(fill: self.fill, foreground: self.foreground)
    }
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        guard let parameters = parameters as? ChatListStatusFailedNodeParameters else {
            return
        }
        
        let diameter: CGFloat = 14.0
        let rect = CGRect(origin: CGPoint(x: floor((bounds.width - diameter) / 2.0), y: floor((bounds.height - diameter) / 2.0)), size: CGSize(width: diameter, height: diameter)).offsetBy(dx: 1.0, dy: UIScreenPixel)
        
        context.setFillColor(parameters.fill.cgColor)
        context.fillEllipse(in: rect)
        context.setStrokeColor(parameters.foreground.cgColor)
        
        let string = NSAttributedString(string: "!", font: Font.medium(12.0), textColor: parameters.foreground)
        let stringRect = string.boundingRect(with: rect.size, options: .usesLineFragmentOrigin, context: nil)
        
        UIGraphicsPushContext(context)
        string.draw(at: CGPoint(x: rect.minX + floor((rect.width - stringRect.width) / 2.0), y: 1.0 - UIScreenPixel + rect.minY + floor((rect.height - stringRect.height) / 2.0)))
        UIGraphicsPopContext()
    }
    
    override func updateWithState(_ state: ChatListStatusNodeState, animated: Bool) {
        switch state {
        case let .failed(fill, foreground):
            self.fill = fill
            self.foreground = foreground
        default:
            break
        }
        self.state = state
    }
}

private class ChatListStatusProgressNode: ChatListStatusContentNode {
    private let statusNode: RadialStatusNode
    
    init(color: UIColor, progress: CGFloat) {
        self.statusNode = RadialStatusNode(backgroundNodeColor: .clear)
        
        super.init()
        
        self.statusNode.transitionToState(.progress(color: color, lineWidth: 1.0, value: progress, cancelEnabled: false, animateRotation: true))
        
        self.addSubnode(self.statusNode)
    }
    
    override func updateWithState(_ state: ChatListStatusNodeState, animated: Bool) {
        if case let .progress(color, progress) = state {
            self.statusNode.transitionToState(.progress(color: color, lineWidth: 1.0, value: progress, cancelEnabled: false, animateRotation: true), animated: animated, completion: {})
        }
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        let size = CGSize(width: 12.0, height: 12.0)
        self.statusNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((bounds.width - size.width) / 2.0), y: floorToScreenPixels((bounds.height - size.height) / 2.0)), size: size)
    }
}
