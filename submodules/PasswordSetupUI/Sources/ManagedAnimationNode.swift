import Foundation
import UIKit
import Display
import AsyncDisplayKit
import RLottieBinding
import AppBundle
import GZip

enum ManagedAnimationTrackState {
    case intro
    case loop
    case outro
}

private final class ManagedAnimationState {
    var item: ManagedAnimationItem
    
    private let instance: LottieInstance
    
    let frameCount: Int
    let fps: Double
    
    var startTime: Double?
    var trackState: ManagedAnimationTrackState?
    var trackingFrameState: (Int, Int)?
    var frameIndex: Int?
    
    private let renderContext: DrawingContext
    
    init?(item: ManagedAnimationItem) {
        guard let path = getAppBundle().path(forResource: item.name, ofType: "tgs") else {
            return nil
        }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        guard let unpackedData = TGGUnzipData(data, 5 * 1024 * 1024) else {
            return nil
        }
        guard let instance = LottieInstance(data: unpackedData, cacheKey: item.name) else {
            return nil
        }
        
        self.item = item
        self.instance = instance
        
        self.frameCount = Int(instance.frameCount)
        self.fps = Double(instance.frameRate)
        
        self.renderContext = DrawingContext(size: instance.dimensions, scale: UIScreenScale, premultiplied: true, clear: true)
    }
    
    func draw() -> UIImage? {
        self.instance.renderFrame(with: Int32(self.frameIndex ?? 0), into: self.renderContext.bytes.assumingMemoryBound(to: UInt8.self), width: Int32(self.renderContext.size.width * self.renderContext.scale), height: Int32(self.renderContext.size.height * self.renderContext.scale), bytesPerRow: Int32(self.renderContext.bytesPerRow))
        return self.renderContext.generateImage()
    }
}

enum ManagedAnimationActionAtEnd {
    case pause
    case advance
    case loop
}

struct ManagedAnimationTrack: Equatable {
    let frameRange: Range<Int>
}

struct ManagedAnimationItem: Equatable {
    let name: String
    var intro: ManagedAnimationTrack?
    var loop: ManagedAnimationTrack?
    var outro: ManagedAnimationTrack?
}

final class ManagedAnimationNode: ASDisplayNode {
    let intrinsicSize: CGSize
    
    private let imageNode: ASImageNode
    private let displayLink: CADisplayLink
    
    private var items: [ManagedAnimationState] = []
    
    var currentItemName: String? {
        return self.items.first?.item.name
    }
    
    init(size: CGSize) {
        self.intrinsicSize = size
        
        self.imageNode = ASImageNode()
        self.imageNode.displayWithoutProcessing = true
        self.imageNode.displaysAsynchronously = false
        self.imageNode.frame = CGRect(origin: CGPoint(), size: self.intrinsicSize)
        
        final class DisplayLinkTarget: NSObject {
            private let f: () -> Void
            
            init(_ f: @escaping () -> Void) {
                self.f = f
            }
            
            @objc func event() {
                self.f()
            }
        }
        var displayLinkUpdate: (() -> Void)?
        self.displayLink = CADisplayLink(target: DisplayLinkTarget {
            displayLinkUpdate?()
        }, selector: #selector(DisplayLinkTarget.event))
        
        super.init()
        
        self.addSubnode(self.imageNode)
        
        self.displayLink.add(to: RunLoop.main, forMode: .common)
        
        displayLinkUpdate = { [weak self] in
            self?.updateAnimation()
        }
    }
    
    private func updateAnimation() {
        guard let item = self.items.first else {
            return
        }
        let timestamp = CACurrentMediaTime()
        var startTime: Double
        let maybeTrackState: ManagedAnimationTrackState?
        if let current = item.startTime {
            startTime = current
        } else {
            startTime = timestamp
            item.startTime = startTime
        }
        if let current = item.trackState {
            maybeTrackState = current
        } else if let _ = item.item.intro {
            maybeTrackState = .intro
        } else if let _ = item.item.loop {
            maybeTrackState = .loop
        } else if let _ = item.item.outro {
            maybeTrackState = .outro
        } else {
            maybeTrackState = nil
        }
        if item.trackState != maybeTrackState {
            item.trackState = maybeTrackState
            item.startTime = timestamp
            startTime = timestamp
        }
        
        guard let trackState = maybeTrackState else {
            self.items.removeFirst()
            return
        }
        
        var fps = item.fps
        
        let track: ManagedAnimationTrack
        switch trackState {
        case .intro:
            track = item.item.intro!
        case .loop:
            track = item.item.loop!
            if self.items.count > 1 {
                //fps *= 2.0
            }
        case .outro:
            track = item.item.outro!
        }
        
        let frameIndex: Int
        if let (startFrame, endFrame) = item.trackingFrameState {
            let duration: Double = 0.3
            var t = (timestamp - startTime) / duration
            t = max(0.0, t)
            t = min(1.0, t)
            let frameOffset = Int(Double(startFrame) * (1.0 - t) + Double(endFrame) * t)
            let lowerBound = min(track.frameRange.lowerBound, item.frameCount - 1)
            let upperBound = min(track.frameRange.upperBound, item.frameCount)
            frameIndex = max(lowerBound, min(upperBound, frameOffset))
        } else {
            let frameOffset = Int((timestamp - startTime) * fps)
            let lowerBound = min(track.frameRange.lowerBound, item.frameCount - 1)
            let upperBound = min(track.frameRange.upperBound, item.frameCount)
            if frameOffset >= upperBound - lowerBound {
                switch trackState {
                case .intro:
                    if let _ = item.item.loop {
                        item.trackState = .loop
                        item.startTime = timestamp
                        return
                    } else if let _ = item.item.outro {
                        item.trackState = .outro
                        item.startTime = timestamp
                        return
                    } else {
                        self.items.removeFirst()
                        return
                    }
                case .loop:
                    if self.items.count > 1 {
                        if let _ = item.item.outro {
                            item.trackState = .outro
                            item.startTime = timestamp
                        } else {
                            self.items.removeFirst()
                        }
                        return
                    } else {
                        item.startTime = timestamp
                        frameIndex = lowerBound
                    }
                case .outro:
                    self.items.removeFirst()
                    return
                }
            } else {
                frameIndex = lowerBound + frameOffset % (upperBound - lowerBound)
            }
        }
        
        if item.frameIndex != frameIndex {
            item.frameIndex = frameIndex
            if let image = item.draw() {
                self.imageNode.image = image
            }
        }
    }
    
    func switchTo(_ item: ManagedAnimationItem, noOutro: Bool = false) {
        if let state = ManagedAnimationState(item: item) {
            if let last = self.items.last {
                if last.item.name == item.name {
                    return
                }
            }
            if let first = self.items.first {
                if noOutro {
                    first.item.outro = nil
                }
            }
            self.items.append(state)
            self.updateAnimation()
        }
    }
    
    func trackTo(frameIndex: Int) {
        if let first = self.items.first {
            first.startTime = CACurrentMediaTime()
            first.trackingFrameState = (first.frameIndex ?? 0, frameIndex)
            self.updateAnimation()
        }
    }
}
