import Foundation
import UIKit
import ComponentFlow

final class TextView: UIView {
    private struct Params: Equatable {
        var string: String
        var fontSize: CGFloat
        var fontWeight: CGFloat
        var monospacedDigits: Bool
        var alignment: NSTextAlignment
        var constrainedWidth: CGFloat
    }
    
    private struct LayoutState: Equatable {
        var params: Params
        var size: CGSize
        var attributedString: NSAttributedString
    }
    
    private var layoutState: LayoutState?
    private var animateContentsTransition: Bool = false
    
    override init(frame: CGRect) {
        super.init(frame: CGRect())
        
        self.isOpaque = false
        self.backgroundColor = nil
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func action(for layer: CALayer, forKey event: String) -> CAAction? {
        if self.animateContentsTransition && event == "contents" {
            self.animateContentsTransition = false
            let animation = CABasicAnimation(keyPath: "contents")
            animation.duration = 0.15 * UIView.animationDurationFactor()
            animation.timingFunction = CAMediaTimingFunction(name: .linear)
            return animation
        }
        return super.action(for: layer, forKey: event)
    }
    
    func update(string: String, fontSize: CGFloat, fontWeight: CGFloat, monospacedDigits: Bool = false, alignment: NSTextAlignment = .natural, color: UIColor, constrainedWidth: CGFloat, transition: ComponentTransition) -> CGSize {
        let params = Params(string: string, fontSize: fontSize, fontWeight: fontWeight, monospacedDigits: monospacedDigits, alignment: alignment, constrainedWidth: constrainedWidth)
        if let layoutState = self.layoutState, layoutState.params == params {
            return layoutState.size
        }
        
        let font: UIFont
        if monospacedDigits {
            font = UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: UIFont.Weight(fontWeight))
        } else {
            font = UIFont.systemFont(ofSize: fontSize, weight: UIFont.Weight(fontWeight))
        }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineSpacing = 0.6
        let attributedString = NSAttributedString(string: string, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ])
        let stringBounds = attributedString.boundingRect(with: CGSize(width: constrainedWidth, height: 200.0), options: .usesLineFragmentOrigin, context: nil)
        let stringSize = CGSize(width: ceil(stringBounds.width), height: ceil(stringBounds.height))
        let size = CGSize(width: min(constrainedWidth, stringSize.width), height: stringSize.height)
        
        let layoutState = LayoutState(params: params, size: size, attributedString: attributedString)
        if self.layoutState != layoutState {
            self.layoutState = layoutState
            self.animateContentsTransition = !transition.animation.isImmediate
            self.setNeedsDisplay()
        }
        
        return size
    }
    
    override func draw(_ rect: CGRect) {
        guard let layoutState = self.layoutState else {
            return
        }
        
        layoutState.attributedString.draw(with: rect, options: [.truncatesLastVisibleLine, .usesLineFragmentOrigin], context: nil)
    }
}
