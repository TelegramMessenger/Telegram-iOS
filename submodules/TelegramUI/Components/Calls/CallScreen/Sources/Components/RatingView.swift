import Foundation
import UIKit
import Display
import ComponentFlow

final class RatingView: OverlayMaskContainerView {
    private let backgroundView: RoundedCornersView
    private let textContainer: UIView
    private let textView: TextView
    
    override init(frame: CGRect) {
        self.backgroundView = RoundedCornersView(color: .white)
        self.textContainer = UIView()
        self.textContainer.clipsToBounds = true
        self.textView = TextView()
        
        super.init(frame: frame)
        
        self.clipsToBounds = true
        
        self.maskContents.addSubview(self.backgroundView)
        
        self.textContainer.addSubview(self.textView)
        self.addSubview(self.textContainer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func animateIn() {
        let delay: Double = 0.2
        
        self.layer.animateScale(from: 0.001, to: 1.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
        self.textView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, delay: delay)
        
        self.backgroundView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
        self.backgroundView.layer.animateFrame(from: CGRect(origin: CGPoint(x: (self.bounds.width - self.bounds.height) * 0.5, y: 0.0), size: CGSize(width: self.bounds.height, height: self.bounds.height)), to: self.backgroundView.frame, duration: 0.5, delay: delay, timingFunction: kCAMediaTimingFunctionSpring)
        
        self.textContainer.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: delay)
        self.textContainer.layer.cornerRadius = self.bounds.height * 0.5
        self.textContainer.layer.animateFrame(from: CGRect(origin: CGPoint(x: (self.bounds.width - self.bounds.height) * 0.5, y: 0.0), size: CGSize(width: self.bounds.height, height: self.bounds.height)), to: self.textContainer.frame, duration: 0.5, delay: delay, timingFunction: kCAMediaTimingFunctionSpring, completion: { [weak self] completed in
            guard let self, completed else {
                return
            }
            self.textContainer.layer.cornerRadius = 0.0
        })
    }
    
    func animateOut(completion: @escaping () -> Void) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
            completion()
        })
        self.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, removeOnCompletion: false)
    }
    
    func update(text: String, constrainedWidth: CGFloat, transition: ComponentTransition) -> CGSize {
        let sideInset: CGFloat = 12.0
        let verticalInset: CGFloat = 6.0
        
        let textSize = self.textView.update(string: text, fontSize: 15.0, fontWeight: 0.0, color: .white, constrainedWidth: constrainedWidth - sideInset * 2.0, transition: .immediate)
        let size = CGSize(width: textSize.width + sideInset * 2.0, height: textSize.height + verticalInset * 2.0)
        
        transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: size))
        self.backgroundView.update(cornerRadius: floor(size.height * 0.5), transition: transition)
        
        transition.setFrame(view: self.textContainer, frame: CGRect(origin: CGPoint(), size: size))
        transition.setFrame(view: self.textView, frame: CGRect(origin: CGPoint(x: sideInset, y: verticalInset), size: textSize))
        
        return size
    }
}
