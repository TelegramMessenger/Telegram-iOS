import Foundation
import UIKit
import Display
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import AppBundle

public struct VenueIconResourceId: MediaResourceId {
    public let type: String
    
    public init(type: String) {
        self.type = type
    }
    
    public var uniqueId: String {
        return "venue-icon-\(self.type.replacingOccurrences(of: "/", with: "_"))"
    }
    
    public var hashValue: Int {
        return self.type.hashValue
    }
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? VenueIconResourceId {
            return self.type == to.type
        } else {
            return false
        }
    }
}

public class VenueIconResource: TelegramMediaResource {
    public let type: String
    
    public init(type: String) {
        self.type = type
    }
    
    public required init(decoder: PostboxDecoder) {
        self.type = decoder.decodeStringForKey("t", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.type, forKey: "t")
    }
    
    public var id: MediaResourceId {
        return VenueIconResourceId(type: self.type)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? VenueIconResource {
            return self.type == to.type
        } else {
            return false
        }
    }
}

public func fetchVenueIconResource(account: Account, resource: VenueIconResource) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return Signal { subscriber in
        subscriber.putNext(.reset)
        
        let url = "https://ss3.4sqi.net/img/categories_v2/\(resource.type)_88.png"
        
        let fetchDisposable = MetaDisposable()
        fetchDisposable.set(fetchHttpResource(url: url).start(next: { next in
            subscriber.putNext(next)
        }, completed: {
            subscriber.putCompletion()
        }))
        
        return ActionDisposable {
            fetchDisposable.dispose()
        }
    }
}

private func venueIconData(postbox: Postbox, resource: MediaResource) -> Signal<Data?, NoError> {
    let resourceData = postbox.mediaBox.resourceData(resource)
    
    let signal = resourceData
    |> take(1)
    |> mapToSignal { maybeData -> Signal<Data?, NoError> in
        if maybeData.complete {
            let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
            return .single((loadedData))
        } else {
            let fetched = postbox.mediaBox.fetchedResource(resource, parameters: nil)
            let data = Signal<Data?, NoError> { subscriber in
                let fetchedDisposable = fetched.start()
                let resourceDisposable = resourceData.start(next: { next in
                    subscriber.putNext(next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []))
                }, error: subscriber.putError, completed: subscriber.putCompletion)
                
                return ActionDisposable {
                    fetchedDisposable.dispose()
                    resourceDisposable.dispose()
                }
            }
            
            return data
        }
    } |> distinctUntilChanged(isEqual: { lhs, rhs in
        if lhs == nil && rhs == nil {
            return true
        } else {
            return false
        }
    })
    
    return signal
}

private let colors = [UIColor(rgb: 0xe56cd5), UIColor(rgb: 0xf89440), UIColor(rgb: 0x9986ff), UIColor(rgb: 0x44b3f5), UIColor(rgb: 0x6dc139), UIColor(rgb: 0xff5d5a), UIColor(rgb: 0xf87aad), UIColor(rgb: 0x6e82b3), UIColor(rgb: 0xf5ba21)]

public func venueIconColor(type: String) -> UIColor {
    let parentType = type.components(separatedBy: "/").first ?? type
    let index = Int(abs(persistentHash32(parentType)) % Int32(colors.count))
    return colors[index]
}

public func venueIcon(postbox: Postbox, type: String, background: Bool) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    let data: Signal<Data?, NoError> = type.isEmpty ? .single(nil) : venueIconData(postbox: postbox, resource: VenueIconResource(type: type))
    return data |> map { data in
        return { arguments in
            let context = DrawingContext(size: arguments.drawingSize, clear: true)
            
            var iconImage: UIImage?
            if let data = data, let image = UIImage(data: data) {
                iconImage = image
            }
            
            let backgroundColor = venueIconColor(type: type)
            let foregroundColor = UIColor.white
            
            context.withFlippedContext { c in
                if background {
                    c.setFillColor(backgroundColor.cgColor)
                    c.fillEllipse(in: CGRect(origin: CGPoint(), size: arguments.drawingRect.size))
                }
                if let image = iconImage, let cgImage = generateTintedImage(image: image, color: foregroundColor)?.cgImage {
                    let boundsSize = CGSize(width: arguments.drawingRect.size.width - 4.0 * 2.0, height: arguments.drawingRect.size.height - 4.0 * 2.0)
                    let fittedSize = image.size.aspectFitted(boundsSize)
                    c.draw(cgImage, in: CGRect(origin: CGPoint(x: floor((arguments.drawingRect.width - fittedSize.width) / 2.0), y: floor((arguments.drawingRect.height - fittedSize.height) / 2.0)), size: fittedSize))
                } else if type.isEmpty, let pinImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/LocationPinForeground"), color: foregroundColor), let cgImage = pinImage.cgImage {
                    c.draw(cgImage, in: CGRect(origin: CGPoint(x: floor((arguments.drawingRect.width - pinImage.size.width) / 2.0), y: floor((arguments.drawingRect.height - pinImage.size.height) / 2.0)), size: pinImage.size))
                }
            }
                        
            return context
        }
    }
}
