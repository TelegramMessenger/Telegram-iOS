import Foundation
import UIKit
import Display
import ComponentFlow

final class EmojiExpandedInfoView: OverlayMaskContainerView {
    private struct Params: Equatable {
        var width: CGFloat
        
        init(width: CGFloat) {
            self.width = width
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
    private let separatorLayer: SimpleLayer
    
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
        
        self.separatorLayer = SimpleLayer()
        
        self.titleView = TextView()
        self.textView = TextView()
        
        self.actionButton = HighlightTrackingButton()
        self.actionTitleView = TextView()
        self.actionTitleView.isUserInteractionEnabled = false
        
        super.init(frame: CGRect())
        
        self.maskContents.addSubview(self.backgroundView)
        
        self.layer.addSublayer(self.separatorLayer)
        
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
                    let transition = ComponentTransition(animation: .curve(duration: 0.15, curve: .easeInOut))
                    transition.setScale(layer: self.actionButton.layer, scale: topScale)
                } else {
                    let t = self.actionButton.layer.presentation()?.transform ?? layer.transform
                    let currentScale = sqrt((t.m11 * t.m11) + (t.m12 * t.m12) + (t.m13 * t.m13))
                    
                    let transition = ComponentTransition(animation: .none)
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
        
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func actionButtonPressed() {
        self.closeAction?()
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.closeAction?()
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.actionButton.hitTest(self.convert(point, to: self.actionButton), with: event) {
            return result
        }
        return nil
    }
    
    func update(width: CGFloat, transition: ComponentTransition) -> CGSize {
        let params = Params(width: width)
        if let currentLayout = self.currentLayout, currentLayout.params == params {
            return currentLayout.size
        }
        let size = self.update(params: params, transition: transition)
        self.currentLayout = Layout(params: params, size: size)
        return size
    }
    
    private func update(params: Params, transition: ComponentTransition) -> CGSize {
        let buttonHeight: CGFloat = 56.0
        
        let titleSize = self.titleView.update(string: self.title, fontSize: 16.0, fontWeight: 0.3, alignment: .center, color: .white, constrainedWidth: params.width - 16.0 * 2.0, transition: transition)
        let textSize = self.textView.update(string: self.text, fontSize: 16.0, fontWeight: 0.0, alignment: .center, color: .white, constrainedWidth: params.width - 16.0 * 2.0, transition: transition)
        
        let contentHeight = 78.0 + titleSize.height + 10.0 + textSize.height + 22.0 + buttonHeight
        
        let size = CGSize(width: params.width, height: contentHeight)
        
        transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: size))
        
        let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) * 0.5), y: 78.0), size: titleSize)
        transition.setFrame(view: self.titleView, frame: titleFrame)
        
        let textFrame = CGRect(origin: CGPoint(x: floor((size.width - textSize.width) * 0.5), y: titleFrame.maxY + 10.0), size: textSize)
        transition.setFrame(view: self.textView, frame: textFrame)
        
        let buttonFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height - buttonHeight), size: CGSize(width: size.width, height: buttonHeight))
        transition.setFrame(view: self.actionButton, frame: buttonFrame)
        
        transition.setFrame(layer: self.separatorLayer, frame: CGRect(origin: CGPoint(x: 0.0, y: size.height - buttonHeight), size: CGSize(width: size.width, height: UIScreenPixel)))
        
        let actionTitleSize = self.actionTitleView.update(string: "OK", fontSize: 19.0, fontWeight: 0.3, color: .white, constrainedWidth: size.width, transition: transition)
        let actionTitleFrame = CGRect(origin: CGPoint(x: floor((buttonFrame.width - actionTitleSize.width) * 0.5), y: floor((buttonFrame.height - actionTitleSize.height) * 0.5)), size: actionTitleSize)
        transition.setFrame(view: self.actionTitleView, frame: actionTitleFrame)
        
        return size
    }
}
