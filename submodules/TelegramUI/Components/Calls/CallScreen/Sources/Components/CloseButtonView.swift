import Foundation
import UIKit
import Display
import ComponentFlow
import UIKitRuntimeUtils

final class CloseButtonView: HighlightTrackingButton, OverlayMaskContainerViewProtocol {
    private struct Params: Equatable {
        var text: String
        var size: CGSize
        
        init(text: String, size: CGSize) {
            self.text = text
            self.size = size
        }
    }
    
    private let backdropBackgroundView: RoundedCornersView
    private let backgroundView: RoundedCornersView
    private let backgroundMaskView: UIView
    private let backgroundClippingView: UIView
    
    private let duration: Double = 5.0
    private var fillTime: Double = 0.0
    
    private let backgroundTextView: TextView
    private let backgroundTextClippingView: UIView
    
    private let textView: TextView
    
    var pressAction: (() -> Void)?
    
    private var params: Params?
    private var updateDisplayLink: SharedDisplayLinkDriver.Link?
    
    let maskContents: UIView
    override static var layerClass: AnyClass {
        return MirroringLayer.self
    }
    
    override init(frame: CGRect) {
        self.backdropBackgroundView = RoundedCornersView(color: .white, smoothCorners: true)
        self.backdropBackgroundView.update(cornerRadius: 12.0, transition: .immediate)
        
        self.backgroundView = RoundedCornersView(color: .white, smoothCorners: true)
        self.backgroundView.update(cornerRadius: 12.0, transition: .immediate)
        self.backgroundView.isUserInteractionEnabled = false
        
        self.backgroundMaskView = UIView()
        self.backgroundMaskView.backgroundColor = .white
        self.backgroundView.mask = self.backgroundMaskView
        if let filter = makeLuminanceToAlphaFilter() {
            self.backgroundMaskView.layer.filters = [filter]
        }
        
        self.backgroundClippingView = UIView()
        self.backgroundClippingView.clipsToBounds = true
        self.backgroundClippingView.layer.cornerRadius = 12.0
        
        self.backgroundTextClippingView = UIView()
        self.backgroundTextClippingView.clipsToBounds = true
        
        self.backgroundTextView = TextView()
        self.textView = TextView()
        
        self.maskContents = UIView()
        
        self.maskContents.addSubview(self.backdropBackgroundView)
        
        super.init(frame: frame)
        
        (self.layer as? MirroringLayer)?.targetLayer = self.maskContents.layer
        
        self.backgroundTextClippingView.addSubview(self.backgroundTextView)
        self.backgroundTextClippingView.isUserInteractionEnabled = false
        self.addSubview(self.backgroundTextClippingView)
        
        self.backgroundClippingView.addSubview(self.backgroundView)
        self.backgroundClippingView.isUserInteractionEnabled = false
        self.addSubview(self.backgroundClippingView)
        
        self.backgroundMaskView.addSubview(self.textView)
        
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
        
        (self.layer as? MirroringLayer)?.didEnterHierarchy = { [weak self] in
            guard let self else {
                return
            }
            if self.fillTime < self.duration && self.updateDisplayLink == nil {
                self.updateDisplayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] deltaTime in
                    guard let self else {
                        return
                    }
                    self.fillTime = min(self.duration, self.fillTime + deltaTime)
                    if let params = self.params {
                        self.update(params: params, transition: .immediate)
                    }
                    
                    if self.fillTime >= self.duration {
                        self.updateDisplayLink = nil
                    }
                })
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func pressed() {
        self.pressAction?()
    }
    
    func animateIn() {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
    }
    
    func animateOut(completion: @escaping () -> Void) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }
    
    func update(text: String, size: CGSize, transition: ComponentTransition) {
        let params = Params(text: text, size: size)
        if self.params == params {
            return
        }
        self.params = params
        self.update(params: params, transition: transition)
    }
    
    private func update(params: Params, transition: ComponentTransition) {
        let fillFraction: CGFloat = CGFloat(self.fillTime / self.duration)
        
        let sideInset: CGFloat = 12.0
        let textSize = self.textView.update(string: params.text, fontSize: 17.0, fontWeight: UIFont.Weight.semibold.rawValue, color: .black, constrainedWidth: params.size.width - sideInset * 2.0, transition: .immediate)
        let _ = self.backgroundTextView.update(string: params.text, fontSize: 17.0, fontWeight: UIFont.Weight.semibold.rawValue, color: .white, constrainedWidth: params.size.width - sideInset * 2.0, transition: .immediate)
        
        transition.setFrame(view: self.backdropBackgroundView, frame: CGRect(origin: CGPoint(), size: params.size))
        transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: params.size))
        transition.setFrame(view: self.backgroundMaskView, frame: CGRect(origin: CGPoint(), size: params.size))
        
        let progressWidth: CGFloat = max(0.0, min(params.size.width, floorToScreenPixels(fillFraction * params.size.width)))
        let backgroundClippingFrame = CGRect(origin: CGPoint(x: progressWidth, y: 0.0), size: CGSize(width: params.size.width - progressWidth, height: params.size.height))
        transition.setPosition(view: self.backgroundClippingView, position: backgroundClippingFrame.center)
        transition.setBounds(view: self.backgroundClippingView, bounds: CGRect(origin: CGPoint(x: backgroundClippingFrame.minX, y: 0.0), size: backgroundClippingFrame.size))
        
        let backgroundTextClippingFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: progressWidth, height: params.size.height))
        transition.setPosition(view: self.backgroundTextClippingView, position: backgroundTextClippingFrame.center)
        transition.setBounds(view: self.backgroundTextClippingView, bounds: CGRect(origin: CGPoint(), size: backgroundTextClippingFrame.size))
        
        let textFrame = CGRect(origin: CGPoint(x: floor((params.size.width - textSize.width) * 0.5), y: floor((params.size.height - textSize.height) * 0.5)), size: textSize)
        transition.setFrame(view: self.textView, frame: textFrame)
        transition.setFrame(view: self.backgroundTextView, frame: textFrame)
    }
}
