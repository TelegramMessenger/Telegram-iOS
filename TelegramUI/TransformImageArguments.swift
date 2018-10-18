import Foundation
import UIKit

public enum TransformImageResizeMode {
    case fill(UIColor)
    case blurBackground
}

public struct TransformImageArguments: Equatable {
    public let corners: ImageCorners
    
    public let imageSize: CGSize
    public let boundingSize: CGSize
    public let intrinsicInsets: UIEdgeInsets
    public let resizeMode: TransformImageResizeMode
    public let emptyColor: UIColor?
    
    public init(corners: ImageCorners, imageSize: CGSize, boundingSize: CGSize, intrinsicInsets: UIEdgeInsets, resizeMode: TransformImageResizeMode = .fill(.black), emptyColor: UIColor? = nil) {
        self.corners = corners
        self.imageSize = imageSize
        self.boundingSize = boundingSize
        self.intrinsicInsets = intrinsicInsets
        self.resizeMode = resizeMode
        self.emptyColor = emptyColor
    }
    
    public var drawingSize: CGSize {
        let cornersExtendedEdges = self.corners.extendedEdges
        return CGSize(width: self.boundingSize.width + cornersExtendedEdges.left + cornersExtendedEdges.right + self.intrinsicInsets.left + self.intrinsicInsets.right, height: self.boundingSize.height + cornersExtendedEdges.top + cornersExtendedEdges.bottom + self.intrinsicInsets.top + self.intrinsicInsets.bottom)
    }
    
    public var drawingRect: CGRect {
        let cornersExtendedEdges = self.corners.extendedEdges
        return CGRect(x: cornersExtendedEdges.left + self.intrinsicInsets.left, y: cornersExtendedEdges.top + self.intrinsicInsets.top, width: self.boundingSize.width, height: self.boundingSize.height);
    }
    
    public var insets: UIEdgeInsets {
        let cornersExtendedEdges = self.corners.extendedEdges
        return UIEdgeInsets(top: cornersExtendedEdges.top + self.intrinsicInsets.top, left: cornersExtendedEdges.left + self.intrinsicInsets.left, bottom: cornersExtendedEdges.bottom + self.intrinsicInsets.bottom, right: cornersExtendedEdges.right + self.intrinsicInsets.right)
    }
    
    public static func ==(lhs: TransformImageArguments, rhs: TransformImageArguments) -> Bool {
        return lhs.imageSize == rhs.imageSize && lhs.boundingSize == rhs.boundingSize && lhs.corners == rhs.corners
    }
}
