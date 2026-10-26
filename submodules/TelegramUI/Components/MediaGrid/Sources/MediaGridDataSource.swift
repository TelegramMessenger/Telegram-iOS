import Foundation
import UIKit

public protocol MediaGridImageRequest: AnyObject {
    func cancel()
}

public protocol MediaGridDataSource: AnyObject {
    var count: Int { get }
    func date(at index: Int) -> Date?
    func aspectRatio(at index: Int) -> CGFloat
    func requestImage(at index: Int, pixelSize: CGSize, completion: @escaping (UIImage?, _ isDegraded: Bool) -> Void) -> MediaGridImageRequest?
    func startCaching(indices: [Int], pixelSize: CGSize)
    func stopCaching(indices: [Int], pixelSize: CGSize)
}
