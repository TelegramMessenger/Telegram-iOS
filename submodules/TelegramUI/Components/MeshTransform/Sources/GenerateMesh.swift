import Foundation
import UIKit

private func a(_ a1: CGFloat, _ a2: CGFloat) -> CGFloat
{
    return 1.0 - 3.0 * a2 + 3.0 * a1
}

private func b(_ a1: CGFloat, _ a2: CGFloat) -> CGFloat
{
    return 3.0 * a2 - 6.0 * a1
}

private func c(_ a1: CGFloat) -> CGFloat
{
    return 3.0 * a1
}

private func calcBezier(_ t: CGFloat, _ a1: CGFloat, _ a2: CGFloat) -> CGFloat
{
    return ((a(a1, a2)*t + b(a1, a2))*t + c(a1)) * t
}

private func calcSlope(_ t: CGFloat, _ a1: CGFloat, _ a2: CGFloat) -> CGFloat
{
    return 3.0 * a(a1, a2) * t * t + 2.0 * b(a1, a2) * t + c(a1)
}

private func getTForX(_ x: CGFloat, _ x1: CGFloat, _ x2: CGFloat) -> CGFloat {
    var t = x
    var i = 0
    while i < 4 {
        let currentSlope = calcSlope(t, x1, x2)
        if currentSlope == 0.0 {
            return t
        } else {
            let currentX = calcBezier(t, x1, x2) - x
            t -= currentX / currentSlope
        }
        
        i += 1
    }
    
    return t
}

private func bezierPoint(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ x: CGFloat) -> CGFloat
{
    var value = calcBezier(getTForX(x, x1, x2), y1, y2)
    if value >= 0.997 {
        value = 1.0
    }
    return value
}

/// Bezier control points for displacement easing curve
public struct DisplacementBezier {
    var x1: CGFloat
    var y1: CGFloat
    var x2: CGFloat
    var y2: CGFloat

    public init(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }
}

/// Computes signed distance from a point to the edge of a rounded rectangle.
/// Returns negative inside, zero on edge, positive outside.
/// All values in points.
public func roundedRectSDF(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> CGFloat {
    // Center the point (SDF formula assumes center at origin)
    let px = x - width / 2
    let py = y - height / 2

    // Half extents of the box
    let bx = width / 2
    let by = height / 2

    // Standard rounded box SDF (Inigo Quilez formula)
    let qx = abs(px) - bx + cornerRadius
    let qy = abs(py) - by + cornerRadius

    let outsideDist = hypot(max(qx, 0), max(qy, 0))
    let insideDist = min(max(qx, qy), 0)

    return outsideDist + insideDist - cornerRadius
}

/// Computes the gradient (outward normal) of the rounded rect SDF.
/// Returns normalized direction perpendicular to the nearest edge point.
public func roundedRectGradient(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> (nx: CGFloat, ny: CGFloat) {
    // Center the point
    let px = x - width / 2
    let py = y - height / 2

    // Half extents
    let bx = width / 2
    let by = height / 2

    // q values from SDF formula
    let qx = abs(px) - bx + cornerRadius
    let qy = abs(py) - by + cornerRadius

    var nx: CGFloat = 0
    var ny: CGFloat = 0

    if qx > 0 && qy > 0 {
        // Corner region - normal points radially from corner arc center
        let d = hypot(qx, qy)
        if d > 0 {
            nx = qx / d
            ny = qy / d
        }
    } else if qx > qy {
        // Nearest point is on vertical edge (left or right)
        nx = 1
        ny = 0
    } else {
        // Nearest point is on horizontal edge (top or bottom)
        nx = 0
        ny = 1
    }

    // Restore sign based on which side of center we're on
    if px < 0 { nx = -nx }
    if py < 0 { ny = -ny }

    return (nx, ny)
}

/// Generates a displacement map image as a signed distance field from rounded rect edges.
/// - edgeDistance: The distance (in points) over which displacement is applied
/// - R channel: X displacement (127 = neutral, 0 = max left, 255 = max right)
/// - G channel: Y displacement (127 = neutral, 0 = max up, 255 = max down)
/// - B channel: Unused (always 0)
/// Displacement is maximum at the edge and fades linearly to zero at edgeDistance.
/// Actual displacement magnitude is applied when sampling the map.
public func generateDisplacementMap(size: CGSize, cornerRadius: CGFloat, edgeDistance: CGFloat, scale: CGFloat) -> CGImage? {
    let width = Int(size.width * scale)
    let height = Int(size.height * scale)

    // Clamp corner radius
    let maxCornerRadius = min(size.width, size.height) / 2.0
    let clampedRadius = min(cornerRadius, maxCornerRadius)

    // Create bitmap context
    var pixelData = [UInt8](repeating: 0, count: width * height * 4)

    for py in 0 ..< height {
        for px in 0 ..< width {
            // Convert pixel to point coordinates
            let x = CGFloat(px) / scale
            let y = CGFloat(py) / scale

            // Get signed distance (negative inside, positive outside)
            let sdf = roundedRectSDF(x: x, y: y, width: size.width, height: size.height, cornerRadius: clampedRadius)

            // Get gradient (outward normal direction)
            let (nx, ny) = roundedRectGradient(x: x, y: y, width: size.width, height: size.height, cornerRadius: clampedRadius)

            // Inward normal (content moves away from edge, toward center)
            let inwardX = -nx
            let inwardY = -ny

            // Distance from edge (positive inside the shape)
            let distFromEdge = -sdf

            // Weight: 1 at edge, 0 at edgeDistance (linear falloff)
            let weight = max(0, min(1, 1.0 - distFromEdge / edgeDistance))

            // Displacement modulated by distance from edge
            let displacementX = inwardX * weight
            let displacementY = inwardY * weight

            // Encode in R/G: 127 = neutral, map -1..1 to 0..254
            let r = UInt8(max(0, min(255, Int(127 + displacementX * 127))))
            let g = UInt8(max(0, min(255, Int(127 + displacementY * 127))))

            let idx = (py * width + px) * 4
            pixelData[idx + 0] = r    // X displacement
            pixelData[idx + 1] = g    // Y displacement
            pixelData[idx + 2] = 0    // Unused
            pixelData[idx + 3] = 255  // A
        }
    }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: &pixelData,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return nil
    }

    return context.makeImage()
}

/// Samples displacement from a displacement map with bilinear interpolation and bezier easing
/// - Parameters:
///   - x, y: Coordinates in the displacement map's pixel space
///   - pixels: Pointer to displacement map pixel data
///   - width, height: Displacement map dimensions
///   - bytesPerRow, bytesPerPixel: Displacement map layout
///   - bezier: Bezier control points for easing curve
/// - Returns: Displacement (dx, dy) in range -1..1 with bezier easing applied
public func sampleDisplacement(
    x: CGFloat,
    y: CGFloat,
    pixels: UnsafePointer<UInt8>,
    width: Int,
    height: Int,
    bytesPerRow: Int,
    bytesPerPixel: Int,
    bezier: DisplacementBezier
) -> (dx: CGFloat, dy: CGFloat) {
    let clampedX = max(0, min(CGFloat(width - 1), x))
    let clampedY = max(0, min(CGFloat(height - 1), y))

    let x0 = Int(clampedX)
    let y0 = Int(clampedY)
    let x1 = min(x0 + 1, width - 1)
    let y1 = min(y0 + 1, height - 1)

    let fx = clampedX - CGFloat(x0)
    let fy = clampedY - CGFloat(y0)

    func sample(_ sx: Int, _ sy: Int) -> (r: CGFloat, g: CGFloat) {
        let offset = sy * bytesPerRow + sx * bytesPerPixel
        return (CGFloat(pixels[offset + 0]), CGFloat(pixels[offset + 1]))
    }

    let c00 = sample(x0, y0)
    let c10 = sample(x1, y0)
    let c01 = sample(x0, y1)
    let c11 = sample(x1, y1)

    let r = (c00.r * (1 - fx) + c10.r * fx) * (1 - fy) + (c01.r * (1 - fx) + c11.r * fx) * fy
    let g = (c00.g * (1 - fx) + c10.g * fx) * (1 - fy) + (c01.g * (1 - fx) + c11.g * fx) * fy

    // Decode: 127 = neutral, map 0..254 to -1..1
    var dx = (r - 127.0) / 127.0
    var dy = (g - 127.0) / 127.0

    // Apply bezier easing to vector magnitude, preserving direction
    let mag = hypot(dx, dy)
    if mag > 0 {
        let newMag = bezierPoint(bezier.x1, bezier.y1, bezier.x2, bezier.y2, mag)
        let scale = newMag / mag
        dx *= scale
        dy *= scale
    }

    return (dx, dy)
}

/// Generates a glass mesh with corner-aware topology.
/// - 4 radial corner wedges sampled in polar space
/// - 4 edge strips aligned with the rectangle sides
/// - 1 center patch
/// Corner/edge seams share the same coordinates (but do not reuse vertices) so
/// the neighbouring faces fit perfectly without T-junctions.
public func generateGlassMeshFromDisplacementMap(
    size: CGSize,
    cornerRadius: CGFloat,
    displacementMap: CGImage,
    displacementMagnitudeU: CGFloat,
    displacementMagnitudeV: CGFloat,
    cornerResolution: Int,
    outerEdgeDistance: CGFloat,
    bezier: DisplacementBezier,
    generateWireframe: Bool = false
) -> (mesh: MeshTransform, wireframe: CGPath?) {
    guard let dispDataProvider = displacementMap.dataProvider,
          let dispData = dispDataProvider.data,
          let dispPixels = CFDataGetBytePtr(dispData) else {
        return (mesh: MeshTransform(), wireframe: nil)
    }

    let dispWidth = displacementMap.width
    let dispHeight = displacementMap.height
    let dispBytesPerRow = displacementMap.bytesPerRow
    let dispBytesPerPixel = displacementMap.bitsPerPixel / 8

    let clampedRadius = min(cornerRadius, min(size.width, size.height) / 2)

    let transform = MeshTransform()
    var wireframe: CGMutablePath?
    if generateWireframe {
        wireframe = CGMutablePath()
    }

    // Debug flags
    let debugNoDisplacement = false
    let debugLogCorner = false

    // Inset the mesh slightly (1 pixel) to clear the clip mask
    let insetPoints = -1.0
    let usableWidth = max(1.0, size.width - insetPoints * 2)
    let usableHeight = max(1.0, size.height - insetPoints * 2)
    let insetUOffset = insetPoints / size.width
    let insetVOffset = insetPoints / size.height
    let usableUNorm = usableWidth / size.width
    let usableVNorm = usableHeight / size.height

    // Helper to sample displacement and create vertex
    func makeVertex(u: CGFloat, v: CGFloat, depth: CGFloat = 0) -> (vertex: MeshTransform.Vertex, point: CGPoint) {
        let mappedU = insetUOffset + u * usableUNorm
        let mappedV = insetVOffset + v * usableVNorm
        let fromX: CGFloat
        let fromY: CGFloat

        if debugNoDisplacement {
            fromX = mappedU
            fromY = mappedV
        } else {
            let (dispX, dispY) = sampleDisplacement(
                x: mappedU * CGFloat(dispWidth - 1),
                y: mappedV * CGFloat(dispHeight - 1),
                pixels: dispPixels,
                width: dispWidth,
                height: dispHeight,
                bytesPerRow: dispBytesPerRow,
                bytesPerPixel: dispBytesPerPixel,
                bezier: bezier
            )

            // Slight boost near the edge to emphasize the outer strip (rounded-corner aware)
            let worldX = insetPoints + u * usableWidth
            let worldY = insetPoints + v * usableHeight
            let sdf = roundedRectSDF(x: worldX, y: worldY, width: size.width, height: size.height, cornerRadius: clampedRadius)
            let distToEdge = max(0.0, -sdf) // distance inside the rounded rect to the edge
            let edgeBand = max(0.0, outerEdgeDistance)
            let edgeBoostGain: CGFloat = 0.5 // up to +50% displacement at the edge, fades inside
            let edgeBoost: CGFloat
            if edgeBand > 0 {
                let t = max(0.0, min(1.0, (edgeBand - distToEdge) / edgeBand))
                let eased = t * t * (3 - 2 * t) // smoothstep
                edgeBoost = 1.0 + eased * edgeBoostGain
            } else {
                edgeBoost = 1.0
            }

            fromX = max(0.0, min(1.0, mappedU + dispX * displacementMagnitudeU * edgeBoost))
            fromY = max(0.0, min(1.0, mappedV + dispY * displacementMagnitudeV * edgeBoost))
        }

        let vertex = MeshTransform.Vertex(from: CGPoint(x: fromX, y: fromY), to: MeshTransform.Point3D(x: mappedU, y: mappedV, z: depth))
        return (vertex, CGPoint(x: mappedU * size.width, y: mappedV * size.height))
    }

    var vertexIndex = 0
    var vertexPoints: [CGPoint] = []

    func addVertex(u: CGFloat, v: CGFloat, depth: CGFloat = 0) -> Int {
        let (vertex, point) = makeVertex(u: u, v: v, depth: depth)
        transform.add(vertex)
        vertexPoints.append(point)
        let idx = vertexIndex
        vertexIndex += 1
        return idx
    }

    func addVertex(point: CGPoint, depth: CGFloat = 0) -> Int {
        let u = point.x / size.width
        let v = point.y / size.height
        return addVertex(u: u, v: v, depth: depth)
    }

    func addQuadFace(_ i0: Int, _ i1: Int, _ i2: Int, _ i3: Int) {
        let p0 = vertexPoints[i0]
        let p1 = vertexPoints[i1]
        let p2 = vertexPoints[i2]
        let p3 = vertexPoints[i3]

        let sdf0 = roundedRectSDF(x: p0.x, y: p0.y, width: size.width, height: size.height, cornerRadius: clampedRadius)
        let sdf1 = roundedRectSDF(x: p1.x, y: p1.y, width: size.width, height: size.height, cornerRadius: clampedRadius)
        let sdf2 = roundedRectSDF(x: p2.x, y: p2.y, width: size.width, height: size.height, cornerRadius: clampedRadius)
        let sdf3 = roundedRectSDF(x: p3.x, y: p3.y, width: size.width, height: size.height, cornerRadius: clampedRadius)

        if sdf0 > 0 && sdf1 > 0 && sdf2 > 0 && sdf3 > 0 {
            return
        }

        transform.add(MeshTransform.Face(indices: (UInt32(i0), UInt32(i1), UInt32(i2), UInt32(i3)), w: (0.0, 0.0, 0.0, 0.0)))

        if let wireframe {
            wireframe.move(to: p0)
            wireframe.addLine(to: p1)
            wireframe.addLine(to: p2)
            wireframe.addLine(to: p3)
            wireframe.closeSubpath()
        }
    }

    // Utility to build a grid of vertices from 2D points and emit quads
    func buildGrid(points: [[CGPoint]]) {
        guard !points.isEmpty else { return }

        var indexGrid: [[Int]] = []
        for row in points {
            var rowIndices: [Int] = []
            for point in row {
                rowIndices.append(addVertex(point: point))
            }
            indexGrid.append(rowIndices)
        }

        let numRows = indexGrid.count - 1
        let numCols = indexGrid.first!.count - 1
        for row in 0..<numRows {
            for col in 0..<numCols {
                addQuadFace(
                    indexGrid[row][col],
                    indexGrid[row][col + 1],
                    indexGrid[row + 1][col + 1],
                    indexGrid[row + 1][col]
                )
            }
        }
    }

    let width = size.width
    let height = size.height

    // Even angular sampling (forced even for collapse), radial sampling mostly even with a thin outer band
    // (outerEdgeDistance) near the silhouette for edge-specific refraction.
    let angularStepsBase = max(3, cornerResolution)
    let angularSteps = angularStepsBase % 2 == 0 ? angularStepsBase : angularStepsBase + 1
    let radialSteps = max(2, cornerResolution)

    func depthFactorsWithOuterBand(count: Int, band: CGFloat, maxRadius: CGFloat) -> [CGFloat] {
        guard count > 0, maxRadius > 0 else { return [0, 1] }
        let bandNorm = max(0, min(1, band / maxRadius))

        // Evenly distribute inner rings up to (1 - bandNorm), then insert the outer strip edge and 1.0.
        let innerSegments = max(1, count - 1)
        let innerMax = max(0, 1 - bandNorm)

        var factors: [CGFloat] = (0...innerSegments).map { i in
            innerMax * CGFloat(i) / CGFloat(innerSegments)
        }

        func appendUnique(_ value: CGFloat) {
            if let last = factors.last, abs(last - value) < 1e-4 { return }
            factors.append(value)
        }

        appendUnique(innerMax)
        appendUnique(1.0)

        return factors
    }

    let depthFactors = depthFactorsWithOuterBand(count: radialSteps, band: outerEdgeDistance, maxRadius: clampedRadius) // 0...1
    let angularFactors = (0...angularSteps).map { CGFloat($0) / CGFloat(angularSteps) } // 0...1

    // Edge segmentation along the long axes; even spacing
    let horizontalSegments = max(2, cornerResolution / 2 + 1)
    let verticalSegments = max(2, cornerResolution / 2 + 1)

    func linearPositions(count: Int, start: CGFloat, end: CGFloat) -> [CGFloat] {
        return (0...count).map { i in
            let t = CGFloat(i) / CGFloat(count)
            return start + (end - start) * t
        }
    }

    // Shared tangential coordinates for strips/center
    let topXPositions: [CGFloat] = linearPositions(
        count: horizontalSegments,
        start: clampedRadius,
        end: width - clampedRadius
    )
    let sideYPositions: [CGFloat] = linearPositions(
        count: verticalSegments,
        start: clampedRadius,
        end: height - clampedRadius
    )

    // Shared depth coordinates (outer -> inner) so seams line up without T-junctions
    let outerToInner = depthFactors.reversed()
    let topYPositions: [CGFloat] = outerToInner.map { clampedRadius * (1 - $0) }             // 0 ... radius
    let bottomYPositions: [CGFloat] = depthFactors.map { height - clampedRadius + clampedRadius * $0 } // (h-r) ... h
    let leftXPositions: [CGFloat] = outerToInner.map { clampedRadius * (1 - $0) }            // 0 ... radius
    let rightXPositions: [CGFloat] = depthFactors.map { width - clampedRadius + clampedRadius * $0 }   // (w-r) ... w

    // Corner wedges in polar space with an explicit center fan to avoid zero-area quads
    func buildCorner(center: CGPoint, startAngle: CGFloat, endAngle: CGFloat) {
        let ringRadials = outerToInner.filter { $0 > 0 }
        guard !ringRadials.isEmpty else { return }

        func formatVertex(_ idx: Int) -> String {
            let p = vertexPoints[idx]
            return "\(idx)=\(String(format: "(%.2f, %.2f)", p.x, p.y))"
        }

        // Generate ring vertices from outer arc toward the center point
        var ringIndices: [[Int]] = []
        for radial in ringRadials {
            let r = clampedRadius * radial
            var row: [Int] = []
            for t in angularFactors {
                let angle = startAngle + (endAngle - startAngle) * t
                let x = center.x + r * cos(angle)
                let y = center.y + r * sin(angle)
                row.append(addVertex(point: CGPoint(x: x, y: y)))
            }
            ringIndices.append(row)
        }

        // Quad rings between concentric samples
        for r in 0..<(ringIndices.count - 1) {
            let outerRing = ringIndices[r]
            let innerRing = ringIndices[r + 1]
            for i in 0..<(outerRing.count - 1) {
                addQuadFace(
                    outerRing[i],
                    outerRing[i + 1],
                    innerRing[i + 1],
                    innerRing[i]
                )
            }
        }

        // Final collapse: merge two wedge slices into one quad anchored at the center.
        // Each quad spans a double-width wedge: center -> v0 -> v1 -> v2 (contiguous along the arc).
        if let innermostRing = ringIndices.last {
            let ringSegments = innermostRing.count - 1 // last point is the arc end (not wrapped)
            guard ringSegments >= 2 else { return }

            if debugLogCorner {
                let formatted = innermostRing.map { formatVertex($0) }.joined(separator: ", ")
                print("Corner collapse ringSegments=\(ringSegments) stride=2 angularSteps=\(angularSteps)")
                print("Innermost ring vertices: \(formatted)")
            }

            let centerAnchor = addVertex(point: center, depth: -0.02)
            let stride = 2

            // Each quad covers two arc segments: (vi, vi+1) and (vi+1, vi+2)
            var i = 0
            while i + 2 <= ringSegments {
                let v0 = innermostRing[i]
                let v1 = innermostRing[i + 1]
                let v2 = innermostRing[i + 2]

                if debugLogCorner {
                    print("Quad indices: [\(centerAnchor), \(v0), \(v1), \(v2)]")
                }

                addQuadFace(
                    centerAnchor,
                    v0,
                    v1,
                    v2
                )

                i += stride
            }

            // Safety: if an odd segment remains, cap it with a final quad
            if i < ringSegments {
                let v0 = innermostRing[ringSegments - 1]
                let v1 = innermostRing[ringSegments]
                let v2 = innermostRing[ringSegments] // duplicate to keep quad valid
                if debugLogCorner {
                    print("Quad indices (odd tail): [\(centerAnchor), \(v0), \(v1), \(v2)]")
                }
                addQuadFace(centerAnchor, v0, v1, v2)
            }
        }
    }

    // Edge strips
    func buildStrip(xPositions: [CGFloat], yPositions: [CGFloat]) {
        var points: [[CGPoint]] = []
        for y in yPositions {
            let row = xPositions.map { CGPoint(x: $0, y: y) }
            points.append(row)
        }
        buildGrid(points: points)
    }

    // Top / bottom strips
    buildStrip(xPositions: topXPositions, yPositions: topYPositions)
    buildStrip(xPositions: topXPositions, yPositions: bottomYPositions)

    // Left / right strips
    buildStrip(xPositions: leftXPositions, yPositions: sideYPositions)
    buildStrip(xPositions: rightXPositions, yPositions: sideYPositions)

    // Center patch uses the same tangential sampling to meet edges cleanly
    buildStrip(xPositions: topXPositions, yPositions: sideYPositions)

    // Corners (angles chosen to keep columns increasing along +x)
    buildCorner(
        center: CGPoint(x: clampedRadius, y: clampedRadius),
        startAngle: .pi,
        endAngle: 1.5 * .pi
    )
    buildCorner(
        center: CGPoint(x: width - clampedRadius, y: clampedRadius),
        startAngle: 1.5 * .pi,
        endAngle: 2 * .pi
    )
    buildCorner(
        center: CGPoint(x: width - clampedRadius, y: height - clampedRadius),
        startAngle: .pi / 2,
        endAngle: 0
    )
    buildCorner(
        center: CGPoint(x: clampedRadius, y: height - clampedRadius),
        startAngle: .pi,
        endAngle: .pi / 2
    )

    return (mesh: transform, wireframe: wireframe)
}
