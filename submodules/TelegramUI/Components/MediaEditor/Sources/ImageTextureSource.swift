import Foundation
import AVFoundation
import Metal
import MetalKit
import Display
import Accelerate

final class ImageTextureSource: TextureSource {
    weak var output: MediaEditorRenderer?
    
    var texture: MTLTexture?
        
    init(image: UIImage, renderTarget: RenderTarget) {
        if let device = renderTarget.mtlDevice {
            self.texture = loadTexture(image: image, device: device)
        }
    }
    
    func connect(to consumer: MediaEditorRenderer) {
        self.output = consumer
        if let texture = self.texture {
            self.output?.consume(main: .texture(texture, .zero), additional: nil, render: false)
        }
    }
    
    func invalidate() {
        self.texture = nil
    }
}
