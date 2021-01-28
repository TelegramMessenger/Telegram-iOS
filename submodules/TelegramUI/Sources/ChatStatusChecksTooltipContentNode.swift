import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import LegacyComponents
import TelegramPresentationData
import TooltipUI

private final class ChecksNodeParameters: NSObject {
    let color: UIColor
    let progress: CGFloat
    
    init(color: UIColor, progress: CGFloat) {
        self.color = color
        self.progress = progress
        
        super.init()
    }
}

private class ChecksNode: ASDisplayNode {
    var state: Bool? = nil
    
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
    
    init(color: UIColor) {
        self.color = color
        
        super.init()
        
        self.backgroundColor = .clear
        self.isOpaque = false
    }
    
    func animateProgress(from: CGFloat, to: CGFloat) {
        self.pop_removeAllAnimations()
        
        let animation = POPBasicAnimation()
        animation.property = (POPAnimatableProperty.property(withName: "progress", initializer: { property in
            property?.readBlock = { node, values in
                values?.pointee = (node as! ChecksNode).effectiveProgress
            }
            property?.writeBlock = { node, values in
                (node as! ChecksNode).effectiveProgress = values!.pointee
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
        return ChecksNodeParameters(color: self.color, progress: self.effectiveProgress)
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
        
        guard let parameters = parameters as? ChecksNodeParameters else {
            return
        }
        
        let scaleFactor: CGFloat = 1.0
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
    
    func updateState(_ state: Bool, animated: Bool) {
        guard state != self.state else {
            return
        }
        let previousState = self.state
        self.state = state
        if animated {
            if previousState == nil && self.state == false {
                self.animateProgress(from: 0.0, to: 1.0)
            } else if previousState == false && self.state == true {
                self.animateProgress(from: 1.0, to: 2.0)
            }
        } else {
            if let state = self.state {
                self.effectiveProgress = state ? 2.0 : 1.0
            } else {
                self.effectiveProgress = 0.0
            }
        }
    }
}

class ChatStatusChecksTooltipContentNode: ASDisplayNode, TooltipControllerCustomContentNode {
    private let deliveredChecksNode: ChecksNode
    private let deliveredTextNode: ImmediateTextNode
    private let readChecksNode: ChecksNode
    private let readTextNode: ImmediateTextNode
    
    init(presentationData: PresentationData) {
        self.deliveredChecksNode = ChecksNode(color: .white)
        self.deliveredTextNode = ImmediateTextNode()
        self.readChecksNode = ChecksNode(color: .white)
        self.readTextNode = ImmediateTextNode()
        
        self.deliveredTextNode.attributedText = NSAttributedString(string: presentationData.strings.Conversation_ChecksTooltip_Delivered, font: Font.regular(14.0), textColor: UIColor.white)
        self.readTextNode.attributedText = NSAttributedString(string: presentationData.strings.Conversation_ChecksTooltip_Read, font: Font.regular(14.0), textColor: UIColor.white)
        
        super.init()
        
        self.addSubnode(self.deliveredChecksNode)
        self.addSubnode(self.deliveredTextNode)
        self.addSubnode(self.readChecksNode)
        self.addSubnode(self.readTextNode)
    }
    
    func animateIn() {
        self.deliveredChecksNode.updateState(false, animated: true)
        self.readChecksNode.updateState(false, animated: true)
        
        self.deliveredChecksNode.layer.animateScale(from: 1.0, to: 1.12, duration: 0.25, delay: 0.1, removeOnCompletion: false, completion: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.deliveredChecksNode.layer.animateScale(from: 1.12, to: 1.0, duration: 0.25)
            }
        })
        
        self.deliveredTextNode.layer.animateScale(from: 1.0, to: 1.12, duration: 0.25, delay: 0.1, removeOnCompletion: false, completion: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.deliveredTextNode.layer.animateScale(from: 1.12, to: 1.0, duration: 0.25)
            }
        })
        
        Queue.mainQueue().after(0.5) {
            self.readChecksNode.updateState(true, animated: true)
            
            self.readChecksNode.layer.animateScale(from: 1.0, to: 1.12, duration: 0.25, removeOnCompletion: false, completion: { [weak self] _ in
                if let strongSelf = self {
                    strongSelf.readChecksNode.layer.animateScale(from: 1.12, to: 1.0, duration: 0.25)
                }
            })
            
            self.readTextNode.layer.animateScale(from: 1.0, to: 1.12, duration: 0.25, removeOnCompletion: false, completion: { [weak self] _ in
                if let strongSelf = self {
                    strongSelf.readTextNode.layer.animateScale(from: 1.12, to: 1.0, duration: 0.25)
                }
            })
        }
    }
    
    func updateLayout(size: CGSize) -> CGSize {
        let deliveredSize = self.deliveredTextNode.updateLayout(size)
        let readSize = self.readTextNode.updateLayout(size)
        
        let checksInset: CGFloat = 8.0
        let checksSize = CGSize(width: 24.0, height: 24.0)
        
        self.deliveredChecksNode.frame = CGRect(origin: CGPoint(x: checksInset, y: 15.0), size: checksSize)
        self.deliveredTextNode.frame = CGRect(origin: CGPoint(x: checksInset + checksSize.width + 5.0, y: 19.0), size: deliveredSize)
        self.readChecksNode.frame = CGRect(origin: CGPoint(x: checksInset, y: 38.0), size: checksSize)
        self.readTextNode.frame = CGRect(origin: CGPoint(x: checksInset + checksSize.width + 5.0, y: 43.0), size: readSize)
        
        let contentWidth = max(deliveredSize.width, readSize.width) + checksInset + checksSize.width + 18.0
        let contentHeight: CGFloat = 77.0
        
        return CGSize(width: contentWidth, height: contentHeight)
    }
}
