import Foundation
import CoreGraphics

/**
 A CompositionLayer responsible for initializing and rendering shapes
 */
final class MyShapeCompositionLayer: MyCompositionLayer {

    let rootNode: AnimatorNode?
    let renderContainer: ShapeContainerLayer?

    init(shapeLayer: ShapeLayerModel) {
        let results = shapeLayer.items.initializeNodeTree()
        let renderContainer = ShapeContainerLayer()
        self.renderContainer = renderContainer
        self.rootNode = results.rootNode
        super.init(layer: shapeLayer, size: .zero)

        //NOTE
        //contentsLayer.addSublayer(renderContainer)
        for container in results.renderContainers {
            renderContainer.insertRenderLayer(container)
        }
        rootNode?.updateTree(0, forceUpdates: true)
    }

    override func displayContentsWithFrame(frame: CGFloat, forceUpdates: Bool) {
        rootNode?.updateTree(frame, forceUpdates: forceUpdates)
        renderContainer?.markRenderUpdates(forFrame: frame)
    }

    override func captureGeometry() -> CapturedGeometryNode {
        var subnodes: [CapturedGeometryNode] = []
        if let renderContainer = self.renderContainer {
            subnodes.append(renderContainer.captureGeometry())
        }

        return CapturedGeometryNode(
            transform: self.transformNode.globalTransform,
            alpha: CGFloat(self.transformNode.opacity),
            isHidden: self.isHidden,
            displayItem: nil,
            subnodes: subnodes
        )
    }

    override func captureDisplayItem() -> CapturedGeometryNode.DisplayItem? {
        preconditionFailure()
    }

    override func captureChildren() -> [CapturedGeometryNode] {
        preconditionFailure()
    }
}
