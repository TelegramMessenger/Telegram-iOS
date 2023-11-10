import Foundation
import UIKit

final class TextView: UIView {
    private struct Params: Equatable {
        var string: String
        var fontSize: CGFloat
        var fontWeight: CGFloat
        var constrainedWidth: CGFloat
    }
    
    private struct LayoutState: Equatable {
        var params: Params
        var size: CGSize
        var attributedString: NSAttributedString
    }
    
    private var layoutState: LayoutState?
    
    override init(frame: CGRect) {
        super.init(frame: CGRect())
        
        self.isOpaque = false
        self.backgroundColor = nil
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(string: String, fontSize: CGFloat, fontWeight: CGFloat, constrainedWidth: CGFloat) -> CGSize {
        let params = Params(string: string, fontSize: fontSize, fontWeight: fontWeight, constrainedWidth: constrainedWidth)
        if let layoutState = self.layoutState, layoutState.params == params {
            return layoutState.size
        }
        
        let font = UIFont.systemFont(ofSize: fontSize, weight: UIFont.Weight(fontWeight))
        
        let attributedString = NSAttributedString(string: string, attributes: [
            .font: font,
            .foregroundColor: UIColor.white
        ])
        let stringBounds = attributedString.boundingRect(with: CGSize(width: constrainedWidth, height: 200.0), options: .usesLineFragmentOrigin, context: nil)
        let stringSize = CGSize(width: ceil(stringBounds.width), height: ceil(stringBounds.height))
        let size = CGSize(width: min(constrainedWidth, stringSize.width), height: stringSize.height)
        
        let layoutState = LayoutState(params: params, size: size, attributedString: attributedString)
        if self.layoutState != layoutState {
            self.layoutState = layoutState
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
