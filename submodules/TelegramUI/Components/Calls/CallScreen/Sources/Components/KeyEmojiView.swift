import Foundation
import UIKit
import Display

final class KeyEmojiView: UIView {
    private let emojiViews: [TextView]
    
    let size: CGSize
    
    init(emoji: [String]) {
        self.emojiViews = emoji.map { emoji in
            TextView()
        }
        
        let itemSpacing: CGFloat = 3.0
        
        var height: CGFloat = 0.0
        var nextX = 0.0
        for i in 0 ..< self.emojiViews.count {
            if nextX != 0.0 {
                nextX += itemSpacing
            }
            let emojiView = self.emojiViews[i]
            let itemSize = emojiView.update(string: emoji[i], fontSize: 16.0, fontWeight: 0.0, color: .white, constrainedWidth: 100.0, transition: .immediate)
            if height == 0.0 {
                height = itemSize.height
            }
            emojiView.frame = CGRect(origin: CGPoint(x: nextX, y: 0.0), size: itemSize)
            nextX += itemSize.width
        }
        
        self.size = CGSize(width: nextX, height: height)
        
        super.init(frame: CGRect())
        
        for emojiView in self.emojiViews {
            self.addSubview(emojiView)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func animateIn() {
        for i in 0 ..< self.emojiViews.count {
            let emojiView = self.emojiViews[i]
            emojiView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            emojiView.layer.animatePosition(from: CGPoint(x: -CGFloat(self.emojiViews.count - 1 - i) * 30.0, y: 0.0), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        }
    }
}
