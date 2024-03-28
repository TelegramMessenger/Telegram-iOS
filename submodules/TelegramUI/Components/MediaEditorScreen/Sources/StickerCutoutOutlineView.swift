import Foundation
import UIKit
import Display
import CoreImage
import MediaEditor

func createEmitterBehavior(type: String) -> NSObject {
    let selector = ["behaviorWith", "Type:"].joined(separator: "")
    let behaviorClass = NSClassFromString(["CA", "Emitter", "Behavior"].joined(separator: "")) as! NSObject.Type
    let behaviorWithType = behaviorClass.method(for: NSSelectorFromString(selector))!
    let castedBehaviorWithType = unsafeBitCast(behaviorWithType, to:(@convention(c)(Any?, Selector, Any?) -> NSObject).self)
    return castedBehaviorWithType(behaviorClass, NSSelectorFromString(selector), type)
}

private var previousBeginTime: Int = 3

final class StickerCutoutOutlineView: UIView {
    let strokeLayer = SimpleShapeLayer()
    let imageLayer = SimpleLayer()
    var outlineLayer = CAEmitterLayer()
    var glowLayer = CAEmitterLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.strokeLayer.fillColor = UIColor.clear.cgColor
        self.strokeLayer.strokeColor = UIColor.clear.cgColor
        self.strokeLayer.shadowColor = UIColor.white.cgColor
        self.strokeLayer.shadowOpacity = 0.35
        self.strokeLayer.shadowRadius = 4.0
        
        self.layer.allowsGroupOpacity = true
        
//        self.imageLayer.contentsGravity = .resizeAspect
        
        self.layer.addSublayer(self.strokeLayer)
        self.layer.addSublayer(self.imageLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var hasContents: Bool {
        self.imageLayer.contents != nil
    }
    
    func update(image: UIImage, maskImage: CIImage, size: CGSize, values: MediaEditorValues) {
        self.imageLayer.contents = image.cgImage
        
        if let path = getPathFromMaskImage(maskImage, size: size, values: values) {
            self.strokeLayer.shadowPath = path.path.cgPath.expand(width: 1.5)
            
            self.setupAnimation(path: path)
        }
    }
        
    private func setupAnimation(path: BezierPath) {
        self.outlineLayer = CAEmitterLayer()
        self.outlineLayer.opacity = 0.7
        self.glowLayer = CAEmitterLayer()
        
        self.layer.addSublayer(self.outlineLayer)
        self.layer.addSublayer(self.glowLayer)
        
        let randomBeginTime = (previousBeginTime + 4) % 6
        previousBeginTime = randomBeginTime
        
        let duration = path.length / 2200.0
        
        let outlineAnimation = CAKeyframeAnimation(keyPath: "emitterPosition")
        outlineAnimation.path = path.path.cgPath
        outlineAnimation.duration = duration
        outlineAnimation.repeatCount = .infinity
        outlineAnimation.calculationMode = .cubicPaced
        outlineAnimation.beginTime = Double(randomBeginTime)
        self.outlineLayer.add(outlineAnimation, forKey: "emitterPosition")
        
        let lineEmitterCell = CAEmitterCell()
        lineEmitterCell.beginTime = CACurrentMediaTime()
        let lineAlphaBehavior = createEmitterBehavior(type: "valueOverLife")
        lineAlphaBehavior.setValue("color.alpha", forKey: "keyPath")
        lineAlphaBehavior.setValue([0.0, 0.5, 0.8, 0.5, 0.0], forKey: "values")
        lineEmitterCell.setValue([lineAlphaBehavior], forKey: "emitterBehaviors")
        lineEmitterCell.color = UIColor.white.cgColor
        lineEmitterCell.contents = UIImage(named: "Media Editor/ParticleDot")?.cgImage
        lineEmitterCell.lifetime = 2.2
        lineEmitterCell.birthRate = 1000
        lineEmitterCell.scale = 0.14
        lineEmitterCell.alphaSpeed = -0.4
        
        self.outlineLayer.emitterCells = [lineEmitterCell]
        self.outlineLayer.emitterMode = .points
        self.outlineLayer.emitterSize = CGSize(width: 1.0, height: 1.0)
        self.outlineLayer.emitterShape = .point
        
        let glowAnimation = CAKeyframeAnimation(keyPath: "emitterPosition")
        glowAnimation.path = path.path.cgPath
        glowAnimation.duration = duration
        glowAnimation.repeatCount = .infinity
        glowAnimation.calculationMode = .cubicPaced
        glowAnimation.beginTime = Double(randomBeginTime)
        self.glowLayer.add(glowAnimation, forKey: "emitterPosition")
        
        let glowEmitterCell = CAEmitterCell()
        glowEmitterCell.beginTime = CACurrentMediaTime()
        let glowAlphaBehavior = createEmitterBehavior(type: "valueOverLife")
        glowAlphaBehavior.setValue("color.alpha", forKey: "keyPath")
        glowAlphaBehavior.setValue([0.0, 0.32, 0.4, 0.2, 0.0], forKey: "values")
        glowEmitterCell.setValue([glowAlphaBehavior], forKey: "emitterBehaviors")
        glowEmitterCell.color = UIColor.white.cgColor
        glowEmitterCell.contents = UIImage(named: "Media Editor/ParticleGlow")?.cgImage
        glowEmitterCell.lifetime = 2.0
        glowEmitterCell.birthRate = 30
        glowEmitterCell.scale = 1.9
        glowEmitterCell.alphaSpeed = -0.1
        
        self.glowLayer.emitterCells = [glowEmitterCell]
        self.glowLayer.emitterMode = .points
        self.glowLayer.emitterSize = CGSize(width: 1.0, height: 1.0)
        self.glowLayer.emitterShape = .point
           
        self.strokeLayer.animateAlpha(from: 0.0, to: CGFloat(self.strokeLayer.opacity), duration: 0.4)
        
        self.outlineLayer.animateAlpha(from: 0.0, to: CGFloat(self.outlineLayer.opacity), duration: 0.4, delay: 0.0)
        self.glowLayer.animateAlpha(from: 0.0, to: CGFloat(self.glowLayer.opacity), duration: 0.4, delay: 0.0)
        
        let values = [1.0, 1.07, 1.0]
        let keyTimes = [0.0, 0.67, 1.0]
        self.imageLayer.animateKeyframes(values: values as [NSNumber], keyTimes: keyTimes as [NSNumber], duration: 0.4, keyPath: "transform.scale", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
    }
    
    override func layoutSubviews() {
        self.strokeLayer.frame = self.bounds.offsetBy(dx: 0.0, dy: 1.0)
        self.outlineLayer.frame = self.bounds
        self.imageLayer.frame = self.bounds
        self.glowLayer.frame = self.bounds
    }
}

private func getPathFromMaskImage(_ image: CIImage, size: CGSize, values: MediaEditorValues) -> BezierPath? {
    let edges = image.applyingFilter("CILineOverlay", parameters: ["inputEdgeIntensity": 0.1])
            
    guard let pixelBuffer = getEdgesBitmap(edges) else {
        return nil
    }
    let minSide = min(size.width, size.height)
    let scaledImageSize = image.extent.size.aspectFilled(CGSize(width: minSide, height: minSide))
    let positionOffset = CGPoint(
        x: (size.width - scaledImageSize.width) / 2.0,
        y: (size.height - scaledImageSize.height) / 2.0
    )
    
    var contour = findContours(pixelBuffer: pixelBuffer)
    contour = simplify(contour, tolerance: 1.4)
    let path = BezierPath(points: contour, smooth: false)
    
    let firstScale = min(size.width, size.height) / 256.0
    let secondScale = size.width / 1080.0
    
    var transform = CGAffineTransform.identity
    let position = values.cropOffset
    let rotation = values.cropRotation
    let scale = values.cropScale
    
    transform = transform.translatedBy(x: positionOffset.x + position.x * secondScale, y: positionOffset.y + position.y * secondScale)
    transform = transform.rotated(by: rotation)
    transform = transform.scaledBy(x: scale * firstScale, y: scale * firstScale)
    
    if !path.path.isEmpty {
        path.apply(transform, scale: scale)
        return path
    }
    return nil
}

private func findContours(pixelBuffer: CVPixelBuffer) -> [CGPoint] {
    struct Point: Hashable {
        let x: Int
        let y: Int
        
        var cgPoint: CGPoint {
            return CGPoint(x: x, y: y)
        }
    }
    
    var contours = [[Point]]()
    
    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
    
    let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    
    var visited: [Point: Bool] = [:]
    func markVisited(_ point: Point) {
        visited[point] = true
    }
    
    func getPixelIntensity(_ point: Point) -> UInt8 {
        let pixelOffset = point.y * bytesPerRow + point.x
        let pixelPtr = baseAddress?.advanced(by: pixelOffset)
        return pixelPtr?.load(as: UInt8.self) ?? 0
    }
    
    func isBlackPixel(_ point: Point) -> Bool {
        if point.x >= 0 && point.x < width && point.y >= 0 && point.y < height {
            let value = getPixelIntensity(point)
            return value < 220
        } else {
            return false
        }
    }
    
    func traceContour(startPoint: Point) -> [Point] {
        var contour = [startPoint]
        var currentPoint = startPoint
        var previousDirection = 7
        
        let dx = [1, 1, 0, -1, -1, -1, 0, 1]
        let dy = [0, 1, 1, 1, 0, -1, -1, -1]
        
        repeat {
            var found = false
            for i in 0 ..< 8 {
                let direction = (previousDirection + i) % 8
                let newX = currentPoint.x + dx[direction]
                let newY = currentPoint.y + dy[direction]
                let newPoint = Point(x: newX, y: newY)
                
                if isBlackPixel(newPoint) && !(visited[newPoint] == true) {
                    contour.append(newPoint)
                    previousDirection = (direction + 5) % 8
                    currentPoint = newPoint
                    found = true
                    markVisited(newPoint)
                    break
                }
            }
            if !found {
                break
            }
        } while currentPoint != startPoint
        
        return contour
    }
    
    for y in 0 ..< height {
        for x in 0 ..< width {
            let point = Point(x: x, y: y)
            if visited[point] == true {
                continue
            }
            if isBlackPixel(point) {
                let contour = traceContour(startPoint: point)
                if contour.count > 25 {
                    contours.append(contour)
                }
            }
        }
    }
    
    return (contours.sorted(by: { lhs, rhs in lhs.count > rhs.count }).first ?? []).map { $0.cgPoint }
}

private func getEdgesBitmap(_ ciImage: CIImage) -> CVPixelBuffer? {
    let context = CIContext(options: nil)
    guard let contourCgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
        return nil
    }
    let image = UIImage(cgImage: contourCgImage)
    
    let size = image.size.aspectFilled(CGSize(width: 256, height: 256))
    let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                 kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                     Int(size.width),
                                     Int(size.height),
                                     kCVPixelFormatType_OneComponent8,
                                     attrs,
                                     &pixelBuffer)
    guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
        return nil
    }
    
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    
    let pixelData = CVPixelBufferGetBaseAddress(buffer)
    let rgbColorSpace = CGColorSpaceCreateDeviceGray()
    guard let context = CGContext(data: pixelData,
                                  width: Int(size.width),
                                  height: Int(size.height),
                                  bitsPerComponent: 8,
                                  bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                  space: rgbColorSpace,
                                  bitmapInfo: 0) else {
                                    return nil
    }
    
    context.translateBy(x: 0, y: size.height)
    context.scaleBy(x: 1.0, y: -1.0)
    
    UIGraphicsPushContext(context)
    context.setFillColor(UIColor.white.cgColor)
    context.fill(CGRect(origin: .zero, size: size))
    image.draw(in: CGRect(origin: .zero, size: size))
    UIGraphicsPopContext()
    
    return buffer
}

private extension CGPath {
    func expand(width: CGFloat) -> CGPath {
        let expandedPath = self.copy(strokingWithWidth: width * 2.0, lineCap: .round, lineJoin: .round, miterLimit: 0.0)
        
        class UserInfo {
            let outputPath = CGMutablePath()
            var passedFirst = false
        }
        var userInfo = UserInfo()
        
        withUnsafeMutablePointer(to: &userInfo) { userInfoPointer in
            expandedPath.apply(info: userInfoPointer) { (userInfo, nextElementPointer) in
                let element = nextElementPointer.pointee
                let userInfoPointer = userInfo!.assumingMemoryBound(to: UserInfo.self)
                let userInfo = userInfoPointer.pointee
                
                if !userInfo.passedFirst {
                    if case .closeSubpath = element.type {
                        userInfo.passedFirst = true
                    }
                } else {
                    switch element.type {
                    case .moveToPoint:
                        userInfo.outputPath.move(to: element.points[0])
                    case .addLineToPoint:
                        userInfo.outputPath.addLine(to: element.points[0])
                    case .addQuadCurveToPoint:
                        userInfo.outputPath.addQuadCurve(to: element.points[1], control: element.points[0])
                    case .addCurveToPoint:
                        userInfo.outputPath.addCurve(to: element.points[2], control1: element.points[0], control2: element.points[1])
                    case .closeSubpath:
                        userInfo.outputPath.closeSubpath()
                    @unknown default:
                        userInfo.outputPath.closeSubpath()
                    }
                }
            }
        }
        return userInfo.outputPath
    }
}

private func simplify(_ points: [CGPoint], tolerance: CGFloat?) -> [CGPoint] {
    guard points.count > 1 else {
        return points
    }
    
    let sqTolerance = tolerance != nil ? (tolerance! * tolerance!) : 1.0
    var result = simplifyRadialDistance(points, tolerance: sqTolerance)
    result = simplifyDouglasPeucker(result, sqTolerance: sqTolerance)
    
    return result
}

private func simplifyRadialDistance(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
    guard points.count > 2 else {
        return points
    }
    
    var prevPoint = points.first!
    var newPoints = [prevPoint]
    var currentPoint: CGPoint!
    
    for i in 1..<points.count {
        currentPoint = points[i]
        if currentPoint.distanceFrom(prevPoint) > tolerance {
            newPoints.append(currentPoint)
            prevPoint = currentPoint
        }
    }
    
    if prevPoint.equalsTo(currentPoint) == false {
        newPoints.append(currentPoint)
    }
    
    return newPoints
}

private func simplifyDPStep(_ points: [CGPoint], first: Int, last: Int, sqTolerance: CGFloat, simplified: inout [CGPoint]) {
    guard last > first else {
        return
    }
    var maxSqDistance = sqTolerance
    var index = 0
    
    for currentIndex in first+1..<last {
        let sqDistance = points[currentIndex].distanceToSegment(points[first], points[last])
        if sqDistance > maxSqDistance {
            maxSqDistance = sqDistance
            index = currentIndex
        }
    }
    
    if maxSqDistance > sqTolerance {
        if (index - first) > 1 {
            simplifyDPStep(points, first: first, last: index, sqTolerance: sqTolerance, simplified: &simplified)
        }
        simplified.append(points[index])
        if (last - index) > 1 {
            simplifyDPStep(points, first: index, last: last, sqTolerance: sqTolerance, simplified: &simplified)
        }
    }
}

private func simplifyDouglasPeucker(_ points: [CGPoint], sqTolerance: CGFloat) -> [CGPoint] {
    guard points.count > 1 else {
        return []
    }
    
    let last = (points.count - 1)
    var simplied = [points.first!]
    simplifyDPStep(points, first: 0, last: last, sqTolerance: sqTolerance, simplified: &simplied)
    simplied.append(points.last!)
    
    return simplied
}

private extension CGPoint {
    func equalsTo(_ compare: CGPoint) -> Bool {
        return self.x == compare.self.x && self.y == compare.y
    }

    func distanceFrom(_ otherPoint: CGPoint) -> CGFloat {
        let dx = self.x - otherPoint.x
        let dy = self.y - otherPoint.y
        return (dx * dx) + (dy * dy)
    }
    
    func distanceToSegment(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        var x = p1.x
        var y = p1.y
        var dx = p2.x - x
        var dy = p2.y - y
        
        if dx != 0 || dy != 0 {
            let t = ((self.x - x) * dx + (self.y - y) * dy) / (dx * dx + dy * dy)
            if t > 1 {
                x = p2.x
                y = p2.y
            } else if t > 0 {
                x += dx * t
                y += dy * t
            }
        }
        
        dx = self.x - x
        dy = self.y - y
        
        return dx * dx + dy * dy
    }
}

fileprivate extension Array {
    subscript(circularIndex index: Int) -> Element {
        get {
            assert(self.count > 0)
            let index = (index + self.count) % self.count
            return self[index]
        }
        set {
            assert(self.count > 0)
            let index = (index + self.count) % self.count
            return self[index] = newValue
        }
    }
    func circularIndex(_ index: Int) -> Int {
        return (index + self.count) % self.count
    }
}

private class BezierPath {
    let path: UIBezierPath
    var length: CGFloat = 0.0
    
    init(points: [CGPoint], smooth: Bool) {
        self.path = UIBezierPath()
        
        if smooth {
            let K: CGFloat = 0.2
            var c1 = [Int: CGPoint]()
            var c2 = [Int: CGPoint]()
            let count = points.count - 1
            for index in 1 ..< count {
                let p = points[circularIndex: index]
                let vP1 = points[circularIndex: index + 1]
                let vP2 = points[index - 1]
                let vP = CGPoint(x: vP1.x - vP2.x, y: vP1.y - vP2.y)
                let v = CGPoint(x: vP.x * K, y: vP.y * K)
                c2[(index + points.count - 1) % points.count] = CGPoint(x: p.x - v.x, y: p.y - v.y) //(p - v)
                c1[(index + points.count) % points.count] = CGPoint(x: p.x + v.x, y: p.y + v.y) //(p + v)
            }
            self.path.move(to: points[0])
            for index in 0 ..< points.count - 1 {
                let c1 = c1[index] ?? points[points.circularIndex(index)]
                let c2 = c2[index] ?? points[points.circularIndex(index + 1)]
                self.path.addCurve(to: points[circularIndex: index + 1], controlPoint1: c1, controlPoint2: c2)
            }
            self.path.close()
        } else {
            self.path.move(to: points[0])
            for index in 1 ..< points.count - 1 {
                self.length += points[index].distanceFrom(points[index - 1])
                self.path.addLine(to: points[index])
            }
            self.path.close()
        }
    }
    
    func apply(_ transform: CGAffineTransform, scale: CGFloat) {
        self.path.apply(transform)
        self.length *= scale
    }
}
