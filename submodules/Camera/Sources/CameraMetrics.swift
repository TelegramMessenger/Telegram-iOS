import Foundation
import DeviceModel

public extension Camera {
    enum Metrics {
        case singleCamera
        case iPhone14
        case iPhone14Plus
        case iPhone14Pro
        case iPhone14ProMax
        case iPhone15
        case iPhone15Plus
        case iPhone15Pro
        case iPhone15ProMax
        case unknown
        
        public init(model: DeviceModel) {
            switch model {
            case  .iPodTouch1, .iPodTouch2, .iPodTouch3, .iPodTouch4, .iPodTouch5, .iPodTouch6, .iPodTouch7:
                self = .singleCamera
            case .iPhone14:
                self = .iPhone14
            case .iPhone14Plus:
                self = .iPhone14Plus
            case .iPhone14Pro:
                self = .iPhone14Pro
            case .iPhone14ProMax:
                self = .iPhone14ProMax
            case .iPhone15:
                self = .iPhone15
            case .iPhone15Plus:
                self = .iPhone15Plus
            case .iPhone15Pro:
                self = .iPhone15Pro
            case .iPhone15ProMax:
                self = .iPhone15ProMax
            case .iPhone16Pro:
                self = .iPhone15Pro
            case .iPhone16ProMax:
                self = .iPhone15ProMax
            case .unknown:
                self = .unknown
            default:
                self = .unknown
            }
        }
        
        public var zoomLevels: [Float] {
            switch self {
            case .singleCamera:
                return [1.0]
            case .iPhone14, .iPhone14Plus, .iPhone15, .iPhone15Plus:
                return [0.5, 1.0, 2.0]
            case .iPhone14Pro, .iPhone14ProMax, .iPhone15Pro:
                return [0.5, 1.0, 2.0, 3.0]
            case .iPhone15ProMax:
                return [0.5, 1.0, 2.0, 5.0]
            case .unknown:
                return [1.0, 2.0]
            }
        }
    }
}
