import Foundation
import UIKit

public enum TransformImageResizeMode {
    case fill(UIColor)
    case aspectFill
    case blurBackground
}

public protocol TransformImageCustomArguments {
    func serialized() -> NSArray
}

public struct TransformImageArguments: Equatable {
    public var corners: ImageCorners
    
    public var imageSize: CGSize
    public var boundingSize: CGSize
    public var intrinsicInsets: UIEdgeInsets
    public var resizeMode: TransformImageResizeMode
    public var emptyColor: UIColor?
    public var custom: TransformImageCustomArguments?
    public var scale: CGFloat?
    
    public init(corners: ImageCorners, imageSize: CGSize, boundingSize: CGSize, intrinsicInsets: UIEdgeInsets, resizeMode: TransformImageResizeMode = .fill(.black), emptyColor: UIColor? = nil, custom: TransformImageCustomArguments? = nil, scale: CGFloat? = nil) {
        self.corners = corners
        self.imageSize = imageSize
        self.boundingSize = boundingSize
        self.intrinsicInsets = intrinsicInsets
        self.resizeMode = resizeMode
        self.emptyColor = emptyColor
        self.custom = custom
        self.scale = scale
    }
    
    public var drawingSize: CGSize {
        let cornersExtendedEdges = self.corners.extendedEdges
        return CGSize(width: self.boundingSize.width + cornersExtendedEdges.left + cornersExtendedEdges.right + self.intrinsicInsets.left + self.intrinsicInsets.right, height: self.boundingSize.height + cornersExtendedEdges.top + cornersExtendedEdges.bottom + self.intrinsicInsets.top + self.intrinsicInsets.bottom)
    }
    
    public var drawingRect: CGRect {
        let cornersExtendedEdges = self.corners.extendedEdges
        return CGRect(x: cornersExtendedEdges.left + self.intrinsicInsets.left, y: cornersExtendedEdges.top + self.intrinsicInsets.top, width: self.boundingSize.width, height: self.boundingSize.height)
    }
    
    public var imageRect: CGRect {
        let drawingRect = self.drawingRect
        return CGRect(x: drawingRect.minX + floor((drawingRect.width - self.imageSize.width) / 2.0), y: drawingRect.minX + floor((drawingRect.height - self.imageSize.height) / 2.0), width: self.imageSize.width, height: self.imageSize.height)
    }
    
    public var insets: UIEdgeInsets {
        let cornersExtendedEdges = self.corners.extendedEdges
        return UIEdgeInsets(top: cornersExtendedEdges.top + self.intrinsicInsets.top, left: cornersExtendedEdges.left + self.intrinsicInsets.left, bottom: cornersExtendedEdges.bottom + self.intrinsicInsets.bottom, right: cornersExtendedEdges.right + self.intrinsicInsets.right)
    }
    
    public static func ==(lhs: TransformImageArguments, rhs: TransformImageArguments) -> Bool {
        let result = lhs.imageSize == rhs.imageSize && lhs.boundingSize == rhs.boundingSize && lhs.corners == rhs.corners && lhs.emptyColor == rhs.emptyColor
        if result {
            if let lhsCustom = lhs.custom, let rhsCustom = rhs.custom {
                return lhsCustom.serialized().isEqual(rhsCustom.serialized())
            } else {
                return (lhs.custom != nil) == (rhs.custom != nil)
            }
        }
        return result
    }
}
