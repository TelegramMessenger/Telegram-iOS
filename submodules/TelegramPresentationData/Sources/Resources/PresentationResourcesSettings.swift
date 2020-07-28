import Foundation
import UIKit
import Display
import AppBundle

private func drawBorder(context: CGContext, rect: CGRect) {
    context.setLineWidth(UIScreenPixel)
    context.setStrokeColor(UIColor(rgb: 0xffffff, alpha: 0.25).cgColor)
    let path = CGPath(roundedRect: rect.insetBy(dx: UIScreenPixel / 2.0, dy: UIScreenPixel / 2.0), cornerWidth: 6.0, cornerHeight: 6.0, transform: nil)
    context.addPath(path)
    context.strokePath()
}

private func renderIcon(name: String) -> UIImage? {
    return generateImage(CGSize(width: 29.0, height: 29.0), contextGenerator: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        if let image = UIImage(bundleImageName: name)?.cgImage {
            context.draw(image, in: bounds)
        }
        drawBorder(context: context, rect: bounds)
    })
}

public struct PresentationResourcesSettings {
    public static let editProfile = renderIcon(name: "Settings/MenuIcons/EditProfile")
    public static let proxy = renderIcon(name: "Settings/MenuIcons/Proxy")
    public static let savedMessages = renderIcon(name: "Settings/MenuIcons/SavedMessages")
    public static let recentCalls = renderIcon(name: "Settings/MenuIcons/RecentCalls")
    public static let devices = renderIcon(name: "Settings/MenuIcons/Sessions")
    public static let chatFolders = renderIcon(name: "Settings/MenuIcons/ChatListFilters")
    public static let stickers = renderIcon(name: "Settings/MenuIcons/Stickers")
    
    public static let notifications = renderIcon(name: "Settings/MenuIcons/Notifications")
    public static let security = renderIcon(name: "Settings/MenuIcons/Security")
    public static let dataAndStorage = renderIcon(name: "Settings/MenuIcons/DataAndStorage")
    public static let appearance = renderIcon(name: "Settings/MenuIcons/Appearance")
    public static let language = renderIcon(name: "Settings/MenuIcons/Language")

    public static let wallet = generateImage(CGSize(width: 29.0, height: 29.0), contextGenerator: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        context.setFillColor(UIColor.white.cgColor)
        context.fill(bounds.insetBy(dx: 5.0, dy: 5.0))
        
        if let image = generateTintedImage(image: UIImage(bundleImageName: "Settings/MenuIcons/Wallet"), color: UIColor(rgb: 0x1b1b1c))?.cgImage {
            context.draw(image, in: bounds)
        }
        
        drawBorder(context: context, rect: bounds)
    })
        
    public static let passport = renderIcon(name: "Settings/MenuIcons/Passport")
    public static let watch = renderIcon(name: "Settings/MenuIcons/Watch")
    
    public static let support = renderIcon(name: "Settings/MenuIcons/Support")
    public static let faq = renderIcon(name: "Settings/MenuIcons/Faq")
    
    public static let addAccount = renderIcon(name: "Settings/MenuIcons/AddAccount")
    public static let setPasscode = renderIcon(name: "Settings/MenuIcons/SetPasscode")
    public static let clearCache = renderIcon(name: "Settings/MenuIcons/ClearCache")
    public static let changePhoneNumber = renderIcon(name: "Settings/MenuIcons/ChangePhoneNumber")
    
    public static let websites = renderIcon(name: "Settings/MenuIcons/Websites")
}
