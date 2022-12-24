import Foundation
import UIKit
import AsyncDisplayKit

private enum CornerType {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

private func drawFullCorner(context: CGContext, color: UIColor, at point: CGPoint, type: CornerType, radius: CGFloat) {
    if radius.isZero {
        return
    }
    context.setFillColor(color.cgColor)
    switch type {
    case .topLeft:
        context.clear(CGRect(origin: point, size: CGSize(width: radius, height: radius)))
        context.fillEllipse(in: CGRect(origin: point, size: CGSize(width: radius * 2.0, height: radius * 2.0)))
    case .topRight:
        context.clear(CGRect(origin: CGPoint(x: point.x - radius, y: point.y), size: CGSize(width: radius, height: radius)))
        context.fillEllipse(in: CGRect(origin: CGPoint(x: point.x - radius * 2.0, y: point.y), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
    case .bottomLeft:
        context.clear(CGRect(origin: CGPoint(x: point.x, y: point.y - radius), size: CGSize(width: radius, height: radius)))
        context.fillEllipse(in: CGRect(origin: CGPoint(x: point.x, y: point.y - radius * 2.0), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
    case .bottomRight:
        context.clear(CGRect(origin: CGPoint(x: point.x - radius, y: point.y - radius), size: CGSize(width: radius, height: radius)))
        context.fillEllipse(in: CGRect(origin: CGPoint(x: point.x - radius * 2.0, y: point.y - radius * 2.0), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
    }
}

private func drawConnectingCorner(context: CGContext, color: UIColor, at point: CGPoint, type: CornerType, radius: CGFloat) {
    context.setFillColor(color.cgColor)
    switch type {
    case .topLeft:
        context.fill(CGRect(origin: CGPoint(x: point.x - radius, y: point.y), size: CGSize(width: radius, height: radius)))
        context.setFillColor(UIColor.clear.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: point.x - radius * 2.0, y: point.y), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
    case .topRight:
        context.fill(CGRect(origin: CGPoint(x: point.x, y: point.y), size: CGSize(width: radius, height: radius)))
        context.setFillColor(UIColor.clear.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: point.x, y: point.y), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
    case .bottomLeft:
        context.fill(CGRect(origin: CGPoint(x: point.x - radius, y: point.y - radius), size: CGSize(width: radius, height: radius)))
        context.setFillColor(UIColor.clear.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: point.x - radius * 2.0, y: point.y - radius * 2.0), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
    case .bottomRight:
        context.fill(CGRect(origin: CGPoint(x: point.x, y: point.y - radius), size: CGSize(width: radius, height: radius)))
        context.setFillColor(UIColor.clear.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: point.x, y: point.y - radius * 2.0), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
    }
}

private func generateRectsImage(color: UIColor, rects: [CGRect], inset: CGFloat, outerRadius: CGFloat, innerRadius: CGFloat, useModernPathCalculation: Bool) -> (CGPoint, UIImage?) {
    if rects.isEmpty {
        return (CGPoint(), nil)
    }
    
    var topLeft = rects[0].origin
    var bottomRight = CGPoint(x: rects[0].maxX, y: rects[0].maxY)
    for i in 1 ..< rects.count {
        topLeft.x = min(topLeft.x, rects[i].origin.x)
        topLeft.y = min(topLeft.y, rects[i].origin.y)
        bottomRight.x = max(bottomRight.x, rects[i].maxX)
        bottomRight.y = max(bottomRight.y, rects[i].maxY)
    }
    
    topLeft.x -= inset
    topLeft.y -= inset
    bottomRight.x += inset * 2.0
    bottomRight.y += inset * 2.0
    
    return (topLeft, generateImage(CGSize(width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        
        context.setBlendMode(.copy)
        
        if useModernPathCalculation {
            var rects = rects.map { $0.insetBy(dx: -inset, dy: -inset).offsetBy(dx: -topLeft.x, dy: -topLeft.y) }
            if rects.count > 1 {
                let minRadius: CGFloat = 2.0
                
                for _ in 0 ..< rects.count * rects.count {
                    var hadChanges = false
                    for i in 0 ..< rects.count - 1 {
                        if rects[i].maxY > rects[i + 1].minY {
                            let midY = floor((rects[i].maxY + rects[i + 1].minY) * 0.5)
                            rects[i].size.height = midY - rects[i].minY
                            rects[i + 1].origin.y = midY
                            rects[i + 1].size.height = rects[i + 1].maxY - midY
                            hadChanges = true
                        }
                        if rects[i].maxY >= rects[i + 1].minY && rects[i].insetBy(dx: 0.0, dy: 1.0).intersects(rects[i + 1]) {
                            if abs(rects[i].minX - rects[i + 1].minX) < minRadius {
                                let commonMinX = min(rects[i].origin.x, rects[i + 1].origin.x)
                                if rects[i].origin.x != commonMinX {
                                    rects[i].origin.x = commonMinX
                                    hadChanges = true
                                }
                                if rects[i + 1].origin.x != commonMinX {
                                    rects[i + 1].origin.x = commonMinX
                                    hadChanges = true
                                }
                            }
                            if abs(rects[i].maxX - rects[i + 1].maxX) < minRadius {
                                let commonMaxX = max(rects[i].maxX, rects[i + 1].maxX)
                                if rects[i].maxX != commonMaxX {
                                    rects[i].size.width = commonMaxX - rects[i].minX
                                    hadChanges = true
                                }
                                if rects[i + 1].maxX != commonMaxX {
                                    rects[i + 1].size.width = commonMaxX - rects[i + 1].minX
                                    hadChanges = true
                                }
                            }
                        }
                    }
                    if !hadChanges {
                        break
                    }
                }
                
                context.move(to: CGPoint(x: rects[0].midX, y: rects[0].minY))
                context.addLine(to: CGPoint(x: rects[0].maxX - outerRadius, y: rects[0].minY))
                context.addArc(tangent1End: rects[0].topRight, tangent2End: CGPoint(x: rects[0].maxX, y: rects[0].minY + outerRadius), radius: outerRadius)
                context.addLine(to: CGPoint(x: rects[0].maxX, y: rects[0].midY))
                
                for i in 0 ..< rects.count - 1 {
                    let rect = rects[i]
                    let next = rects[i + 1]
                    
                    if rect.maxX == next.maxX {
                        context.addLine(to: CGPoint(x: next.maxX, y: next.midY))
                    } else {
                        let nextRadius = min(outerRadius, floor(abs(rect.maxX - next.maxX) * 0.5))
                        context.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - nextRadius))
                        if next.maxX > rect.maxX {
                            context.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX + nextRadius, y: rect.maxY), radius: nextRadius)
                            context.addLine(to: CGPoint(x: next.maxX - nextRadius, y: next.minY))
                        } else {
                            context.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - nextRadius, y: rect.maxY), radius: nextRadius)
                            context.addLine(to: CGPoint(x: next.maxX + nextRadius, y: next.minY))
                        }
                        context.addArc(tangent1End: next.topRight, tangent2End: CGPoint(x: next.maxX, y: next.minY + nextRadius), radius: nextRadius)
                        context.addLine(to: CGPoint(x: next.maxX, y: next.midY))
                    }
                }
                
                let last = rects[rects.count - 1]
                context.addLine(to: CGPoint(x: last.maxX, y: last.maxY - outerRadius))
                context.addArc(tangent1End: last.bottomRight, tangent2End: CGPoint(x: last.maxX - outerRadius, y: last.maxY), radius: outerRadius)
                context.addLine(to: CGPoint(x: last.minX + outerRadius, y: last.maxY))
                context.addArc(tangent1End: last.bottomLeft, tangent2End: CGPoint(x: last.minX, y: last.maxY - outerRadius), radius: outerRadius)
                
                for i in (1 ..< rects.count).reversed() {
                    let rect = rects[i]
                    let prev = rects[i - 1]
                    
                    if rect.minX == prev.minX {
                        context.addLine(to: CGPoint(x: prev.minX, y: prev.midY))
                    } else {
                        let prevRadius = min(outerRadius, floor(abs(rect.minX - prev.minX) * 0.5))
                        context.addLine(to: CGPoint(x: rect.minX, y: rect.minY + prevRadius))
                        if rect.minX < prev.minX {
                            context.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + prevRadius, y: rect.minY), radius: prevRadius)
                            context.addLine(to: CGPoint(x: prev.minX - prevRadius, y: prev.maxY))
                        } else {
                            context.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX - prevRadius, y: rect.minY), radius: prevRadius)
                            context.addLine(to: CGPoint(x: prev.minX + prevRadius, y: prev.maxY))
                        }
                        context.addArc(tangent1End: prev.bottomLeft, tangent2End: CGPoint(x: prev.minX, y: prev.maxY - prevRadius), radius: prevRadius)
                        context.addLine(to: CGPoint(x: prev.minX, y: prev.midY))
                    }
                }
                
                context.addLine(to: CGPoint(x: rects[0].minX, y: rects[0].minY + outerRadius))
                context.addArc(tangent1End: rects[0].topLeft, tangent2End: CGPoint(x: rects[0].minX + outerRadius, y: rects[0].minY), radius: outerRadius)
                context.addLine(to: CGPoint(x: rects[0].midX, y: rects[0].minY))
                
                context.fillPath()
                return
            } else {
                let path = UIBezierPath(roundedRect: rects[0], cornerRadius: outerRadius).cgPath
                context.addPath(path)
                context.fillPath()
                return
            }
        }
        
        for i in 0 ..< rects.count {
            let rect = rects[i].insetBy(dx: -inset, dy: -inset)
            context.fill(rect.offsetBy(dx: -topLeft.x, dy: -topLeft.y))
        }
        
        for i in 0 ..< rects.count {
            let rect = rects[i].insetBy(dx: -inset, dy: -inset).offsetBy(dx: -topLeft.x, dy: -topLeft.y)
            
            var previous: CGRect?
            if i != 0 {
                previous = rects[i - 1].insetBy(dx: -inset, dy: -inset).offsetBy(dx: -topLeft.x, dy: -topLeft.y)
            }
            
            var next: CGRect?
            if i != rects.count - 1 {
                next = rects[i + 1].insetBy(dx: -inset, dy: -inset).offsetBy(dx: -topLeft.x, dy: -topLeft.y)
            }
            
            if let previous = previous {
                if previous.contains(rect.topLeft) {
                    if abs(rect.topLeft.x - previous.minX) >= innerRadius {
                        var radius = innerRadius
                        if let next = next {
                            radius = min(radius, floor((next.minY - previous.maxY) / 2.0))
                        }
                        drawConnectingCorner(context: context, color: color, at: CGPoint(x: rect.topLeft.x, y: previous.maxY), type: .topLeft, radius: radius)
                    }
                } else {
                    drawFullCorner(context: context, color: color, at: rect.topLeft, type: .topLeft, radius: outerRadius)
                }
                if previous.contains(rect.topRight.offsetBy(dx: -1.0, dy: 0.0)) {
                    if abs(rect.topRight.x - previous.maxX) >= innerRadius {
                        var radius = innerRadius
                        if let next = next {
                            radius = min(radius, floor((next.minY - previous.maxY) / 2.0))
                        }
                        drawConnectingCorner(context: context, color: color, at: CGPoint(x: rect.topRight.x, y: previous.maxY), type: .topRight, radius: radius)
                    }
                } else {
                    drawFullCorner(context: context, color: color, at: rect.topRight, type: .topRight, radius: outerRadius)
                }
            } else {
                drawFullCorner(context: context, color: color, at: rect.topLeft, type: .topLeft, radius: outerRadius)
                drawFullCorner(context: context, color: color, at: rect.topRight, type: .topRight, radius: outerRadius)
            }
            
            if let next = next {
                if next.contains(rect.bottomLeft) {
                    if abs(rect.bottomRight.x - next.maxX) >= innerRadius {
                        var radius = innerRadius
                        if let previous = previous {
                            radius = min(radius, floor((next.minY - previous.maxY) / 2.0))
                        }
                        drawConnectingCorner(context: context, color: color, at: CGPoint(x: rect.bottomLeft.x, y: next.minY), type: .bottomLeft, radius: radius)
                    }
                } else {
                    drawFullCorner(context: context, color: color, at: rect.bottomLeft, type: .bottomLeft, radius: outerRadius)
                }
                if next.contains(rect.bottomRight.offsetBy(dx: -1.0, dy: 0.0)) {
                    if abs(rect.bottomRight.x - next.maxX) >= innerRadius {
                        var radius = innerRadius
                        if let previous = previous {
                            radius = min(radius, floor((next.minY - previous.maxY) / 2.0))
                        }
                        drawConnectingCorner(context: context, color: color, at: CGPoint(x: rect.bottomRight.x, y: next.minY), type: .bottomRight, radius: radius)
                    }
                } else {
                    drawFullCorner(context: context, color: color, at: rect.bottomRight, type: .bottomRight, radius: outerRadius)
                }
            } else {
                drawFullCorner(context: context, color: color, at: rect.bottomLeft, type: .bottomLeft, radius: outerRadius)
                drawFullCorner(context: context, color: color, at: rect.bottomRight, type: .bottomRight, radius: outerRadius)
            }
        }
    }))
}

public final class LinkHighlightingNode: ASDisplayNode {
    public private(set) var rects: [CGRect] = []
    public let imageNode: ASImageNode
    
    public var innerRadius: CGFloat = 4.0
    public var outerRadius: CGFloat = 4.0
    public var inset: CGFloat = 2.0
    public var useModernPathCalculation: Bool = false
    
    private var _color: UIColor
    public var color: UIColor {
        get {
            return _color
        } set(value) {
            self._color = value
            if !self.rects.isEmpty {
                self.updateImage()
            }
        }
    }
    
    public init(color: UIColor) {
        self._color = color
        
        self.imageNode = ASImageNode()
        self.imageNode.isUserInteractionEnabled = false
        self.imageNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.imageNode)
    }
    
    public func updateRects(_ rects: [CGRect], color: UIColor? = nil) {
        var updated = false
        if self.rects != rects {
            updated = true
            self.rects = rects
        }
        
        if let color, !color.isEqual(self.color) {
            updated = true
            self.color = color
        }
        
        if updated {
            self.updateImage()
        }
    }
    
    private func updateImage() {
        if self.rects.isEmpty {
            self.imageNode.image = nil
        }
        let (offset, image) = generateRectsImage(color: self.color, rects: self.rects, inset: self.inset, outerRadius: self.outerRadius, innerRadius: self.innerRadius, useModernPathCalculation: self.useModernPathCalculation)
        
        if let image = image {
            self.imageNode.image = image
            self.imageNode.frame = CGRect(origin: offset, size: image.size)
        }
    }

    public static func generateImage(color: UIColor, inset: CGFloat, innerRadius: CGFloat, outerRadius: CGFloat, rects: [CGRect], useModernPathCalculation: Bool) -> (CGPoint, UIImage)? {
        if rects.isEmpty {
           return nil
        }
        let (offset, image) = generateRectsImage(color: color, rects: rects, inset: inset, outerRadius: outerRadius, innerRadius: innerRadius, useModernPathCalculation: useModernPathCalculation)

        if let image = image {
            return (offset, image)
        } else {
            return nil
        }
    }
    
    public func asyncLayout() -> (UIColor, [CGRect], CGFloat, CGFloat, CGFloat) -> () -> Void {
        let currentRects = self.rects
        let currentColor = self._color
        let currentInnerRadius = self.innerRadius
        let currentOuterRadius = self.outerRadius
        let currentInset = self.inset
        let useModernPathCalculation = self.useModernPathCalculation
        
        return { [weak self] color, rects, innerRadius, outerRadius, inset in
            var updatedImage: (CGPoint, UIImage?)?
            if currentRects != rects || !currentColor.isEqual(color) || currentInnerRadius != innerRadius || currentOuterRadius != outerRadius || currentInset != inset {
                updatedImage = generateRectsImage(color: color, rects: rects, inset: inset, outerRadius: outerRadius, innerRadius: innerRadius, useModernPathCalculation: useModernPathCalculation)
            }
            
            return {
                if let strongSelf = self {
                    strongSelf._color = color
                    strongSelf.rects = rects
                    strongSelf.innerRadius = innerRadius
                    strongSelf.outerRadius = outerRadius
                    strongSelf.inset = inset
                    
                    if let (offset, maybeImage) = updatedImage, let image = maybeImage {
                        strongSelf.imageNode.image = image
                        strongSelf.imageNode.frame = CGRect(origin: offset, size: image.size)
                    }
                }
            }
        }
    }
}
