import Foundation
import MapKit
import UIKit

/// Renders static map images for location/venue bubbles. `MKMapSnapshotter`
/// is the only real-tile path on watchOS (SwiftUI `Map` and `MKMapView` are
/// unavailable). Results are memoized in a process-wide `NSCache` keyed by a
/// quantized coordinate + size, so scrolling and reprojection don't re-render.
enum MapSnapshotRenderer {
    // NSCache is thread-safe; no actor isolation needed.
    private static let cache = NSCache<NSString, UIImage>()

    /// Map span shown in the bubble/snapshot, in meters (square).
    private static let spanMeters: CLLocationDistance = 1000

    /// Pure cache key. Coordinates are quantized to 5 decimal places (~1 m) so
    /// float noise doesn't thrash the cache; width/height participate so the
    /// bubble and any larger render stay distinct.
    static func cacheKey(latitude: Double, longitude: Double, width: Int, height: Int) -> String {
        let lat = (latitude * 100_000).rounded() / 100_000
        let lon = (longitude * 100_000).rounded() / 100_000
        return "\(lat),\(lon),\(width)x\(height)"
    }

    /// Returns a snapshot image for the coordinate, or nil on failure.
    static func image(latitude: Double, longitude: Double, size: CGSize) async -> UIImage? {
        let key = cacheKey(
            latitude: latitude, longitude: longitude,
            width: Int(size.width.rounded()), height: Int(size.height.rounded())
        ) as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            latitudinalMeters: spanMeters,
            longitudinalMeters: spanMeters
        )
        options.size = size
        options.preferredConfiguration = MKStandardMapConfiguration()

        // MKMapSnapshotter retains itself while a render is in flight, so the local
        // doesn't need an explicit strong capture (which would trip a non-Sendable
        // capture warning in the @Sendable completion closure).
        let snapshotter = MKMapSnapshotter(options: options)
        let image: UIImage? = await withCheckedContinuation { continuation in
            snapshotter.start(with: .global(qos: .userInitiated)) { snapshot, _ in
                continuation.resume(returning: snapshot?.image)
            }
        }
        if let image { cache.setObject(image, forKey: key) }
        return image
    }
}
