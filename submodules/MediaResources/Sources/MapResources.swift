import Foundation
import UIKit
import Postbox
import TelegramCore
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

public func fetchMapSnapshotResource(resource: MapSnapshotMediaResource) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return Signal { subscriber in
        let disposable = MetaDisposable()
        
        Queue.concurrentDefaultQueue().async {
            let options = MKMapSnapshotter.Options()
            let latitude = adjustGMapLatitude(resource.latitude, offset: -10, zoom: 15)
            options.region = MKCoordinateRegion(center: CLLocationCoordinate2DMake(latitude, resource.longitude), span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003))
            options.mapType = .standard
            options.showsPointsOfInterest = false
            options.showsBuildings = true
            options.size = CGSize(width: CGFloat(resource.width + 1), height: CGFloat(resource.height + 24))
            options.scale = 2.0
            let snapshotter = MKMapSnapshotter(options: options)
            snapshotter.start(with: DispatchQueue.global(), completionHandler: { result, error in
                if let image = result?.image {
                    if let data = image.jpegData(compressionQuality: 0.9) {
                        subscriber.putNext(MediaResourceDataFetchResult.dataPart(resourceOffset: 0, data: data, range: 0 ..< data.count, complete: true))
                        subscriber.putCompletion()
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

