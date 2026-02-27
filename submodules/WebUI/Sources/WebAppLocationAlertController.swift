
import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import AppBundle
import ComponentFlow
import AlertComponent
import AvatarComponent
import AlertTransferHeaderComponent

private func generateLocationIcon() -> UIImage? {
    let size = CGSize(width: 24.0, height: 24.0)
    return generateImage(size, contextGenerator: { size, context in
        let bounds = CGRect(origin: .zero, size: size)
        context.clear(bounds)
        
        context.addEllipse(in: bounds)
        context.clip()
        
        var locations: [CGFloat] = [1.0, 0.0]
        let colors: [CGColor] = [UIColor(rgb: 0x36c089).cgColor, UIColor(rgb: 0x3ca5eb).cgColor]
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: size.width, y: size.height), options: CGGradientDrawingOptions())
        
        if let image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Attach Menu/Location"), color: .white), let cgImage = image.cgImage {
            context.draw(cgImage, in: bounds.insetBy(dx: 4.0, dy: 4.0))
        }
        
        context.resetClip()
    }, opaque: false)
}

func webAppLocationAlertController(context: AccountContext, accountPeer: EnginePeer, botPeer: EnginePeer, completion: @escaping (Bool) -> Void) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
    
    let locationIcon = generateLocationIcon()
    
    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(
        id: "header",
        component: AnyComponent(
            AlertTransferHeaderComponent(
                fromComponent: AnyComponentWithIdentity(id: "user", component: AnyComponent(
                    AvatarComponent(
                        context: context,
                        theme: presentationData.theme,
                        peer: accountPeer,
                        icon: AnyComponent(Image(image: locationIcon, contentMode: .center))
                    )
                )),
                toComponent: AnyComponentWithIdentity(id: "bot", component: AnyComponent(
                    AvatarComponent(
                        context: context,
                        theme: presentationData.theme,
                        peer: botPeer
                    )
                )),
                type: .transfer
            )
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "text",
        component: AnyComponent(
            AlertTextComponent(content: .plain(strings.WebApp_LocationPermission_Text(botPeer.compactDisplayTitle, botPeer.compactDisplayTitle).string))
        )
    ))
    
    let alertController = AlertScreen(
        context: context,
        content: content,
        actions: [
            .init(title: strings.WebApp_LocationPermission_Decline, action: {
                completion(false)
            }),
            .init(title: strings.WebApp_LocationPermission_Allow, type: .default, action: {
                completion(true)
            })
        ]
    )
    return alertController
}
