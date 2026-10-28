import Foundation
import CoreGraphics
import TLottieBinding

public enum LottieFitzModifier {
    case none
    case type12
    case type3
    case type4
    case type5
    case type6
}

public protocol LottieInstance: AnyObject {
    var frameCount: Int32 { get }
    var frameRate: Int32 { get }
    var dimensions: CGSize { get }

    /// Used only by makeLottieInstance's duration limit.
    var duration: Double { get }

    func renderFrame(with index: Int32, into buffer: UnsafeMutablePointer<UInt8>,
                     width: Int32, height: Int32, bytesPerRow: Int32)
}

extension TLottieAnimation: LottieInstance {
}

extension LottieFitzModifier {
    var tlottieValue: TLottieFitzModifier {
        switch self {
        case .none: return .none
        case .type12: return .type12
        case .type3: return .type3
        case .type4: return .type4
        case .type5: return .type5
        case .type6: return .type6
        }
    }
}
