import Foundation
import UIKit

public enum VideoCaptureResult: Equatable {
    public struct Result {
        public let path: String
        public let thumbnail: UIImage
        public let isMirrored: Bool
        public let dimensions: CGSize

        public init(path: String, thumbnail: UIImage, isMirrored: Bool, dimensions: CGSize) {
            self.path = path
            self.thumbnail = thumbnail
            self.isMirrored = isMirrored
            self.dimensions = dimensions
        }
    }

    case finished(main: Result, additional: Result?, duration: Double, positionChangeTimestamps: [(Bool, Double)], captureTimestamp: Double)
    case failed

    public static func == (lhs: VideoCaptureResult, rhs: VideoCaptureResult) -> Bool {
        switch lhs {
        case .failed:
            if case .failed = rhs {
                return true
            } else {
                return false
            }
        case let .finished(_, _, lhsDuration, lhsChangeTimestamps, lhsTimestamp):
            if case let .finished(_, _, rhsDuration, rhsChangeTimestamps, rhsTimestamp) = rhs, lhsDuration == rhsDuration, lhsTimestamp == rhsTimestamp {
                if lhsChangeTimestamps.count != rhsChangeTimestamps.count {
                    return false
                }
                return true
            } else {
                return false
            }
        }
    }
}

public struct CameraCode: Equatable {
    public enum CodeType {
        case qr
    }

    public let type: CodeType
    public let message: String
    public let corners: [CGPoint]

    public init(type: CameraCode.CodeType, message: String, corners: [CGPoint]) {
        self.type = type
        self.message = message
        self.corners = corners
    }

    public var boundingBox: CGRect {
        let x = self.corners.map { $0.x }
        let y = self.corners.map { $0.y }
        if let minX = x.min(), let minY = y.min(), let maxX = x.max(), let maxY = y.max() {
            return CGRect(x: minX, y: minY, width: abs(maxX - minX), height: abs(maxY - minY))
        }
        return CGRect.null
    }

    public var rotation: CGFloat {
        guard self.corners.count == 4 else {
            return 0.0
        }

        let topLeft = self.corners[1]
        let topRight = self.corners[2]

        let dx = topRight.x - topLeft.x
        let dy = topRight.y - topLeft.y

        return atan2(dy, dx) - .pi / 2.0
    }

    public static func == (lhs: CameraCode, rhs: CameraCode) -> Bool {
        if lhs.type != rhs.type {
            return false
        }
        if lhs.message != rhs.message {
            return false
        }
        if lhs.corners != rhs.corners {
            return false
        }
        return true
    }
}
