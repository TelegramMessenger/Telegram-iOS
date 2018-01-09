import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit

import LegacyComponents

private final class InstantVideoRadialStatusNodeParameters: NSObject {
    let color: UIColor
    let progress: CGFloat
    
    init(color: UIColor, progress: CGFloat) {
        self.color = color
        self.progress = progress
    }
}

final class InstantVideoRadialStatusNode: ASDisplayNode {
    private let color: UIColor
    
    private var effectiveProgress: CGFloat = 0.0 {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    private var _statusValue: MediaPlayerStatus?
    private var statusValue: MediaPlayerStatus? {
        get {
            return self._statusValue
        } set(value) {
            if value != self._statusValue {
                self._statusValue = value
                self.updateProgress()
            }
        }
    }
    
    private var statusDisposable: Disposable?
    private var statusValuePromise = Promise<MediaPlayerStatus?>()
    
    var status: Signal<MediaPlayerStatus, NoError>? {
        didSet {
            if let status = self.status {
                self.statusValuePromise.set(status |> map { $0 })
            } else {
                self.statusValuePromise.set(.single(nil))
            }
        }
    }
    
    init(color: UIColor) {
        self.color = color
        
        super.init()
        
        self.isOpaque = false
        
        self.statusDisposable = (self.statusValuePromise.get()
            |> deliverOnMainQueue).start(next: { [weak self] status in
                if let strongSelf = self {
                    strongSelf.statusValue = status
                }
            })
    }
    
    deinit {
        self.statusDisposable?.dispose()
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return InstantVideoRadialStatusNodeParameters(color: self.color, progress: self.effectiveProgress)
    }
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        if let parameters = parameters as? InstantVideoRadialStatusNodeParameters {
            context.setStrokeColor(parameters.color.cgColor)
            
            var progress = parameters.progress
            let startAngle = -CGFloat.pi / 2.0
            let endAngle = CGFloat(progress) * 2.0 * CGFloat.pi + startAngle
            
            progress = min(1.0, progress)
            
            let lineWidth: CGFloat = 4.0
            
            let pathDiameter = bounds.size.width - lineWidth
            
            let path = UIBezierPath(arcCenter: CGPoint(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0), radius: pathDiameter / 2.0, startAngle: startAngle, endAngle: endAngle, clockwise:true)
            path.lineWidth = lineWidth
            path.lineCapStyle = .round
            path.stroke()
        }
    }
    
    private func updateProgress() {
        let timestampAndDuration: (timestamp: Double, duration: Double)?
        if let statusValue = self.statusValue, Double(0.0).isLess(than: statusValue.duration) {
            timestampAndDuration = (statusValue.timestamp, statusValue.duration)
        } else {
            timestampAndDuration = nil
        }
        
        if let (timestamp, duration) = timestampAndDuration, let statusValue = self.statusValue {
            let progress = CGFloat(timestamp / duration)
            
            if progress.isNaN || !progress.isFinite || statusValue.generationTimestamp.isZero {
                self.pop_removeAnimation(forKey: "progress")
                self.effectiveProgress = 0.0
            } else if statusValue.status != .playing {
                self.pop_removeAnimation(forKey: "progress")
                self.effectiveProgress = progress
            } else {
                self.pop_removeAnimation(forKey: "progress")
                
                let animation = POPBasicAnimation()
                animation.property = POPAnimatableProperty.property(withName: "progress", initializer: { property in
                    property?.readBlock = { node, values in
                        values?.pointee = (node as! InstantVideoRadialStatusNode).effectiveProgress
                    }
                    property?.writeBlock = { node, values in
                        (node as! InstantVideoRadialStatusNode).effectiveProgress = values!.pointee
                    }
                    property?.threshold = 0.01
                }) as! POPAnimatableProperty
                animation.fromValue = progress as NSNumber
                animation.toValue = 1.0 as NSNumber
                animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
                animation.duration = max(0.0, duration - timestamp)
                animation.completionBlock = { [weak self] _, _ in
                    
                }
                animation.beginTime = statusValue.generationTimestamp
                //animation.offset = timestamp
                self.pop_add(animation, forKey: "progress")
                
                /*let fromBounds = CGRect(origin: CGPoint(), size: fromRect.size)
                let toBounds = CGRect(origin: CGPoint(), size: toRect.size)
                
                foregroundNode.frame = toRect
                foregroundNode.layer.add(self.preparedAnimation(keyPath: "bounds", from: NSValue(cgRect: fromBounds), to: NSValue(cgRect: toBounds), duration: duration, beginTime: statusValue.generationTimestamp, offset: timestamp, speed: statusValue.status == .playing ? 1.0 : 0.0), forKey: "playback-bounds")
                foregroundNode.layer.add(self.preparedAnimation(keyPath: "position", from: NSValue(cgPoint: CGPoint(x: fromRect.midX, y: fromRect.midY)), to: NSValue(cgPoint: CGPoint(x: toRect.midX, y: toRect.midY)), duration: duration, beginTime: statusValue.generationTimestamp, offset: timestamp, speed: statusValue.status == .playing ? 1.0 : 0.0), forKey: "playback-position")*/
            }
        } else {
            self.pop_removeAnimation(forKey: "progress")
            self.effectiveProgress = 0.0
        }
    }
}
