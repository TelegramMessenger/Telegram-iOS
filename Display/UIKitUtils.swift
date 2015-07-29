import UIKit

public func dumpViews(view: UIView) {
    dumpViews(view, indent: "")
}

private func dumpViews(view: UIView, indent: String = "") {
    print("\(indent)\(view)")
    let nextIndent = indent + "-"
    for subview in view.subviews {
        dumpViews(subview as UIView, indent: nextIndent)
    }
}

public func dumpLayers(layer: CALayer) {
    dumpLayers(layer, indent: "")
}

private func dumpLayers(layer: CALayer, indent: String = "") {
    print("\(indent)\(layer)(\(layer.frame))")
    if layer.sublayers != nil {
        let nextIndent = indent + ".."
        for sublayer in layer.sublayers ?? [] {
            dumpLayers(sublayer as CALayer, indent: nextIndent)
        }
    }
}

public func floorToScreenPixels(value: CGFloat) -> CGFloat {
    return floor(value * 2.0) / 2.0
}
