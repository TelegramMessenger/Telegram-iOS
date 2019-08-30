import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import ActivityIndicator
import AppBundle

enum ChatTitleProxyStatus {
    case connecting
    case connected
    case available
}

private func generateIcon(color: UIColor, connected: Bool, off: Bool) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
        
        if let image = generateTintedImage(image: UIImage(bundleImageName: "Chat List/ProxyShieldIcon"), color: color) {
            context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: image.size))
        }
        if connected {
            if let image = generateTintedImage(image: UIImage(bundleImageName: "Chat List/ProxyCheckIcon"), color: color) {
                context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: image.size))
            }
        } else if off {
            if let image = generateTintedImage(image: UIImage(bundleImageName: "Chat List/ProxyOnIcon"), color: color) {
                context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: image.size))
            }
        }
    })
}

final class ChatTitleProxyNode: ASDisplayNode {
    private let iconNode: ASImageNode
    private let activityIndicator: ActivityIndicator
    
    var theme: PresentationTheme {
        didSet {
            if self.theme !== oldValue {
                switch self.status {
                    case .connecting:
                        self.iconNode.image = generateIcon(color: theme.rootController.navigationBar.accentTextColor, connected: false, off: false)
                    case .connected:
                        self.iconNode.image = generateIcon(color: theme.rootController.navigationBar.accentTextColor, connected: true, off: false)
                    case .available:
                        self.iconNode.image = generateIcon(color: theme.rootController.navigationBar.accentTextColor, connected: false, off: true)
                }
                self.activityIndicator.type = .custom(theme.rootController.navigationBar.accentTextColor, 10.0, 1.3333, true)
            }
        }
    }
    
    var status: ChatTitleProxyStatus = .connected {
        didSet {
            if self.status != oldValue {
                switch self.status {
                    case .connecting:
                        self.activityIndicator.isHidden = false
                        self.iconNode.image = generateIcon(color: theme.rootController.navigationBar.accentTextColor, connected: false, off: false)
                    case .connected:
                        self.activityIndicator.isHidden = true
                        self.iconNode.image = generateIcon(color: theme.rootController.navigationBar.accentTextColor, connected: true, off: false)
                    case .available:
                        self.activityIndicator.isHidden = true
                        self.iconNode.image = generateIcon(color: theme.rootController.navigationBar.accentTextColor, connected: false, off: true)
                }
            }
        }
    }
    
    init(theme: PresentationTheme) {
        self.theme = theme
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        self.iconNode.image = generateIcon(color: theme.rootController.navigationBar.accentTextColor, connected: false, off: true)
        
        self.activityIndicator = ActivityIndicator(type: .custom(theme.rootController.navigationBar.accentTextColor, 10.0, 1.3333, true), speed: .slow)
        
        super.init()
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.activityIndicator)
        
        let iconFrame = CGRect(origin: CGPoint(), size: CGSize(width: 30.0, height: 30.0))
        self.iconNode.frame = iconFrame
        self.activityIndicator.frame = CGRect(origin: CGPoint(x: floor(iconFrame.midX - 5.0), y: 10.0), size: CGSize(width: 10.0, height: 10.0))
        
        self.frame = CGRect(origin: CGPoint(), size: CGSize(width: 30.0, height: 30.0))
    }
}
