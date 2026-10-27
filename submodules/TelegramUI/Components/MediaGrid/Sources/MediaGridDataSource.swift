import Foundation
import UIKit

public protocol MediaGridImageRequest: AnyObject {
    func cancel()
}

public enum MediaGridImageQuality {
    case full
    case fast
}

public typealias MediaGridAspectRatioReader = @Sendable (Int) -> CGFloat

public protocol MediaGridDataSource: AnyObject {
    var count: Int { get }
    func date(at index: Int) -> Date?
    func aspectRatioReader() -> MediaGridAspectRatioReader
    func requestImage(at index: Int, pixelSize: CGSize, quality: MediaGridImageQuality, completion: @escaping (UIImage?, _ isDegraded: Bool) -> Void) -> MediaGridImageRequest?
    func startCaching(indices: [Int], pixelSize: CGSize, quality: MediaGridImageQuality)
    func stopCaching(indices: [Int], pixelSize: CGSize, quality: MediaGridImageQuality)
    func performBatch(_ updates: () -> Void)
}

public extension MediaGridDataSource {
    func performBatch(_ updates: () -> Void) {
        updates()
    }
}
