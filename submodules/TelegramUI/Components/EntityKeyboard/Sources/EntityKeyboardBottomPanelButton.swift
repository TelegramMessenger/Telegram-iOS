import Foundation
import UIKit
import Display
import ComponentFlow
import PagerComponent
import ComponentDisplayAdapters
import BundleIconComponent
import GlassBackgroundComponent
import AppBundle

final class EntityKeyboardBottomPanelButton: Component {
    let icon: String
    let color: UIColor
    let action: () -> Void
    let holdAction: (() -> Void)?
    
    init(
        icon: String,
        color: UIColor,
        action: @escaping () -> Void,
        holdAction: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.color = color
        self.action = action
        self.holdAction = holdAction
    }
    
    static func ==(lhs: EntityKeyboardBottomPanelButton, rhs: EntityKeyboardBottomPanelButton) -> Bool {
        if lhs.icon != rhs.icon {
            return false
        }
        if lhs.color != rhs.color {
            return false
        }
        if (lhs.holdAction == nil) != (rhs.holdAction == nil) {
            return false
        }
        return true
    }
    
    final class View: HighlightTrackingButton {
        let iconView: GlassBackgroundView.ContentImageView
        let tintMaskContainer: UIView

        private var holdActionTriggerred: Bool = false
        private var holdActionTimer: Timer?
        
        var component: EntityKeyboardBottomPanelButton?

        private var currentIsHighlighted: Bool = false {
            didSet {
                if self.currentIsHighlighted != oldValue {
                    self.updateAlpha(transition: .immediate)
                }
            }
        }
        
        override init(frame: CGRect) {
            self.iconView = GlassBackgroundView.ContentImageView()
            self.iconView.isUserInteractionEnabled = false
            
            self.tintMaskContainer = UIView()
            self.tintMaskContainer.addSubview(self.iconView.tintMask)
            
            super.init(frame: frame)

            self.addSubview(self.iconView)
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.holdActionTimer?.invalidate()
        }
        
        @objc private func pressed() {
            if self.holdActionTriggerred {
                self.holdActionTriggerred = false
            } else {
                self.component?.action()
            }
        }

        override public func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
            self.currentIsHighlighted = true
            
            self.holdActionTriggerred = false
            
            if self.component?.holdAction != nil {
                self.holdActionTriggerred = true
                self.component?.action()
                
                self.holdActionTimer?.invalidate()
                let holdActionTimer = Timer(timeInterval: 0.5, repeats: false, block: { [weak self] _ in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.holdActionTimer?.invalidate()
                    strongSelf.component?.holdAction?()
                    strongSelf.beginExecuteHoldActionTimer()
                })
                self.holdActionTimer = holdActionTimer
                RunLoop.main.add(holdActionTimer, forMode: .common)
            }
            
            return super.beginTracking(touch, with: event)
        }
        
        private func beginExecuteHoldActionTimer() {
            self.holdActionTimer?.invalidate()
            let holdActionTimer = Timer(timeInterval: 0.1, repeats: true, block: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.component?.holdAction?()
            })
            self.holdActionTimer = holdActionTimer
            RunLoop.main.add(holdActionTimer, forMode: .common)
        }
        
        override public func endTracking(_ touch: UITouch?, with event: UIEvent?) {
            self.currentIsHighlighted = false
            
            self.holdActionTimer?.invalidate()
            self.holdActionTimer = nil
            
            super.endTracking(touch, with: event)
        }
        
        override public func cancelTracking(with event: UIEvent?) {
            self.currentIsHighlighted = false
            
            self.holdActionTimer?.invalidate()
            self.holdActionTimer = nil
            
            super.cancelTracking(with: event)
        }

        private func updateAlpha(transition: ComponentTransition) {
            let alpha: CGFloat = self.currentIsHighlighted ? 0.6 : 1.0
            transition.setAlpha(view: self.iconView, alpha: alpha)
        }
        
        func update(component: EntityKeyboardBottomPanelButton, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            if self.component?.icon != component.icon {
                self.iconView.image = UIImage(bundleImageName: component.icon)?.withRenderingMode(.alwaysTemplate)
            }

            self.component = component

            self.iconView.tintColor = component.color
            
            let size = CGSize(width: 38.0, height: 38.0)
            
            if let image = self.iconView.image {
                let iconFrame = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) * 0.5), y: floor((size.height - image.size.height) * 0.5)), size: image.size)
                self.iconView.frame = iconFrame
            }
            
            return size
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
