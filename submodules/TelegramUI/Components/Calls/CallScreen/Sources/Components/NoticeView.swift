import Foundation
import UIKit
import Display
import ComponentFlow
import AppBundle

final class NoticeView: OverlayMaskContainerView {
    private let backgroundView: RoundedCornersView
    private let textContainer: UIView
    private let iconView: UIImageView
    private let textView: TextView
    private var closeButton: HighlightableButton?
    private var closeIconView: UIImageView?
    private var actionButton: HighlightTrackingButton?
    private var tailView: UIImageView?
    private var pillSize: CGSize = CGSize()
    
    var action: (() -> Void)?
    var closeAction: (() -> Void)?
    var closeAccessibilityLabel: String?
    
    override init(frame: CGRect) {
        self.backgroundView = RoundedCornersView(color: .white)
        self.textContainer = UIView()
        self.textContainer.clipsToBounds = true
        self.iconView = UIImageView()
        self.textView = TextView()
        
        super.init(frame: frame)
        
        self.clipsToBounds = true
        
        self.maskContents.addSubview(self.backgroundView)
        
        self.textContainer.addSubview(self.iconView)
        self.textContainer.addSubview(self.textView)
        self.addSubview(self.textContainer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func animateIn() {
        let delay: Double = 0.2
        let pillSize = self.pillSize
        
        self.layer.animateScale(from: 0.001, to: 1.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
        self.textView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, delay: delay)
        
        self.backgroundView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
        self.backgroundView.layer.animateFrame(from: CGRect(origin: CGPoint(x: (pillSize.width - pillSize.height) * 0.5, y: 0.0), size: CGSize(width: pillSize.height, height: pillSize.height)), to: self.backgroundView.frame, duration: 0.5, delay: delay, timingFunction: kCAMediaTimingFunctionSpring)
        
        if let tailView = self.tailView {
            tailView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, delay: delay)
        }
        
        self.iconView.layer.animatePosition(from: CGPoint(x: -4.0, y: 0.0), to: CGPoint(), duration: 0.15, delay: delay, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        
        //self.textContainer.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: delay)
        self.textContainer.layer.cornerRadius = pillSize.height * 0.5
        self.textContainer.layer.animateFrame(from: CGRect(origin: CGPoint(x: (pillSize.width - pillSize.height) * 0.5, y: 0.0), size: CGSize(width: pillSize.height, height: pillSize.height)), to: self.textContainer.frame, duration: 0.5, delay: delay, timingFunction: kCAMediaTimingFunctionSpring, completion: { [weak self] completed in
            guard let self, completed else {
                return
            }
            self.textContainer.layer.cornerRadius = 0.0
        })
    }
    
    @objc private func closePressed() {
        self.closeAction?()
    }
    
    @objc private func actionPressed() {
        self.action?()
    }
    
    func animateOut(completion: @escaping () -> Void) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
            completion()
        })
        self.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, removeOnCompletion: false)
    }
    
    /// The returned size includes the tail (`PrivateCallNoticeTailLayout.tailHeight`, below the pill) when `displayTail`
    /// is set; `updateTail(x:transition:)` then places it.
    func update(icon: String, text: String, displayClose: Bool, displayTail: Bool, constrainedWidth: CGFloat, transition: ComponentTransition) -> CGSize {
        let sideInset: CGFloat = 12.0
        let verticalInset: CGFloat = 6.0
        let iconSpacing: CGFloat = -3.0
        let closeSpacing: CGFloat = 6.0
        let closeIconSize = CGSize(width: 16.0, height: 16.0)
        let closeWidth: CGFloat = displayClose ? closeSpacing + closeIconSize.width : 0.0
        
        if self.iconView.image == nil {
            self.iconView.image = UIImage(bundleImageName: icon)?.withRenderingMode(.alwaysTemplate)
            self.iconView.tintColor = .white
        }
        let iconSize = self.iconView.image?.size ?? CGSize(width: 12.0, height: 12.0)
        
        let textSize = self.textView.update(string: text, fontSize: 15.0, fontWeight: 0.0, color: .white, constrainedWidth: constrainedWidth - sideInset * 2.0 - closeWidth, transition: .immediate)
        let size = CGSize(width: iconSize.width + iconSpacing + textSize.width + closeWidth + sideInset * 2.0, height: textSize.height + verticalInset * 2.0)
        self.pillSize = size
        
        transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: size))
        self.backgroundView.update(cornerRadius: floor(size.height * 0.5), transition: transition)
        
        transition.setFrame(view: self.textContainer, frame: CGRect(origin: CGPoint(), size: size))
        
        transition.setFrame(view: self.iconView, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.height - iconSize.height) * 0.5) + 4.0, y: verticalInset + floorToScreenPixels((textSize.height - iconSize.height) * 0.5)), size: iconSize))
        
        let textFrame = CGRect(origin: CGPoint(x: sideInset + iconSize.width + iconSpacing, y: verticalInset), size: textSize)
        transition.setFrame(view: self.textView, frame: textFrame)
        
        if self.action != nil {
            let actionButton: HighlightTrackingButton
            var actionTransition = transition
            if let current = self.actionButton {
                actionButton = current
            } else {
                actionTransition = .immediate
                actionButton = HighlightTrackingButton()
                actionButton.addTarget(self, action: #selector(self.actionPressed), for: .touchUpInside)
                actionButton.highligthedChanged = { [weak self] highlighted in
                    guard let self else {
                        return
                    }
                    for view in [self.iconView, self.textView] {
                        if highlighted {
                            view.layer.removeAnimation(forKey: "opacity")
                            view.alpha = 0.6
                        } else {
                            view.alpha = 1.0
                            view.layer.animateAlpha(from: 0.6, to: 1.0, duration: 0.2)
                        }
                    }
                }
                self.actionButton = actionButton
                // Above the icon and text, below the close button.
                self.textContainer.insertSubview(actionButton, aboveSubview: self.textView)
            }
            actionButton.accessibilityLabel = text
            actionTransition.setFrame(view: actionButton, frame: CGRect(origin: CGPoint(), size: size))
        } else if let actionButton = self.actionButton {
            self.actionButton = nil
            actionButton.removeFromSuperview()
        }
        
        if displayClose {
            let closeButton: HighlightableButton
            let closeIconView: UIImageView
            var closeTransition = transition
            if let current = self.closeButton, let currentIconView = self.closeIconView {
                closeButton = current
                closeIconView = currentIconView
            } else {
                closeTransition = .immediate
                closeButton = HighlightableButton()
                closeButton.addTarget(self, action: #selector(self.closePressed), for: .touchUpInside)
                closeIconView = UIImageView(image: UIImage(bundleImageName: "Components/Close")?.withRenderingMode(.alwaysTemplate))
                closeIconView.tintColor = .white
                closeButton.addSubview(closeIconView)
                self.closeButton = closeButton
                self.closeIconView = closeIconView
                self.textContainer.addSubview(closeButton)
            }
            closeButton.accessibilityLabel = self.closeAccessibilityLabel
            // The button takes the pill's height from just before the end of the text to its trailing edge.
            let closeButtonOverlap: CGFloat = 10.0
            let closeButtonFrame = CGRect(origin: CGPoint(x: textFrame.maxX - closeButtonOverlap, y: 0.0), size: CGSize(width: size.width - textFrame.maxX + closeButtonOverlap, height: size.height))
            closeTransition.setFrame(view: closeButton, frame: closeButtonFrame)
            closeTransition.setFrame(view: closeIconView, frame: CGRect(origin: CGPoint(x: closeButtonOverlap + closeSpacing, y: floorToScreenPixels((size.height - closeIconSize.height) * 0.5)), size: closeIconSize))
        } else if let closeButton = self.closeButton {
            self.closeButton = nil
            self.closeIconView = nil
            closeButton.removeFromSuperview()
        }
        
        if displayTail {
            if self.tailView == nil {
                let tailSize = CGSize(width: PrivateCallNoticeTailLayout.tailWidth, height: PrivateCallNoticeTailLayout.tailHeight)
                let tailView = UIImageView(image: generateImage(tailSize, rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.translateBy(x: 0.0, y: size.height)
                    context.scaleBy(x: 1.0, y: -1.0)
                    context.setFillColor(UIColor.white.cgColor)
                    let _ = try? drawSvgPath(context, path: callTooltipTailSvgPath)
                }))
                tailView.frame = CGRect(origin: CGPoint(x: floor((size.width - tailSize.width) * 0.5), y: size.height), size: tailSize)
                self.tailView = tailView
                self.maskContents.addSubview(tailView)
            }
            return CGSize(width: size.width, height: size.height + PrivateCallNoticeTailLayout.tailHeight)
        } else {
            if let tailView = self.tailView {
                self.tailView = nil
                tailView.removeFromSuperview()
            }
            return size
        }
    }
    
    /// Centers the tail at `x` in the notice, under the pill.
    func updateTail(x: CGFloat, transition: ComponentTransition) {
        guard let tailView = self.tailView else {
            return
        }
        let tailSize = CGSize(width: PrivateCallNoticeTailLayout.tailWidth, height: PrivateCallNoticeTailLayout.tailHeight)
        transition.setFrame(view: tailView, frame: CGRect(origin: CGPoint(x: x - tailSize.width * 0.5, y: self.pillSize.height), size: tailSize))
    }
}
