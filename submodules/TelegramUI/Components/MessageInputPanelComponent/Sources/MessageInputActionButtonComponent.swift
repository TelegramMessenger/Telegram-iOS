import Foundation
import UIKit
import Display
import ComponentFlow
import AppBundle

public final class MessageInputActionButtonComponent: Component {
    public enum Mode {
        case send
        case voiceInput
        case videoInput
    }

    public let mode: Mode
    public let action: () -> Void
    
    public init(
        mode: Mode,
        action: @escaping () -> Void
    ) {
        self.mode = mode
        self.action = action
    }
    
    public static func ==(lhs: MessageInputActionButtonComponent, rhs: MessageInputActionButtonComponent) -> Bool {
        if lhs.mode != rhs.mode {
            return false
        }
        return true
    }
    
    public final class View: HighlightTrackingButton {
        private let microphoneIconView: UIImageView
        private let cameraIconView: UIImageView
        private let sendIconView: UIImageView
        
        private var component: MessageInputActionButtonComponent?
        private weak var componentState: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.microphoneIconView = UIImageView()
            
            self.cameraIconView = UIImageView()
            self.sendIconView = UIImageView()
            
            super.init(frame: frame)
            
            self.isMultipleTouchEnabled = false
            
            self.addSubview(self.microphoneIconView)
            self.addSubview(self.cameraIconView)
            self.addSubview(self.sendIconView)
            
            self.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                
                let scale: CGFloat = highlighted ? 0.6 : 1.0
                
                let transition = Transition(animation: .curve(duration: highlighted ? 0.5 : 0.3, curve: .spring))
                transition.setSublayerTransform(view: self, transform: CATransform3DMakeScale(scale, scale, 1.0))
            }
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            self.component?.action()
        }
        
        override public func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
            return super.continueTracking(touch, with: event)
        }
        
        func update(component: MessageInputActionButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.componentState = state
            
            if self.microphoneIconView.image == nil {
                self.microphoneIconView.image = UIImage(bundleImageName: "Chat/Input/Text/IconMicrophone")?.withRenderingMode(.alwaysTemplate)
                self.microphoneIconView.tintColor = .white
            }
            if self.cameraIconView.image == nil {
                self.cameraIconView.image = UIImage(bundleImageName: "Chat/Input/Text/IconVideo")?.withRenderingMode(.alwaysTemplate)
                self.cameraIconView.tintColor = .white
            }
            
            if self.sendIconView.image == nil {
                self.sendIconView.image = generateImage(CGSize(width: 33.0, height: 33.0), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.setFillColor(UIColor.white.cgColor)
                    context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                    context.setBlendMode(.copy)
                    context.setStrokeColor(UIColor.clear.cgColor)
                    context.setLineWidth(2.0)
                    context.setLineCap(.round)
                    context.setLineJoin(.round)
                    
                    context.translateBy(x: 5.45, y: 4.0)
                    
                    context.saveGState()
                    context.translateBy(x: 4.0, y: 4.0)
                    let _ = try? drawSvgPath(context, path: "M1,7 L7,1 L13,7 S ")
                    context.restoreGState()
                    
                    context.saveGState()
                    context.translateBy(x: 10.0, y: 4.0)
                    let _ = try? drawSvgPath(context, path: "M1,16 V1 S ")
                    context.restoreGState()
                })
            }
            
            var sendAlpha: CGFloat = 0.0
            var microphoneAlpha: CGFloat = 0.0
            var cameraAlpha: CGFloat = 0.0
            
            switch component.mode {
            case .send:
                sendAlpha = 1.0
            case .videoInput:
                cameraAlpha = 1.0
            case .voiceInput:
                microphoneAlpha = 1.0
            }
            
            transition.setAlpha(view: self.sendIconView, alpha: sendAlpha)
            transition.setScale(view: self.sendIconView, scale: sendAlpha == 0.0 ? 0.01 : 1.0)
            
            transition.setAlpha(view: self.cameraIconView, alpha: cameraAlpha)
            transition.setScale(view: self.cameraIconView, scale: cameraAlpha == 0.0 ? 0.01 : 1.0)
            
            transition.setAlpha(view: self.microphoneIconView, alpha: microphoneAlpha)
            transition.setScale(view: self.microphoneIconView, scale: microphoneAlpha == 0.0 ? 0.01 : 1.0)
            
            if let image = self.sendIconView.image {
                let iconFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - image.size.width) * 0.5), y: floorToScreenPixels((availableSize.height - image.size.height) * 0.5)), size: image.size)
                transition.setPosition(view: self.sendIconView, position: iconFrame.center)
                transition.setBounds(view: self.sendIconView, bounds: CGRect(origin: CGPoint(), size: iconFrame.size))
            }
            if let image = self.cameraIconView.image {
                let iconFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - image.size.width) * 0.5), y: floorToScreenPixels((availableSize.height - image.size.height) * 0.5)), size: image.size)
                transition.setPosition(view: self.cameraIconView, position: iconFrame.center)
                transition.setBounds(view: self.cameraIconView, bounds: CGRect(origin: CGPoint(), size: iconFrame.size))
            }
            if let image = self.microphoneIconView.image {
                let iconFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - image.size.width) * 0.5), y: floorToScreenPixels((availableSize.height - image.size.height) * 0.5)), size: image.size)
                transition.setPosition(view: self.microphoneIconView, position: iconFrame.center)
                transition.setBounds(view: self.microphoneIconView, bounds: CGRect(origin: CGPoint(), size: iconFrame.size))
            }
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
