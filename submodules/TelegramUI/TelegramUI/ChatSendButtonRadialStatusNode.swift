import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import LegacyComponents

private final class ChatSendButtonRadialStatusNodeParameters: NSObject {
    let color: UIColor
    let progress: CGFloat
    
    init(color: UIColor, progress: CGFloat) {
        self.color = color
        self.progress = progress
    }
}

final class ChatSendButtonRadialStatusNode: ASDisplayNode {
    private let color: UIColor
    
    private var effectiveProgress: CGFloat = 0.0 {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    var slowmodeState: ChatSlowmodeState? = nil {
        didSet {
            if self.slowmodeState != oldValue {
                self.updateProgress()
            }
        }
    }
    
    private var updateTimer: SwiftSignalKit.Timer?
    
    init(color: UIColor) {
        self.color = color
        
        super.init()
        
        self.isUserInteractionEnabled = false
        self.isOpaque = false
    }
    
    deinit {
        self.updateTimer?.invalidate()
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return ChatSendButtonRadialStatusNodeParameters(color: self.color, progress: self.effectiveProgress)
    }
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        if let parameters = parameters as? ChatSendButtonRadialStatusNodeParameters {
            context.setStrokeColor(parameters.color.cgColor)
            
            var progress = parameters.progress
            let startAngle = -CGFloat.pi / 2.0
            let endAngle = CGFloat(progress) * 2.0 * CGFloat.pi + startAngle
            
            progress = min(1.0, progress)
            
            let lineWidth: CGFloat = 2.0
            
            let pathDiameter = bounds.size.width - lineWidth
            
            let path = UIBezierPath(arcCenter: CGPoint(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0), radius: pathDiameter / 2.0, startAngle: startAngle, endAngle: endAngle, clockwise:true)
            path.lineWidth = lineWidth
            path.lineCapStyle = .round
            path.stroke()
        }
    }
    
    private func updateProgress() {
        if let slowmodeState = self.slowmodeState {
            let progress: CGFloat
            switch slowmodeState.variant {
            case .pendingMessages:
                progress = 1.0
            case let .timestamp(validUntilTimestamp):
                let timestamp = CGFloat(Date().timeIntervalSince1970)
                let relativeTimestamp = CGFloat(validUntilTimestamp) - timestamp
                progress = max(0.0, min(1.0, CGFloat(relativeTimestamp / CGFloat(slowmodeState.timeout))))
            }
            
            self.effectiveProgress = progress
            self.updateTimer?.invalidate()
            self.updateTimer = SwiftSignalKit.Timer(timeout: 1.0 / 60.0, repeat: false, completion: { [weak self] in
                self?.updateProgress()
            }, queue: .mainQueue())
            self.updateTimer?.start()
            /*if progress.isNaN || !progress.isFinite {
                self.pop_removeAnimation(forKey: "progress")
                self.effectiveProgress = 0.0
            } else {
                self.pop_removeAnimation(forKey: "progress")
                
                let animation = POPBasicAnimation()
                animation.property = POPAnimatableProperty.property(withName: "progress", initializer: { property in
                    property?.readBlock = { node, values in
                        values?.pointee = (node as! ChatSendButtonRadialStatusNode).effectiveProgress
                    }
                    property?.writeBlock = { node, values in
                        (node as! ChatSendButtonRadialStatusNode).effectiveProgress = values!.pointee
                    }
                    property?.threshold = 0.01
                }) as? POPAnimatableProperty
                animation.fromValue = progress as NSNumber
                animation.toValue = 1.0 as NSNumber
                animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
                animation.duration = max(0.0, duration - timestamp) / baseRate
                animation.beginTime = CACurrentMediaTime()
                self.pop_add(animation, forKey: "progress")
            }*/
        } else {
            //self.pop_removeAnimation(forKey: "progress")
            self.effectiveProgress = 0.0
            self.updateTimer?.invalidate()
            self.updateTimer = nil
        }
    }
}
