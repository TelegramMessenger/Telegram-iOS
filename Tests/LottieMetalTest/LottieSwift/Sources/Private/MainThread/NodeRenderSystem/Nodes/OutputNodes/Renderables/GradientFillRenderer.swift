//
//  GradientFillRenderer.swift
//  lottie-swift
//
//  Created by Brandon Withrow on 1/30/19.
//

import Foundation
import QuartzCore

public var lottieSwift_getPathNativeBoundingBox: ((CGPath) -> CGRect)?

// MARK: - GradientFillLayer

extension CGPath {
    var stringRepresentation: String {
        var result = ""
        
        var indent = 1
        self.applyWithBlock { element in
            let indentString = Array<String>(repeating: " ", count: indent * 2).joined(separator: "")
            switch element.pointee.type {
            case .moveToPoint:
                let point = element.pointee.points.advanced(by: 0).pointee
                result += indentString + (NSString(format: "moveto (%10.15f, %10.15f)\n", point.x, point.y) as String)
                indent += 1
            case .addLineToPoint:
                let point = element.pointee.points.advanced(by: 0).pointee
                result += indentString + (NSString(format: "lineto (%10.15f, %10.15f)\n", point.x, point.y) as String)
            case .addCurveToPoint:
                let cp1 = element.pointee.points.advanced(by: 0).pointee
                let cp2 = element.pointee.points.advanced(by: 1).pointee
                let point = element.pointee.points.advanced(by: 2).pointee
                result += indentString + (NSString(format: "curveto (%10.15f, %10.15f) (%10.15f, %10.15f) (%10.15f, %10.15f)\n", cp1.x, cp1.y, cp2.x, cp2.y, point.x, point.y) as String)
            case .addQuadCurveToPoint:
                let cp = element.pointee.points.advanced(by: 0).pointee
                let point = element.pointee.points.advanced(by: 1).pointee
                result += indentString + (NSString(format: "quadcurveto (%10.15f, %10.15f) (%10.15f, %10.15f)\n", cp.x, cp.y, point.x, point.y) as String)
            case .closeSubpath:
                result += indentString + "closepath\n"
                indent -= 1
            @unknown default:
                break
            }
        }
        
        return result
    }
}

private final class GradientFillLayer: CALayer, LottieDrawingLayer {

  var start: CGPoint = .zero {
    didSet {
      setNeedsDisplay()
    }
  }

  var numberOfColors = 0 {
    didSet {
      setNeedsDisplay()
    }
  }

  var colors: [CGFloat] = [] {
    didSet {
      setNeedsDisplay()
    }
  }

  var end: CGPoint = .zero {
    didSet {
      setNeedsDisplay()
    }
  }

  var type: GradientType = .none {
    didSet {
      setNeedsDisplay()
    }
  }

  override func draw(in ctx: CGContext) {
    var alphaValues = [CGFloat]()
    var alphaLocations = [CGFloat]()

    var gradientColors = [Color]()
    var colorLocations = [CGFloat]()
    let colorSpace = ctx.colorSpace ?? CGColorSpaceCreateDeviceRGB()
    for i in 0..<numberOfColors {
      let ix = i * 4
      if colors.count > ix {
        gradientColors.append(Color(r: colors[ix + 1], g: colors[ix + 2], b: colors[ix + 3], a: 1.0))
        colorLocations.append(colors[ix])
      }
    }

    var drawMask = false
    for i in stride(from: numberOfColors * 4, to: colors.endIndex, by: 2) {
      let alpha = colors[i + 1]
      if alpha < 1 {
        drawMask = true
      }
      alphaLocations.append(colors[i])
      alphaValues.append(alpha)
    }
      
    if drawMask {
        var locations: [CGFloat] = []
        for i in 0 ..< min(gradientColors.count, colorLocations.count) {
            if !locations.contains(colorLocations[i]) {
                locations.append(colorLocations[i])
            }
        }
        for i in 0 ..< min(alphaValues.count, alphaLocations.count) {
            if !locations.contains(alphaLocations[i]) {
                locations.append(alphaLocations[i])
            }
        }
        
        locations.sort()
        if locations[0] != 0.0 {
            locations.insert(0.0, at: 0)
        }
        if locations[locations.count - 1] != 1.0 {
            locations.append(1.0)
        }
        
        var colors: [Color] = []
        
        for location in locations {
            var color: Color?
            for i in 0 ..< min(gradientColors.count, colorLocations.count) - 1 {
                if location >= colorLocations[i] && location <= colorLocations[i + 1] {
                    let localLocation: Double
                    if colorLocations[i] != colorLocations[i + 1] {
                        localLocation = location.remap(fromLow: colorLocations[i], fromHigh: colorLocations[i + 1], toLow: 0.0, toHigh: 1.0)
                    } else {
                        localLocation = 0.0
                    }
                    let fromColor = gradientColors[i]
                    let toColor = gradientColors[i + 1]
                    color = fromColor.interpolate(to: toColor, amount: localLocation)
                    
                    break
                }
            }
            
            var alpha: CGFloat?
            for i in 0 ..< min(alphaValues.count, alphaLocations.count) - 1 {
                if location >= alphaLocations[i] && location <= alphaLocations[i + 1] {
                    let localLocation: Double
                    if alphaLocations[i] != alphaLocations[i + 1] {
                        localLocation = location.remap(fromLow: alphaLocations[i], fromHigh: alphaLocations[i + 1], toLow: 0.0, toHigh: 1.0)
                    } else {
                        localLocation = 0.0
                    }
                    let fromAlpha = alphaValues[i]
                    let toAlpha = alphaValues[i + 1]
                    alpha = fromAlpha.interpolate(to: toAlpha, amount: localLocation)
                    
                    break
                }
            }
            
            var resultColor = color ?? gradientColors[0]
            resultColor.a = alpha ?? 1.0
            
            /*resultColor.r = 1.0
            resultColor.g = 0.0
            resultColor.b = 0.0
            resultColor.a = 1.0*/
            
            colors.append(resultColor)
        }
        
        gradientColors = colors
        colorLocations = locations
    }

    let cgGradientColors: [CGColor] = gradientColors.map { color -> CGColor in
        return color.cgColorValue(colorSpace: colorSpace)
    }
      
    guard let gradient = CGGradient(colorsSpace: colorSpace, colors: cgGradientColors as CFArray, locations: colorLocations)
    else { return }
    if type == .linear {
      ctx.drawLinearGradient(gradient, start: start, end: end, options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
    } else {
      ctx.drawRadialGradient(
        gradient,
        startCenter: start,
        startRadius: 0,
        endCenter: start,
        endRadius: start.distanceTo(end),
        options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
    }
  }

}

// MARK: - GradientFillRenderer

/// A rendered for a Path Fill
final class GradientFillRenderer: PassThroughOutputNode, Renderable {

  // MARK: Lifecycle

  override init(parent: NodeOutput?) {
    super.init(parent: parent)

    maskLayer.fillColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [1, 1, 1, 1])
    gradientLayer.mask = maskLayer

    maskLayer.actions = [
      "startPoint" : NSNull(),
      "endPoint" : NSNull(),
      "opacity" : NSNull(),
      "locations" : NSNull(),
      "colors" : NSNull(),
      "bounds" : NSNull(),
      "anchorPoint" : NSNull(),
      "isRadial" : NSNull(),
      "path" : NSNull(),
    ]
    gradientLayer.actions = maskLayer.actions
  }

  // MARK: Internal

  var shouldRenderInContext = false

  var start: CGPoint = .zero {
    didSet {
      hasUpdate = true
    }
  }

  var numberOfColors = 0 {
    didSet {
      hasUpdate = true
    }
  }

  var colors: [CGFloat] = [] {
    didSet {
      hasUpdate = true
    }
  }

  var end: CGPoint = .zero {
    didSet {
      hasUpdate = true
    }
  }

  var opacity: CGFloat = 0 {
    didSet {
      hasUpdate = true
    }
  }

  var type: GradientType = .none {
    didSet {
      hasUpdate = true
    }
  }

  func render(_: CGContext) {
    // do nothing
  }

  func setupSublayers(layer: CAShapeLayer) {
    layer.addSublayer(gradientLayer)
    layer.fillColor = nil
  }

  func updateShapeLayer(layer: CAShapeLayer) {
    hasUpdate = false

    guard let path = layer.path else {
      return
    }

    let frame = lottieSwift_getPathNativeBoundingBox!(path)
    
    let anchor = (frame.size.width.isZero || frame.size.height.isZero) ? CGPoint() : CGPoint(
      x: -frame.origin.x / frame.size.width,
      y: -frame.origin.y / frame.size.height)
    maskLayer.path = path
    maskLayer.bounds = frame
    maskLayer.anchorPoint = anchor

    gradientLayer.bounds = maskLayer.bounds
    gradientLayer.anchorPoint = anchor

    // setup gradient properties
    gradientLayer.start = start
    gradientLayer.end = end
    gradientLayer.numberOfColors = numberOfColors
    gradientLayer.colors = colors
    gradientLayer.opacity = Float(opacity)
    gradientLayer.type = type
  }

  // MARK: Private

  private let gradientLayer = GradientFillLayer()
  private let maskLayer = LottieCAShapeLayer()

}
