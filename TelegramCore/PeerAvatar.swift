import Foundation
import SwiftSignalKit
import Postbox
import Display
import ImageIO


private let roundCorners = { () -> UIImage in
    let diameter: CGFloat = 60.0
    UIGraphicsBeginImageContextWithOptions(CGSize(width: diameter, height: diameter), false, 0.0)
    let context = UIGraphicsGetCurrentContext()!
    context.setBlendMode(.copy)
    context.setFillColor(UIColor.black.cgColor)
    context.fill(CGRect(origin: CGPoint(), size: CGSize(width: diameter, height: diameter)))
    context.setFillColor(UIColor.clear.cgColor)
    context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: diameter, height: diameter)))
    let image = UIGraphicsGetImageFromCurrentImageContext()!.stretchableImage(withLeftCapWidth: Int(diameter / 2.0), topCapHeight: Int(diameter / 2.0))
    UIGraphicsEndImageContext()
    return image
}()

func peerAvatarImage(account: Account, peer: Peer, displayDimensions: CGSize = CGSize(width: 60.0, height: 60.0)) -> Signal<UIImage, NoError>? {
    var location: TelegramCloudMediaLocation?
    
    if let user = peer as? TelegramUser {
        if let photo = user.photo.first {
            location = photo.location.cloudLocation
        }
    } else if let group = peer as? TelegramGroup {
        if let photo = group.photo.first {
            location = photo.location.cloudLocation
        }
    }
    
    if let location = location {
        return deferred { () -> Signal<UIImage, NoError> in
            return cachedCloudFileLocation(location)
                |> `catch` { _ in
                    return multipartDownloadFromCloudLocation(account: account, location: location, size: nil)
                        |> afterNext { data in
                            cacheCloudFileLocation(location, data: data)
                        }
                }
                |> runOn(account.graphicsThreadPool) |> deliverOn(account.graphicsThreadPool)
                |> map { data -> UIImage in
                    assertNotOnMainThread()
                    
                    if let image = generateImage(displayDimensions, contextGenerator: { size, context -> Void in
                        if let imageSource = CGImageSourceCreateWithData(data, nil), let dataImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                            context.setBlendMode(.copy)
                            context.draw(in: CGRect(origin: CGPoint(), size: displayDimensions), image: dataImage)
                            context.setBlendMode(.destinationOut)
                            context.draw(in: CGRect(origin: CGPoint(), size: displayDimensions), image: roundCorners.cgImage!)
                        }
                    }) {
                        return image
                    } else {
                        UIGraphicsBeginImageContextWithOptions(displayDimensions, false, 0.0)
                        let image = UIGraphicsGetImageFromCurrentImageContext()!
                        UIGraphicsEndImageContext()
                        return image
                    }
                }
        } |> runOn(account.graphicsThreadPool)
    } else {
        return nil
    }
}
