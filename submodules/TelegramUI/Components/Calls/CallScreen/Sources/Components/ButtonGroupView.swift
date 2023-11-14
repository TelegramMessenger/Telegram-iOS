import Foundation
import UIKit
import Display
import ComponentFlow
import AppBundle

final class ButtonGroupView: UIView, ContentOverlayView {
    final class Button {
        enum Content: Equatable {
            enum Key: Hashable {
                case speaker
                case video
                case microphone
                case end
            }
            
            case speaker(isActive: Bool)
            case video(isActive: Bool)
            case microphone(isMuted: Bool)
            case end
            
            var key: Key {
                switch self {
                case .speaker:
                    return .speaker
                case .video:
                    return .video
                case .microphone:
                    return .microphone
                case .end:
                    return .end
                }
            }
        }
        
        let content: Content
        let action: () -> Void
        
        init(content: Content, action: @escaping () -> Void) {
            self.content = content
            self.action = action
        }
    }
    
    let overlayMaskLayer: CALayer
    
    private var buttons: [Button]?
    private var buttonViews: [Button.Content.Key: ContentOverlayButton] = [:]
    
    override init(frame: CGRect) {
        self.overlayMaskLayer = SimpleLayer()
        
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func addSubview(_ view: UIView) {
        super.addSubview(view)
        
        if let view = view as? ContentOverlayView {
            self.overlayMaskLayer.addSublayer(view.overlayMaskLayer)
        }
    }
    
    override func insertSubview(_ view: UIView, at index: Int) {
        super.insertSubview(view, at: index)
        
        if let view = view as? ContentOverlayView {
            self.overlayMaskLayer.addSublayer(view.overlayMaskLayer)
        }
    }
    
    override func insertSubview(_ view: UIView, aboveSubview siblingSubview: UIView) {
        super.insertSubview(view, aboveSubview: siblingSubview)
        
        if let view = view as? ContentOverlayView {
            self.overlayMaskLayer.addSublayer(view.overlayMaskLayer)
        }
    }
    
    override func insertSubview(_ view: UIView, belowSubview siblingSubview: UIView) {
        super.insertSubview(view, belowSubview: siblingSubview)
        
        if let view = view as? ContentOverlayView {
            self.overlayMaskLayer.addSublayer(view.overlayMaskLayer)
        }
    }
    
    override func willRemoveSubview(_ subview: UIView) {
        super.willRemoveSubview(subview)
        
        if let view = subview as? ContentOverlayView {
            view.overlayMaskLayer.removeFromSuperlayer()
        }
    }
    
    func update(size: CGSize, buttons: [Button], transition: Transition) {
        self.buttons = buttons
        
        let buttonSize: CGFloat = 56.0
        let buttonSpacing: CGFloat = 36.0
        
        let buttonY: CGFloat = size.height - 86.0 - buttonSize
        var buttonX: CGFloat = floor((size.width - buttonSize * CGFloat(buttons.count) - buttonSpacing * CGFloat(buttons.count - 1)) * 0.5)
        
        for button in buttons {
            let title: String
            let image: UIImage?
            let isActive: Bool
            var isDestructive: Bool = false
            switch button.content {
            case let .speaker(isActiveValue):
                title = "speaker"
                image = UIImage(bundleImageName: "Call/Speaker")
                isActive = isActiveValue
            case let .video(isActiveValue):
                title = "video"
                image = UIImage(bundleImageName: "Call/Video")
                isActive = isActiveValue
            case let .microphone(isActiveValue):
                title = "mute"
                image = UIImage(bundleImageName: "Call/Mute")
                isActive = isActiveValue
            case .end:
                title = "end"
                image = UIImage(bundleImageName: "Call/End")
                isActive = false
                isDestructive = true
            }
            
            let buttonView: ContentOverlayButton
            if let current = self.buttonViews[button.content.key] {
                buttonView = current
            } else {
                buttonView = ContentOverlayButton(frame: CGRect())
                self.addSubview(buttonView)
                self.buttonViews[button.content.key] = buttonView
                
                let key = button.content.key
                buttonView.action = { [weak self] in
                    guard let self, let button = self.buttons?.first(where: { $0.content.key == key }) else {
                        return
                    }
                    button.action()
                }
            }
            
            buttonView.frame = CGRect(origin: CGPoint(x: buttonX, y: buttonY), size: CGSize(width: buttonSize, height: buttonSize))
            buttonView.update(size: CGSize(width: buttonSize, height: buttonSize), image: image, isSelected: isActive, isDestructive: isDestructive, title: title, transition: transition)
            buttonX += buttonSize + buttonSpacing
        }
        
        var removeKeys: [Button.Content.Key] = []
        for (key, buttonView) in self.buttonViews {
            if !buttons.contains(where: { $0.content.key == key }) {
                removeKeys.append(key)
                transition.setScale(view: buttonView, scale: 0.001)
                transition.setAlpha(view: buttonView, alpha: 0.0, completion: { [weak buttonView] _ in
                    buttonView?.removeFromSuperview()
                })
            }
        }
        for key in removeKeys {
            self.buttonViews.removeValue(forKey: key)
        }
    }
}
