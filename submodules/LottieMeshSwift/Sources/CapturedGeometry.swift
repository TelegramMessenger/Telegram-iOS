import Foundation
import UIKit

final class CapturedGeometryNode {
    final class DisplayItem {
        enum Display {
            enum Style {
                enum GradientType {
                    case linear
                    case radial
                }

                case color(color: UIColor, alpha: CGFloat)
                case gradient(colors: [UIColor], positions: [CGFloat], start: CGPoint, end: CGPoint, type: GradientType)
            }

            struct Fill {
                var style: Style
                var fillRule: CGPathFillRule
            }

            struct Stroke {
                var style: Style
                var lineWidth: CGFloat
                var lineCap: CGLineCap
                var lineJoin: CGLineJoin
                var miterLimit: CGFloat
            }

            case fill(Fill)
            case stroke(Stroke)
        }

        let path: CGPath
        let display: Display

        init(path: CGPath, display: Display) {
            self.path = path
            self.display = display
        }
    }

    var transform: CATransform3D
    let alpha: CGFloat
    let isHidden: Bool
    let displayItem: DisplayItem?
    let subnodes: [CapturedGeometryNode]

    init(
        transform: CATransform3D,
        alpha: CGFloat,
        isHidden: Bool,
        displayItem: DisplayItem?,
        subnodes: [CapturedGeometryNode]
    ) {
        self.transform = transform
        self.alpha = alpha
        self.isHidden = isHidden
        self.displayItem = displayItem
        self.subnodes = subnodes
    }
}
