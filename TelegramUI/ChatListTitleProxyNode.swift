import Foundation
import UIKit
import Display
import AsyncDisplayKit

enum ChatTitleProxyStatus {
    case connecting
    case connected
    case available
}

private func generateIcon(color: UIColor, connected: Bool, off: Bool) -> UIImage? {
    return generateImage(CGSize(width: 18.0, height: 22.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setStrokeColor(color.cgColor)
        context.setFillColor(color.cgColor)
        context.scaleBy(x: 0.3333, y: 0.3333)
        context.setLineWidth(3.0)
        
        let _ = try? drawSvgPath(context, path: "M27,1.6414763 L1.5,12.9748096 L1.5,30 C1.5,45.9171686 12.4507463,60.7063193 27,64.4535514 C41.5492537,60.7063193 52.5,45.9171686 52.5,30 L52.5,12.9748096 L27,1.6414763 S")
        
        if connected {
            let _ = try? drawSvgPath(context, path: "M15.5769231,34.1735387 L23.5896918,42.2164446 C23.6840928,42.3112006 23.8352513,42.30478 23.9262955,42.2032393 L40.5,23.71875 S")
        } else if off {
            let _ = try? drawSvgPath(context, path: "M27.5,15 C28.3284271,15 29,15.6715729 29,16.5 L29,28.5 C29,29.3284271 28.3284271,30 27.5,30 C26.6715729,30 26,29.3284271 26,28.5 L26,16.5 C26,15.6715729 26.6715729,15 27.5,15 Z")
            context.translateBy(x: 27.0, y: 33.0)
            context.rotate(by: 2.35619)
            context.translateBy(x: -27.0, y: -33.0)
            let _ = try? drawSvgPath(context, path: "M27,47 C34.7319865,47 41,40.7319865 41,33 C41,25.2680135 34.7319865,19 27,19 C19.2680135,19 13,25.2680135 13,33 S")
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
                self.activityIndicator.type = .custom(theme.rootController.navigationBar.accentTextColor, 10.0, 1.0, true)
            }
        }
    }
    
    var status: ChatTitleProxyStatus = .connected {
        didSet {
            if self.status != oldValue {
                switch status {
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
        
        self.activityIndicator = ActivityIndicator(type: .custom(theme.rootController.navigationBar.accentTextColor, 10.0, 1.0, true), speed: .slow)
        
        super.init()
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.activityIndicator)
        
        let iconFrame = CGRect(origin: CGPoint(), size: CGSize(width: 18.0, height: 22.0))
        self.iconNode.frame = iconFrame
        self.activityIndicator.frame = CGRect(origin: CGPoint(x: floor(iconFrame.midX - 5.0), y: 6.0), size: CGSize(width: 10.0, height: 10.0))
        
        self.frame = CGRect(origin: CGPoint(), size: CGSize(width: 18.0, height: 22.0))
    }
}
