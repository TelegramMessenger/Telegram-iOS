import Foundation
import SwiftSignalKit

public enum MediaResourceStatus: Equatable {
    case Remote(progress: Float)
    case Local
    case Fetching(isActive: Bool, progress: Float)
    case Paused(progress: Float)
}
