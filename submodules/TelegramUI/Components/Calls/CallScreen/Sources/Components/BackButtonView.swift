import Foundation
import UIKit
import Display

final class BackButtonView: HighlightableButton {
    private struct Params: Equatable {
        var text: String
        /// When set, the button is an arrow-only circle of this diameter (iPhone Duo's side strip).
        var circleDiameter: CGFloat?
        
        init(text: String, circleDiameter: CGFloat? = nil) {
            self.text = text
            self.circleDiameter = circleDiameter
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
    
    private let iconView: UIImageView
    private let textView: TextView
    
    private var currentLayout: Layout?
    
    var pressAction: (() -> Void)?
    
    override init(frame: CGRect) {
        self.iconView = UIImageView(image: navigationBarBackArrowImage(color: .white))
        self.iconView.isUserInteractionEnabled = false
        
        self.textView = TextView()
        self.textView.isUserInteractionEnabled = false
        
        super.init(frame: frame)
        
        self.addSubview(self.iconView)
        self.addSubview(self.textView)
        
        self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func pressed() {
        self.pressAction?()
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.insetBy(dx: -8.0, dy: -4.0).contains(point) {
            return super.hitTest(self.bounds.center, with: event)
        } else {
            return nil
        }
    }
    
    func update(text: String) -> CGSize {
        let params = Params(text: text)
        if let currentLayout = self.currentLayout, currentLayout.params == params {
            return currentLayout.size
        }
        let size = self.update(params: params)
        self.currentLayout = Layout(params: params, size: size)
        return size
    }
    
    /// The button as an arrow in a translucent circle, the shape every screen's back button takes in iPhone Duo's
    /// side strip. The text is kept as the accessibility label.
    func updateCircle(text: String, diameter: CGFloat) -> CGSize {
        let params = Params(text: text, circleDiameter: diameter)
        if let currentLayout = self.currentLayout, currentLayout.params == params {
            return currentLayout.size
        }
        let size = self.update(params: params)
        self.currentLayout = Layout(params: params, size: size)
        return size
    }
    
    private func update(params: Params) -> CGSize {
        let spacing: CGFloat = 8.0
        
        var iconSize: CGSize = self.iconView.image?.size ?? CGSize(width: 2.0, height: 2.0)
        let iconScaleFactor: CGFloat = 0.9
        iconSize.width = floor(iconSize.width * iconScaleFactor)
        iconSize.height = floor(iconSize.height * iconScaleFactor)
        
        if let diameter = params.circleDiameter {
            let size = CGSize(width: diameter, height: diameter)
            self.textView.isHidden = true
            self.accessibilityLabel = params.text
            self.backgroundColor = UIColor(white: 1.0, alpha: 0.18)
            self.layer.cornerRadius = diameter * 0.5
            // The arrow's visual centre sits right of its bounds' centre.
            self.iconView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((diameter - iconSize.width) * 0.5) - 1.0, y: floorToScreenPixels((diameter - iconSize.height) * 0.5)), size: iconSize)
            return size
        }
        self.textView.isHidden = false
        self.accessibilityLabel = nil
        self.backgroundColor = nil
        self.layer.cornerRadius = 0.0
        
        let textSize = self.textView.update(string: params.text, fontSize: 17.0, fontWeight: UIFont.Weight.regular.rawValue, color: .white, constrainedWidth: 100.0, transition: .immediate)
        let size = CGSize(width: iconSize.width + spacing + textSize.width, height: textSize.height)
        
        self.iconView.frame = CGRect(origin: CGPoint(x: 0.0, y: floorToScreenPixels((size.height - iconSize.height) * 0.5)), size: iconSize)
        self.textView.frame = CGRect(origin: CGPoint(x: iconSize.width + spacing, y: floorToScreenPixels((size.height - textSize.height) * 0.5)), size: textSize)
        
        return size
    }
}
