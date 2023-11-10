import Foundation
import UIKit
import Display

final class ButtonGroupView: UIView, ContentOverlayView {
    enum Key: Hashable {
        case audio
        case video
        case mic
        case close
    }
    
    let overlayMaskLayer: CALayer
    private var buttons: [Key: ContentOverlayButton] = [:]
    
    var audioPressed: (() -> Void)?
    var toggleVideo: (() -> Void)?
    
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
    
    func update(size: CGSize) {
        var keys: [Key] = []
        keys.append(.audio)
        keys.append(.video)
        keys.append(.mic)
        keys.append(.close)
        
        let buttonSize: CGFloat = 56.0
        let buttonSpacing: CGFloat = 36.0
        
        let buttonY: CGFloat = size.height - 86.0 - buttonSize
        var buttonX: CGFloat = floor((size.width - buttonSize * CGFloat(keys.count) - buttonSpacing * CGFloat(keys.count - 1)) * 0.5)
        
        for key in keys {
            let button: ContentOverlayButton
            if let current = self.buttons[key] {
                button = current
            } else {
                button = ContentOverlayButton(frame: CGRect())
                self.addSubview(button)
                self.buttons[key] = button
                
                let image: UIImage?
                switch key {
                case .audio:
                    image = UIImage(named: "Call/Speaker")
                    button.action = { [weak self] in
                        guard let self else {
                            return
                        }
                        self.audioPressed?()
                    }
                case .video:
                    image = UIImage(named: "Call/Video")
                    button.action = { [weak self] in
                        guard let self else {
                            return
                        }
                        self.toggleVideo?()
                    }
                case .mic:
                    image = UIImage(named: "Call/Mute")
                case .close:
                    image = UIImage(named: "Call/End")
                }
                
                button.setImage(image?.withRenderingMode(.alwaysTemplate), for: .normal)
                button.imageView?.tintColor = .white
            }
            
            button.frame = CGRect(origin: CGPoint(x: buttonX, y: buttonY), size: CGSize(width: buttonSize, height: buttonSize))
            buttonX += buttonSize + buttonSpacing
        }
        
        var removeKeys: [Key] = []
        for (key, button) in self.buttons {
            if !keys.contains(key) {
                removeKeys.append(key)
                button.removeFromSuperview()
            }
        }
        for key in removeKeys {
            self.buttons.removeValue(forKey: key)
        }
    }
}
