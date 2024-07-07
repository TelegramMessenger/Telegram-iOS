import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import TelegramCore

private let premiumBadgeIcon: UIImage? = generateTintedImage(image: UIImage(bundleImageName: "Chat List/PeerPremiumIcon"), color: .white)
private let featuredBadgeIcon: UIImage? = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Media/PanelBadgeAdd"), color: .white)
private let lockedBadgeIcon: UIImage? = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Media/PanelBadgeLock"), color: .white)

private let itemBadgeTextFont: UIFont = {
    return Font.regular(10.0)
}()

final class PremiumBadgeView: UIView {
    private let context: AccountContext
    
    private var badge: EmojiKeyboardItemLayer.Badge?
    
    let contentLayer: SimpleLayer
    private let overlayColorLayer: SimpleLayer
    private let iconLayer: SimpleLayer
    private var customFileLayer: InlineFileIconLayer?
    
    init(context: AccountContext) {
        self.context = context
        
        self.contentLayer = SimpleLayer()
        self.contentLayer.contentsGravity = .resize
        self.contentLayer.masksToBounds = true
        
        self.overlayColorLayer = SimpleLayer()
        self.overlayColorLayer.masksToBounds = true
        
        self.iconLayer = SimpleLayer()
        
        super.init(frame: CGRect())
        
        self.layer.addSublayer(self.contentLayer)
        self.layer.addSublayer(self.overlayColorLayer)
        self.layer.addSublayer(self.iconLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(transition: ComponentTransition, badge: EmojiKeyboardItemLayer.Badge, backgroundColor: UIColor, size: CGSize) {
        if self.badge != badge {
            self.badge = badge
            
            switch badge {
            case .premium:
                self.iconLayer.contents = premiumBadgeIcon?.cgImage
            case .featured:
                self.iconLayer.contents = featuredBadgeIcon?.cgImage
            case .locked:
                self.iconLayer.contents = lockedBadgeIcon?.cgImage
            case let .text(text):
                let string = NSAttributedString(string: text, font: itemBadgeTextFont)
                let size = CGSize(width: 12.0, height: 12.0)
                let stringBounds = string.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
                let image = generateImage(size, rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    UIGraphicsPushContext(context)
                    string.draw(at: CGPoint(x: floor((size.width - stringBounds.width) * 0.5), y: floor((size.height - stringBounds.height) * 0.5)))
                    UIGraphicsPopContext()
                })
                self.iconLayer.contents = image?.cgImage
            case .customFile:
                self.iconLayer.contents = nil
            }
            
            if case let .customFile(customFile) = badge {
                let customFileLayer: InlineFileIconLayer
                if let current = self.customFileLayer {
                    customFileLayer = current
                } else {
                    customFileLayer = InlineFileIconLayer(
                        context: self.context,
                        userLocation: .other,
                        attemptSynchronousLoad: false,
                        file: customFile,
                        cache: self.context.animationCache,
                        renderer: self.context.animationRenderer,
                        unique: false,
                        placeholderColor: .clear,
                        pointSize: CGSize(width: 18.0, height: 18.0),
                        dynamicColor: nil
                    )
                    self.customFileLayer = customFileLayer
                    self.layer.addSublayer(customFileLayer)
                }
                let _ = customFileLayer
            } else {
                if let customFileLayer = self.customFileLayer {
                    self.customFileLayer = nil
                    customFileLayer.removeFromSuperlayer()
                }
            }
        }
        
        let iconInset: CGFloat
        switch badge {
        case .premium:
            iconInset = 2.0
        case .featured:
            iconInset = 0.0
        case .locked:
            iconInset = 0.0
        case .text, .customFile:
            iconInset = 0.0
        }
        
        switch badge {
        case .text, .customFile:
            self.contentLayer.isHidden = true
            self.overlayColorLayer.isHidden = true
        default:
            self.contentLayer.isHidden = false
            self.overlayColorLayer.isHidden = false
        }
        
        self.overlayColorLayer.backgroundColor = backgroundColor.cgColor
        
        transition.setFrame(layer: self.contentLayer, frame: CGRect(origin: CGPoint(), size: size))
        transition.setCornerRadius(layer: self.contentLayer, cornerRadius: min(size.width / 2.0, size.height / 2.0))
        
        transition.setFrame(layer: self.overlayColorLayer, frame: CGRect(origin: CGPoint(), size: size))
        transition.setCornerRadius(layer: self.overlayColorLayer, cornerRadius: min(size.width / 2.0, size.height / 2.0))
        
        transition.setFrame(layer: self.iconLayer, frame: CGRect(origin: CGPoint(), size: size).insetBy(dx: iconInset, dy: iconInset))
        
        if let customFileLayer = self.customFileLayer {
            let iconSize = CGSize(width: 18.0, height: 18.0)
            transition.setFrame(layer: customFileLayer, frame: CGRect(origin: CGPoint(), size: iconSize))
        }
    }
}
