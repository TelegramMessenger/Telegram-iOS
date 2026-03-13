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

private func addRoundedRectPath(context: CGContext, rect: CGRect, radius: CGFloat) {
    context.saveGState()
    context.translateBy(x: rect.minX, y: rect.minY)
    context.scaleBy(x: radius, y: radius)
    let fw = rect.width / radius
    let fh = rect.height / radius
    context.move(to: CGPoint(x: fw, y: fh / 2.0))
    context.addArc(tangent1End: CGPoint(x: fw, y: fh), tangent2End: CGPoint(x: fw/2, y: fh), radius: 1.0)
    context.addArc(tangent1End: CGPoint(x: 0, y: fh), tangent2End: CGPoint(x: 0, y: fh/2), radius: 1)
    context.addArc(tangent1End: CGPoint(x: 0, y: 0), tangent2End: CGPoint(x: fw/2, y: 0), radius: 1)
    context.addArc(tangent1End: CGPoint(x: fw, y: 0), tangent2End: CGPoint(x: fw, y: fh/2), radius: 1)
    context.closePath()
    context.restoreGState()
}

private let gradientImage = UIImage(bundleImageName: "Item List/Icons/Gradient")
private let backdropImage = UIImage(bundleImageName: "Item List/Icons/Backdrop")
public func renderSettingsIcon(name: String, scaleFactor: CGFloat = 1.0, backgroundColors: [UIColor]? = nil) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        if let backgroundColors {
            context.addPath(UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 8.0).cgPath)
            context.clip()
            
            var locations: [CGFloat] = [0.0, 1.0]
            let colors: [CGColor] = backgroundColors.map(\.cgColor)
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
            
            context.drawLinearGradient(gradient, start: CGPoint(x: size.width, y: size.height), end: CGPoint(x: 0.0, y: 0.0), options: CGGradientDrawingOptions())
            
            context.resetClip()
            
            if let gradientImage, let cgImage = gradientImage.cgImage {
                context.saveGState()
                context.setBlendMode(.plusLighter)
                context.draw(cgImage, in: CGRect(origin: .zero, size: size))
                context.restoreGState()
            }
            
            if let backdropImage, let cgImage = backdropImage.cgImage {
                context.saveGState()
                context.setBlendMode(.overlay)
                context.draw(cgImage, in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
                context.restoreGState()
            }
            
            if let image = generateTintedImage(image: UIImage(bundleImageName: name), color: .white), let cgImage = image.cgImage {
                let imageSize = CGSize(width: image.size.width * scaleFactor, height: image.size.height * scaleFactor)
                context.draw(cgImage, in: CGRect(origin: CGPoint(x: (bounds.width - imageSize.width) * 0.5, y: (bounds.height - imageSize.height) * 0.5), size: imageSize))
            }
        } else {
            if let image = UIImage(bundleImageName: name), let cgImage = image.cgImage {
                let imageSize: CGSize
                if scaleFactor == 1.0 {
                    imageSize = size
                } else {
                    imageSize = CGSize(width: image.size.width * scaleFactor, height: image.size.height * scaleFactor)
                }
                context.draw(cgImage, in: CGRect(origin: CGPoint(x: (bounds.width - imageSize.width) * 0.5, y: (bounds.height - imageSize.height) * 0.5), size: imageSize))
            }
        }
    })
}

private let colorRed = UIColor(rgb: 0xFF453A)
private let colorGreen = UIColor(rgb: 0x34C759)
private let colorBlue = UIColor(rgb: 0x0A84FF)
private let colorLightBlue = UIColor(rgb: 0x32ADE6)
private let colorTeal = UIColor(rgb: 0x00c7be)
private let colorOrange = UIColor(rgb: 0xFF9F0A)
private let colorPurple = UIColor(rgb: 0xAF52DE)
private let colorGray = UIColor(rgb: 0x8E8E93)
private let colorViolet = UIColor(rgb: 0x5E5CE6)

public struct PresentationResourcesSettings {
    public static let proxy = renderSettingsIcon(name: "Settings/Menu/Proxy")
    public static let savedMessages = renderSettingsIcon(name: "Item List/Icons/SavedMessages", backgroundColors: [colorBlue])
    public static let recentCalls = renderSettingsIcon(name: "Item List/Icons/Phone", backgroundColors: [colorGreen])
    public static let devices = renderSettingsIcon(name: "Item List/Icons/Devices", backgroundColors: [colorOrange])
    public static let chatFolders = renderSettingsIcon(name: "Item List/Icons/Folder", backgroundColors: [colorLightBlue])
    public static let stickers = renderSettingsIcon(name: "Item List/Icons/Sticker", backgroundColors: [colorOrange])
    public static let notifications = renderSettingsIcon(name: "Item List/Icons/Notifications", backgroundColors: [colorRed])
    public static let security = renderSettingsIcon(name: "Item List/Icons/Privacy", backgroundColors: [colorGray])
    public static let dataAndStorage = renderSettingsIcon(name: "Item List/Icons/Data", backgroundColors: [colorGreen])
    public static let appearance = renderSettingsIcon(name: "Item List/Icons/Appearance", backgroundColors: [colorLightBlue])
    public static let language = renderSettingsIcon(name: "Item List/Icons/Language", backgroundColors: [colorPurple])
    public static let deleteAccount = renderSettingsIcon(name: "Chat/Info/GroupRemovedIcon")
    public static let powerSaving = renderSettingsIcon(name: "Item List/Icons/PowerSaving", backgroundColors: [colorOrange])
    public static let business = renderSettingsIcon(name: "Settings/Menu/Business", backgroundColors: [UIColor(rgb: 0xA95CE3), UIColor(rgb: 0xF16B80)])
    public static let myProfile = renderSettingsIcon(name: "Item List/Icons/Profile", backgroundColors: [colorRed])
    
    public static let storageUsage = renderSettingsIcon(name: "Item List/Icons/Pie", backgroundColors: [colorOrange])
    public static let dataUsage = renderSettingsIcon(name: "Item List/Icons/Stats", backgroundColors: [colorPurple])
    
    public static let cellular = renderSettingsIcon(name: "Item List/Icons/Cellular", backgroundColors: [colorGreen])
    public static let wifi = renderSettingsIcon(name: "Item List/Icons/Wifi", backgroundColors: [colorBlue])
    
    public static let privateChats = renderSettingsIcon(name: "Item List/Icons/Member", backgroundColors: [colorBlue])
    public static let groups = renderSettingsIcon(name: "Item List/Icons/Group", backgroundColors: [colorGreen])
    public static let channels = renderSettingsIcon(name: "Item List/Icons/Channel", backgroundColors: [colorOrange])
    public static let stories = renderSettingsIcon(name: "Item List/Icons/Stories", backgroundColors: [colorViolet])
    public static let reactions = renderSettingsIcon(name: "Item List/Icons/Reactions", backgroundColors: [UIColor(rgb: 0xFF2D55)])
    
    public static let photos = renderSettingsIcon(name: "Item List/Icons/Photo", backgroundColors: [colorOrange])
    public static let videos = renderSettingsIcon(name: "Item List/Icons/Video", backgroundColors: [colorRed])
    public static let files = renderSettingsIcon(name: "Item List/Icons/File", backgroundColors: [colorBlue])
    public static let gifs = renderSettingsIcon(name: "Item List/Icons/Gif", backgroundColors: [colorOrange])
    public static let stickersGreen = renderSettingsIcon(name: "Item List/Icons/Sticker", backgroundColors: [colorGreen])
    public static let emoji = renderSettingsIcon(name: "Item List/Icons/Emoji", backgroundColors: [colorTeal])
    public static let effects = renderSettingsIcon(name: "Item List/Icons/Effect", backgroundColors: [colorLightBlue])
    public static let photosBlue = renderSettingsIcon(name: "Item List/Icons/Photo", backgroundColors: [colorBlue])
    public static let clock = renderSettingsIcon(name: "Item List/Icons/Clock", backgroundColors: [colorPurple])
    public static let photosLightBlue = renderSettingsIcon(name: "Item List/Icons/Photo", backgroundColors: [colorLightBlue])
    public static let videosBlue = renderSettingsIcon(name: "Item List/Icons/Video", backgroundColors: [colorBlue])
    
    public static let block = renderSettingsIcon(name: "Item List/Icons/Block", backgroundColors: [colorRed])
    public static let activeSessions = renderSettingsIcon(name: "Item List/Icons/Language", backgroundColors: [colorBlue])
    public static let faceId = renderSettingsIcon(name: "Item List/Icons/FaceId", backgroundColors: [colorGreen])
    public static let lockOrange = renderSettingsIcon(name: "Item List/Icons/Privacy", backgroundColors: [colorOrange])
    public static let passkeys = renderSettingsIcon(name: "Item List/Icons/Key", backgroundColors: [colorViolet])
    public static let timer = renderSettingsIcon(name: "Item List/Icons/Timer", backgroundColors: [colorPurple])
    public static let email = renderSettingsIcon(name: "Item List/Icons/Email", backgroundColors: [colorViolet])
    
    public static let balance = renderSettingsIcon(name: "Settings/Menu/Balance", scaleFactor: 0.97, backgroundColors: [colorGreen])
    public static let affiliateProgram = renderSettingsIcon(name: "Settings/Menu/AffiliateProgram")
    public static let earnStars = renderSettingsIcon(name: "Settings/Menu/EarnStars")
    public static let channelMessages = renderSettingsIcon(name: "Chat/Info/ChannelMessages", backgroundColors: [UIColor(rgb: 0x5856D6)])
    
    public static let premium = generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: 8.0)
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
        
        if let gradientImage, let cgImage = gradientImage.cgImage {
            context.saveGState()
            context.setBlendMode(.plusLighter)
            context.draw(cgImage, in: CGRect(origin: .zero, size: size))
            context.restoreGState()
        }
        
        if let backdropImage, let cgImage = backdropImage.cgImage {
            context.saveGState()
            context.setBlendMode(.overlay)
            context.draw(cgImage, in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
            context.restoreGState()
        }
        
        if let image = generateTintedImage(image: UIImage(bundleImageName: "Item List/Icons/Premium"), color: UIColor(rgb: 0xffffff)), let cgImage = image.cgImage {
            context.draw(cgImage, in: CGRect(origin: CGPoint(x: floorToScreenPixels((bounds.width - image.size.width) / 2.0), y: floorToScreenPixels((bounds.height - image.size.height) / 2.0)), size: image.size))
        }
    })
    
    public static let ton = generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: 8.0)
        context.addPath(path.cgPath)
        context.clip()

        context.setFillColor(UIColor(rgb: 0x32ade6).cgColor)
        context.fill(bounds)
        
        if let gradientImage, let cgImage = gradientImage.cgImage {
            context.saveGState()
            context.setBlendMode(.plusLighter)
            context.draw(cgImage, in: CGRect(origin: .zero, size: size))
            context.restoreGState()
        }
        
        if let backdropImage, let cgImage = backdropImage.cgImage {
            context.saveGState()
            context.setBlendMode(.overlay)
            context.draw(cgImage, in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
            context.restoreGState()
        }
        
        if let image = generateTintedImage(image: UIImage(bundleImageName: "Ads/TonAbout"), color: UIColor(rgb: 0xffffff)), let cgImage = image.cgImage {
            context.draw(cgImage, in: CGRect(origin: CGPoint(x: floorToScreenPixels((bounds.width - image.size.width) / 2.0), y: floorToScreenPixels((bounds.height - image.size.height) / 2.0)), size: image.size))
        }
        
        drawBorder(context: context, rect: bounds)
    })
    
    public static let stars = generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: 7.0)
        context.addPath(path.cgPath)
        context.clip()
        
        let colorsArray: [CGColor] = [
            UIColor(rgb: 0xfec80f).cgColor,
            UIColor(rgb: 0xdd6f12).cgColor
        ]
        var locations: [CGFloat] = [0.0, 1.0]
        let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray as CFArray, locations: &locations)!

        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: size.width, y: size.height), options: CGGradientDrawingOptions())
        
        if let gradientImage, let cgImage = gradientImage.cgImage {
            context.saveGState()
            context.setBlendMode(.plusLighter)
            context.draw(cgImage, in: CGRect(origin: .zero, size: size))
            context.restoreGState()
        }
        
        if let backdropImage, let cgImage = backdropImage.cgImage {
            context.saveGState()
            context.setBlendMode(.overlay)
            context.draw(cgImage, in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
            context.restoreGState()
        }
        
        if let image = generateTintedImage(image: UIImage(bundleImageName: "Item List/Icons/Stars"), color: UIColor(rgb: 0xffffff)), let cgImage = image.cgImage {
            context.draw(cgImage, in: CGRect(origin: CGPoint(x: floorToScreenPixels((bounds.width - image.size.width) / 2.0), y: floorToScreenPixels((bounds.height - image.size.height) / 2.0)), size: image.size))
        }
    })
    
    public static let premiumGift = generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: 8.0)
        context.addPath(path.cgPath)
        context.clip()
        
        let colorsArray: [CGColor] = [
            UIColor(rgb: 0x3ba1f2).cgColor,
            UIColor(rgb: 0x3ba1f2).cgColor,
            UIColor(rgb: 0x39b3b4).cgColor,
            UIColor(rgb: 0x34c27d).cgColor,
            UIColor(rgb: 0x34c27d).cgColor
        ]
        var locations: [CGFloat] = [0.0, 0.15, 0.5, 0.85, 1.0]
        let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray as CFArray, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: size.width, y: size.height), options: CGGradientDrawingOptions())
        
        if let gradientImage, let cgImage = gradientImage.cgImage {
            context.saveGState()
            context.setBlendMode(.plusLighter)
            context.draw(cgImage, in: CGRect(origin: .zero, size: size))
            context.restoreGState()
        }
        
        if let backdropImage, let cgImage = backdropImage.cgImage {
            context.saveGState()
            context.setBlendMode(.overlay)
            context.draw(cgImage, in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
            context.restoreGState()
        }
        
        if let image = generateTintedImage(image: UIImage(bundleImageName: "Item List/Icons/Gift"), color: UIColor(rgb: 0xffffff)), let cgImage = image.cgImage {
            context.draw(cgImage, in: CGRect(origin: CGPoint(x: floorToScreenPixels((bounds.width - image.size.width) / 2.0), y: floorToScreenPixels((bounds.height - image.size.height) / 2.0)), size: image.size))
        }
    })
    
    public static let bot = generateImage(CGSize(width: 29.0, height: 29.0), contextGenerator: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: 7.0)
        context.addPath(path.cgPath)
        context.clip()

        context.setFillColor(UIColor(rgb: 0x0088ff).cgColor)
        context.fill(bounds)
        
        if let image = generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/Bot"), color: UIColor(rgb: 0xffffff)), let cgImage = image.cgImage {
            context.draw(cgImage, in: CGRect(origin: CGPoint(x: floorToScreenPixels((bounds.width - image.size.width) / 2.0), y: floorToScreenPixels((bounds.height - image.size.height) / 2.0)), size: image.size))
        }
        
        drawBorder(context: context, rect: bounds)
    })

    public static let passport = renderSettingsIcon(name: "Settings/Menu/Passport")
    public static let watch = renderSettingsIcon(name: "Settings/Menu/Watch")
    
    public static let support = renderSettingsIcon(name: "Item List/Icons/Support", backgroundColors: [colorOrange])
    public static let faq = renderSettingsIcon(name: "Item List/Icons/Faq", backgroundColors: [colorLightBlue])
    public static let tips = renderSettingsIcon(name: "Item List/Icons/Tips", backgroundColors: [UIColor(rgb: 0xffcc02)])
    
    public static let addAccount = renderSettingsIcon(name: "Settings/Menu/AddAccount")
    public static let setPasscode = renderSettingsIcon(name: "Settings/Menu/SetPasscode")
    public static let clearCache = renderSettingsIcon(name: "Settings/Menu/ClearCache")
    public static let changePhoneNumber = renderSettingsIcon(name: "Settings/Menu/ChangePhoneNumber")
    
    public static let deleteAddAccount = renderSettingsIcon(name: "Settings/Menu/DeleteAddAccount")
    public static let deleteSetTwoStepAuth = renderSettingsIcon(name: "Settings/Menu/DeleteTwoStepAuth")
    public static let deleteSetPasscode = renderSettingsIcon(name: "Settings/Menu/FaceId")
    public static let deleteChats = renderSettingsIcon(name: "Settings/Menu/DeleteChats")
    public static let clearSynced = renderSettingsIcon(name: "Settings/Menu/ClearSynced")
    
    public static let websites = renderSettingsIcon(name: "Settings/Menu/Websites")
}
