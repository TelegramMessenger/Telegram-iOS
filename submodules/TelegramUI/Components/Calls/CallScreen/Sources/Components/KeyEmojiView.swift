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
                    let transition = Transition(animation: .curve(duration: 0.15, curve: .easeInOut))
                    transition.setScale(layer: self.layer, scale: topScale)
                } else {
                    let t = self.layer.presentation()?.transform ?? layer.transform
                    let currentScale = sqrt((t.m11 * t.m11) + (t.m12 * t.m12) + (t.m13 * t.m13))
                    
                    let transition = Transition(animation: .none)
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
            emojiView.layer.animatePosition(from: CGPoint(x: -CGFloat(self.emojiViews.count - 1 - i) * 30.0, y: 0.0), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        }
    }
    
    func update(isExpanded: Bool, transition: Transition) -> CGSize {
        let params = Params(isExpanded: isExpanded)
        if let currentLayout = self.currentLayout, currentLayout.params == params {
            return currentLayout.size
        }
        
        let size = self.update(params: params, transition: transition)
        self.currentLayout = Layout(params: params, size: size)
        return size
    }
    
    private func update(params: Params, transition: Transition) -> CGSize {
        let itemSpacing: CGFloat = 3.0
        
        var height: CGFloat = 0.0
        var nextX = 0.0
        for i in 0 ..< self.emojiViews.count {
            if nextX != 0.0 {
                nextX += itemSpacing
            }
            let emojiView = self.emojiViews[i]
            let itemSize = emojiView.update(string: emoji[i], fontSize: params.isExpanded ? 40.0 : 16.0, fontWeight: 0.0, color: .white, constrainedWidth: 100.0, transition: transition)
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
