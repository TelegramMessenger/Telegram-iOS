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

private let randomColors = [UIColor(rgb: 0xe56cd5), UIColor(rgb: 0xf89440), UIColor(rgb: 0x9986ff), UIColor(rgb: 0x44b3f5), UIColor(rgb: 0x6dc139), UIColor(rgb: 0xff5d5a), UIColor(rgb: 0xf87aad), UIColor(rgb: 0x6e82b3), UIColor(rgb: 0xf5ba21)]

private let venueColors: [String: UIColor] = [
    "building/medical": UIColor(rgb: 0x43b3f4),
    "building/gym": UIColor(rgb: 0x43b3f4),
    "arts_entertainment": UIColor(rgb: 0xe56dd6),
    "travel/bedandbreakfast": UIColor(rgb: 0x9987ff),
    "travel/hotel": UIColor(rgb: 0x9987ff),
    "travel/hostel": UIColor(rgb: 0x9987ff),
    "travel/resort": UIColor(rgb: 0x9987ff),
    "building": UIColor(rgb: 0x6e81b2),
    "education": UIColor(rgb: 0xa57348),
    "event": UIColor(rgb: 0x959595),
    "food": UIColor(rgb: 0xf7943f),
    "education/cafeteria": UIColor(rgb: 0xf7943f),
    "nightlife": UIColor(rgb: 0xe56dd6),
    "travel/hotel_bar": UIColor(rgb: 0xe56dd6),
    "parks_outdoors": UIColor(rgb: 0x6cc039),
    "shops": UIColor(rgb: 0xffb300),
    "travel": UIColor(rgb: 0x1c9fff),
    "work": UIColor(rgb: 0xad7854),
    "home": UIColor(rgb: 0x00aeef)
]

public func venueIconColor(type: String) -> UIColor {
    if type.isEmpty {
        return UIColor(rgb: 0x008df2)
    }
    if let color = venueColors[type] {
        return color
    }
    let generalType = type.components(separatedBy: "/").first ?? type
    if let color = venueColors[generalType] {
        return color
    }
    
    let index = Int(abs(persistentHash32(type)) % Int32(randomColors.count))
    return randomColors[index]
}

public struct VenueIconArguments: TransformImageCustomArguments {
    let defaultForegroundColor: UIColor
    
    public init(defaultForegroundColor: UIColor) {
        self.defaultForegroundColor = defaultForegroundColor
    }
    
    public func serialized() -> NSArray {
        let array = NSMutableArray()
        array.add(self.defaultForegroundColor)
        return array
    }
}

public func venueIcon(postbox: Postbox, type: String, background: Bool) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    let isBuiltinIcon = ["", "home", "work"].contains(type)
    let data: Signal<Data?, NoError> = isBuiltinIcon ? .single(nil) : venueIconData(postbox: postbox, resource: VenueIconResource(type: type))
    return data |> map { data in
        return { arguments in
            let context = DrawingContext(size: arguments.drawingSize, clear: true)
            
            var iconImage: UIImage?
            if let data = data, let image = UIImage(data: data) {
                iconImage = image
            }
            
            let backgroundColor = venueIconColor(type: type)
            let foregroundColor: UIColor
            if type.isEmpty, let customArguments = arguments.custom as? VenueIconArguments {
                foregroundColor = customArguments.defaultForegroundColor
            } else {
                foregroundColor = UIColor.white
            }
                
            context.withFlippedContext { c in
                if background {
                    c.setFillColor(backgroundColor.cgColor)
                    c.fillEllipse(in: CGRect(origin: CGPoint(), size: arguments.drawingRect.size))
                }
                let boundsSize = CGSize(width: arguments.drawingRect.size.width - 4.0 * 2.0, height: arguments.drawingRect.size.height - 4.0 * 2.0)
                if let image = iconImage, let cgImage = generateTintedImage(image: image, color: foregroundColor)?.cgImage {
                    let fittedSize = image.size.aspectFitted(boundsSize)
                    c.draw(cgImage, in: CGRect(origin: CGPoint(x: floor((arguments.drawingRect.width - fittedSize.width) / 2.0), y: floor((arguments.drawingRect.height - fittedSize.height) / 2.0)), size: fittedSize))
                } else if isBuiltinIcon {
                    let image: UIImage?
                    switch type {
                        case "":
                            image = UIImage(bundleImageName: "Chat/Message/LocationPinForeground")
                        case "home":
                            image = UIImage(bundleImageName: "Location/HomeIcon")
                        case "work":
                            image = UIImage(bundleImageName: "Location/WorkIcon")
                        default:
                            image = nil
                    }
                    if let image = image, let pinImage = generateTintedImage(image: image, color: foregroundColor), let cgImage = pinImage.cgImage {
                        let fittedSize = image.size.aspectFitted(boundsSize)
                        c.draw(cgImage, in: CGRect(origin: CGPoint(x: floor((arguments.drawingRect.width - fittedSize.width) / 2.0), y: floor((arguments.drawingRect.height - fittedSize.height) / 2.0)), size: fittedSize))
                    }
                }
            }
                        
            return context
        }
    }
}
