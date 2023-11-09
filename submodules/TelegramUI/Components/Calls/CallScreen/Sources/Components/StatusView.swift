import Foundation
import UIKit

private final class AnimatedDotsLayer: SimpleLayer {
    private let dotLayers: [SimpleLayer]
    
    let size: CGSize
    
    override init() {
        self.dotLayers = (0 ..< 3).map { _ in
            SimpleLayer()
        }
        
        let dotSpacing: CGFloat = 1.0
        let dotSize = CGSize(width: 5.0, height: 5.0)
        
        self.size = CGSize(width: CGFloat(self.dotLayers.count) * dotSize.width + CGFloat(self.dotLayers.count - 1) * dotSpacing, height: dotSize.height)
        
        super.init()
        
        let dotImage = UIGraphicsImageRenderer(size: dotSize).image(actions: { context in
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.fillEllipse(in: CGRect(origin: CGPoint(), size: dotSize))
        })
        
        var nextX: CGFloat = 0.0
        for dotLayer in self.dotLayers {
            dotLayer.contents = dotImage.cgImage
            dotLayer.frame = CGRect(origin: CGPoint(x: nextX, y: 0.0), size: dotSize)
            nextX += dotSpacing + dotSize.width
            self.addSublayer(dotLayer)
        }
        
        self.didEnterHierarchy = { [weak self] in
            self?.updateAnimations()
        }
    }
    
    override init(layer: Any) {
        self.dotLayers = []
        self.size = CGSize()
        
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateAnimations() {
        if self.dotLayers[0].animation(forKey: "dotAnimation") != nil {
            return
        }
        
        let animationDuration: Double = 0.6
        for i in 0 ..< self.dotLayers.count {
            let dotLayer = self.dotLayers[i]
            
            let animation = CABasicAnimation(keyPath: "transform.scale")
            animation.duration = animationDuration
            animation.fromValue = 0.3
            animation.toValue = 1.0
            animation.timingFunction = CAMediaTimingFunction(name: .linear)
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timeOffset = CGFloat(self.dotLayers.count - 1 - i) * animationDuration * 0.33
            
            dotLayer.add(animation, forKey: "dotAnimation")
        }
    }
}

final class StatusView: UIView {
    enum WaitingState {
        case requesting
        case ringing
        case generatingKeys
    }
    enum State {
        case waiting(WaitingState)
    }
    
    private var textView: TextView
    private var dotsLayer: AnimatedDotsLayer?
    
    override init(frame: CGRect) {
        self.textView = TextView()
        
        super.init(frame: frame)
        
        self.addSubview(self.textView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(state: State) -> CGSize {
        let textString: String
        var needsDots = false
        switch state {
        case let .waiting(waitingState):
            needsDots = true
            
            switch waitingState {
            case .requesting:
                textString = "Requesting"
            case .ringing:
                textString = "Ringing"
            case .generatingKeys:
                textString = "Exchanging encryption keys"
            }
        }
        let textSize = self.textView.update(string: textString, fontSize: 16.0, fontWeight: 0.0, constrainedWidth: 200.0)
        self.textView.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: textSize)
        
        var contentSize = textSize
        
        let dotsSpacing: CGFloat = 6.0
        
        if needsDots {
            let dotsLayer: AnimatedDotsLayer
            if let current = self.dotsLayer {
                dotsLayer = current
            } else {
                dotsLayer = AnimatedDotsLayer()
                self.dotsLayer = dotsLayer
                self.layer.addSublayer(dotsLayer)
            }
            
            dotsLayer.frame = CGRect(origin: CGPoint(x: textSize.width + dotsSpacing, y: 1.0 + floor((textSize.height - dotsLayer.size.height) * 0.5)), size: dotsLayer.size)
            contentSize.width += dotsSpacing + dotsLayer.size.width
        } else if let dotsLayer = self.dotsLayer {
            self.dotsLayer = nil
            dotsLayer.removeFromSuperlayer()
        }
        
        return contentSize
    }
}
