import Foundation
import UIKit
import ComponentFlow
import Display

public final class StarsParticleEffectLayer: SimpleLayer {
    private let emitterLayer = CAEmitterLayer()
    private var currentColor: UIColor?
    
    override public init() {
        self.emitterLayer.masksToBounds = true
        
        super.init()
        
        self.addSublayer(self.emitterLayer)
    }
    
    override public init(layer: Any) {
        super.init(layer: layer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup(rate: CGFloat) {
        guard let currentColor = self.currentColor else {
            return
        }
        let color = currentColor
        
        let emitter = CAEmitterCell()
        emitter.name = "emitter"
        emitter.contents = UIImage(bundleImageName: "Premium/Stars/Particle")?.cgImage
        emitter.birthRate = Float(rate)
        emitter.lifetime = 2.0
        emitter.velocity = 12.0
        emitter.velocityRange = 3
        emitter.scale = 0.1
        emitter.scaleRange = 0.08
        emitter.alphaRange = 0.1
        emitter.emissionRange = .pi * 2.0
        emitter.setValue(3.0, forKey: "mass")
        emitter.setValue(2.0, forKey: "massRange")
        
        let staticColors: [Any] = [
            color.withAlphaComponent(0.0).cgColor,
            color.cgColor,
            color.cgColor,
            color.withAlphaComponent(0.0).cgColor
        ]
        let staticColorBehavior = CAEmitterCell.createEmitterBehavior(type: "colorOverLife")
        staticColorBehavior.setValue(staticColors, forKey: "colors")
        emitter.setValue([staticColorBehavior], forKey: "emitterBehaviors")
        
        self.emitterLayer.emitterCells = [emitter]
    }
    
    public func update(color: UIColor, rate: CGFloat = 25.0, size: CGSize, cornerRadius: CGFloat, transition: ComponentTransition) {
        if self.emitterLayer.emitterCells == nil || self.currentColor != color {
            self.currentColor = color
            self.setup(rate: rate)
        }
        self.emitterLayer.emitterShape = .circle
        self.emitterLayer.emitterSize = CGSize(width: size.width * 0.7, height: size.height * 0.7)
        self.emitterLayer.emitterMode = .surface
        transition.setFrame(layer: self.emitterLayer, frame: CGRect(origin: CGPoint(), size: size))
        transition.setCornerRadius(layer: self.emitterLayer, cornerRadius: cornerRadius)
        self.emitterLayer.emitterPosition = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
    }
}
