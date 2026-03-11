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

private struct GlassMeshCacheKey: Hashable {
    var cornerRadius: CGFloat
    var edgeDistance: CGFloat
    var cornerResolution: Int
    var outerEdgeDistance: CGFloat
    var bezierX1: CGFloat
    var bezierY1: CGFloat
    var bezierX2: CGFloat
    var bezierY2: CGFloat

    init(cornerRadius: CGFloat, edgeDistance: CGFloat, cornerResolution: Int, outerEdgeDistance: CGFloat, bezier: DisplacementBezier) {
        self.cornerRadius = cornerRadius
        self.edgeDistance = edgeDistance
        self.cornerResolution = cornerResolution
        self.outerEdgeDistance = outerEdgeDistance
        self.bezierX1 = bezier.x1
        self.bezierY1 = bezier.y1
        self.bezierX2 = bezier.x2
        self.bezierY2 = bezier.y2
    }
}

private struct GlassMeshTemplate {
    struct VertexTemplate {
        /// worldX = baseX + sizeScaleX * width
        var baseX: CGFloat
        var sizeScaleX: CGFloat
        /// worldY = baseY + sizeScaleY * height
        var baseY: CGFloat
        var sizeScaleY: CGFloat
        /// Unitless displacement (direction * weight * bezier * edgeBoost), range roughly -1...1
        var dispX: CGFloat
        var dispY: CGFloat
        var depth: CGFloat
    }

    var vertices: ContiguousArray<VertexTemplate>
    var faces: ContiguousArray<MeshTransform.Face>
}

private var glassMeshTemplateCache: [GlassMeshCacheKey: GlassMeshTemplate] = [:]

private func instantiateGlassMesh(
    from template: GlassMeshTemplate,
    size: CGSize,
    displacementMagnitudeU: CGFloat,
    displacementMagnitudeV: CGFloat
) -> MeshTransform {
    let W = size.width
    let H = size.height
    let insetPoints: CGFloat = -1.0
    let insetUOffset = insetPoints / W
    let insetVOffset = insetPoints / H
    let usableUNorm = (W - insetPoints * 2) / W
    let usableVNorm = (H - insetPoints * 2) / H

    let transform = MeshTransform()
    for v in template.vertices {
        let worldX = v.baseX + v.sizeScaleX * W
        let worldY = v.baseY + v.sizeScaleY * H
        let u = worldX / W
        let vCoord = worldY / H
        let mappedU = insetUOffset + u * usableUNorm
        let mappedV = insetVOffset + vCoord * usableVNorm
        let fromX = max(0.0, min(1.0, mappedU + v.dispX * displacementMagnitudeU))
        let fromY = max(0.0, min(1.0, mappedV + v.dispY * displacementMagnitudeV))
        transform.add(MeshTransform.Vertex(
            from: CGPoint(x: fromX, y: fromY),
            to: MeshTransform.Point3D(x: mappedU, y: mappedV, z: v.depth)
        ))
    }
    for face in template.faces {
        transform.add(face)
    }
    return transform
}

private func generateGlassMeshTemplate(
    cornerRadius: CGFloat,
    edgeDistance: CGFloat,
    cornerResolution: Int,
    outerEdgeDistance: CGFloat,
    bezier: DisplacementBezier
) -> GlassMeshTemplate {
    let clampedRadius = cornerRadius

    // Reference size for displacement computation (must be >= 2R per axis)
    let refW = max(4 * clampedRadius, 100)
    let refH = max(4 * clampedRadius, 100)

    var vertices = ContiguousArray<GlassMeshTemplate.VertexTemplate>()
    var faces = ContiguousArray<MeshTransform.Face>()
    var vertexIndex: Int = 0

    // Compute unitless displacement (direction * weight * bezier * edgeBoost) at reference size
    func templateDisplacement(worldX: CGFloat, worldY: CGFloat) -> (CGFloat, CGFloat) {
        let (rawDispX, rawDispY, sdf) = computeDisplacement(
            x: worldX, y: worldY,
            width: refW, height: refH,
            cornerRadius: clampedRadius,
            edgeDistance: edgeDistance,
            bezier: bezier
        )
        let distToEdge = max(0.0, -sdf)
        let edgeBand = max(0.0, outerEdgeDistance)
        let edgeBoost: CGFloat
        if edgeBand > 0 {
            let t = max(0.0, min(1.0, (edgeBand - distToEdge) / edgeBand))
            edgeBoost = 1.0 + t * t * (3 - 2 * t) * 0.5
        } else {
            edgeBoost = 1.0
        }
        return (rawDispX * edgeBoost, rawDispY * edgeBoost)
    }

    func addVertex(baseX: CGFloat, scaleX: CGFloat, baseY: CGFloat, scaleY: CGFloat, depth: CGFloat = 0) -> Int {
        let worldX = baseX + scaleX * refW
        let worldY = baseY + scaleY * refH
        let (dispX, dispY) = templateDisplacement(worldX: worldX, worldY: worldY)
        vertices.append(GlassMeshTemplate.VertexTemplate(
            baseX: baseX, sizeScaleX: scaleX,
            baseY: baseY, sizeScaleY: scaleY,
            dispX: dispX, dispY: dispY, depth: depth
        ))
        let idx = vertexIndex
        vertexIndex += 1
        return idx
    }

    func addQuadFace(_ i0: Int, _ i1: Int, _ i2: Int, _ i3: Int) {
        faces.append(MeshTransform.Face(
            indices: (UInt32(i0), UInt32(i1), UInt32(i2), UInt32(i3)),
            w: (0.0, 0.0, 0.0, 0.0)
        ))
    }

    // Topology parameters (same formulas as generateGlassMesh)
    let angularStepsBase = max(3, cornerResolution)
    let angularSteps = angularStepsBase % 2 == 0 ? angularStepsBase : angularStepsBase + 1
    let radialSteps = max(2, cornerResolution)
    let horizontalSegments = max(2, cornerResolution / 2 + 1)
    let verticalSegments = max(2, cornerResolution / 2 + 1)
    let R = clampedRadius

    func depthFactorsWithOuterBand(count: Int, band: CGFloat, maxRadius: CGFloat) -> [CGFloat] {
        guard count > 0, maxRadius > 0 else { return [0, 1] }
        let bandNorm = max(0, min(1, band / maxRadius))
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

    let depthFactors = depthFactorsWithOuterBand(count: radialSteps, band: outerEdgeDistance, maxRadius: R)
    let angularFactors = (0...angularSteps).map { CGFloat($0) / CGFloat(angularSteps) }
    let outerToInner = depthFactors.reversed()

    // Affine coefficient arrays for strip/grid positions
    let topXCoeffs: [(base: CGFloat, scale: CGFloat)] = (0...horizontalSegments).map { i in
        let t = CGFloat(i) / CGFloat(horizontalSegments)
        return (base: R * (1 - 2 * t), scale: t)
    }
    let sideYCoeffs: [(base: CGFloat, scale: CGFloat)] = (0...verticalSegments).map { j in
        let t = CGFloat(j) / CGFloat(verticalSegments)
        return (base: R * (1 - 2 * t), scale: t)
    }
    let topYCoeffs: [(base: CGFloat, scale: CGFloat)] = outerToInner.map { factor in
        (base: R * (1 - factor), scale: 0)
    }
    let bottomYCoeffs: [(base: CGFloat, scale: CGFloat)] = depthFactors.map { factor in
        (base: -R * (1 - factor), scale: 1)
    }
    let leftXCoeffs: [(base: CGFloat, scale: CGFloat)] = outerToInner.map { factor in
        (base: R * (1 - factor), scale: 0)
    }
    let rightXCoeffs: [(base: CGFloat, scale: CGFloat)] = depthFactors.map { factor in
        (base: -R * (1 - factor), scale: 1)
    }

    // Build a grid of vertices from coefficient arrays and emit quad faces
    func buildGridTemplate(
        xCoeffs: [(base: CGFloat, scale: CGFloat)],
        yCoeffs: [(base: CGFloat, scale: CGFloat)]
    ) {
        var indexGrid: [[Int]] = []
        for yc in yCoeffs {
            var row: [Int] = []
            for xc in xCoeffs {
                row.append(addVertex(baseX: xc.base, scaleX: xc.scale, baseY: yc.base, scaleY: yc.scale))
            }
            indexGrid.append(row)
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

    // Corner wedge template
    func buildCornerTemplate(
        centerBaseX: CGFloat, centerScaleX: CGFloat,
        centerBaseY: CGFloat, centerScaleY: CGFloat,
        startAngle: CGFloat, endAngle: CGFloat
    ) {
        let ringRadials = outerToInner.filter { $0 > 0 }
        guard !ringRadials.isEmpty else { return }

        var ringIndices: [[Int]] = []
        for radial in ringRadials {
            let r = R * radial
            var row: [Int] = []
            for t in angularFactors {
                let angle = startAngle + (endAngle - startAngle) * t
                let offsetX = r * cos(angle)
                let offsetY = r * sin(angle)
                row.append(addVertex(
                    baseX: centerBaseX + offsetX, scaleX: centerScaleX,
                    baseY: centerBaseY + offsetY, scaleY: centerScaleY
                ))
            }
            ringIndices.append(row)
        }

        // Quad rings between concentric samples
        for r in 0..<(ringIndices.count - 1) {
            let outerRing = ringIndices[r]
            let innerRing = ringIndices[r + 1]
            for i in 0..<(outerRing.count - 1) {
                addQuadFace(outerRing[i], outerRing[i + 1], innerRing[i + 1], innerRing[i])
            }
        }

        // Center fan collapse (same logic as original)
        if let innermostRing = ringIndices.last {
            let ringSegments = innermostRing.count - 1
            guard ringSegments >= 2 else { return }

            let centerAnchor = addVertex(
                baseX: centerBaseX, scaleX: centerScaleX,
                baseY: centerBaseY, scaleY: centerScaleY,
                depth: -0.02
            )
            let stride = 2
            var i = 0
            while i + 2 <= ringSegments {
                addQuadFace(centerAnchor, innermostRing[i], innermostRing[i + 1], innermostRing[i + 2])
                i += stride
            }
            if i < ringSegments {
                addQuadFace(centerAnchor, innermostRing[ringSegments - 1], innermostRing[ringSegments], innermostRing[ringSegments])
            }
        }
    }

    // Edge strips
    buildGridTemplate(xCoeffs: topXCoeffs, yCoeffs: topYCoeffs)
    buildGridTemplate(xCoeffs: topXCoeffs, yCoeffs: bottomYCoeffs)
    buildGridTemplate(xCoeffs: leftXCoeffs, yCoeffs: sideYCoeffs)
    buildGridTemplate(xCoeffs: rightXCoeffs, yCoeffs: sideYCoeffs)

    // Center patch
    buildGridTemplate(xCoeffs: topXCoeffs, yCoeffs: sideYCoeffs)

    // Corners
    buildCornerTemplate(
        centerBaseX: R, centerScaleX: 0,
        centerBaseY: R, centerScaleY: 0,
        startAngle: .pi, endAngle: 1.5 * .pi
    )
    buildCornerTemplate(
        centerBaseX: -R, centerScaleX: 1,
        centerBaseY: R, centerScaleY: 0,
        startAngle: 1.5 * .pi, endAngle: 2 * .pi
    )
    buildCornerTemplate(
        centerBaseX: -R, centerScaleX: 1,
        centerBaseY: -R, centerScaleY: 1,
        startAngle: .pi / 2, endAngle: 0
    )
    buildCornerTemplate(
        centerBaseX: R, centerScaleX: 0,
        centerBaseY: -R, centerScaleY: 1,
        startAngle: .pi, endAngle: .pi / 2
    )

    return GlassMeshTemplate(vertices: vertices, faces: faces)
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

/// Computes displacement at a point analytically using the rounded rect SDF.
/// - Parameters:
///   - x, y: Point coordinates in the shape's coordinate space
///   - width, height: Dimensions of the rounded rectangle
///   - cornerRadius: Already-clamped corner radius
///   - edgeDistance: Distance (in points) over which displacement fades from edge inward
///   - bezier: Bezier control points for easing the displacement magnitude
/// - Returns: (dx, dy) displacement in range -1..1 with bezier easing, plus the raw SDF value
public func computeDisplacement(
    x: CGFloat,
    y: CGFloat,
    width: CGFloat,
    height: CGFloat,
    cornerRadius: CGFloat,
    edgeDistance: CGFloat,
    bezier: DisplacementBezier
) -> (dx: CGFloat, dy: CGFloat, sdf: CGFloat) {
    let sdf = roundedRectSDF(x: x, y: y, width: width, height: height, cornerRadius: cornerRadius)
    let (nx, ny) = roundedRectGradient(x: x, y: y, width: width, height: height, cornerRadius: cornerRadius)

    // Inward normal (content moves away from edge, toward center)
    let inwardX = -nx
    let inwardY = -ny

    // Distance from edge (positive inside the shape)
    let distFromEdge = -sdf

    // Weight: 1 at edge, 0 at edgeDistance inward (linear falloff)
    let weight = max(0, min(1, 1.0 - distFromEdge / edgeDistance))

    // Displacement direction modulated by distance
    var dx = inwardX * weight
    var dy = inwardY * weight

    // Apply bezier easing to vector magnitude, preserving direction
    let mag = hypot(dx, dy)
    if mag > 0 {
        let newMag = bezierPoint(bezier.x1, bezier.y1, bezier.x2, bezier.y2, mag)
        let scale = newMag / mag
        dx *= scale
        dy *= scale
    }

    return (dx, dy, sdf)
}

/// Generates a glass mesh with corner-aware topology.
/// - 4 radial corner wedges sampled in polar space
/// - 4 edge strips aligned with the rectangle sides
/// - 1 center patch
/// Corner/edge seams share the same coordinates (but do not reuse vertices) so
/// the neighbouring faces fit perfectly without T-junctions.
public func generateGlassMesh(
    size: CGSize,
    cornerRadius: CGFloat,
    edgeDistance: CGFloat,
    displacementMagnitudeU: CGFloat,
    displacementMagnitudeV: CGFloat,
    cornerResolution: Int,
    outerEdgeDistance: CGFloat,
    bezier: DisplacementBezier,
    generateWireframe: Bool = false
) -> (mesh: MeshTransform, wireframe: CGPath?) {
    let clampedRadius = min(cornerRadius, min(size.width, size.height) / 2)

    // Fast cached path (non-wireframe)
    if !generateWireframe {
        let key = GlassMeshCacheKey(
            cornerRadius: clampedRadius,
            edgeDistance: edgeDistance,
            cornerResolution: cornerResolution,
            outerEdgeDistance: outerEdgeDistance,
            bezier: bezier
        )
        let template: GlassMeshTemplate
        if let cached = glassMeshTemplateCache[key] {
            template = cached
        } else {
            template = generateGlassMeshTemplate(
                cornerRadius: clampedRadius,
                edgeDistance: edgeDistance,
                cornerResolution: cornerResolution,
                outerEdgeDistance: outerEdgeDistance,
                bezier: bezier
            )
            glassMeshTemplateCache[key] = template
        }
        let mesh = instantiateGlassMesh(
            from: template,
            size: size,
            displacementMagnitudeU: displacementMagnitudeU,
            displacementMagnitudeV: displacementMagnitudeV
        )
        return (mesh: mesh, wireframe: nil)
    }

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

    // Helper to compute displacement analytically and create vertex
    func makeVertex(u: CGFloat, v: CGFloat, depth: CGFloat = 0) -> (vertex: MeshTransform.Vertex, point: CGPoint) {
        let mappedU = insetUOffset + u * usableUNorm
        let mappedV = insetVOffset + v * usableVNorm
        let fromX: CGFloat
        let fromY: CGFloat

        if debugNoDisplacement {
            fromX = mappedU
            fromY = mappedV
        } else {
            let worldX = insetPoints + u * usableWidth
            let worldY = insetPoints + v * usableHeight

            let (dispX, dispY, sdf) = computeDisplacement(
                x: worldX,
                y: worldY,
                width: size.width,
                height: size.height,
                cornerRadius: clampedRadius,
                edgeDistance: edgeDistance,
                bezier: bezier
            )

            // Edge boost: slight displacement boost near the silhouette
            let distToEdge = max(0.0, -sdf)
            let edgeBand = max(0.0, outerEdgeDistance)
            let edgeBoostGain: CGFloat = 0.5
            let edgeBoost: CGFloat
            if edgeBand > 0 {
                let t = max(0.0, min(1.0, (edgeBand - distToEdge) / edgeBand))
                let eased = t * t * (3 - 2 * t)
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
