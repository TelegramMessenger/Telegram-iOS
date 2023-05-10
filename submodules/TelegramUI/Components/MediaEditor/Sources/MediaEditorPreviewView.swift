import Foundation
import UIKit
import Metal
import MetalKit
import SwiftSignalKit

public final class MediaEditorPreviewView: MTKView, MTKViewDelegate, RenderTarget {
    var renderer: MediaEditorRenderer? {
        didSet {
            if let renderer = self.renderer {
                renderer.renderTargetDidChange(self)
            }
        }
    }
    
    var drawable: MTLDrawable? {
        return self.currentDrawable
    }
    
    var renderPassDescriptor: MTLRenderPassDescriptor? {
        return self.currentRenderPassDescriptor
    }
    
    var mtlDevice: MTLDevice? {
        return self.device
    }
    
    public override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        
        self.setup()
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return
        }
                
        self.device = device
        self.delegate = self
        
        self.colorPixelFormat = .bgra8Unorm
        
        self.isPaused = true
        self.enableSetNeedsDisplay = false
    }
    
    func scheduleFrame() {
        Queue.mainQueue().async {
            self.draw()
        }
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        Queue.mainQueue().justDispatch {
            self.renderer?.renderTargetDrawableSizeDidChange(size)
        }
    }
    
    public func draw(in view: MTKView) {
        guard self.frame.width > 0.0 else {
            return
        }
        self.renderer?.renderFrame()
    }
}
