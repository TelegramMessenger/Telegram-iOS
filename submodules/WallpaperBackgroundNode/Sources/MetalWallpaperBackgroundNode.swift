import Foundation
import UIKit
import AsyncDisplayKit
import Display
import GradientBackground
import TelegramPresentationData
import TelegramCore
import AccountContext
import SwiftSignalKit
import WallpaperResources
import FastBlur
import Svg
import GZip
import AppBundle
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import HierarchyTrackingLayer
import MetalKit
import HierarchyTrackingLayer
import simd

private final class NullActionClass: NSObject, CAAction {
    static let shared = NullActionClass()
    
    @objc public func run(forKey event: String, object anObject: Any, arguments dict: [AnyHashable : Any]?) {
    }
}

@available(iOS 13.0, *)
open class SimpleMetalLayer: CAMetalLayer {
    override open func action(forKey event: String) -> CAAction? {
        return nullAction
    }
    
    override public init() {
        super.init()
    }
    
    override public init(layer: Any) {
        super.init(layer: layer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private func makePipelineState(device: MTLDevice, library: MTLLibrary, vertexProgram: String, fragmentProgram: String) -> MTLRenderPipelineState? {
    guard let loadedVertexProgram = library.makeFunction(name: vertexProgram) else {
        return nil
    }
    guard let loadedFragmentProgram = library.makeFunction(name: fragmentProgram) else {
        return nil
    }

    let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
    pipelineStateDescriptor.vertexFunction = loadedVertexProgram
    pipelineStateDescriptor.fragmentFunction = loadedFragmentProgram
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineStateDescriptor) else {
        return nil
    }

    return pipelineState
}


@available(iOS 13.0, *)
final class MetalWallpaperBackgroundNode: ASDisplayNode, WallpaperBackgroundNode {
    private let device: MTLDevice
    private let metalLayer: SimpleMetalLayer
    private let commandQueue: MTLCommandQueue
    private let renderPipelineState: MTLRenderPipelineState
    
    private let hierarchyTrackingLayer = HierarchyTrackingLayer()
    
    var isReady: Signal<Bool, NoError> {
        return .single(true)
    }
    
    var rotation: CGFloat = 0.0
    
    private var animationPhase: Int = 0
    
    private var animationThread: Thread?
    private var displayLink: CADisplayLink?
    
    override init() {
        self.device = MTLCreateSystemDefaultDevice()!
        self.metalLayer = SimpleMetalLayer()
        self.metalLayer.maximumDrawableCount = 3
        self.metalLayer.presentsWithTransaction = true
        self.metalLayer.contentsScale = UIScreenScale
        self.commandQueue = self.device.makeCommandQueue()!
        
        let mainBundle = Bundle(for: MetalWallpaperBackgroundNode.self)

        guard let path = mainBundle.path(forResource: "WallpaperBackgroundNodeBundle", ofType: "bundle") else {
            preconditionFailure()
        }
        guard let bundle = Bundle(path: path) else {
            preconditionFailure()
        }
        guard let defaultLibrary = try? self.device.makeDefaultLibrary(bundle: bundle) else {
            preconditionFailure()
        }

        guard let renderPipelineState = makePipelineState(device: self.device, library: defaultLibrary, vertexProgram: "wallpaperVertex", fragmentProgram: "wallpaperFragment") else {
            preconditionFailure()
        }
        self.renderPipelineState = renderPipelineState
        
        super.init()
        
        self.metalLayer.device = self.device
        self.metalLayer.pixelFormat = .bgra8Unorm
        self.metalLayer.framebufferOnly = true
        self.metalLayer.allowsNextDrawableTimeout = true
        self.metalLayer.isOpaque = true
        
        self.layer.addSublayer(self.metalLayer)
        self.layer.addSublayer(self.hierarchyTrackingLayer)
        
        self.hierarchyTrackingLayer.opacity = 0.0
        self.hierarchyTrackingLayer.didEnterHierarchy = { [weak self] in
            self?.updateIsVisible(true)
        }
        self.hierarchyTrackingLayer.didExitHierarchy = { [weak self] in
            self?.updateIsVisible(false)
        }
    }

    func update(wallpaper: TelegramWallpaper) {
        
    }
    
    func _internalUpdateIsSettingUpWallpaper() {
        
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        if self.metalLayer.drawableSize != size {
            self.metalLayer.drawableSize = size
            
            transition.updateFrame(layer: self.metalLayer, frame: CGRect(origin: CGPoint(), size: size))
            
            self.redraw()
        }
    }
    
    private func updateIsVisible(_ isVisible: Bool) {
        if isVisible {
            if self.displayLink == nil {
                let displayLink = CADisplayLink(target: DisplayLinkTarget { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.redraw()
                }, selector: #selector(DisplayLinkTarget.event))
                self.displayLink = displayLink
                if #available(iOS 15.0, iOSApplicationExtension 15.0, *) {
                    if "".isEmpty {
                        displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 60.0, maximum: 60.0, preferred: 60.0)
                    } else {
                        displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: Float(UIScreen.main.maximumFramesPerSecond), maximum: Float(UIScreen.main.maximumFramesPerSecond), preferred: Float(UIScreen.main.maximumFramesPerSecond))
                    }
                }
                displayLink.isPaused = false
                
                if !"".isEmpty {
                    self.animationThread = Thread(block: {
                        displayLink.add(to: .current, forMode: .common)
                        
                        while true {
                            if Thread.current.isCancelled {
                                break
                            }
                            RunLoop.current.run(until: .init(timeIntervalSinceNow: 1.0))
                        }
                    })
                    self.animationThread?.name = "MetalWallpaperBackgroundNode"
                    self.animationThread?.qualityOfService = .userInteractive
                    self.animationThread?.start()
                } else {
                    displayLink.add(to: .current, forMode: .common)
                }
            }
        } else {
            if let displayLink = self.displayLink {
                self.displayLink = nil
                
                displayLink.invalidate()
            }
            if let animationThread = self.animationThread {
                self.animationThread = nil
                animationThread.cancel()
            }
        }
    }
    
    private var previousDrawTime: Double?
    
    private func redraw() {
        let timestamp = CACurrentMediaTime()
        if let previousDrawTime = self.previousDrawTime {
            let _ = previousDrawTime
            //print("frame time \((timestamp - previousDrawTime) * 1000.0)")
        }
        self.previousDrawTime = timestamp
        
        self.animationPhase += 1
        let animationOffset = Float(self.animationPhase % 200) / 200.0
        let _ = animationOffset
        
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            return
        }
        guard let drawable = self.metalLayer.nextDrawable() else {
            return
        }
        
        let drawTime = CACurrentMediaTime() - timestamp
        if drawTime > 9.0 / 1000.0 {
            print("get time \(drawTime * 1000.0)")
        }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: 0.0,
            green: 0.0,
            blue: 0.0,
            alpha: 1.0
        )

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        var vertices: [Float] = [
            -1.0, -1.0,
            1.0, -1.0,
            -1.0, 1.0,
            1.0, 1.0
        ]
        
        renderEncoder.setRenderPipelineState(self.renderPipelineState)

        renderEncoder.setVertexBytes(&vertices, length: 4 * vertices.count, index: 0)
        
        var resolution = simd_uint2(UInt32(drawable.texture.width), UInt32(drawable.texture.height))
        renderEncoder.setFragmentBytes(&resolution, length: MemoryLayout<simd_uint2>.size * 2, index: 0)
        
        var time = Float(timestamp) * 0.25
        renderEncoder.setFragmentBytes(&time, length: 4, index: 1)

        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)
        
        renderEncoder.endEncoding()
        
        if self.metalLayer.presentsWithTransaction {
            if Thread.isMainThread {
                commandBuffer.commit()
                commandBuffer.waitUntilScheduled()
                drawable.present()
            } else {
                CATransaction.begin()
                commandBuffer.commit()
                commandBuffer.waitUntilScheduled()
                drawable.present()
                CATransaction.commit()
            }
        } else {
            commandBuffer.addScheduledHandler { _ in
                drawable.present()
            }
            commandBuffer.commit()
        }
    }
    
    func animateEvent(transition: ContainedViewLayoutTransition, extendAnimation: Bool) {
        
    }
    
    func updateIsLooping(_ isLooping: Bool) {

    }
    
    func updateBubbleTheme(bubbleTheme: PresentationTheme, bubbleCorners: PresentationChatBubbleCorners) {
        
    }
    
    func hasBubbleBackground(for type: WallpaperBubbleType) -> Bool {
        return false
    }
    
    func hasExtraBubbleBackground() -> Bool {
        return false
    }
    
    func makeBubbleBackground(for type: WallpaperBubbleType) -> WallpaperBubbleBackgroundNode? {
        return nil
    }
    
    func makeDimmedNode() -> ASDisplayNode? {
        return nil
    }
}
