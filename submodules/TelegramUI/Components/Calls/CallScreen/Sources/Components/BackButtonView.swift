import Foundation
import UIKit
import Display

final class BackButtonView: HighlightableButton {
    private struct Params: Equatable {
        var text: String
        
        init(text: String) {
            self.text = text
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
        self.iconView = UIImageView(image: NavigationBar.backArrowImage(color: .white))
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
    
    private func update(params: Params) -> CGSize {
        let spacing: CGFloat = 8.0
        
        var iconSize: CGSize = self.iconView.image?.size ?? CGSize(width: 2.0, height: 2.0)
        let iconScaleFactor: CGFloat = 0.9
        iconSize.width = floor(iconSize.width * iconScaleFactor)
        iconSize.height = floor(iconSize.height * iconScaleFactor)
        
        let textSize = self.textView.update(string: params.text, fontSize: 17.0, fontWeight: UIFont.Weight.regular.rawValue, color: .white, constrainedWidth: 100.0, transition: .immediate)
        let size = CGSize(width: iconSize.width + spacing + textSize.width, height: textSize.height)
        
        self.iconView.frame = CGRect(origin: CGPoint(x: 0.0, y: floorToScreenPixels((size.height - iconSize.height) * 0.5)), size: iconSize)
        self.textView.frame = CGRect(origin: CGPoint(x: iconSize.width + spacing, y: floorToScreenPixels((size.height - textSize.height) * 0.5)), size: textSize)
        
        return size
    }
}
