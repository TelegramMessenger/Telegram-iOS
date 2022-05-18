import Foundation
import UIKit
import ComponentFlow
import Display
import ShimmerEffect
import UniversalMediaPlayer
import SwiftSignalKit

public final class AudioWaveformComponent: Component {
    public let backgroundColor: UIColor
    public let foregroundColor: UIColor
    public let shimmerColor: UIColor?
    public let samples: Data
    public let peak: Int32
    public let status: Signal<MediaPlayerStatus, NoError>
    
    public init(
        backgroundColor: UIColor,
        foregroundColor: UIColor,
        shimmerColor: UIColor?,
        samples: Data,
        peak: Int32,
        status: Signal<MediaPlayerStatus, NoError>
    ) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.shimmerColor = shimmerColor
        self.samples = samples
        self.peak = peak
        self.status = status
    }
    
    public static func ==(lhs: AudioWaveformComponent, rhs: AudioWaveformComponent) -> Bool {
        if lhs.backgroundColor !== rhs.backgroundColor {
            return false
        }
        if lhs.foregroundColor != rhs.foregroundColor {
            return false
        }
        if lhs.shimmerColor != rhs.shimmerColor {
            return false
        }
        if lhs.samples != rhs.samples {
            return false
        }
        if lhs.peak != rhs.peak {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private struct ShimmerParams: Equatable {
            var backgroundColor: UIColor
            var foregroundColor: UIColor
        }
        
        private final class LayerImpl: SimpleLayer {
            private var shimmerNode: ShimmerEffectNode?
            private var shimmerMask: SimpleLayer?
            
            var shimmerParams: ShimmerParams? {
                didSet {
                    if (self.shimmerParams != nil) != (oldValue != nil) {
                        if self.shimmerParams != nil {
                            if self.shimmerNode == nil {
                                let shimmerNode = ShimmerEffectNode()
                                shimmerNode.isLayerBacked = true
                                self.shimmerNode = shimmerNode
                                self.addSublayer(shimmerNode.layer)
                                
                                let shimmerMask = SimpleLayer()
                                shimmerNode.layer.mask = shimmerMask
                                shimmerMask.contents = self.contents
                                shimmerMask.frame = self.bounds
                                self.shimmerMask = shimmerMask
                            }
                            
                            self.updateShimmer()
                        } else {
                            if let shimmerNode = self.shimmerNode {
                                self.shimmerNode = nil
                                shimmerNode.layer.removeFromSuperlayer()
                                
                                self.shimmerMask = nil
                            }
                        }
                    }
                }
            }
            
            private func updateShimmer() {
                guard let shimmerNode = self.shimmerNode, !self.bounds.width.isZero, let shimmerParams = self.shimmerParams else {
                    return
                }
                
                shimmerNode.frame = self.bounds
                shimmerNode.updateAbsoluteRect(self.bounds, within: CGSize(width: self.bounds.size.width + 60.0, height: self.bounds.size.height + 4.0))

                var shapes: [ShimmerEffectNode.Shape] = []
                shapes.append(.rect(rect: CGRect(origin: CGPoint(), size: self.bounds.size)))
                shimmerNode.update(
                    backgroundColor: .clear,
                    foregroundColor: shimmerParams.backgroundColor,
                    shimmeringColor: shimmerParams.foregroundColor,
                    shapes: shapes,
                    horizontal: true,
                    effectSize: 60.0,
                    globalTimeOffset: false,
                    duration: 0.7,
                    size: self.bounds.size
                )
            }
            
            override func display() {
                if self.bounds.size.width.isZero {
                    return
                }
                
                UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, 0.0)
                if let view = self.delegate as? View {
                    view.draw(CGRect(origin: CGPoint(), size: self.bounds.size))
                }
                let image = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                if let image = image {
                    let previousContents = self.contents
                    
                    self.contents = image.cgImage
                    
                    if let shimmerMask = self.shimmerMask {
                        shimmerMask.contents = image.cgImage
                        shimmerMask.frame = self.bounds
                        
                        self.updateShimmer()
                    }
                    
                    if let previousContents = previousContents, let contents = self.contents {
                        self.animate(from: previousContents as AnyObject, to: contents as AnyObject, keyPath: "contents", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.15)
                    }
                }
            }
        }
        
        override public static var layerClass: AnyClass {
            return LayerImpl.self
        }
        
        private var component: AudioWaveformComponent?
        private var validSize: CGSize?
        
        private var playbackStatus: MediaPlayerStatus?
        private var scrubbingTimestampValue: Double?
        private var statusDisposable: Disposable?
        private var playbackStatusAnimator: ConstantDisplayLinkAnimator?
        
        private var revealProgress: CGFloat = 1.0
        private var animator: DisplayLinkAnimator?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.backgroundColor = nil
            self.isOpaque = false
            
            (self.layer as! LayerImpl).didEnterHierarchy = { [weak self] in
                self?.updatePlaybackAnimation()
            }
            (self.layer as! LayerImpl).didExitHierarchy = { [weak self] in
                self?.updatePlaybackAnimation()
            }
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.statusDisposable?.dispose()
        }
        
        public func animateIn() {
            if self.animator == nil {
                self.revealProgress = 0.0
                self.setNeedsDisplay()
                
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.08, execute: {
                    self.animator = DisplayLinkAnimator(duration: 0.8, from: 0.0, to: 1.0, update: { [weak self] progress in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.revealProgress = progress
                        strongSelf.setNeedsDisplay()
                    }, completion: { [weak self] in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.animator?.invalidate()
                        strongSelf.animator = nil
                    })
                })
            }
        }
        
        func update(component: AudioWaveformComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            let size = CGSize(width: availableSize.width, height: availableSize.height)
            
            if self.validSize != size || self.component?.samples != component.samples || self.component?.peak != component.peak {
                self.setNeedsDisplay()
            }
            
            (self.layer as! LayerImpl).shimmerParams = component.shimmerColor.flatMap { shimmerColor in
                return ShimmerParams(
                    backgroundColor: component.backgroundColor,
                    foregroundColor: shimmerColor
                )
            }
            
            self.component = component
            self.validSize = size
            
            if self.statusDisposable == nil {
                self.statusDisposable = (component.status
                |> deliverOnMainQueue).start(next: { [weak self] value in
                    guard let strongSelf = self else {
                        return
                    }
                    if strongSelf.playbackStatus != value {
                        strongSelf.playbackStatus = value
                        strongSelf.setNeedsDisplay()
                        strongSelf.updatePlaybackAnimation()
                    }
                })
            }
            
            return size
        }
        
        private func updatePlaybackAnimation() {
            var needsAnimation = false
            if let playbackStatus = self.playbackStatus {
                switch playbackStatus.status {
                case .playing:
                    needsAnimation = true
                default:
                    needsAnimation = false
                }
            }
            
            if needsAnimation != (self.playbackStatusAnimator != nil) {
                if needsAnimation {
                    self.playbackStatusAnimator = ConstantDisplayLinkAnimator(update: { [weak self] in
                        self?.setNeedsDisplay()
                    })
                    self.playbackStatusAnimator?.isPaused = false
                } else {
                    self.playbackStatusAnimator?.invalidate()
                    self.playbackStatusAnimator = nil
                }
            }
        }
        
        override public func draw(_ rect: CGRect) {
            guard let component = self.component else {
                return
            }
            guard let context = UIGraphicsGetCurrentContext() else {
                return
            }
            
            let timestampAndDuration: (timestamp: Double, duration: Double)?
            var isPlaying = false
            if let statusValue = self.playbackStatus, Double(0.0).isLess(than: statusValue.duration) {
                switch statusValue.status {
                case .playing:
                    isPlaying = true
                default:
                    break
                }
                
                if let scrubbingTimestampValue = self.scrubbingTimestampValue {
                    timestampAndDuration = (max(0.0, min(scrubbingTimestampValue, statusValue.duration)), statusValue.duration)
                } else {
                    timestampAndDuration = (statusValue.timestamp, statusValue.duration)
                }
            } else {
                timestampAndDuration = nil
            }
            
            let playbackProgress: CGFloat
            if let (timestamp, duration) = timestampAndDuration {
                if let scrubbingTimestampValue = self.scrubbingTimestampValue {
                    var progress = CGFloat(scrubbingTimestampValue / duration)
                    if progress.isNaN || !progress.isFinite {
                        progress = 0.0
                    }
                    progress = max(0.0, min(1.0, progress))
                    playbackProgress = progress
                } else if let statusValue = self.playbackStatus {
                    let actualTimestamp: Double
                    if statusValue.generationTimestamp.isZero || !isPlaying {
                        actualTimestamp = timestamp
                    } else {
                        let currentTimestamp = CACurrentMediaTime()
                        actualTimestamp = timestamp + (currentTimestamp - statusValue.generationTimestamp) * statusValue.baseRate
                    }
                    var progress = CGFloat(actualTimestamp / duration)
                    if progress.isNaN || !progress.isFinite {
                        progress = 0.0
                    }
                    progress = max(0.0, min(1.0, progress))
                    playbackProgress = progress
                } else {
                    playbackProgress = 0.0
                }
            } else {
                playbackProgress = 0.0
            }
            
            let sampleWidth: CGFloat = 2.0
            let halfSampleWidth: CGFloat = 1.0
            let distance: CGFloat = 2.0
            
            let size = bounds.size
            
            component.samples.withUnsafeBytes { rawSamples -> Void in
                let samples = rawSamples.baseAddress!.assumingMemoryBound(to: UInt16.self)
                
                let peakHeight: CGFloat = 18.0
                let maxReadSamples = rawSamples.count / 2
                
                var maxSample: UInt16 = 0
                for i in 0 ..< maxReadSamples {
                    let sample = samples[i]
                    if maxSample < sample {
                        maxSample = sample
                    }
                }
                
                let numSamples = Int(floor(size.width / (sampleWidth + distance)))
                
                let adjustedSamplesMemory = malloc(numSamples * 2)!
                let adjustedSamples = adjustedSamplesMemory.assumingMemoryBound(to: UInt16.self)
                defer {
                    free(adjustedSamplesMemory)
                }
                memset(adjustedSamplesMemory, 0, numSamples * 2)
                
                var generateFakeSamples = false
                
                var bins: [UInt16: Int] = [:]
                for i in 0 ..< maxReadSamples {
                    let index = i * numSamples / maxReadSamples
                    let sample = samples[i]
                    if adjustedSamples[index] < sample {
                        adjustedSamples[index] = sample
                    }
                  
                    if let count = bins[sample] {
                        bins[sample] = count + 1
                    } else {
                        bins[sample] = 1
                    }
                }
                
                var sortedSamples: [(UInt16, Int)] = []
                var totalCount: Int = 0
                for (sample, count) in bins {
                    if sample > 0 {
                        sortedSamples.append((sample, count))
                        totalCount += count
                    }
                }
                sortedSamples.sort { $0.1 > $1.1 }
                
                let topSamples = sortedSamples.prefix(1)
                let topCount = topSamples.map{ $0.1 }.reduce(.zero, +)
                var topCountPercent: Float = 0.0
                if bins.count > 0 {
                    topCountPercent = Float(topCount) / Float(totalCount)
                }
                
                if topCountPercent > 0.75 {
                    generateFakeSamples = true
                }
                
                if generateFakeSamples {
                    if maxSample < 10 {
                        maxSample = 20
                    }
                    for i in 0 ..< maxReadSamples {
                        let index = i * numSamples / maxReadSamples
                        adjustedSamples[index] = UInt16.random(in: 6...maxSample)
                    }
                }
                
                let invScale = 1.0 / max(1.0, CGFloat(maxSample))
                
                let commonRevealFraction = listViewAnimationCurveSystem(self.revealProgress)
                
                for i in 0 ..< numSamples {
                    let offset = CGFloat(i) * (sampleWidth + distance)
                    let peakSample = adjustedSamples[i]
                    
                    var sampleHeight = CGFloat(peakSample) * peakHeight * invScale
                    if abs(sampleHeight) > peakHeight {
                        sampleHeight = peakHeight
                    }
                    
                    let startFraction = CGFloat(i) / CGFloat(numSamples)
                    let nextStartFraction = CGFloat(i + 1) / CGFloat(numSamples)
                    
                    if startFraction < commonRevealFraction {
                        let currentVerticalProgress: CGFloat = max(0.0, min(1.0, max(0.0, commonRevealFraction - startFraction) / (1.0 - startFraction)))
                        sampleHeight *= currentVerticalProgress
                    } else {
                        sampleHeight *= 0.0
                    }
                    
                    let colorMixFraction: CGFloat
                    if startFraction < playbackProgress {
                        colorMixFraction = max(0.0, min(1.0, (playbackProgress - startFraction) / (playbackProgress - nextStartFraction)))
                    } else {
                        colorMixFraction = 0.0
                    }
                    
                    let diff: CGFloat
                    diff = sampleWidth * 1.5
                    
                    let gravityMultiplierY: CGFloat
                    gravityMultiplierY = 1.0
                    
                    /*switch parameters.gravity ?? .bottom {
                    case .bottom:
                        return 1
                    case .center:
                        return 0.5
                    }*/
                    
                    context.setFillColor(component.backgroundColor.mixedWith(component.foregroundColor, alpha: colorMixFraction).cgColor)
                    
                    let adjustedSampleHeight = sampleHeight - diff
                    if adjustedSampleHeight.isLessThanOrEqualTo(sampleWidth) {
                        context.fillEllipse(in: CGRect(x: offset, y: (size.height - sampleWidth) * gravityMultiplierY, width: sampleWidth, height: sampleWidth))
                    } else {
                        let adjustedRect = CGRect(
                            x: offset,
                            y: (size.height - adjustedSampleHeight) * gravityMultiplierY,
                            width: sampleWidth,
                            height: adjustedSampleHeight - halfSampleWidth
                        )
                        context.fill(adjustedRect)
                        context.fillEllipse(in: CGRect(x: adjustedRect.minX, y: adjustedRect.minY - halfSampleWidth, width: sampleWidth, height: sampleWidth))
                        context.fillEllipse(in: CGRect(x: adjustedRect.minX, y: adjustedRect.maxY - halfSampleWidth, width: sampleWidth, height: sampleWidth))
                    }
                }
            }
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
