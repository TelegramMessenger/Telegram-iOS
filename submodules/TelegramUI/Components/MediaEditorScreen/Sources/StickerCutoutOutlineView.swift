import Foundation
import UIKit
import Display
import CoreImage
import MediaEditor

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
        self.outlineLayer.removeFromSuperlayer()
        self.glowLayer.removeFromSuperlayer()
        
        self.outlineLayer = CAEmitterLayer()
        self.outlineLayer.opacity = 0.75
        
        self.glowLayer = CAEmitterLayer()
        
        self.layer.addSublayer(self.outlineLayer)
        self.layer.addSublayer(self.glowLayer)
        
        let randomBeginTime = (previousBeginTime + 4) % 6
        previousBeginTime = randomBeginTime
        
        let duration = min(8.0, max(3.0, path.length / 135.0))
        
        let outlineAnimation = CAKeyframeAnimation(keyPath: "emitterPosition")
        outlineAnimation.path = path.path.cgPath
        outlineAnimation.duration = duration
        outlineAnimation.repeatCount = .infinity
        outlineAnimation.calculationMode = .paced
        outlineAnimation.fillMode = .forwards
        outlineAnimation.beginTime = Double(randomBeginTime)
        self.outlineLayer.add(outlineAnimation, forKey: "emitterPosition")
        
        let lineEmitterCell = CAEmitterCell()
        lineEmitterCell.beginTime = CACurrentMediaTime()
        let lineAlphaBehavior = CAEmitterCell.createEmitterBehavior(type: "valueOverLife")
        lineAlphaBehavior.setValue("color.alpha", forKey: "keyPath")
        lineAlphaBehavior.setValue([0.0, 0.5, 0.8, 0.5, 0.0], forKey: "values")
        lineEmitterCell.setValue([lineAlphaBehavior], forKey: "emitterBehaviors")
        lineEmitterCell.color = UIColor.white.cgColor
        lineEmitterCell.contents = UIImage(named: "Media Editor/ParticleDot")?.cgImage
        lineEmitterCell.lifetime = 2.2
        lineEmitterCell.birthRate = 1700
        lineEmitterCell.scale = 0.185
        lineEmitterCell.alphaSpeed = -0.4
        
        self.outlineLayer.emitterCells = [lineEmitterCell]
        self.outlineLayer.emitterMode = .outline
        self.outlineLayer.emitterSize = CGSize(width: 2.0, height: 2.0)
        self.outlineLayer.emitterShape = .line
        
        let glowAnimation = CAKeyframeAnimation(keyPath: "emitterPosition")
        glowAnimation.path = path.path.cgPath
        glowAnimation.duration = duration
        glowAnimation.repeatCount = .infinity
        glowAnimation.calculationMode = .cubicPaced
        glowAnimation.beginTime = Double(randomBeginTime)
        self.glowLayer.add(glowAnimation, forKey: "emitterPosition")
        
        let glowEmitterCell = CAEmitterCell()
        glowEmitterCell.beginTime = CACurrentMediaTime()
        let glowAlphaBehavior = CAEmitterCell.createEmitterBehavior(type: "valueOverLife")
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
        
        
        self.animateBump(path: path)
    }
    
    private func animateBump(path: BezierPath) {
        let boundingBox = path.path.cgPath.boundingBox
        let pathCenter = CGPoint(x: boundingBox.midX, y: boundingBox.midY)
                
        let layerPathCenter = self.imageLayer.convert(pathCenter, from: self.imageLayer.superlayer)
        self.imageLayer.anchorPoint = CGPoint(x: layerPathCenter.x / layer.bounds.width, y: layerPathCenter.y / layer.bounds.height)
        self.imageLayer.position = layerPathCenter
        
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
    let extendedImage = image.applyingFilter("CIMorphologyMaximum", parameters: ["inputRadius": 3.0])
    guard let pixelBuffer = getEdgesBitmap(extendedImage) else {
        return nil
    }
    let minSide = min(size.width, size.height)
    let scaledImageSize = image.extent.size.aspectFilled(CGSize(width: minSide, height: minSide))
    let contourImageSize = image.extent.size.aspectFilled(CGSize(width: 256.0, height: 256.0))
    
    var contour = findEdgePoints(in: pixelBuffer)
    guard contour.count > 1 else {
        return nil
    }
    
    contour = simplify(contour, tolerance: 1.0)
    let path = BezierPath(points: contour, smooth: false)
    
    let contoursScale = min(size.width, size.height) / 256.0
    let valuesScale = size.width / 1080.0
    
    let position = values.cropOffset
    let rotation = values.cropRotation
    let scale = values.cropScale
    
    let positionOffset = CGPoint(
        x: (size.width - scaledImageSize.width * scale) / 2.0,
        y: (size.height - scaledImageSize.height * scale) / 2.0
    )
    
    var transform = CGAffineTransform.identity
    transform = transform.translatedBy(x: contourImageSize.width / 2.0, y: contourImageSize.height / 2.0)
    transform = transform.rotated(by: rotation)
    transform = transform.translatedBy(x: -contourImageSize.width / 2.0, y: -contourImageSize.height / 2.0)
    path.apply(transform, scale: 1.0)
    
    transform = CGAffineTransform.identity
    transform = transform.translatedBy(x: positionOffset.x + position.x * valuesScale, y: positionOffset.y + position.y * valuesScale)
    transform = transform.scaledBy(x: scale * contoursScale, y: scale * contoursScale)
    
    if !path.path.isEmpty {
        path.apply(transform, scale: scale)
        return path
    }
    return nil
}

func findEdgePoints(in pixelBuffer: CVPixelBuffer) -> [CGPoint] {
    struct Point: Hashable {
        let x: Int
        let y: Int
        
        var cgPoint: CGPoint {
            return CGPoint(x: x, y: y)
        }
    }
    
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    var edgePoints: Set<Point> = []
    var edgePath: [Point] = []
    
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    
    func isPixelWhiteAt(x: Int, y: Int) -> Bool {
        let pixelOffset = y * bytesPerRow + x
        let pixelPtr = baseAddress?.advanced(by: pixelOffset)
        let pixel = pixelPtr?.load(as: UInt8.self) ?? 0
        return pixel >= 235
    }
    
    var startPoint: Point? = nil
    var visited = Set<Point>()
    var componentSize = 0

    func floodFill(from point: Point) -> Int {
        var stack = [point]
        var size = 0

        while let current = stack.popLast() {
            let x = Int(current.x)
            let y = Int(current.y)

            if x < 0 || x >= width || y < 0 || y >= height || visited.contains(current) || !isPixelWhiteAt(x: x, y: y) {
                continue
            }

            visited.insert(current)
            size += 1
            stack.append(contentsOf: [Point(x: x+1, y: y), Point(x: x-1, y: y), Point(x: x, y: y+1), Point(x: x, y: y-1)])
        }
        
        return size
    }

    for y in 0..<height {
        for x in 0..<width {
            let point = Point(x: x, y: y)
            if isPixelWhiteAt(x: x, y: y) && !visited.contains(point) {
                let size = floodFill(from: point)
                if size > componentSize {
                    componentSize = size
                    startPoint = point
                }
            }
        }
    }
    
    let directions = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]
    var lastDirectionIndex = 0
    
    guard let startingPoint = startPoint, componentSize > 60 else { return [] }
    
    edgePoints.insert(startingPoint)
    edgePath.append(startingPoint)
    var currentPoint = startingPoint
    
    let tolerance: Int = 1
    func isCloseEnough(_ point: Point, to startPoint: Point) -> Bool {
        return abs(point.x - startPoint.x) <= tolerance && abs(point.y - startPoint.y) <= tolerance
    }
    
    repeat {
        var foundNextPoint = false
        for i in 0..<directions.count {
            let directionIndex = (lastDirectionIndex + i) % directions.count
            let dir = directions[directionIndex]
            let nextX = Int(currentPoint.x) + dir.0
            let nextY = Int(currentPoint.y) + dir.1
            
            if nextX >= 0, nextX < width, nextY >= 0, nextY < height, isPixelWhiteAt(x: nextX, y: nextY) {
                let nextPoint = Point(x: nextX, y: nextY)
                if !edgePoints.contains(nextPoint) {
                    edgePoints.insert(nextPoint)
                    edgePath.append(nextPoint)
                    currentPoint = nextPoint
                    lastDirectionIndex = (directionIndex + 6) % directions.count
                    foundNextPoint = true
                    break
                }
            }
        }
        
        if !foundNextPoint || (edgePath.count > 3 && isCloseEnough(currentPoint, to: startingPoint)) {
            break
        }
    } while true
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
    
    return Array(edgePath.map { $0.cgPoint })
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
        return sqrt((dx * dx) + (dy * dy))
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
            if points.count < 3 {
                self.path.move(to: points.first ?? CGPoint.zero)
                self.path.addLine(to: points[1])
                self.length = points[1].distanceFrom(points[0])
                return
            } else {
                self.path.move(to: points.first!)
                
                let n = points.count - 1
                let tension = 0.5
                
                for i in 0 ..< n {
                    let currentPoint = points[i]
                    var nextIndex = (i + 1) % points.count
                    var prevIndex = i == 0 ? points.count - 1 : i - 1
                    var nextNextIndex = (nextIndex + 1) % points.count
                    let prevPoint = points[prevIndex]
                    let nextPoint = points[nextIndex]
                    let nextNextPoint = points[nextNextIndex]
                    
                    let d1 = sqrt(pow(currentPoint.x - prevPoint.x, 2) + pow(currentPoint.y - prevPoint.y, 2))
                    let d2 = sqrt(pow(nextPoint.x - currentPoint.x, 2) + pow(nextPoint.y - currentPoint.y, 2))
                    let d3 = sqrt(pow(nextNextPoint.x - nextPoint.x, 2) + pow(nextNextPoint.y - nextPoint.y, 2))
                    
                    var controlPoint1: CGPoint
                    if d1 < 0.0001 {
                        controlPoint1 = currentPoint
                    } else {
                        controlPoint1 = CGPoint(x: currentPoint.x + (tension * d2 / (d2 + d3)) * (nextPoint.x - prevPoint.x),
                                                y: currentPoint.y + (tension * d2 / (d2 + d3)) * (nextPoint.y - prevPoint.y))
                    }
                    
                    prevIndex = i
                    nextIndex = (i + 1) % points.count
                    nextNextIndex = (nextIndex + 1) % points.count
                    
                    let controlPoint2: CGPoint
                    if d3 < 0.0001 {
                        controlPoint2 = nextPoint
                    } else {
                        controlPoint2 = CGPoint(x: nextPoint.x - (tension * d2 / (d1 + d2)) * (nextNextPoint.x - currentPoint.x),
                                                y: nextPoint.y - (tension * d2 / (d1 + d2)) * (nextNextPoint.y - currentPoint.y))
                    }
                    
                    self.path.addCurve(to: nextPoint, controlPoint1: controlPoint1, controlPoint2: controlPoint2)
                    self.length += nextPoint.distanceFrom(currentPoint)
                }
                
                self.path.close()
            }
        } else if smooth {
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
