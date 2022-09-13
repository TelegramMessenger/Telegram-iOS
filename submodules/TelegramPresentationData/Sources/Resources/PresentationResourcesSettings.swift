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
    })
}

public struct PresentationResourcesSettings {
    public static let editProfile = renderIcon(name: "Settings/Menu/EditProfile")
    public static let proxy = renderIcon(name: "Settings/Menu/Proxy")
    public static let savedMessages = renderIcon(name: "Settings/Menu/SavedMessages")
    public static let recentCalls = renderIcon(name: "Settings/Menu/RecentCalls")
    public static let devices = renderIcon(name: "Settings/Menu/Sessions")
    public static let chatFolders = renderIcon(name: "Settings/Menu/ChatListFilters")
    public static let stickers = renderIcon(name: "Settings/Menu/Stickers")
    
    public static let notifications = renderIcon(name: "Settings/Menu/Notifications")
    public static let security = renderIcon(name: "Settings/Menu/Security")
    public static let dataAndStorage = renderIcon(name: "Settings/Menu/DataAndStorage")
    public static let appearance = renderIcon(name: "Settings/Menu/Appearance")
    public static let language = renderIcon(name: "Settings/Menu/Language")
    
    public static let deleteAccount = renderIcon(name: "Chat/Info/GroupRemovedIcon")

    public static let wallet = generateImage(CGSize(width: 29.0, height: 29.0), contextGenerator: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        context.setFillColor(UIColor.white.cgColor)
        context.fill(bounds.insetBy(dx: 5.0, dy: 5.0))
        
        if let image = generateTintedImage(image: UIImage(bundleImageName: "Settings/Menu/Wallet"), color: UIColor(rgb: 0x1b1b1c))?.cgImage {
            context.draw(image, in: bounds)
        }
        
        drawBorder(context: context, rect: bounds)
    })
    
    public static let premium = generateImage(CGSize(width: 29.0, height: 29.0), contextGenerator: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: 7.0)
        context.addPath(path.cgPath)
        context.clip()
        
        let colorsArray: [CGColor] = [
            UIColor(rgb: 0x6b93ff).cgColor,
            UIColor(rgb: 0x6b93ff).cgColor,
            UIColor(rgb: 0x8d77ff).cgColor,
            UIColor(rgb: 0xb56eec).cgColor,
            UIColor(rgb: 0xb56eec).cgColor
        ]
        var locations: [CGFloat] = [0.0, 0.15, 0.5, 0.85, 1.0]
        let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray as CFArray, locations: &locations)!

        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: size.width, y: size.height), options: CGGradientDrawingOptions())
        
        if let image = generateTintedImage(image: UIImage(bundleImageName: "Premium/ButtonIcon"), color: UIColor(rgb: 0xffffff)), let cgImage = image.cgImage {
            context.draw(cgImage, in: CGRect(origin: CGPoint(x: floorToScreenPixels((bounds.width - image.size.width) / 2.0), y: floorToScreenPixels((bounds.height - image.size.height) / 2.0)), size: image.size))
        }
        
        drawBorder(context: context, rect: bounds)
    })
        
    public static let passport = renderIcon(name: "Settings/Menu/Passport")
    public static let watch = renderIcon(name: "Settings/Menu/Watch")
    
    public static let support = renderIcon(name: "Settings/Menu/Support")
    public static let faq = renderIcon(name: "Settings/Menu/Faq")
    public static let tips = renderIcon(name: "Settings/Menu/Tips")
    
    public static let addAccount = renderIcon(name: "Settings/Menu/AddAccount")
    public static let setPasscode = renderIcon(name: "Settings/Menu/SetPasscode")
    public static let clearCache = renderIcon(name: "Settings/Menu/ClearCache")
    public static let changePhoneNumber = renderIcon(name: "Settings/Menu/ChangePhoneNumber")
    
    public static let deleteAddAccount = renderIcon(name: "Settings/Menu/DeleteAddAccount")
    public static let deleteSetTwoStepAuth = renderIcon(name: "Settings/Menu/DeleteTwoStepAuth")
    public static let deleteSetPasscode = renderIcon(name: "Settings/Menu/FaceId")
    public static let deleteChats = renderIcon(name: "Settings/Menu/DeleteChats")
    public static let clearSynced = renderIcon(name: "Settings/Menu/ClearSynced")
    
    public static let websites = renderIcon(name: "Settings/Menu/Websites")
}
