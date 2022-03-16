import Foundation
import SwiftSignalKit
import AsyncDisplayKit

public enum AnimationRendererFrameType {
    case argb
    case yuva
    case dct
}

final class AnimationRendererPool {
    final class Holder {
        let pool: AnimationRendererPool
        let renderer: AnimationRenderer
        
        init(pool: AnimationRendererPool, renderer: AnimationRenderer) {
            self.pool = pool
            self.renderer = renderer
        }
        
        deinit {
            self.renderer.removeFromSupernode()
            self.pool.putBack(renderer: self.renderer)
        }
    }
    
    private let generate: () -> AnimationRenderer
    
    private var items: [AnimationRenderer] = []
    
    init(generate: @escaping () -> AnimationRenderer) {
        self.generate = generate
    }
    
    func take() -> Holder {
        if !self.items.isEmpty {
            let item = self.items.removeLast()
            return Holder(pool: self, renderer: item)
        } else {
            return Holder(pool: self, renderer: self.generate())
        }
    }
    
    private func putBack(renderer: AnimationRenderer) {
        /*#if DEBUG
        self.items.append(renderer)
        #endif*/
    }
}

protocol AnimationRenderer: ASDisplayNode {
    func render(queue: Queue, width: Int, height: Int, bytesPerRow: Int, data: Data, type: AnimationRendererFrameType, mulAlpha: Bool, completion: @escaping () -> Void)
    
    func setOverlayColor(_ color: UIColor?, replace: Bool, animated: Bool)
}
