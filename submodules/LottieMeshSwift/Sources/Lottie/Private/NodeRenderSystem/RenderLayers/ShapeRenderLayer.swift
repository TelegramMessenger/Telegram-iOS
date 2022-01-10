//
//  RenderLayer.swift
//  lottie-swift
//
//  Created by Brandon Withrow on 1/18/19.
//

import Foundation
import UIKit

/**
 The layer responsible for rendering shape objects
 */
final class ShapeRenderLayer: ShapeContainerLayer {

    fileprivate(set) var renderer: Renderable & NodeOutput

    let shapeLayer: CAShapeLayer = CAShapeLayer()

    init(renderer: Renderable & NodeOutput) {
        self.renderer = renderer
        super.init()
        self.anchorPoint = .zero
        self.actions = [
            "position" : NSNull(),
            "bounds" : NSNull(),
            "anchorPoint" : NSNull(),
            "path" : NSNull(),
            "transform" : NSNull(),
            "opacity" : NSNull(),
            "hidden" : NSNull(),
        ]
        shapeLayer.actions = [
            "position" : NSNull(),
            "bounds" : NSNull(),
            "anchorPoint" : NSNull(),
            "path" : NSNull(),
            "fillColor" : NSNull(),
            "strokeColor" : NSNull(),
            "lineWidth" : NSNull(),
            "miterLimit" : NSNull(),
            "lineDashPhase" : NSNull(),
            "hidden" : NSNull(),
        ]
        shapeLayer.anchorPoint = .zero
        addSublayer(shapeLayer)
    }

    override init(layer: Any) {
        guard let layer = layer as? ShapeRenderLayer else {
            fatalError("init(layer:) wrong class.")
        }
        self.renderer = layer.renderer
        super.init(layer: layer)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hasRenderUpdate(forFrame: CGFloat) -> Bool {
        self.isHidden = !renderer.isEnabled
        guard self.isHidden == false else { return false }
        return renderer.hasRenderUpdates(forFrame)
    }

    override func rebuildContents(forFrame: CGFloat) {

        if renderer.shouldRenderInContext {
            if let newPath = renderer.outputPath {
                self.bounds = renderer.renderBoundsFor(newPath.boundingBox)
            } else {
                self.bounds = .zero
            }
            self.position = bounds.origin
            self.setNeedsDisplay()
        } else {
            shapeLayer.path = renderer.outputPath
            renderer.updateShapeLayer(layer: shapeLayer)
        }
    }

    override func draw(in ctx: CGContext) {
        if let path = renderer.outputPath {
            if !path.isEmpty {
                ctx.addPath(path)
            }
        }
        renderer.render(ctx)
    }

    override func captureDisplayItem() -> CapturedGeometryNode.DisplayItem? {
        guard let path = renderer.outputPath, !path.isEmpty else {
            return nil
        }
        let display: CapturedGeometryNode.DisplayItem.Display
        if let renderer = self.renderer as? FillRenderer {
            display = .fill(CapturedGeometryNode.DisplayItem.Display.Fill(
                style: .color(color: UIColor(cgColor: renderer.color!), alpha: renderer.opacity),
                fillRule: renderer.fillRule.cgFillRule
            ))
        } else if let renderer = self.renderer as? StrokeRenderer {
            display = .stroke(CapturedGeometryNode.DisplayItem.Display.Stroke(
                style: .color(color: UIColor(cgColor: renderer.color!), alpha: renderer.opacity),
                lineWidth: renderer.width,
                lineCap: renderer.lineCap.cgLineCap,
                lineJoin: renderer.lineJoin.cgLineJoin,
                miterLimit: renderer.miterLimit
            ))
        } else if let renderer = self.renderer as? GradientFillRenderer {
            var gradientColors: [UIColor] = []
            var colorLocations: [CGFloat] = []

            for i in 0 ..< renderer.numberOfColors {
                let ix = i * 4
                if renderer.colors.count > ix {
                    let color = UIColor(red: CGFloat(renderer.colors[ix + 1]), green: CGFloat(renderer.colors[ix + 2]), blue: CGFloat(renderer.colors[ix + 3]), alpha: renderer.opacity)
                    gradientColors.append(color)
                    colorLocations.append(CGFloat(renderer.colors[ix]))
                }
            }

            var alphaIndex = 0
            for i in stride(from: (renderer.numberOfColors * 4), to: renderer.colors.endIndex, by: 2) {
                let alpha = renderer.colors[i + 1]
                var currentAlpha: CGFloat = 1.0
                    if alphaIndex < gradientColors.count {
                    gradientColors[alphaIndex].getRed(nil, green: nil, blue: nil, alpha: &currentAlpha)
                    gradientColors[alphaIndex] = gradientColors[alphaIndex].withAlphaComponent(alpha * currentAlpha)
                }
                alphaIndex += 1
            }

            let mappedType: CapturedGeometryNode.DisplayItem.Display.Style.GradientType
            switch renderer.type {
            case .linear:
                mappedType = .linear
            case .radial:
                mappedType = .radial
            case .none:
                mappedType = .linear
            }

            display = .fill(CapturedGeometryNode.DisplayItem.Display.Fill(
                style: .gradient(
                    colors: gradientColors,
                    positions: colorLocations,
                    start: renderer.start,
                    end: renderer.end,
                    type: mappedType
                ),
                fillRule: .evenOdd
            ))
        } else if let renderer = renderer as? GradientStrokeRenderer {
            var gradientColors: [UIColor] = []
            var colorLocations: [CGFloat] = []

            let gradientRender = renderer.gradientRender

            for i in 0 ..< gradientRender.numberOfColors {
                let ix = i * 4
                if gradientRender.colors.count > ix {
                    let color = UIColor(red: CGFloat(gradientRender.colors[ix + 1]), green: CGFloat(gradientRender.colors[ix + 2]), blue: CGFloat(gradientRender.colors[ix + 3]), alpha: 1.0)
                    gradientColors.append(color)
                    colorLocations.append(CGFloat(gradientRender.colors[ix]))
                }
            }

            var alphaIndex = 0
            for i in stride(from: (gradientRender.numberOfColors * 4), to: gradientRender.colors.endIndex, by: 2) {
                let alpha = gradientRender.colors[i + 1]
                gradientColors[alphaIndex] = gradientColors[alphaIndex].withAlphaComponent(alpha)
                alphaIndex += 1
            }

            let mappedType: CapturedGeometryNode.DisplayItem.Display.Style.GradientType
            switch gradientRender.type {
            case .linear:
                mappedType = .linear
            case .radial:
                mappedType = .radial
            case .none:
                mappedType = .linear
            }

            display = .stroke(CapturedGeometryNode.DisplayItem.Display.Stroke(
                style: .gradient(
                    colors: gradientColors,
                    positions: colorLocations,
                    start: gradientRender.start,
                    end: gradientRender.end,
                    type: mappedType
                ),
                lineWidth: renderer.strokeRender.width,
                lineCap: renderer.strokeRender.lineCap.cgLineCap,
                lineJoin: renderer.strokeRender.lineJoin.cgLineJoin,
                miterLimit: renderer.strokeRender.miterLimit
            ))
        } else {
            return nil
        }
        return CapturedGeometryNode.DisplayItem(path: path, display: display)
    }
}
