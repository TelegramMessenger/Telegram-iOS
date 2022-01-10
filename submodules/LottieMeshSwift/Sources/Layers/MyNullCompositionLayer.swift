import Foundation

final class MyNullCompositionLayer: MyCompositionLayer {
    init(layer: LayerModel) {
        super.init(layer: layer, size: .zero)
    }

    override func captureDisplayItem() -> CapturedGeometryNode.DisplayItem? {
        return nil
    }

    override func captureChildren() -> [CapturedGeometryNode] {
        return []
    }
}
