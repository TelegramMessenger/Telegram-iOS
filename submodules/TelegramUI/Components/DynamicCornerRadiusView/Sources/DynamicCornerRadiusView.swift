import Foundation
import UIKit
import ComponentFlow

private func generatePath(size: CGSize, corners: DynamicCornerRadiusView.Corners) -> CGPath {
    let path = CGMutablePath()
    
    var corners = corners
    corners.minXMinY = max(0.01, corners.minXMinY)
    corners.maxXMinY = max(0.01, corners.maxXMinY)
    corners.minXMaxY = max(0.01, corners.minXMaxY)
    corners.maxXMaxY = max(0.01, corners.maxXMaxY)
    
    path.move(to: CGPoint(x: 0.0, y: corners.minXMinY))
    path.addArc(tangent1End: CGPoint(x: 0.0, y: 0.0), tangent2End: CGPoint(x: corners.minXMinY, y: 0.0), radius: corners.minXMinY)
    path.addLine(to: CGPoint(x: size.width - corners.maxXMinY, y: 0.0))
    path.addArc(tangent1End: CGPoint(x: size.width, y: 0.0), tangent2End: CGPoint(x: size.width, y: corners.maxXMinY), radius: corners.maxXMinY)
    path.addLine(to: CGPoint(x: size.width, y: size.height - corners.maxXMaxY))
    path.addArc(tangent1End: CGPoint(x: size.width, y: size.height), tangent2End: CGPoint(x: size.width - corners.maxXMaxY, y: size.height), radius: corners.maxXMaxY)
    path.addLine(to: CGPoint(x: corners.minXMaxY, y: size.height))
    path.addArc(tangent1End: CGPoint(x: 0.0, y: size.height), tangent2End: CGPoint(x: 0.0, y: size.height - corners.minXMaxY), radius: corners.minXMaxY)
    path.closeSubpath()
    
    return path
}

open class DynamicCornerRadiusView: UIView {
    override public static var layerClass: AnyClass {
        return CAShapeLayer.self
    }
    
    public struct Corners: Equatable {
        public var minXMinY: CGFloat
        public var maxXMinY: CGFloat
        public var minXMaxY: CGFloat
        public var maxXMaxY: CGFloat

        public init(minXMinY: CGFloat, maxXMinY: CGFloat, minXMaxY: CGFloat, maxXMaxY: CGFloat) {
            self.minXMinY = minXMinY
            self.maxXMinY = maxXMinY
            self.minXMaxY = minXMaxY
            self.maxXMaxY = maxXMaxY
        }
    }

    private struct Params: Equatable {
        var size: CGSize
        var corners: Corners
        
        init(size: CGSize, corners: Corners) {
            self.size = size
            self.corners = corners
        }
    }

    private var params: Params?

    override public init(frame: CGRect) {
        super.init(frame: frame)
        
        if let shapeLayer = self.layer as? CAShapeLayer {
            shapeLayer.strokeColor = nil
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(size: CGSize, corners: Corners, transition: ComponentTransition) {
        let params = Params(size: size, corners: corners)
        if self.params == params {
            return
        }
        self.params = params
        self.update(params: params, transition: transition)
    }
    
    public func updateColor(color: UIColor, transition: ComponentTransition) {
        if let shapeLayer = self.layer as? CAShapeLayer {
            transition.setShapeLayerFillColor(layer: shapeLayer, color: color)
        }
    }

    private func update(params: Params, transition: ComponentTransition) {
        if let shapeLayer = self.layer as? CAShapeLayer {
            transition.setShapeLayerPath(layer: shapeLayer, path: generatePath(size: params.size, corners: params.corners))
        }
    }
}
