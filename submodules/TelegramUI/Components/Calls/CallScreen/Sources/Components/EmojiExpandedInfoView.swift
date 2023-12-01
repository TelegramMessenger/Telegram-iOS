import Foundation
import UIKit
import Display
import ComponentFlow

final class EmojiExpandedInfoView: OverlayMaskContainerView {
    private struct Params: Equatable {
        var constrainedWidth: CGFloat
        var sideInset: CGFloat
        
        init(constrainedWidth: CGFloat, sideInset: CGFloat) {
            self.constrainedWidth = constrainedWidth
            self.sideInset = sideInset
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
    
    private let title: String
    private let text: String
    
    private let backgroundView: UIImageView
    private let titleView: TextView
    private let textView: TextView
    
    private let actionButton: HighlightTrackingButton
    private let actionTitleView: TextView
    
    private var currentLayout: Layout?
    
    var closeAction: (() -> Void)?
    
    init(title: String, text: String) {
        self.title = title
        self.text = text
        
        self.backgroundView = UIImageView()
        let cornerRadius: CGFloat = 18.0
        let buttonHeight: CGFloat = 56.0
        self.backgroundView.image = generateImage(CGSize(width: cornerRadius * 2.0 + 10.0, height: cornerRadius + 10.0 + buttonHeight), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.addPath(UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: cornerRadius).cgPath)
            context.setFillColor(UIColor.white.cgColor)
            context.fillPath()
            
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(CGRect(origin: CGPoint(x: 0.0, y: size.height - buttonHeight), size: CGSize(width: size.width, height: UIScreenPixel)))
        })?.stretchableImage(withLeftCapWidth: Int(cornerRadius) + 5, topCapHeight: Int(cornerRadius) + 5)
        
        self.titleView = TextView()
        self.textView = TextView()
        
        self.actionButton = HighlightTrackingButton()
        self.actionTitleView = TextView()
        self.actionTitleView.isUserInteractionEnabled = false
        
        super.init(frame: CGRect())
        
        self.maskContents.addSubview(self.backgroundView)
        
        self.addSubview(self.titleView)
        self.addSubview(self.textView)
        
        self.addSubview(self.actionButton)
        self.actionButton.addSubview(self.actionTitleView)
        
        self.actionButton.internalHighligthedChanged = { [weak self] highlighted in
            if let self, self.bounds.width > 0.0 {
                let topScale: CGFloat = (self.bounds.width - 8.0) / self.bounds.width
                let maxScale: CGFloat = (self.bounds.width + 2.0) / self.bounds.width
                
                if highlighted {
                    self.actionButton.layer.removeAnimation(forKey: "sublayerTransform")
                    let transition = Transition(animation: .curve(duration: 0.15, curve: .easeInOut))
                    transition.setScale(layer: self.actionButton.layer, scale: topScale)
                } else {
                    let t = self.actionButton.layer.presentation()?.transform ?? layer.transform
                    let currentScale = sqrt((t.m11 * t.m11) + (t.m12 * t.m12) + (t.m13 * t.m13))
                    
                    let transition = Transition(animation: .none)
                    transition.setScale(layer: self.actionButton.layer, scale: 1.0)
                    
                    self.actionButton.layer.animateScale(from: currentScale, to: maxScale, duration: 0.13, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { [weak self] completed in
                        guard let self, completed else {
                            return
                        }
                        
                        self.actionButton.layer.animateScale(from: maxScale, to: 1.0, duration: 0.1, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue)
                    })
                }
            }
        }
        self.actionButton.addTarget(self, action: #selector(self.actionButtonPressed), for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func actionButtonPressed() {
        self.closeAction?()
    }
    
    func update(constrainedWidth: CGFloat, sideInset: CGFloat, transition: Transition) -> CGSize {
        let params = Params(constrainedWidth: constrainedWidth, sideInset: sideInset)
        if let currentLayout = self.currentLayout, currentLayout.params == params {
            return currentLayout.size
        }
        let size = self.update(params: params, transition: transition)
        self.currentLayout = Layout(params: params, size: size)
        return size
    }
    
    private func update(params: Params, transition: Transition) -> CGSize {
        let size = CGSize(width: 304.0, height: 227.0)
        
        transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: size))
        
        let titleSize = self.titleView.update(string: self.title, fontSize: 16.0, fontWeight: 0.3, alignment: .center, color: .white, constrainedWidth: params.constrainedWidth - params.sideInset * 2.0 - 16.0 * 2.0, transition: transition)
        let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) * 0.5), y: 78.0), size: titleSize)
        transition.setFrame(view: self.titleView, frame: titleFrame)
        
        let textSize = self.textView.update(string: self.text, fontSize: 16.0, fontWeight: 0.0, alignment: .center, color: .white, constrainedWidth: params.constrainedWidth - params.sideInset * 2.0 - 16.0 * 2.0, transition: transition)
        let textFrame = CGRect(origin: CGPoint(x: floor((size.width - textSize.width) * 0.5), y: titleFrame.maxY + 10.0), size: textSize)
        transition.setFrame(view: self.textView, frame: textFrame)
        
        let buttonHeight: CGFloat = 56.0
        let buttonFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height - buttonHeight), size: CGSize(width: size.width, height: buttonHeight))
        transition.setFrame(view: self.actionButton, frame: buttonFrame)
        
        let actionTitleSize = self.actionTitleView.update(string: "OK", fontSize: 19.0, fontWeight: 0.3, color: .white, constrainedWidth: size.width, transition: transition)
        let actionTitleFrame = CGRect(origin: CGPoint(x: floor((buttonFrame.width - actionTitleSize.width) * 0.5), y: floor((buttonFrame.height - actionTitleSize.height) * 0.5)), size: actionTitleSize)
        transition.setFrame(view: self.actionTitleView, frame: actionTitleFrame)
        
        return size
    }
}
