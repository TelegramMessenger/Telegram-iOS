import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import UniversalMediaPlayer
import LegacyComponents

private final class InstantVideoRadialStatusNodeParameters: NSObject {
    let color: UIColor
    let progress: CGFloat
    let dimProgress: CGFloat
    let playProgress: CGFloat
    let blinkProgress: CGFloat
    let hasSeek: Bool
    
    init(color: UIColor, progress: CGFloat, dimProgress: CGFloat, playProgress: CGFloat, blinkProgress: CGFloat, hasSeek: Bool) {
        self.color = color
        self.progress = progress
        self.dimProgress = dimProgress
        self.playProgress = playProgress
        self.blinkProgress = blinkProgress
        self.hasSeek = hasSeek
    }
}

private extension CGFloat {
    var degrees: CGFloat {
        return self * CGFloat(180) / .pi
    }
}

private extension CGPoint {
    func angle(to otherPoint: CGPoint) -> CGFloat {
        let originX = otherPoint.x - x
        let originY = otherPoint.y - y
        let bearingRadians = atan2f(Float(originY), Float(originX))
        return CGFloat(bearingRadians)
    }
}

final class InstantVideoRadialStatusNode: ASDisplayNode, UIGestureRecognizerDelegate {
    private let color: UIColor
    private let hasSeek: Bool
    private let hapticFeedback = HapticFeedback()
    
    private var effectiveProgress: CGFloat = 0.0 {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    private var seeking = false
    private var seekingProgress: CGFloat?
    
    private var dimmed = false
    private var effectiveDimProgress: CGFloat = 0.0 {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    private var effectivePlayProgress: CGFloat = 0.0 {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    private var effectiveBlinkProgress: CGFloat = 0.0 {
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
    
    var duration: Double? {
        if let statusValue = self.statusValue {
            return statusValue.duration
        } else {
            return nil
        }
    }
    
    var status: Signal<MediaPlayerStatus, NoError>? {
        didSet {
            if let status = self.status {
                self.statusValuePromise.set(status |> map { $0 })
            } else {
                self.statusValuePromise.set(.single(nil))
            }
        }
    }
    
    var tapGestureRecognizer: UITapGestureRecognizer?
    var panGestureRecognizer: UIPanGestureRecognizer?
    
    var seekTo: ((Double, Bool) -> Void)?
    
    init(color: UIColor, hasSeek: Bool) {
        self.color = color
        self.hasSeek = hasSeek
        
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
    
    override func didLoad() {
        super.didLoad()
        
        guard self.hasSeek else {
            return
        }
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
        tapGestureRecognizer.delegate = self
        self.view.addGestureRecognizer(tapGestureRecognizer)
        
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
        panGestureRecognizer.delegate = self
        self.view.addGestureRecognizer(panGestureRecognizer)
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === self.tapGestureRecognizer || gestureRecognizer === self.panGestureRecognizer {
            let center = CGPoint(x: self.bounds.width / 2.0, y: self.bounds.height / 2.0)
            let location = gestureRecognizer.location(in: self.view)
            let distanceFromCenter = location.distanceTo(center)
            if distanceFromCenter < self.bounds.width * 0.2 {
                return false
            }
            return true
        } else {
            return true
        }
    }
    
    @objc private func tapGesture(_ gestureRecognizer: UITapGestureRecognizer) {
        let center = CGPoint(x: self.bounds.width / 2.0, y: self.bounds.height / 2.0)
        let location = gestureRecognizer.location(in: self.view)

        var angle = center.angle(to: location) + CGFloat.pi / 2.0
        if angle < 0.0 {
            angle = CGFloat.pi * 2.0 + angle
        }
        let fraction = max(0.0, min(1.0, Double(angle / (2.0 * CGFloat.pi))))
        self.seekTo?(min(0.99, fraction), true)
    }
    
    @objc private func panGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        let center = CGPoint(x: self.bounds.width / 2.0, y: self.bounds.height / 2.0)
        let location = gestureRecognizer.location(in: self.view)
        var angle = center.angle(to: location) + CGFloat.pi / 2.0
        if angle < 0.0 {
            angle = CGFloat.pi * 2.0 + angle
        }
        let fraction = max(0.0, min(1.0, Double(angle / (2.0 * CGFloat.pi))))
        
        switch gestureRecognizer.state {
            case .began:
                self.seeking = true
                
                let playAnimation = POPSpringAnimation()
                playAnimation.property = POPAnimatableProperty.property(withName: "playProgress", initializer: { property in
                    property?.readBlock = { node, values in
                        values?.pointee = (node as! InstantVideoRadialStatusNode).effectivePlayProgress
                    }
                    property?.writeBlock = { node, values in
                        (node as! InstantVideoRadialStatusNode).effectivePlayProgress = values!.pointee
                    }
                    property?.threshold = 0.01
                }) as? POPAnimatableProperty
                playAnimation.fromValue = self.effectivePlayProgress as NSNumber
                playAnimation.toValue = 0.0 as NSNumber
                playAnimation.springSpeed = 20
                playAnimation.springBounciness = 8
                self.pop_add(playAnimation, forKey: "playProgress")
            case .changed:
                if let seekingProgress = self.seekingProgress {
                    if seekingProgress > 0.98 && fraction > 0.0 && fraction < 0.05 {
                        self.hapticFeedback.impact(.light)
                        
                        let blinkAnimation = POPBasicAnimation()
                        blinkAnimation.property = POPAnimatableProperty.property(withName: "blinkProgress", initializer: { property in
                            property?.readBlock = { node, values in
                                values?.pointee = (node as! InstantVideoRadialStatusNode).effectiveBlinkProgress
                            }
                            property?.writeBlock = { node, values in
                                (node as! InstantVideoRadialStatusNode).effectiveBlinkProgress = values!.pointee
                            }
                            property?.threshold = 0.01
                        }) as? POPAnimatableProperty
                        blinkAnimation.fromValue = 1.0 as NSNumber
                        blinkAnimation.toValue = 0.0 as NSNumber
                        blinkAnimation.duration = 0.5
                        self.pop_add(blinkAnimation, forKey: "blinkProgress")
                    } else if seekingProgress > 0.0 && seekingProgress < 0.05 && fraction > 0.98 {
                        self.hapticFeedback.impact(.light)
                        
                        let blinkAnimation = POPBasicAnimation()
                        blinkAnimation.property = POPAnimatableProperty.property(withName: "blinkProgress", initializer: { property in
                            property?.readBlock = { node, values in
                                values?.pointee = (node as! InstantVideoRadialStatusNode).effectiveBlinkProgress
                            }
                            property?.writeBlock = { node, values in
                                (node as! InstantVideoRadialStatusNode).effectiveBlinkProgress = values!.pointee
                            }
                            property?.threshold = 0.01
                        }) as? POPAnimatableProperty
                        blinkAnimation.fromValue = -1.0 as NSNumber
                        blinkAnimation.toValue = 0.0 as NSNumber
                        blinkAnimation.duration = 0.5
                        self.pop_add(blinkAnimation, forKey: "blinkProgress")
                    }
                }
                let newProgress = min(0.99, fraction)
                if let seekingProgress = self.seekingProgress, abs(seekingProgress - CGFloat(newProgress)) < 0.005 {
                } else {
                    self.seekTo?(newProgress, false)
                    self.seekingProgress = CGFloat(fraction)
                }
            case .ended, .cancelled:
                self.seeking = false
                self.seekTo?(min(0.99, fraction), true)
                self.seekingProgress = nil
            default:
                break
        }
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return InstantVideoRadialStatusNodeParameters(color: self.color, progress: self.effectiveProgress, dimProgress: self.effectiveDimProgress, playProgress: self.effectivePlayProgress, blinkProgress: self.effectiveBlinkProgress, hasSeek: self.hasSeek)
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
            
            context.addEllipse(in: bounds)
            context.clip()
            
            if !parameters.dimProgress.isZero {
                if parameters.playProgress == 1.0 {
                    context.setFillColor(UIColor(rgb: 0x000000, alpha: 0.35 * min(1.0, parameters.dimProgress)).cgColor)
                    context.fillEllipse(in: bounds)
                } else {
                    var locations: [CGFloat] = [0.0, 0.8, 1.0]
                    let alpha: CGFloat = 0.2 + 0.15 * parameters.playProgress
                    let colors: [CGColor] = [UIColor(rgb: 0x000000, alpha: alpha * min(1.0, parameters.dimProgress * parameters.playProgress)).cgColor, UIColor(rgb: 0x000000, alpha: alpha * min(1.0, parameters.dimProgress * parameters.playProgress)).cgColor, UIColor(rgb: 0x000000, alpha: alpha * min(1.0, parameters.dimProgress)).cgColor]
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
                    
                    let center = bounds.center
                    context.drawRadialGradient(gradient, startCenter: center, startRadius: 0.0, endCenter: center, endRadius: bounds.width / 2.0, options: .drawsAfterEndLocation)
                }
            }
            
            context.setBlendMode(.normal)
            
            var progress = parameters.progress
            let startAngle = -CGFloat.pi / 2.0
            let endAngle = CGFloat(progress) * 2.0 * CGFloat.pi + startAngle
            
            progress = min(1.0, progress)
            
            var lineWidth: CGFloat = 4.0
            if parameters.hasSeek {
                lineWidth += 1.0 * parameters.dimProgress
            }
            
            var pathDiameter = bounds.size.width - lineWidth - 8.0
            if parameters.hasSeek {
                pathDiameter -= (18.0 * 2.0) * parameters.dimProgress
            }
                
            if !parameters.dimProgress.isZero {
                context.setLineWidth(lineWidth)
                
                if parameters.blinkProgress > 0.0 {
                    context.setStrokeColor(parameters.color.withAlphaComponent(0.2 * parameters.blinkProgress).cgColor)
                    context.strokeEllipse(in: CGRect(x: (bounds.size.width - pathDiameter) / 2.0 , y: (bounds.size.height - pathDiameter) / 2.0, width: pathDiameter, height: pathDiameter))
                }
                
                if parameters.hasSeek {
                    var progress = parameters.dimProgress
                    if parameters.blinkProgress < 0.0 {
                        progress = parameters.dimProgress + parameters.blinkProgress
                    }
                    context.setStrokeColor(parameters.color.withAlphaComponent(0.2 * progress).cgColor)
                    context.strokeEllipse(in: CGRect(x: (bounds.size.width - pathDiameter) / 2.0 , y: (bounds.size.height - pathDiameter) / 2.0, width: pathDiameter, height: pathDiameter))
                }
                    
                if !parameters.playProgress.isZero {
                    context.saveGState()
                    context.translateBy(x: bounds.width / 2.0, y: bounds.height / 2.0)
                    if parameters.hasSeek {
                        context.scaleBy(x: 1.0 + 1.4 * parameters.playProgress, y: 1.0 + 1.4 * parameters.playProgress)
                    } else {
                        context.scaleBy(x: 1.0 + 0.7 * parameters.playProgress, y: 1.0 + 0.7 * parameters.playProgress)
                    }
                    context.translateBy(x: -bounds.width / 2.0, y: -bounds.height / 2.0)
                    
                    let iconSize = CGSize(width: 15.0, height: 18.0)
                    context.translateBy(x: (bounds.width - iconSize.width) / 2.0 + 2.0, y: (bounds.height - iconSize.height) / 2.0)
                
                    context.setFillColor(UIColor(rgb: 0xffffff).withAlphaComponent(min(1.0, parameters.playProgress)).cgColor)
                    let _ = try? drawSvgPath(context, path: "M1.71891969,0.209353049 C0.769586558,-0.350676705 0,0.0908839327 0,1.18800046 L0,16.8564753 C0,17.9569971 0.750549162,18.357187 1.67393713,17.7519379 L14.1073836,9.60224049 C15.0318735,8.99626906 15.0094718,8.04970371 14.062401,7.49100858 L1.71891969,0.209353049 ")
                    context.fillPath()
                    
                    context.restoreGState()
                }
            }
                
            context.setStrokeColor(parameters.color.cgColor)
            let path = UIBezierPath(arcCenter: CGPoint(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0), radius: pathDiameter / 2.0, startAngle: startAngle, endAngle: endAngle, clockwise:true)
            path.lineWidth = lineWidth
            path.lineCapStyle = .round
            path.stroke()
            
            if parameters.hasSeek {
                let handleSide = 16.0 * min(1.0, (parameters.dimProgress * 2.0))
                let handleSize = CGSize(width: handleSide, height: handleSide)
                let handlePosition = CGPoint(x: 0.5 * pathDiameter * cos(endAngle), y: 0.5 * pathDiameter * sin(endAngle)).offsetBy(dx: bounds.size.width / 2.0, dy: bounds.size.height / 2.0)
                let handleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(handlePosition.x - handleSize.width / 2.0), y: floorToScreenPixels(handlePosition.y - handleSize.height / 2.0)), size: handleSize)
                context.setFillColor(UIColor.white.cgColor)
                context.fillEllipse(in: handleFrame)
            }
        }
    }
    
    private func updateProgress() {
        let timestampAndDuration: (timestamp: Double, duration: Double, baseRate: Double)?
        if let statusValue = self.statusValue, Double(0.0).isLess(than: statusValue.duration) {
            timestampAndDuration = (statusValue.timestamp, statusValue.duration, statusValue.baseRate)
        } else {
            timestampAndDuration = nil
        }
        
        var dimmed = false
        if let statusValue = self.statusValue {
            dimmed = statusValue.status == .paused
        }
        if self.seeking {
            dimmed = true
        }
                
        if dimmed != self.dimmed {
            self.dimmed = dimmed
            
            let animation = POPSpringAnimation()
            animation.property = POPAnimatableProperty.property(withName: "dimProgress", initializer: { property in
                property?.readBlock = { node, values in
                    values?.pointee = (node as! InstantVideoRadialStatusNode).effectiveDimProgress
                }
                property?.writeBlock = { node, values in
                    (node as! InstantVideoRadialStatusNode).effectiveDimProgress = values!.pointee
                }
                property?.threshold = 0.01
            }) as? POPAnimatableProperty
            animation.fromValue = self.effectiveDimProgress as NSNumber
            animation.toValue = (dimmed ? 1.0 : 0.0) as NSNumber
            animation.springSpeed = 20
            animation.springBounciness = 8
            self.pop_add(animation, forKey: "dimProgress")
            
            let playAnimation = POPSpringAnimation()
            playAnimation.property = POPAnimatableProperty.property(withName: "playProgress", initializer: { property in
                property?.readBlock = { node, values in
                    values?.pointee = (node as! InstantVideoRadialStatusNode).effectivePlayProgress
                }
                property?.writeBlock = { node, values in
                    (node as! InstantVideoRadialStatusNode).effectivePlayProgress = values!.pointee
                }
                property?.threshold = 0.01
            }) as? POPAnimatableProperty
            playAnimation.fromValue = self.effectivePlayProgress as NSNumber
            playAnimation.toValue = (dimmed ? 1.0 : 0.0) as NSNumber
            playAnimation.springSpeed = 20
            playAnimation.springBounciness = 8
            self.pop_add(playAnimation, forKey: "playProgress")
        }
        
        if self.seeking, let progress = self.seekingProgress {
            self.pop_removeAnimation(forKey: "progress")
            self.effectiveProgress = progress
        } else if let (timestamp, duration, baseRate) = timestampAndDuration, let statusValue = self.statusValue {
            let progress = CGFloat(timestamp / duration)
            
            if progress.isNaN || !progress.isFinite {
                self.pop_removeAnimation(forKey: "progress")
                self.effectiveProgress = 0.0
            } else if statusValue.status != .playing || statusValue.generationTimestamp.isZero {
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
                }) as? POPAnimatableProperty
                animation.fromValue = progress as NSNumber
                animation.toValue = 1.0 as NSNumber
                animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
                animation.duration = max(0.0, duration - timestamp) / baseRate
                animation.beginTime = statusValue.generationTimestamp
                self.pop_add(animation, forKey: "progress")
            }
        } else {
            self.pop_removeAnimation(forKey: "dimProgress")
            self.effectiveDimProgress = 0.0
            
            self.pop_removeAnimation(forKey: "progress")
            self.effectiveProgress = 0.0
        }
    }
}
