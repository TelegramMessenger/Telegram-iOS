import Foundation
import UIKit
import LegacyComponents
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import Display

private let sharedImageCache = TGMemoryImageCache(softMemoryLimit: 2 * 1024 * 1024, hardMemoryLimit: 3 * 1024 * 1024)!

private let placeholderImage = generateFilledCircleImage(diameter: 40.0, color: UIColor(rgb: 0xf2f2f2))

private final class LegacyLocationVenueIconTask: NSObject {
    private let disposable = DisposableSet()
    
    init(account: Account, url: String, completion: @escaping (Data?) -> Void) {
        super.init()
        
        let resource = HttpReferenceMediaResource(url: url, size: nil)
        self.disposable.add(account.postbox.mediaBox.resourceData(resource).start(next: { data in
            if data.complete {
                if let loadedData = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                    completion(loadedData)
                }
            }
        }))
        self.disposable.add(account.postbox.mediaBox.fetchedResource(resource, parameters: nil).start())
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    func cancel() {
        self.disposable.dispose()
    }
}

private let genericIconImage = TGComponentsImageNamed("LocationMessagePinIcon")?.precomposed()

final class LegacyLocationVenueIconDataSource: TGImageDataSource {
    private let account: () -> Account?
    
    init(account: @escaping () -> Account?) {
        self.account = account
        
        super.init()
    }
    
    override func canHandleUri(_ uri: String!) -> Bool {
        if let uri = uri {
            if uri.hasPrefix("location-venue-icon://") {
                return true
            }
        }
        return false
    }
    
    override func loadAttributeSync(forUri uri: String!, attribute: String!) -> Any! {
        if attribute == "placeholder" {
            return placeholderImage
        }
        return nil
    }
    
    override func loadDataSync(withUri uri: String!, canWait: Bool, acceptPartialData: Bool, asyncTaskId: AutoreleasingUnsafeMutablePointer<AnyObject?>!, progress: ((Float) -> Void)!, partialCompletion: ((TGDataResource?) -> Void)!, completion: ((TGDataResource?) -> Void)!) -> TGDataResource! {
        if let image = sharedImageCache.image(forKey: uri, attributes: nil) {
            return TGDataResource(image: image, decoded: true)
        }
        return nil
    }
    
    private static func unavailableImage(for uri: String) -> TGDataResource? {
        let args: [AnyHashable : Any]
        let argumentsString = String(uri[uri.index(uri.startIndex, offsetBy: "location-venue-icon://".count)...])
        args = TGStringUtils.argumentDictionary(inUrlString: argumentsString)!
        
        guard let width = Int((args["width"] as! String)), width > 1 else {
            return nil
        }
        guard let height = Int((args["height"] as! String)), height > 1 else {
            return nil
        }
        
        guard let colorN = (args["color"] as? String).flatMap({ Int($0) }) else {
            return nil
        }
        
        let color = UIColor(rgb: UInt32(colorN))
        
        let size = CGSize(width: CGFloat(width), height: CGFloat(height))
        
        guard let iconSourceImage = genericIconImage.flatMap({ generateTintedImage(image: $0, color: color) }) else {
            return nil
        }
        
        UIGraphicsBeginImageContextWithOptions(iconSourceImage.size, false, iconSourceImage.scale)
        var context = UIGraphicsGetCurrentContext()!
        iconSourceImage.draw(at: CGPoint())
        context.setBlendMode(.sourceAtop)
        context.setFillColor(color.cgColor)
        context.fill(CGRect(origin: CGPoint(), size: iconSourceImage.size))
        
        let tintedIconImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        context = UIGraphicsGetCurrentContext()!
        let fitSize = CGSize(width: size.width - 4.0 * 2.0, height: size.height - 4.0 * 2.0)
        let imageSize = iconSourceImage.size.aspectFitted(fitSize)
        let imageRect = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: floor((size.height - imageSize.height) / 2.0)), size: imageSize)
        tintedIconImage?.draw(in: imageRect)
        
        let iconImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext()
        
        if let iconImage = iconImage {
            sharedImageCache.setImage(iconImage, forKey: uri, attributes: nil)
            return TGDataResource(image: iconImage, decoded: true)
        }
        
        return nil
    }
    
    override func loadDataAsync(withUri uri: String!, progress: ((Float) -> Void)!, partialCompletion: ((TGDataResource?) -> Void)!, completion: ((TGDataResource?) -> Void)!) -> Any! {
        if let account = self.account() {
            let args: [AnyHashable : Any]
            let argumentsString = String(uri[uri.index(uri.startIndex, offsetBy: "location-venue-icon://".count)...])
            args = TGStringUtils.argumentDictionary(inUrlString: argumentsString)!
            
            guard let width = Int((args["width"] as! String)), width > 1 else {
                return nil
            }
            guard let height = Int((args["height"] as! String)), height > 1 else {
                return nil
            }
            
            guard let colorN = (args["color"] as? String).flatMap({ Int($0) }) else {
                return nil
            }
            
            guard let type = args["type"] as? String else {
                return LegacyLocationVenueIconDataSource.unavailableImage(for: uri)
            }
            
            let color = UIColor(rgb: UInt32(colorN))
            
            let url = "https://ss3.4sqi.net/img/categories_v2/\(type)_88.png"
            
            let size = CGSize(width: CGFloat(width), height: CGFloat(height))
            
            return LegacyLocationVenueIconTask(account: account, url: url, completion: { data in
                if let data = data, let iconSourceImage = UIImage(data: data) {
                    UIGraphicsBeginImageContextWithOptions(iconSourceImage.size, false, iconSourceImage.scale)
                    var context = UIGraphicsGetCurrentContext()!
                    iconSourceImage.draw(at: CGPoint())
                    context.setBlendMode(.sourceAtop)
                    context.setFillColor(color.cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: iconSourceImage.size))
                    
                    let tintedIconImage = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    
                    UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
                    context = UIGraphicsGetCurrentContext()!
                    let imageRect = CGRect(x: 4.0, y: 4.0, width: size.width - 4.0 * 2.0, height: size.height - 4.0 * 2.0)
                    tintedIconImage?.draw(in: imageRect)
                    
                    let iconImage = UIGraphicsGetImageFromCurrentImageContext();
                    UIGraphicsEndImageContext()
                    
                    if let iconImage = iconImage {
                        sharedImageCache.setImage(iconImage, forKey: uri, attributes: nil)
                        completion?(TGDataResource(image: iconImage, decoded: true))
                    }
                } else {
                    if let image = LegacyLocationVenueIconDataSource.unavailableImage(for: uri) {
                        completion?(image)
                    }
                }
            })
        } else {
            return nil
        }
    }
    
    override func cancelTask(byId taskId: Any!) {
        if let disposable = taskId as? LegacyLocationVenueIconTask {
            disposable.cancel()
        }
    }
}
