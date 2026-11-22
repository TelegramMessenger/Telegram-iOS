import Foundation
import UIKit
import Display
import ComponentFlow
import UIKitRuntimeUtils
import AppBundle

final class ConferenceButtonView: HighlightTrackingButton, OverlayMaskContainerViewProtocol {
    private struct Params: Equatable {
        var size: CGSize
        
        init(size: CGSize) {
            self.size = size
        }
    }
    
    private let backdropBackgroundView: RoundedCornersView
    private let iconView: UIImageView
    
    var pressAction: (() -> Void)?
    
    private var params: Params?
    
    let maskContents: UIView
    override static var layerClass: AnyClass {
        return MirroringLayer.self
    }
    
    override init(frame: CGRect) {
        self.backdropBackgroundView = RoundedCornersView(color: .white, smoothCorners: true)
        
        self.iconView = UIImageView()
        
        self.maskContents = UIView()
        self.maskContents.addSubview(self.backdropBackgroundView)
        
        super.init(frame: frame)
        
        self.addSubview(self.iconView)
        
        (self.layer as? MirroringLayer)?.targetLayer = self.maskContents.layer
        
        self.internalHighligthedChanged = { [weak self] highlighted in
            if let self, self.bounds.width > 0.0 {
                let topScale: CGFloat = (self.bounds.width - 8.0) / self.bounds.width
                let maxScale: CGFloat = (self.bounds.width + 2.0) / self.bounds.width
                
                if highlighted {
                    self.layer.removeAnimation(forKey: "sublayerTransform")
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
    
    @objc private func pressed() {
        self.pressAction?()
    }
    
    func update(size: CGSize, transition: ComponentTransition) {
        let params = Params(size: size)
        if self.params == params {
            return
        }
        self.params = params
        self.update(params: params, transition: transition)
    }
    
    private func update(params: Params, transition: ComponentTransition) {
        self.backdropBackgroundView.update(cornerRadius: params.size.height * 0.5, transition: transition)
        transition.setFrame(view: self.backdropBackgroundView, frame: CGRect(origin: CGPoint(), size: params.size))
        
        if self.iconView.image == nil {
            self.iconView.image = UIImage(bundleImageName: "Call/CallNavigationAddPerson")?.withRenderingMode(.alwaysTemplate)
            self.iconView.tintColor = .white
        }
        
        if let image = self.iconView.image {
            let fraction: CGFloat = 1.0
            let imageSize = CGSize(width: floor(image.size.width * fraction), height: floor(image.size.height * fraction))
            transition.setFrame(view: self.iconView, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((params.size.width - imageSize.width) * 0.5), y: floorToScreenPixels((params.size.height - imageSize.height) * 0.5)), size: imageSize))
        }
    }
}
