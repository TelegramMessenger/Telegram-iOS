import Foundation
import UIKit
import Display

final class WeakSignalView: OverlayMaskContainerView {
    private struct Params: Equatable {
        var constrainedSize: CGSize
        
        init(constrainedSize: CGSize) {
            self.constrainedSize = constrainedSize
        }
    }
    private struct Layout {
        var params: Params
        var size: CGSize
        
        init(params: Params, size: CGSize) {
            self.params = params
            self.size = size
        }
    }
    
    private let titleView: TextView
    private let overlayBackgroundView: UIImageView
    private let backgroundView: UIImageView
    
    private var currentLayout: Layout?
    
    override init(frame: CGRect) {
        self.titleView = TextView()
        self.overlayBackgroundView = UIImageView()
        self.backgroundView = UIImageView()
        
        super.init(frame: frame)
        
        self.maskContents.addSubview(self.overlayBackgroundView)
        self.addSubview(self.backgroundView)
        self.addSubview(self.titleView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(constrainedSize: CGSize) -> CGSize {
        let params = Params(constrainedSize: constrainedSize)
        if let currentLayout = self.currentLayout, currentLayout.params == params {
            return currentLayout.size
        }
        
        let sideInset: CGFloat = 8.0
        let height: CGFloat = 30.0
        
        let titleSize = self.titleView.update(string: "Weak network signal", fontSize: 16.0, fontWeight: 0.0, color: .white, constrainedWidth: constrainedSize.width - sideInset * 2.0, transition: .immediate)
        let size = CGSize(width: titleSize.width + sideInset * 2.0, height: height)
        self.titleView.frame = CGRect(origin: CGPoint(x: sideInset, y: floor((size.height - titleSize.height) * 0.5)), size: titleSize)
        
        if self.overlayBackgroundView.image?.size.height != height {
            self.overlayBackgroundView.image = generateStretchableFilledCircleImage(diameter: height, color: .white)
            self.backgroundView.image = generateStretchableFilledCircleImage(diameter: height, color: UIColor(white: 1.0, alpha: 0.2))
        }
        self.overlayBackgroundView.frame = CGRect(origin: CGPoint(), size: size)
        self.backgroundView.frame = CGRect(origin: CGPoint(), size: size)
        
        self.currentLayout = Layout(params: params, size: size)
        return size
    }
}
