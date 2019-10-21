import Foundation
import UIKit
import LegacyComponents
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import Display

private let gradientColors: [NSArray] = [
    [UIColor(rgb: 0xff516a).cgColor, UIColor(rgb: 0xff885e).cgColor],
    [UIColor(rgb: 0xffa85c).cgColor, UIColor(rgb: 0xffcd6a).cgColor],
    [UIColor(rgb: 0x54cb68).cgColor, UIColor(rgb: 0xa0de7e).cgColor],
    [UIColor(rgb: 0x2a9ef1).cgColor, UIColor(rgb: 0x72d5fd).cgColor],
    [UIColor(rgb: 0x665fff).cgColor, UIColor(rgb: 0x82b1ff).cgColor],
    [UIColor(rgb: 0xd669ed).cgColor, UIColor(rgb: 0xe0a2f3).cgColor]
]

private let grayscaleColors: NSArray = [
    UIColor(rgb: 0xefefef).cgColor, UIColor(rgb: 0xeeeeee).cgColor
]

private let sharedImageCache = TGMemoryImageCache(softMemoryLimit: 2 * 1024 * 1024, hardMemoryLimit: 3 * 1024 * 1024)!

final class LegacyPeerAvatarPlaceholderDataSource: TGImageDataSource {
    private let account: () -> Account?
    
    init(account: @escaping () -> Account?) {
        self.account = account
        
        super.init()
    }
    
    override func canHandleUri(_ uri: String!) -> Bool {
        if let uri = uri {
            if uri.hasPrefix("placeholder://") {
                return true
            }
        }
        return false
    }
    
    override func loadDataSync(withUri uri: String!, canWait: Bool, acceptPartialData: Bool, asyncTaskId: AutoreleasingUnsafeMutablePointer<AnyObject?>!, progress: ((Float) -> Void)!, partialCompletion: ((TGDataResource?) -> Void)!, completion: ((TGDataResource?) -> Void)!) -> TGDataResource! {
        if let image = sharedImageCache.image(forKey: uri, attributes: nil) {
            return TGDataResource(image: image, decoded: true)
        }
        return nil
    }
    
    override func loadDataAsync(withUri uri: String!, progress: ((Float) -> Void)!, partialCompletion: ((TGDataResource?) -> Void)!, completion: ((TGDataResource?) -> Void)!) -> Any! {
        if let account = self.account() {
            let signal: Signal<Never, NoError> = Signal { subscriber in
                let args: [AnyHashable : Any]
                let argumentsString = String(uri[uri.index(uri.startIndex, offsetBy: "placeholder://?".count)...])
                args = TGStringUtils.argumentDictionary(inUrlString: argumentsString)!
                
                guard let width = Int((args["w"] as! String)), width > 1 else {
                    return EmptyDisposable
                }
                guard let height = Int((args["h"] as! String)), height > 1 else {
                    return EmptyDisposable
                }
                
                var peerId = PeerId(namespace: 0, id: 0)
                
                if let uid = args["uid"] as? String, let nUid = Int32(uid) {
                    peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: nUid)
                } else if let cid = args["cid"] as? String, let nCid = Int32(cid) {
                    peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: nCid)
                }
                
                let image = generateImage(CGSize(width: CGFloat(width), height: CGFloat(height)), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.beginPath()
                    context.addEllipse(in: CGRect(x: 0.0, y: 0.0, width: size.width, height:
                        size.height))
                    context.clip()
                    
                    let colorIndex: Int
                    if peerId.id == 0 {
                        colorIndex = -1
                    } else {
                        colorIndex = abs(Int(account.peerId.id + peerId.id))
                    }
                    
                    let colorsArray: NSArray
                    if colorIndex == -1 {
                        colorsArray = grayscaleColors
                    } else {
                        colorsArray = gradientColors[colorIndex % gradientColors.count]
                    }
                    
                    var locations: [CGFloat] = [1.0, 0.2];
                    
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let gradient = CGGradient(colorsSpace: colorSpace, colors: colorsArray, locations: &locations)!
                    
                    context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
                    
                    context.setBlendMode(.normal)
                })
                
                sharedImageCache.setImage(image, forKey: uri, attributes: nil)
                completion?(TGDataResource(image: image, decoded: true))
                
                subscriber.putCompletion()
                
                return EmptyDisposable
            }
            
            return (signal |> runOn(Queue.concurrentDefaultQueue())).start()
        } else {
            return nil
        }
    }
    
    override func cancelTask(byId taskId: Any!) {
        if let disposable = taskId as? Disposable {
            disposable.dispose()
        }
    }
}
