import Foundation
import UIKit
import Display

final class ContentOverlayLayer: SimpleLayer {
    private struct Params: Equatable {
        var size: CGSize
        var contentInsets: UIEdgeInsets
        
        init(size: CGSize, contentInsets: UIEdgeInsets) {
            self.size = size
            self.contentInsets = contentInsets
        }
    }
    
    var contentsLayer: CALayer? {
        didSet {
            if self.contentsLayer !== oldValue {
                oldValue?.mask = nil
                oldValue?.removeFromSuperlayer()
                
                if let contentsLayer = self.contentsLayer {
                    contentsLayer.mask = self.maskContentLayer
                    self.addSublayer(contentsLayer)
                    
                    if let params = self.params {
                        let size = params.size
                        let contentInsets = params.contentInsets
                        self.params = nil
                        self.update(size: size, contentInsets: contentInsets)
                    }
                }
            }
        }
    }
    
    let maskContentLayer: SimpleLayer
    
    private var params: Params?
    
    override init() {
        self.maskContentLayer = SimpleLayer()
        
        super.init()
    }
    
    override init(layer: Any) {
        self.maskContentLayer = SimpleLayer()
        
        super.init(layer: layer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(size: CGSize, contentInsets: UIEdgeInsets) {
        let params = Params(size: size, contentInsets: contentInsets)
        if self.params == params {
            return
        }
        self.params = params
        
        let contentInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
        
        self.maskContentLayer.frame = CGRect(origin: CGPoint(x: contentInsets.left, y: contentInsets.top), size: size)
        
        if let contentsLayer = self.contentsLayer {
            contentsLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width - (contentInsets.left + contentInsets.right), height: size.height - (contentInsets.top + contentInsets.bottom)))
        }
    }
}
