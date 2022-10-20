import Foundation
import UIKit

final class MySolidCompositionLayer: MyCompositionLayer {
    let colorProperty: NodeProperty<Color>?
    let solidShape: CAShapeLayer = CAShapeLayer()

    init(solid: SolidLayerModel) {
        let components = solid.colorHex.hexColorComponents()
        self.colorProperty = NodeProperty(provider: SingleValueProvider(Color(r: Double(components.red), g: Double(components.green), b: Double(components.blue), a: 1)))

        super.init(layer: solid, size: .zero)
        solidShape.path = CGPath(rect: CGRect(x: 0, y: 0, width: solid.width, height: solid.height), transform: nil)
        //NOTE
        //contentsLayer.addSublayer(solidShape)
    }

    override func displayContentsWithFrame(frame: CGFloat, forceUpdates: Bool) {
        guard let colorProperty = colorProperty else { return }
        colorProperty.update(frame: frame)
        solidShape.fillColor = colorProperty.value.cgColorValue
    }

    override func captureDisplayItem() -> CapturedGeometryNode.DisplayItem? {
        guard let colorProperty = colorProperty else { return nil }
        guard let path = self.solidShape.path else {
            return nil
        }
        return CapturedGeometryNode.DisplayItem(
            path: path,
            display: .fill(CapturedGeometryNode.DisplayItem.Display.Fill(
                style: .color(color: UIColor(cgColor: colorProperty.value.cgColorValue), alpha: 1.0),
                fillRule: .evenOdd
            ))
        )
    }

    override func captureChildren() -> [CapturedGeometryNode] {
        return []
    }
}
