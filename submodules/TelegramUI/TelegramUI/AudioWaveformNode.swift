import Foundation
import UIKit
import Display
import AsyncDisplayKit

private final class AudioWaveformNodeParameters: NSObject {
    let waveform: AudioWaveform?
    let color: UIColor?
    
    init(waveform: AudioWaveform?, color: UIColor?) {
        self.waveform = waveform
        self.color = color
        
        super.init()
    }
}

final class AudioWaveformNode: ASDisplayNode {
    private var waveform: AudioWaveform?
    private var color: UIColor?
    
    override init() {
        super.init()
        
        self.isOpaque = false
    }
    
    override var frame: CGRect {
        get {
            return super.frame
        } set(value) {
            let redraw = value.size != self.frame.size
            super.frame = value
            
            if redraw {
                self.setNeedsDisplay()
            }
        }
    }
    
    func setup(color: UIColor, waveform: AudioWaveform?) {
        if self.color == nil || !self.color!.isEqual(color) || self.waveform != waveform {
            self.color = color
            self.waveform = waveform
            self.setNeedsDisplay()
        }
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return AudioWaveformNodeParameters(waveform: self.waveform, color: self.color)
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        if let parameters = parameters as? AudioWaveformNodeParameters {
            let sampleWidth: CGFloat = 2.0
            let halfSampleWidth: CGFloat = 1.0
            let distance: CGFloat = 1.0
            
            let size = bounds.size
            
            if let color = parameters.color {
                context.setFillColor(color.cgColor)
            }
            
            if let waveform = parameters.waveform {
                waveform.samples.withUnsafeBytes { (samples: UnsafePointer<UInt16>) -> Void in
                    let peakHeight: CGFloat = 12.0
                    let maxReadSamples = waveform.samples.count / 2
                    
                    var maxSample: UInt16 = 0
                    for i in 0 ..< maxReadSamples {
                        let sample = samples[i]
                        if maxSample < sample {
                            maxSample = sample
                        }
                    }
                    
                    let invScale = 1.0 / max(1.0, CGFloat(maxSample))
                    let numSamples = Int(floor(size.width / (sampleWidth + distance)))
                    
                    let adjustedSamplesMemory = malloc(numSamples * 2)!
                    let adjustedSamples = adjustedSamplesMemory.assumingMemoryBound(to: UInt16.self)
                    defer {
                        free(adjustedSamplesMemory)
                    }
                    memset(adjustedSamplesMemory, 0, numSamples * 2)
                    
                    for i in 0 ..< maxReadSamples {
                        let index = i * numSamples / maxReadSamples
                        let sample = samples[i]
                        if adjustedSamples[index] < sample {
                            adjustedSamples[index] = sample
                        }
                    }
                    
                    for i in 0 ..< numSamples {
                        let offset = CGFloat(i) * (sampleWidth + distance)
                        let peakSample = adjustedSamples[i]
                        
                        var sampleHeight = CGFloat(peakSample) * peakHeight * invScale
                        if abs(sampleHeight) > peakHeight {
                            sampleHeight = peakHeight
                        }
                        
                        let adjustedSampleHeight = sampleHeight - sampleWidth
                        if adjustedSampleHeight.isLessThanOrEqualTo(sampleWidth) {
                            context.fillEllipse(in: CGRect(x: offset, y: size.height - sampleWidth, width: sampleWidth, height: sampleWidth))
                            context.fill(CGRect(x: offset, y: size.height - halfSampleWidth, width: sampleWidth, height: halfSampleWidth))
                        } else {
                            let adjustedRect = CGRect(x: offset, y: size.height - adjustedSampleHeight, width: sampleWidth, height: adjustedSampleHeight)
                            context.fill(adjustedRect)
                            context.fillEllipse(in: CGRect(x: adjustedRect.minX, y: adjustedRect.minY - halfSampleWidth, width: sampleWidth, height: sampleWidth))
                            context.fillEllipse(in: CGRect(x: adjustedRect.minX, y: adjustedRect.maxY - halfSampleWidth, width: sampleWidth, height: sampleWidth))
                        }
                    }
                }
            } else {
                context.fill(CGRect(x: halfSampleWidth, y: size.height - sampleWidth, width: size.width - sampleWidth, height: sampleWidth))
                context.fillEllipse(in: CGRect(x: 0.0, y: size.height - sampleWidth, width: sampleWidth, height: sampleWidth))
                context.fillEllipse(in: CGRect(x: size.width - sampleWidth, y: size.height - sampleWidth, width: sampleWidth, height: sampleWidth))
            }
        }
    }
}
