import Foundation
import UIKit

final class ContentOverlayButton: UIButton, ContentOverlayView {
    var overlayMaskLayer: CALayer {
        return self.overlayBackgroundLayer
    }
    
    override static var layerClass: AnyClass {
        return MirroringLayer.self
    }
    
    private let overlayBackgroundLayer: SimpleLayer
    private let backgroundLayer: SimpleLayer
    
    private var internalHighlighted = false
    
    private var internalHighligthedChanged: (Bool) -> Void = { _ in }
    var highligthedChanged: (Bool) -> Void = { _ in }
    
    var action: (() -> Void)?
    
    override init(frame: CGRect) {
        self.overlayBackgroundLayer = SimpleLayer()
        self.backgroundLayer = SimpleLayer()
        
        super.init(frame: frame)
        
        self.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
        
        let size: CGFloat = 56.0
        let renderer = UIGraphicsImageRenderer(bounds: CGRect(origin: CGPoint(), size: CGSize(width: size, height: size)))
        self.overlayBackgroundLayer.contents = renderer.image { context in
            UIGraphicsPushContext(context.cgContext)
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size, height: size)))
            UIGraphicsPopContext()
        }.cgImage
        
        self.backgroundLayer.contents = renderer.image { context in
            UIGraphicsPushContext(context.cgContext)
            context.cgContext.setFillColor(UIColor.white.withAlphaComponent(0.2).cgColor)
            context.cgContext.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size, height: size)))
            UIGraphicsPopContext()
        }.cgImage
        self.backgroundLayer.frame = CGRect(origin: CGPoint(), size: CGSize(width: size, height: size))
        
        (self.layer as? MirroringLayer)?.targetLayer = self.overlayBackgroundLayer
        
        self.layer.addSublayer(self.backgroundLayer)
        
        self.internalHighligthedChanged = { [weak self] highlighted in
            guard let self else {
                return
            }
            if highlighted {
                self.alpha = 0.5
            } else {
                self.alpha = 1.0
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func buttonPressed() {
        self.action?()
    }
    
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        if !self.internalHighlighted {
            self.internalHighlighted = true
            self.highligthedChanged(true)
            self.internalHighligthedChanged(true)
        }
        
        return super.beginTracking(touch, with: event)
    }
    
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        if self.internalHighlighted {
            self.internalHighlighted = false
            self.highligthedChanged(false)
            self.internalHighligthedChanged(false)
        }
        
        super.endTracking(touch, with: event)
    }
    
    override func cancelTracking(with event: UIEvent?) {
        if self.internalHighlighted {
            self.internalHighlighted = false
            self.highligthedChanged(false)
            self.internalHighligthedChanged(false)
        }
        
        super.cancelTracking(with: event)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if self.internalHighlighted {
            self.internalHighlighted = false
            self.highligthedChanged(false)
            self.internalHighligthedChanged(false)
        }
        
        super.touchesCancelled(touches, with: event)
    }
}
