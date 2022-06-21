import Foundation
import UIKit
import Display
import TelegramCore
import SwiftSignalKit
import AppBundle
import PersistentStringHash

public struct VenueIconResourceId {
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
}

public class VenueIconResource {
    public let type: String
    
    public init(type: String) {
        self.type = type
    }
    
    public var id: EngineMediaResource.Id {
        return EngineMediaResource.Id(VenueIconResourceId(type: self.type).uniqueId)
    }
}

private func fetchVenueIconResource(engine: TelegramEngine, resource: VenueIconResource) -> Signal<EngineMediaResource.Fetch.Result, EngineMediaResource.Fetch.Error> {
    return Signal { subscriber in
        let url = "https://ss3.4sqi.net/img/categories_v2/\(resource.type)_88.png"
        
        return engine.resources.httpData(url: url).start(next: { data in
            let file = EngineTempBox.shared.tempFile(fileName: "file.png")
            let _ = try? data.write(to: URL(fileURLWithPath: file.path))
            subscriber.putNext(.moveTempFile(file: file))
        }, completed: {
            subscriber.putCompletion()
        })
    }
}

private func venueIconData(engine: TelegramEngine, resource: VenueIconResource) -> Signal<Data?, NoError> {
    let resourceData = engine.resources.custom(
        id: resource.id.stringRepresentation,
        fetch: EngineMediaResource.Fetch {
            return fetchVenueIconResource(engine: engine, resource: resource)
        },
        cacheTimeout: .shortLived
    )
    
    let signal = resourceData
    |> take(1)
    |> mapToSignal { maybeData -> Signal<Data?, NoError> in
        if maybeData.isComplete {
            return .single(try? Data(contentsOf: URL(fileURLWithPath: maybeData.path)))
        } else {
            return .single(nil)
        }
    }
    |> distinctUntilChanged(isEqual: { lhs, rhs in
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
    
    let index = Int(abs(Int32(bitPattern: UInt32(clamping: type.persistentHashValue))) % Int32(randomColors.count))
    return randomColors[index]
}

public struct VenueIconArguments: TransformImageCustomArguments {
    let defaultBackgroundColor: UIColor
    let defaultForegroundColor: UIColor
    
    public init(defaultBackgroundColor: UIColor, defaultForegroundColor: UIColor) {
        self.defaultBackgroundColor = defaultBackgroundColor
        self.defaultForegroundColor = defaultForegroundColor
    }
    
    public func serialized() -> NSArray {
        let array = NSMutableArray()
        array.add(self.defaultBackgroundColor)
        array.add(self.defaultForegroundColor)
        return array
    }
}

public func venueIcon(engine: TelegramEngine, type: String, background: Bool) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    let isBuiltinIcon = ["", "home", "work"].contains(type)
    let data: Signal<Data?, NoError> = isBuiltinIcon ? .single(nil) : venueIconData(engine: engine, resource: VenueIconResource(type: type))
    return data |> map { data in
        return { arguments in
            let context = DrawingContext(size: arguments.drawingSize, clear: true)
            
            var iconImage: UIImage?
            if let data = data, let image = UIImage(data: data) {
                iconImage = image
            }
            
            let backgroundColor: UIColor
            let foregroundColor: UIColor
            if type.isEmpty, let customArguments = arguments.custom as? VenueIconArguments {
                backgroundColor = customArguments.defaultBackgroundColor
                foregroundColor = customArguments.defaultForegroundColor
            } else {
                backgroundColor = venueIconColor(type: type)
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
