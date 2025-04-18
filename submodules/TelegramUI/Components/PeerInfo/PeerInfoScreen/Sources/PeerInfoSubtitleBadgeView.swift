import Foundation
import UIKit
import AsyncDisplayKit
import ContextUI
import AnimationUI
import Display
import TelegramPresentationData
import ComponentFlow

final class PeerInfoSubtitleBadgeView: HighlightTrackingButton {
    private let action: () -> Void
    
    private let backgroundView: BlurredBackgroundView
    private let labelView = ComponentView<Empty>()
    
    init(action: @escaping () -> Void) {
        self.action = action
        
        self.backgroundView = BlurredBackgroundView(color: nil, enableBlur: true)
        self.backgroundView.isUserInteractionEnabled = false
        
        super.init(frame: CGRect())
        
        self.addSubview(self.backgroundView)
        
        self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        
        self.highligthedChanged = { [weak self] highlighted in
            if let self, self.bounds.width > 0.0 {
                let topScale: CGFloat = (self.bounds.width - 8.0) / self.bounds.width
                let maxScale: CGFloat = (self.bounds.width + 2.0) / self.bounds.width
                
                if highlighted {
                    self.layer.removeAnimation(forKey: "opacity")
                    self.layer.removeAnimation(forKey: "sublayerTransform")
                    self.alpha = 0.7
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)
                    transition.updateTransformScale(layer: self.layer, scale: topScale)
                } else {
                    self.alpha = 1.0
                    self.layer.animateAlpha(from: 0.7, to: 1.0, duration: 0.2)
                    
                    let transition: ContainedViewLayoutTransition = .immediate
                    transition.updateTransformScale(layer: self.layer, scale: 1.0)
                    
                    self.layer.animateScale(from: topScale, to: maxScale, duration: 0.13, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        
                        self.layer.animateScale(from: maxScale, to: 1.0, duration: 0.1, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue)
                    })
                }
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func pressed() {
        self.action()
    }
    
    func update(title: String, fillColor: UIColor, foregroundColor: UIColor) -> CGSize {
        let labelSize = self.labelView.update(
            transition: .immediate,
            component: AnyComponent(Text(text: title, font: Font.regular(11.0), color: foregroundColor)),
            environment: {},
            containerSize: CGSize(width: 100.0, height: 100.0)
        )
        
        let size = CGSize(width: labelSize.width + 7.0 * 2.0, height: labelSize.height + 4.0 * 2.0)
        
        self.backgroundView.frame = CGRect(origin: CGPoint(), size: size)
        self.backgroundView.updateColor(color: fillColor, transition: .immediate)
        self.backgroundView.update(size: size, cornerRadius: size.height * 0.5, transition: .immediate)
        
        if let labelComponentView = self.labelView.view {
            if labelComponentView.superview == nil {
                labelComponentView.isUserInteractionEnabled = false
                self.addSubview(labelComponentView)
            }
            labelComponentView.frame = CGRect(origin: CGPoint(x: floor((size.width - labelSize.width) * 0.5), y: floor((size.height - labelSize.height) * 0.5)), size: labelSize)
        }
        
        return size
    }
}
