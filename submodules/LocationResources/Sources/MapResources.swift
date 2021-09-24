import Foundation
import UIKit
import Display
import TelegramCore
import MapKit
import SwiftSignalKit

public struct MapSnapshotMediaResourceId {
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
}

public class MapSnapshotMediaResource {
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
    
    public var id: EngineMediaResource.Id {
        return EngineMediaResource.Id(MapSnapshotMediaResourceId(latitude: self.latitude, longitude: self.longitude, width: self.width, height: self.height).uniqueId)
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

private func fetchMapSnapshotResource(resource: MapSnapshotMediaResource) -> Signal<EngineMediaResource.Fetch.Result, EngineMediaResource.Fetch.Error> {
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
                        let tempFile = EngineTempBox.shared.tempFile(fileName: "image.jpg")
                        if let _ = try? data.write(to: URL(fileURLWithPath: tempFile.path), options: .atomic) {
                            subscriber.putNext(.moveTempFile(file: tempFile))
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

public func chatMapSnapshotData(engine: TelegramEngine, resource: MapSnapshotMediaResource) -> Signal<Data?, NoError> {
    return Signal<Data?, NoError> { subscriber in
        let dataDisposable = engine.resources.custom(
            id: resource.id.stringRepresentation,
            fetch: EngineMediaResource.Fetch {
                return fetchMapSnapshotResource(resource: resource)
            },
            cacheTimeout: .shortLived
        ).start(next: { next in
            if next.availableSize != 0 {
                subscriber.putNext(next.availableSize == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []))
            }
        }, error: subscriber.putError, completed: subscriber.putCompletion)
        
        return ActionDisposable {
            dataDisposable.dispose()
        }
    }
}

public func chatMapSnapshotImage(engine: TelegramEngine, resource: MapSnapshotMediaResource) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    let signal = chatMapSnapshotData(engine: engine, resource: resource)
    
    return signal |> map { fullSizeData in
        return { arguments in
            let context = DrawingContext(size: arguments.drawingSize, clear: true)
            
            var fullSizeImage: CGImage?
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
