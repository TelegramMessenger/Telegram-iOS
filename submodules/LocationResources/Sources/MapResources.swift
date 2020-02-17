import Foundation
import UIKit
import Display
import Postbox
import TelegramCore
import SyncCore
import MapKit
import SwiftSignalKit

public struct MapSnapshotMediaResourceId: MediaResourceId {
    public let latitude: Double
    public let longitude: Double
    public let width: Int32
    public let height: Int32
    
    public var uniqueId: String {
        return "map-\(latitude)-\(longitude)-\(width)x\(height)"
    }
    
    public var hashValue: Int {
        return self.uniqueId.hashValue
    }
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? MapSnapshotMediaResourceId {
            return self.latitude == to.latitude && self.longitude == to.longitude && self.width == to.width && self.height == to.height
        } else {
            return false
        }
    }
}

public class MapSnapshotMediaResource: TelegramMediaResource {
    public let latitude: Double
    public let longitude: Double
    public let width: Int32
    public let height: Int32
    
    public init(latitude: Double, longitude: Double, width: Int32, height: Int32) {
        self.latitude = latitude
        self.longitude = longitude
        self.width = width
        self.height = height
    }
    
    public required init(decoder: PostboxDecoder) {
        self.latitude = decoder.decodeDoubleForKey("lt", orElse: 0.0)
        self.longitude = decoder.decodeDoubleForKey("ln", orElse: 0.0)
        self.width = decoder.decodeInt32ForKey("w", orElse: 0)
        self.height = decoder.decodeInt32ForKey("h", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeDouble(self.latitude, forKey: "lt")
        encoder.encodeDouble(self.longitude, forKey: "ln")
        encoder.encodeInt32(self.width, forKey: "w")
        encoder.encodeInt32(self.height, forKey: "h")
    }
    
    public var id: MediaResourceId {
        return MapSnapshotMediaResourceId(latitude: self.latitude, longitude: self.longitude, width: self.width, height: self.height)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? MapSnapshotMediaResource {
            return self.latitude == to.latitude && self.longitude == to.longitude && self.width == to.width && self.height == to.height
        } else {
            return false
        }
    }
}

public final class MapSnapshotMediaResourceRepresentation: CachedMediaResourceRepresentation {
    public let keepDuration: CachedMediaRepresentationKeepDuration = .shortLived
    
    public var uniqueId: String {
        return "cached"
    }
    
    public init() {
    }
    
    public func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let to = to as? MapSnapshotMediaResourceRepresentation {
            return true
        } else {
            return false
        }
    }
}

let TGGoogleMapsOffset: Int = 268435456
let TGGoogleMapsRadius = Double(TGGoogleMapsOffset) / Double.pi

private func yToLatitude(_ y: Int) -> Double {
    return ((Double.pi / 2.0) - 2 * atan(exp((Double(y - TGGoogleMapsOffset)) / TGGoogleMapsRadius))) * 180.0 / Double.pi;
}

private func latitudeToY(_ latitude: Double) -> Int {
    return Int(round(Double(TGGoogleMapsOffset) - TGGoogleMapsRadius * log((1.0 + sin(latitude * Double.pi / 180.0)) / (1.0 - sin(latitude * Double.pi / 180.0))) / 2.0))
}

private func adjustGMapLatitude(_ latitude: Double, offset: Int, zoom: Int) -> Double {
    let t: Int = (offset << (21 - zoom))
    return yToLatitude(latitudeToY(latitude) + t)
}

public func fetchMapSnapshotResource(resource: MapSnapshotMediaResource) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal { subscriber in
        let disposable = MetaDisposable()
        
        Queue.concurrentDefaultQueue().async {
            let options = MKMapSnapshotter.Options()
            let latitude = adjustGMapLatitude(resource.latitude, offset: -10, zoom: 15)
            options.region = MKCoordinateRegion(center: CLLocationCoordinate2DMake(latitude, resource.longitude), span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003))
            options.mapType = .standard
            options.showsPointsOfInterest = false
            options.showsBuildings = true
            options.size = CGSize(width: CGFloat(resource.width + 1), height: CGFloat(resource.height + 10))
            options.scale = 2.0
            let snapshotter = MKMapSnapshotter(options: options)
            snapshotter.start(with: DispatchQueue.global(), completionHandler: { result, error in
                if let image = result?.image {
                    if let data = image.jpegData(compressionQuality: 0.9) {
                        let tempFile = TempBox.shared.tempFile(fileName: "image.jpg")
                        if let _ = try? data.write(to: URL(fileURLWithPath: tempFile.path), options: .atomic) {
                            subscriber.putNext(.tempFile(tempFile))
                            subscriber.putCompletion()
                        }
                    }
                }
            })
            disposable.set(ActionDisposable {
                snapshotter.cancel()
            })
        }
        
        return disposable
    }
}

public func chatMapSnapshotData(account: Account, resource: MapSnapshotMediaResource) -> Signal<Data?, NoError> {
    return Signal<Data?, NoError> { subscriber in
        let dataDisposable = account.postbox.mediaBox.cachedResourceRepresentation(resource, representation: MapSnapshotMediaResourceRepresentation(), complete: true).start(next: { next in
            if next.size != 0 {
                subscriber.putNext(next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []))
            }
        }, error: subscriber.putError, completed: subscriber.putCompletion)
        
        return ActionDisposable {
            dataDisposable.dispose()
        }
    }
}

public func chatMapSnapshotImage(account: Account, resource: MapSnapshotMediaResource) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    let signal = chatMapSnapshotData(account: account, resource: resource)
    
    return signal |> map { fullSizeData in
        return { arguments in
            let context = DrawingContext(size: arguments.drawingSize, clear: true)
            
            var fullSizeImage: CGImage?
            var imageOrientation: UIImage.Orientation = .up
            if let fullSizeData = fullSizeData {
                let options = NSMutableDictionary()
                options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                    fullSizeImage = image
                }
                
                if let fullSizeImage = fullSizeImage {
                    let drawingRect = arguments.drawingRect
                    var fittedSize = CGSize(width: CGFloat(fullSizeImage.width), height: CGFloat(fullSizeImage.height)).aspectFilled(drawingRect.size)
                    if abs(fittedSize.width - arguments.boundingSize.width).isLessThanOrEqualTo(CGFloat(1.0)) {
                        fittedSize.width = arguments.boundingSize.width
                    }
                    if abs(fittedSize.height - arguments.boundingSize.height).isLessThanOrEqualTo(CGFloat(1.0)) {
                        fittedSize.height = arguments.boundingSize.height
                    }
                    
                    let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
                    
                    context.withFlippedContext { c in
                        c.setBlendMode(.copy)
                        if arguments.imageSize.width < arguments.boundingSize.width || arguments.imageSize.height < arguments.boundingSize.height {
                            c.fill(arguments.drawingRect)
                        }
                        
                        c.setBlendMode(.copy)
                        
                        c.interpolationQuality = .medium
                        c.draw(fullSizeImage, in: fittedRect)
                        
                        c.setBlendMode(.normal)
                    }
                } else {
                    context.withFlippedContext { c in
                        c.setBlendMode(.copy)
                        c.setFillColor((arguments.emptyColor ?? UIColor.white).cgColor)
                        c.fill(arguments.drawingRect)
                        
                        c.setBlendMode(.normal)
                    }
                }
            }
            
            addCorners(context, arguments: arguments)
            
            return context
        }
    }
}
