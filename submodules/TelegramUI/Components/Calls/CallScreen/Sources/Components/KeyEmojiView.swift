import Foundation
import UIKit
import Display
import ComponentFlow

final class KeyEmojiView: HighlightTrackingButton {
    private struct Params: Equatable {
        var isExpanded: Bool
        
        init(isExpanded: Bool) {
            self.isExpanded = isExpanded
        }
    }
    
    private struct Layout: Equatable {
        var params: Params
        var size: CGSize
        
        init(params: Params, size: CGSize) {
            self.params = params
            self.size = size
        }
    }
    
    private let emoji: [String]
    private let emojiViews: [TextView]
    
    var pressAction: (() -> Void)?
    
    private var currentLayout: Layout?
    
    var isExpanded: Bool? {
        return self.currentLayout?.params.isExpanded
    }
    
    init(emoji: [String]) {
        self.emoji = emoji
        self.emojiViews = emoji.map { _ in
            TextView()
        }
        
        super.init(frame: CGRect())
        
        for emojiView in self.emojiViews {
            emojiView.contentMode = .scaleToFill
            emojiView.isUserInteractionEnabled = false
            self.addSubview(emojiView)
        }
        
        self.internalHighligthedChanged = { [weak self] highlighted in
            if let self, self.bounds.width > 0.0 {
                let topScale: CGFloat = (self.bounds.width - 8.0) / self.bounds.width
                let maxScale: CGFloat = (self.bounds.width + 2.0) / self.bounds.width
                
                if highlighted {
                    self.layer.removeAnimation(forKey: "opacity")
                    self.layer.removeAnimation(forKey: "transform")
                    let transition = ComponentTransition(animation: .curve(duration: 0.15, curve: .easeInOut))
                    transition.setScale(layer: self.layer, scale: topScale)
                } else {
                    let t = self.layer.presentation()?.transform ?? layer.transform
                    let currentScale = sqrt((t.m11 * t.m11) + (t.m12 * t.m12) + (t.m13 * t.m13))
                    
                    let transition = ComponentTransition(animation: .none)
                    transition.setScale(layer: self.layer, scale: 1.0)
                    
                    self.layer.animateScale(from: currentScale, to: maxScale, duration: 0.13, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { [weak self] completed in
                        guard let self, completed else {
                            return
                        }
                        
                        self.layer.animateScale(from: maxScale, to: 1.0, duration: 0.1, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue)
                    })
                }
            }
        }
        self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return super.hitTest(point, with: event)
    }
    
    @objc private func pressed() {
        self.pressAction?()
    }
    
    func animateIn() {
        for i in 0 ..< self.emojiViews.count {
            let emojiView = self.emojiViews[i]
            emojiView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            //emojiView.layer.animateScale(from: 0.2, to: 1.0, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        }
    }
    
    func update(isExpanded: Bool, transition: ComponentTransition) -> CGSize {
        let params = Params(isExpanded: isExpanded)
        if let currentLayout = self.currentLayout, currentLayout.params == params {
            return currentLayout.size
        }
        
        let size = self.update(params: params, transition: transition)
        self.currentLayout = Layout(params: params, size: size)
        return size
    }
    
    private func update(params: Params, transition: ComponentTransition) -> CGSize {
        let itemSpacing: CGFloat = 0.0
        
        var height: CGFloat = 0.0
        var nextX = 0.0
        for i in 0 ..< self.emojiViews.count {
            if nextX != 0.0 {
                nextX += itemSpacing
            }
            let emojiView = self.emojiViews[i]
            let itemSize = emojiView.update(string: emoji[i], fontSize: params.isExpanded ? 40.0 : 15.0, fontWeight: 0.0, color: .white, constrainedWidth: 100.0, transition: transition)
            if height == 0.0 {
                height = itemSize.height
            }
            let itemFrame = CGRect(origin: CGPoint(x: nextX, y: 0.0), size: itemSize)
            transition.setFrame(view: emojiView, frame: itemFrame)
            nextX += itemSize.width
        }
        
        return CGSize(width: nextX, height: height)
    }
}

func generateParabollicMotionKeyframes(from sourcePoint: CGPoint, to targetPosition: CGPoint, elevation: CGFloat, duration: Double, curve: ComponentTransition.Animation.Curve, reverse: Bool) -> [CGPoint] {
    let midPoint = CGPoint(x: (sourcePoint.x + targetPosition.x) / 2.0, y: sourcePoint.y - elevation)
    
    let x1 = sourcePoint.x
    let y1 = sourcePoint.y
    let x2 = midPoint.x
    let y2 = midPoint.y
    let x3 = targetPosition.x
    let y3 = targetPosition.y
    
    let numPoints: Int = Int(ceil(Double(UIScreen.main.maximumFramesPerSecond) * duration))
    
    var keyframes: [CGPoint] = []
    if abs(y1 - y3) < 5.0 || abs(x1 - x3) < 5.0 {
        for rawI in 0 ..< numPoints {
            let i = reverse ? (numPoints - 1 - rawI) : rawI
            let ks = CGFloat(i) / CGFloat(numPoints - 1)
            var k = curve.solve(at: reverse ? (1.0 - ks) : ks)
            if reverse {
                k = 1.0 - k
            }
            let x = sourcePoint.x * (1.0 - k) + targetPosition.x * k
            let y = sourcePoint.y * (1.0 - k) + targetPosition.y * k
            keyframes.append(CGPoint(x: x, y: y))
        }
    } else {
        let a = (x3 * (y2 - y1) + x2 * (y1 - y3) + x1 * (y3 - y2)) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
        let b = (x1 * x1 * (y2 - y3) + x3 * x3 * (y1 - y2) + x2 * x2 * (y3 - y1)) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
        let c = (x2 * x2 * (x3 * y1 - x1 * y3) + x2 * (x1 * x1 * y3 - x3 * x3 * y1) + x1 * x3 * (x3 - x1) * y2) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
        
        for rawI in 0 ..< numPoints {
            let i = reverse ? (numPoints - 1 - rawI) : rawI
            
            let ks = CGFloat(i) / CGFloat(numPoints - 1)
            var k = curve.solve(at: reverse ? (1.0 - ks) : ks)
            if reverse {
                k = 1.0 - k
            }
            let x = sourcePoint.x * (1.0 - k) + targetPosition.x * k
            let y = a * x * x + b * x + c
            keyframes.append(CGPoint(x: x, y: y))
        }
    }
    
    return keyframes
}
