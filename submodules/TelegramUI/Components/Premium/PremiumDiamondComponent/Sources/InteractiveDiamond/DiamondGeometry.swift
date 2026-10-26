import Foundation
import simd

struct DiamondGeometry {
    static let roundingRadius: Float = 0.055
    static let crownRoundingRadius: Float = 0.32865
    static let girdleRoundingRadius: Float = 0.073114
    static let outlineBow: Float = 0.106987
    struct Vertex {
        var position: SIMD4<Float>
        var normal: SIMD4<Float>
        var surface: SIMD4<Float>
    }

    private(set) var vertices: [Vertex] = []
    private(set) var planes: [SIMD4<Float>] = []

    fileprivate init(vertices: [Vertex], planes: [SIMD4<Float>]) {
        self.vertices = vertices
        self.planes = planes
    }

    init(roundingRadius: Float = Self.roundingRadius) {
        let girdle: [SIMD2<Float>] = [SIMD2(0.70024, 1), SIMD2(1, 0.70024),
            SIMD2(1, -0.70024), SIMD2(0.70024, -1), SIMD2(-0.70024, -1),
            SIMD2(-1, -0.70024), SIMD2(-1, 0.70024), SIMD2(-0.70024, 1)]
        let table: [SIMD2<Float>] = [SIMD2(0.498552, 0.631807), SIMD2(0.631807, 0.498552),
            SIMD2(0.631807, -0.498552), SIMD2(0.498552, -0.631807), SIMD2(-0.498552, -0.631807),
            SIMD2(-0.631807, -0.498552), SIMD2(-0.631807, 0.498552), SIMD2(-0.498552, 0.631807)]
        let sections: [(scale: Float, y: Float, table: Bool)] = [
            (0.965, 0.583526, true), (1, 0.571526, true),
            (0.990, -0.081806, false), (1, -0.112806, false), (0.978, -0.151806, false),
            (0.025, -1.07157, false), (0.009, -1.08757, false)
        ]
        let rings = sections.map { section in
            (0..<8).map { i -> SIMD3<Float> in
                let outline = section.table ? table[i] : girdle[i]
                return SIMD3(outline.x * section.scale, section.y, outline.y * section.scale)
            }
        }

        func face(_ points: [SIMD3<Float>], kind: Float, sector: Int) {
            var p = points
            var n = simd_normalize(simd_cross(p[1] - p[0], p[2] - p[0]))
            let center = p.reduce(.zero, +) / Float(p.count)
            if simd_dot(n, center - SIMD3(0, -0.12, 0)) < 0 {
                p.reverse()
                n = -n
            }
            if kind != 3 { planes.append(SIMD4(n, -simd_dot(n, p[0]))) }
            for j in 1..<(p.count - 1) {
                for k in [0, j, j + 1] {
                    vertices.append(Vertex(position: SIMD4(p[k], 1), normal: SIMD4(n, 0),
                                           surface: SIMD4(0, 0, kind, Float(sector))))
                }
            }
        }
        face(rings[0], kind: 0, sector: 0)
        for band in 0..<(rings.count - 1) {
            for i in 0..<8 {
                let next = (i + 1) % 8
                face([rings[band][i], rings[band + 1][i], rings[band + 1][next], rings[band][next]],
                     kind: band == 1 ? 1 : (band == 4 ? 2 : 3), sector: i)
            }
        }
        face(rings.last!, kind: 3, sector: 0)
        if roundingRadius > 0 {
            vertices = DiamondRounding.mesh(planes: planes, radius: roundingRadius)
        }
    }
}

enum DiamondRounding {
    static let segments = 3
    static let edgeStep: Float = 0.40
    static let radialSteps = 2

    private struct Sample {
        let normal: SIMD3<Float>
        let material: SIMD3<Float> // table, crown, pavilion weights
    }

    private struct Edge: Hashable {
        let a: Int
        let b: Int
        init(_ a: Int, _ b: Int) { self.a = min(a, b); self.b = max(a, b) }
    }

    static func mesh(planes: [SIMD4<Float>], radius: Float, segments: Int = DiamondRounding.segments) -> [DiamondGeometry.Vertex] {
        precondition(radius > 0 && radius <= 0.08 && segments >= 3)
        let normals = planes.map { SIMD3($0.x, $0.y, $0.z) }
        let materials: [SIMD3<Float>] = planes.indices.map {
            $0 == 0 ? SIMD3(1, 0, 0) : ($0 <= 8 ? SIMD3(0, 1, 0) : SIMD3(0, 0, 1))
        }
        let doubleNormals = normals.map { SIMD3<Double>($0) }
        let offsets = planes.map { Double($0.w) + Double(radius) }
        let incidenceTolerance = 2e-6
        var corners: [SIMD3<Double>] = []

        for a in 0..<(planes.count - 2) {
            for b in (a + 1)..<(planes.count - 1) {
                for c in (b + 1)..<planes.count {
                    let na = doubleNormals[a], nb = doubleNormals[b], nc = doubleNormals[c]
                    let determinant = simd_dot(na, simd_cross(nb, nc))
                    if abs(determinant) < 1e-8 { continue }
                    let point = (-offsets[a] * simd_cross(nb, nc)
                                 - offsets[b] * simd_cross(nc, na)
                                 - offsets[c] * simd_cross(na, nb)) / determinant
                    guard planes.indices.allSatisfy({ simd_dot(doubleNormals[$0], point) + offsets[$0] < 2e-7 })
                    else { continue }
                    if !corners.contains(where: { simd_distance_squared($0, point) < 1e-10 }) {
                        corners.append(point)
                    }
                }
            }
        }
        var sharpPoints: [SIMD3<Float>] = []
        var insetDirections: [SIMD3<Float>] = []
        for corner in corners {
            let incident = planes.indices.filter { abs(simd_dot(doubleNormals[$0], corner) + offsets[$0]) < incidenceTolerance }
            var inset = SIMD3<Double>.zero
            outer: for a in 0..<(incident.count - 2) {
                for b in (a + 1)..<(incident.count - 1) {
                    for c in (b + 1)..<incident.count {
                        let na = doubleNormals[incident[a]], nb = doubleNormals[incident[b]], nc = doubleNormals[incident[c]]
                        let determinant = simd_dot(na, simd_cross(nb, nc))
                        if abs(determinant) < 1e-8 { continue }
                        inset = (simd_cross(nb, nc) + simd_cross(nc, na) + simd_cross(na, nb)) / determinant
                        break outer
                    }
                }
            }
            sharpPoints.append(SIMD3(corner + Double(radius) * inset))
            insetDirections.append(SIMD3(inset))
        }
        let radiusScale = radius / DiamondGeometry.roundingRadius
        let radii = sharpPoints.map { point -> Float in
            if point.y > 0.4 { return min(DiamondGeometry.crownRoundingRadius * radiusScale, 0.34) }
            if point.y > -0.5 { return DiamondGeometry.girdleRoundingRadius * radiusScale }
            return radius
        }
        let referencePoints = corners.map { SIMD3<Float>($0) }
        let points = sharpPoints.indices.map { sharpPoints[$0] - radii[$0] * insetDirections[$0] }

        func cyclicOrder(_ indices: [Int], values: [SIMD3<Float>], normal: SIMD3<Float>) -> [Int] {
            let center = indices.reduce(SIMD3<Float>.zero) { $0 + values[$1] } / Float(indices.count)
            let axis = abs(normal.y) < 0.9 ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(1, 0, 0)
            let u = simd_normalize(simd_cross(axis, normal)), v = simd_cross(normal, u)
            return indices.sorted {
                let a = values[$0] - center, b = values[$1] - center
                return atan2(simd_dot(a, v), simd_dot(a, u)) < atan2(simd_dot(b, v), simd_dot(b, u))
            }
        }

        var faces = [[Int]](repeating: [], count: planes.count)
        var incidentFaces = [[Int]](repeating: [], count: corners.count)
        var edgeFaces: [Edge: [Int]] = [:]
        for face in planes.indices {
            let indices = corners.indices.filter { abs(simd_dot(doubleNormals[face], corners[$0]) + offsets[face]) < incidenceTolerance }
            guard indices.count >= 3 else { continue }
            faces[face] = cyclicOrder(Array(indices), values: referencePoints, normal: normals[face])
            for i in faces[face].indices {
                let a = faces[face][i], b = faces[face][(i + 1) % indices.count]
                incidentFaces[a].append(face)
                edgeFaces[Edge(a, b), default: []].append(face)
            }
        }
        precondition(!points.isEmpty && edgeFaces.values.allSatisfy { $0.count == 2 }, "Inset must remain a closed convex solid")

        func blendNormal(_ a: SIMD3<Float>, _ b: SIMD3<Float>, step: Int, count: Int) -> SIMD3<Float> {
            if step == 0 { return a }
            if step == count { return b }
            let t = Float(step) / Float(count)
            return simd_normalize(a * (1 - t) + b * t)
        }

        func blend(_ a: Sample, _ b: Sample, step: Int, count: Int) -> Sample {
            let t = Float(step) / Float(count)
            return Sample(normal: blendNormal(a.normal, b.normal, step: step, count: count),
                          material: a.material * (1 - t) + b.material * t)
        }
        var arcs: [Edge: [Sample]] = [:]
        for adjacent in edgeFaces.values {
            let key = Edge(adjacent[0], adjacent[1])
            let a = Sample(normal: normals[key.a], material: materials[key.a])
            let b = Sample(normal: normals[key.b], material: materials[key.b])
            arcs[key] = (0...segments).map { blend(a, b, step: $0, count: segments) }
        }

        var result: [DiamondGeometry.Vertex] = []
        result.reserveCapacity(60000)
        func vertex(_ p: SIMD3<Float>, _ n: SIMD3<Float>, kind: Float, sector: Float = 0) -> DiamondGeometry.Vertex {
            DiamondGeometry.Vertex(position: SIMD4(p, 1), normal: SIMD4(n, 0), surface: SIMD4(0, 0, kind, sector))
        }
        func roundedVertex(_ index: Int, _ sample: Sample) -> DiamondGeometry.Vertex {
            var v = vertex(points[index] + radii[index] * sample.normal, sample.normal, kind: 3)
            v.surface.x = sample.material.x
            v.surface.y = sample.material.y
            return v
        }
        func triangle(_ a: DiamondGeometry.Vertex, _ b: DiamondGeometry.Vertex, _ c: DiamondGeometry.Vertex) {
            let pa = SIMD3(a.position.x, a.position.y, a.position.z)
            let pb = SIMD3(b.position.x, b.position.y, b.position.z)
            let pc = SIMD3(c.position.x, c.position.y, c.position.z)
            let cross = simd_cross(pb-pa, pc-pa)
            let outward = (pa + pb + pc) / 3 - SIMD3<Float>(0, -0.12, 0)
            if simd_dot(cross, outward) > 0 { result.append(contentsOf: [a, b, c]) }
            else { result.append(contentsOf: [a, c, b]) }
        }
        func quad(_ a: DiamondGeometry.Vertex, _ b: DiamondGeometry.Vertex,
                  _ c: DiamondGeometry.Vertex, _ d: DiamondGeometry.Vertex) {
            triangle(a, b, c)
            triangle(a, c, d)
        }

        var edgeRows: [Edge: [[DiamondGeometry.Vertex]]] = [:]
        for edge in edgeFaces.keys.sorted(by: { $0.a == $1.a ? $0.b < $1.b : $0.a < $1.a }) {
            let adjacent = edgeFaces[edge]!
            let arc = arcs[Edge(adjacent[0], adjacent[1])]!
            let steps = max(1, Int(ceil(simd_distance(sharpPoints[edge.a], sharpPoints[edge.b]) / Self.edgeStep)))
            var rows: [[DiamondGeometry.Vertex]] = []
            for row in 0...steps {
                if row == 0 { rows.append(arc.map { roundedVertex(edge.a, $0) }); continue }
                if row == steps { rows.append(arc.map { roundedVertex(edge.b, $0) }); continue }
                let t = Float(row) / Float(steps)
                let smooth = t * t * (3 - 2 * t)
                let r = radii[edge.a] + (radii[edge.b] - radii[edge.a]) * smooth
                let dr = (radii[edge.b] - radii[edge.a]) * 6 * t * (1 - t)
                let inset = simd_mix(insetDirections[edge.a], insetDirections[edge.b], SIMD3(repeating: t))
                let center = simd_mix(sharpPoints[edge.a], sharpPoints[edge.b], SIMD3(repeating: t)) - r * inset
                let tangent = sharpPoints[edge.b] - sharpPoints[edge.a]
                    - r * (insetDirections[edge.b] - insetDirections[edge.a]) - dr * inset
                let axis = simd_normalize(simd_cross(arc.first!.normal, arc.last!.normal))
                rows.append(arc.enumerated().map { index, sample in
                    let along = tangent + dr * sample.normal
                    let across = simd_cross(axis, sample.normal)
                    var normal = simd_normalize(simd_cross(along, across))
                    if simd_dot(normal, sample.normal) < 0 { normal = -normal }
                    if index == 0 || index == segments { normal = sample.normal }
                    var v = vertex(center + r * sample.normal, normal, kind: 3)
                    v.surface.x = sample.material.x
                    v.surface.y = sample.material.y
                    return v
                })
            }
            edgeRows[edge] = rows
            for row in 0..<steps {
                for i in 0..<segments {
                    quad(rows[row][i], rows[row+1][i], rows[row+1][i+1], rows[row][i+1])
                }
            }
        }

        for face in faces.indices where faces[face].count >= 3 {
            let n = normals[face]
            let kind: Float = face == 0 ? 0 : (face <= 8 ? 1 : 2)
            var rim: [DiamondGeometry.Vertex] = []
            for i in faces[face].indices {
                let a = faces[face][i], b = faces[face][(i+1) % faces[face].count]
                let edge = Edge(a, b)
                let adjacent = edgeFaces[edge]!
                let arcIndex = face == min(adjacent[0], adjacent[1]) ? 0 : segments
                let rows = edgeRows[edge]!
                let orderedRows = a < b ? rows : Array(rows.reversed())
                rim += orderedRows.dropLast().map { row in
                    let p = row[arcIndex].position
                    return vertex(SIMD3(p.x, p.y, p.z), n, kind: kind, sector: Float((face-1) % 8))
                }
            }
            let center = rim.reduce(SIMD4<Float>.zero) { $0 + $1.position } / Float(rim.count)
            let middle = vertex(SIMD3(center.x, center.y, center.z), n, kind: kind)
            for i in rim.indices { triangle(middle, rim[i], rim[(i+1) % rim.count]) }
        }

        let radialSteps = Self.radialSteps
        for corner in points.indices {
            let incident = incidentFaces[corner]
            guard incident.count >= 3 else { continue }
            let centerNormal = simd_normalize(incident.reduce(SIMD3<Float>.zero) { $0 + normals[$1] })
            let centerMaterial = incident.reduce(SIMD3<Float>.zero) { $0 + materials[$1] } / Float(incident.count)
            let centerSample = Sample(normal: centerNormal, material: centerMaterial)
            let ordered = cyclicOrder(incident, values: normals, normal: centerNormal)
            let middle = roundedVertex(corner, centerSample)
            for i in ordered.indices {
                let a = ordered[i], b = ordered[(i+1) % ordered.count]
                let samples = arcs[Edge(a, b)]!
                let arc = a < b ? samples : Array(samples.reversed())
                for j in 0..<segments {
                    func sample(_ side: Int, _ row: Int) -> DiamondGeometry.Vertex {
                        roundedVertex(corner, blend(centerSample, arc[j+side], step: row, count: radialSteps))
                    }
                    triangle(middle, sample(0, 1), sample(1, 1))
                    for row in 1..<radialSteps {
                        quad(sample(0, row), sample(1, row), sample(1, row+1), sample(0, row+1))
                    }
                }
            }
        }

        return result.map { v in
            var v = v
            let x = v.position.x, z = v.position.z, bow = DiamondGeometry.outlineBow
            let a = 1 - bow * z * z, b = 1 - bow * x * x, c = -2 * bow * x * z
            v.position.x = x * a
            v.position.z = z * b
            let determinant = a * b - c * c
            let n = simd_normalize(SIMD3((b * v.normal.x - c * v.normal.z) / determinant,
                                        v.normal.y, (a * v.normal.z - c * v.normal.x) / determinant))
            v.normal = SIMD4(n, 0)
            return v
        }
    }
}

struct DiamondSparkleGeometry {
    struct Anchor {
        var position: SIMD4<Float>
        var normal: SIMD4<Float>
    }

    static func anchors(on geometry: DiamondGeometry) -> [Anchor] {
        let reference = DiamondMath.rotation(x: DiamondMotion.referencePitch, y: 0)
        let projected = geometry.vertices.map { DiamondMath.cameraPoint(reference * $0.position) }
        let halfWidth = projected.reduce(Float(0)) { max($0, abs($1.x)) }
        let top = projected.reduce(-Float.infinity) { max($0, $1.y) }
        return (0..<8).map { instance in
            if instance == 0 {
                let scale = halfWidth / (447.9 * 0.75 / 2)
                let ray = DiamondMath.cameraRay(at: SIMD2(42.375 * scale, top - 105.075 * scale))
                let p = reference.transpose * ray.origin
                let d = reference.transpose * ray.direction
                guard let hit = intersect(geometry: geometry, origin: SIMD3(p.x, p.y, p.z),
                                         direction: SIMD3(d.x, d.y, d.z)) else {
                    preconditionFailure("The branded sparkle must lie on the front facet")
                }
                return hit
            }
            let angle = Float(instance) * .pi / 4 + .pi / 8
            let height: Float = instance % 3 == 0 ? 0.56 : (instance % 3 == 1 ? -0.02 : -0.54)
            let origin = SIMD3<Float>(0, height, 0)
            let direction = SIMD3<Float>(sin(angle), 0, cos(angle))
            let result = intersect(geometry: geometry, origin: origin, direction: direction)
            precondition(result != nil, "Sparkle anchor must intersect the diamond")
            return result!
        }
    }

    private static func intersect(geometry: DiamondGeometry, origin: SIMD3<Float>, direction: SIMD3<Float>) -> Anchor? {
        var nearest = Float.infinity
        var result: Anchor?
        for i in stride(from: 0, to: geometry.vertices.count, by: 3) {
            let a = geometry.vertices[i], b = geometry.vertices[i+1], c = geometry.vertices[i+2]
            func xyz(_ p: SIMD4<Float>) -> SIMD3<Float> { SIMD3(p.x, p.y, p.z) }
            let edge1 = xyz(b.position-a.position), edge2 = xyz(c.position-a.position)
            let cross = simd_cross(direction, edge2)
            let determinant = simd_dot(edge1, cross)
            if abs(determinant) < 1e-10 { continue }
            let offset = origin - xyz(a.position)
            let u = simd_dot(offset, cross) / determinant
            let q = simd_cross(offset, edge1)
            let v = simd_dot(direction, q) / determinant
            let distance = simd_dot(edge2, q) / determinant
            guard u >= -1e-5, v >= -1e-5, u+v <= 1.00001, distance > 0, distance < nearest else { continue }
            nearest = distance
            let normal = simd_normalize(xyz(a.normal)*(1-u-v) + xyz(b.normal)*u + xyz(c.normal)*v)
            result = Anchor(position: SIMD4(origin + direction*distance, 1), normal: SIMD4(normal, 0))
        }
        return result
    }

    struct HighlightInstance {
        var position: SIMD4<Float>
        var facing: SIMD4<Float> // reference view direction in object space; w = opacity
        var axisX: SIMD4<Float>
        var axisY: SIMD4<Float>
    }

    struct Reference {
        let anchors: [Anchor]
        private let appearance: DiamondStyle.Appearance
        private let events: [DiamondReferenceHighlights.Event]
        private let planes: [SIMD4<Float>]
        private let sourceScale: Float
        private let top: Float

        init(geometry: DiamondGeometry, appearance: DiamondStyle.Appearance = .blue) {
            self.appearance = appearance
            let events = DiamondReferenceHighlights.events(for: appearance)
            self.events = events
            let model = DiamondMath.rotation(x: DiamondMotion.referencePitch, y: 0)
            let projected = geometry.vertices.map { DiamondMath.cameraPoint(model * $0.position) }
            let scale = projected.reduce(Float(0)) { max($0, abs($1.x)) } / (447.9 * 0.75 / 2)
            let top = projected.reduce(-Float.infinity) { max($0, $1.y) }
            self.sourceScale = scale
            self.top = top
            planes = geometry.planes
            anchors = events.map { event in
                let inverse = DiamondMath.rotation(x: DiamondMotion.referencePitch,
                    y: DiamondMotion.referenceYaw(time: (event.frame + 2) * (appearance == .white ? 3/121 : 1/60), appearance: appearance)).transpose
                let x = (event.position.x - 256) * scale
                let y = top + (141.85 - event.position.y) * scale
                let ray = DiamondMath.cameraRay(at: SIMD2(x, y))
                let p = inverse * ray.origin
                let d = inverse * ray.direction
                let direction = SIMD3(d.x, d.y, d.z)
                guard let hit = DiamondSparkleGeometry.intersect(geometry: geometry,
                    origin: SIMD3(p.x, p.y, p.z), direction: direction) else {
                    preconditionFailure("Reference flare must lie on the diamond: \(event.frame)")
                }
                return Anchor(position: hit.position - SIMD4(direction * 0.003, 0), normal: -d)
            }
        }

        func smallInstances(at time: Float) -> [HighlightInstance] {
            var result: [HighlightInstance] = []
            result.reserveCapacity(3)
            for (i, event) in events.enumerated() {
                let scale = event.scale(at: time, appearance: appearance)
                guard scale > 0 else { continue }
                let anchor = anchors[i]
                result.append(HighlightInstance(position: anchor.position,
                    facing: SIMD4(anchor.normal.x, anchor.normal.y, anchor.normal.z, 1),
                    axisX: SIMD4(scale, 0, 0, 0), axisY: .zero))
            }
            return result
        }

        func streakInstances(at time: Float) -> [HighlightInstance] {
            let inverse = DiamondMath.rotation(x: DiamondMotion.referencePitch,
                                               y: DiamondMotion.referenceYaw(time: time, appearance: appearance)).transpose
            let view = inverse * SIMD4<Float>(0, 0, 1, 0)
            return DiamondReferenceHighlights.streaks(at: time, appearance: appearance).map { streak in
                let cameraPoint = SIMD2((streak.center.x-256)*sourceScale, top+(141.85-streak.center.y)*sourceScale)
                let ray = DiamondMath.cameraRay(at: cameraPoint)
                let origin = inverse * ray.origin
                let direction = inverse * ray.direction
                var near: Float = 0, far: Float = 12
                for plane in planes {
                    let n = SIMD4(plane.x, plane.y, plane.z, 0)
                    let distance = simd_dot(n, origin) + plane.w
                    let denominator = simd_dot(n, direction)
                    if abs(denominator) < 0.000001 {
                        if distance > 0 { far = -1 }
                    } else if denominator < 0 { near = max(near, -distance / denominator) }
                    else { far = min(far, -distance / denominator) }
                }
                let distance = near <= far ? max(0, near - 0.003)
                    : (0.5 - ray.origin.z) / ray.direction.z
                let position = origin + direction * distance
                let depthScale = DiamondMath.cameraW(z: (inverse.transpose * position).z)
                func axis(_ a: SIMD2<Float>) -> SIMD4<Float> {
                    inverse * SIMD4(a.x*sourceScale*depthScale, -a.y*sourceScale*depthScale, 0, 0)
                }
                return HighlightInstance(position: position,
                    facing: SIMD4(view.x, view.y, view.z, streak.opacity),
                    axisX: axis(streak.axisX), axisY: axis(streak.axisY))
            }
        }
    }

    struct Vertex {
        var contours: SIMD4<Float> // wide.xy, narrow.zw, in the original authoring units
        var material: SIMD4<Float> // layer: 0 circular glow, 1 star glow, 2 white core, 3/4 small glow/core
    }
    private struct Outline {
        var vertices: [SIMD2<Float>]
        var incoming: [SIMD2<Float>]
        var outgoing: [SIMD2<Float>]
        func sample(segment i: Int, t: Float) -> SIMD2<Float> {
            let j = (i + 1) % vertices.count
            let a = vertices[i], b = a + outgoing[i]
            let d = vertices[j], c = d + incoming[j]
            let s = 1 - t
            return a * (s*s*s) + b * (3*s*s*t) + c * (3*s*t*t) + d * (t*t*t)
        }
    }

    let main: [Vertex]
    let small: [Vertex]
    let streakVertices: [Vertex]

    fileprivate init(main: [Vertex], small: [Vertex], streakVertices: [Vertex]) {
        self.main = main
        self.small = small
        self.streakVertices = streakVertices
    }

    init() {
        func tessellate(_ wide: Outline, _ narrow: Outline, layer: Float) -> [Vertex] {
            var result: [Vertex] = []
            for segment in wide.vertices.indices {
                for step in 0..<16 {
                    let t0 = Float(step) / 16, t1 = Float(step + 1) / 16
                    for t in [Float(-1), t0, t1] {
                        let a = t < 0 ? SIMD2<Float>.zero : wide.sample(segment: segment, t: t)
                        let b = t < 0 ? SIMD2<Float>.zero : narrow.sample(segment: segment, t: t)
                        result.append(Vertex(contours: SIMD4(a.x, a.y, b.x, b.y),
                                             material: SIMD4(layer, 0, 0, 0)))
                    }
                }
            }
            return result
        }
        let centeredStreak = Outline(vertices: Self.streak.vertices.map { $0 - SIMD2(-3.2, -84.1) },
                                     incoming: Self.streak.incoming, outgoing: Self.streak.outgoing)
        streakVertices = tessellate(centeredStreak, centeredStreak, layer: 5)
        main = tessellate(Self.circle, Self.circle, layer: 0)
             + tessellate(Self.haloWide, Self.haloNarrow, layer: 1)
             + tessellate(Self.coreWide, Self.coreNarrow, layer: 2)
        let smallCircle = Outline(vertices: Self.circle.vertices.map { $0 * (256 / 108.5) },
                                  incoming: Self.circle.incoming.map { $0 * (256 / 108.5) },
                                  outgoing: Self.circle.outgoing.map { $0 * (256 / 108.5) })
        small = tessellate(smallCircle, smallCircle, layer: 3)
              + tessellate(Self.smallCore, Self.smallCore, layer: 4)
    }

    private static let coreWide = Outline(
        vertices: [SIMD2(1.3, -80.9), SIMD2(17.6, -39.5), SIMD2(38.9, -20.7), SIMD2(80.3, -3.1), SIMD2(38.9, 15.7), SIMD2(17.6, 37), SIMD2(0, 80.9), SIMD2(-17.6, 37), SIMD2(-38.9, 15.7), SIMD2(-80.3, -3.1), SIMD2(-38.9, -20.7), SIMD2(-16.3, -40.8)],
        incoming: [SIMD2(-6.3, 0), SIMD2(-6.3, -15.1), SIMD2(-11.3, -3.8), SIMD2(0, -6.3), SIMD2(13.8, -5), SIMD2(5, -11.3), SIMD2(6.3, 0), SIMD2(6.3, 16.3), SIMD2(11.3, 3.8), SIMD2(0, 7.5), SIMD2(-15.1, 5), SIMD2(-5, 11.3)],
        outgoing: [SIMD2(5, 0), SIMD2(3.8, 10), SIMD2(13.8, 5), SIMD2(0, 7.5), SIMD2(-11.3, 3.8), SIMD2(-6.3, 16.3), SIMD2(-6.3, 0), SIMD2(-3.8, -11.3), SIMD2(-16.3, -6.3), SIMD2(0, -6.3), SIMD2(11.3, -3.8), SIMD2(6.3, -16.3)])
    private static let coreNarrow = Outline(
        vertices: [SIMD2(1.3, -80.9), SIMD2(9, -23), SIMD2(20.8, -12.6), SIMD2(80.3, -3.1), SIMD2(20.8, 7.6), SIMD2(9, 19.4), SIMD2(0, 80.9), SIMD2(-10.5, 19.4), SIMD2(-22.3, 7.6), SIMD2(-80.3, -3.1), SIMD2(-22.3, -12.6), SIMD2(-9.8, -23.7)],
        incoming: [SIMD2(-6.3, 0), SIMD2(-3.5, -8.4), SIMD2(-6.3, -2.1), SIMD2(0, -6.3), SIMD2(7.7, -2.8), SIMD2(2.8, -6.3), SIMD2(6.3, 0), SIMD2(3.5, 9.1), SIMD2(6.3, 2.1), SIMD2(0, 7.5), SIMD2(-8.4, 2.8), SIMD2(-2.8, 6.3)],
        outgoing: [SIMD2(5, 0), SIMD2(2.1, 5.6), SIMD2(7.7, 2.8), SIMD2(0, 7.5), SIMD2(-6.3, 2.1), SIMD2(-3.5, 9.1), SIMD2(-6.3, 0), SIMD2(-2.1, -6.3), SIMD2(-9.1, -3.5), SIMD2(0, -6.3), SIMD2(6.3, -2.1), SIMD2(3.5, -9.1)])
    private static let haloWide = Outline(
        vertices: [SIMD2(1.8, -113.5), SIMD2(24.6, -55.4), SIMD2(54.6, -29), SIMD2(112.7, -4.4), SIMD2(54.6, 22), SIMD2(24.6, 51.9), SIMD2(0, 113.5), SIMD2(-24.6, 51.9), SIMD2(-54.6, 22), SIMD2(-112.7, -4.4), SIMD2(-54.6, -29), SIMD2(-22.9, -57.2)],
        incoming: [SIMD2(-8.8, 0), SIMD2(-8.8, -21.1), SIMD2(-15.8, -5.3), SIMD2(0, -8.8), SIMD2(19.4, -7), SIMD2(7, -15.8), SIMD2(8.8, 0), SIMD2(8.8, 22.9), SIMD2(15.8, 5.3), SIMD2(0, 10.6), SIMD2(-21.1, 7), SIMD2(-7, 15.8)],
        outgoing: [SIMD2(7, 0), SIMD2(5.3, 14.1), SIMD2(19.4, 7), SIMD2(0, 10.6), SIMD2(-15.8, 5.3), SIMD2(-8.8, 22.9), SIMD2(-8.8, 0), SIMD2(-5.3, -15.8), SIMD2(-22.9, -8.8), SIMD2(0, -8.8), SIMD2(15.8, -5.3), SIMD2(8.8, -22.9)])
    private static let haloNarrow = Outline(
        vertices: [SIMD2(1.8, -113.5), SIMD2(12.9, -32), SIMD2(29.5, -17.3), SIMD2(112.7, -4.4), SIMD2(29.5, 11), SIMD2(12.9, 27.7), SIMD2(0, 113.5), SIMD2(-14.5, 27.7), SIMD2(-31.1, 11), SIMD2(-112.7, -4.4), SIMD2(-31.1, -17.3), SIMD2(-13.5, -32.9)],
        incoming: [SIMD2(-8.8, 0), SIMD2(-4.9, -11.7), SIMD2(-8.8, -2.9), SIMD2(0, -8.8), SIMD2(10.7, -3.9), SIMD2(3.9, -8.8), SIMD2(8.8, 0), SIMD2(4.9, 12.7), SIMD2(8.8, 2.9), SIMD2(0, 10.6), SIMD2(-11.7, 3.9), SIMD2(-3.9, 8.8)],
        outgoing: [SIMD2(7, 0), SIMD2(2.9, 7.8), SIMD2(10.7, 3.9), SIMD2(0, 10.6), SIMD2(-8.8, 2.9), SIMD2(-4.9, 12.7), SIMD2(-8.8, 0), SIMD2(-2.9, -8.8), SIMD2(-12.7, -4.9), SIMD2(0, -8.8), SIMD2(8.8, -2.9), SIMD2(4.9, -12.7)])
    private static let circle = Outline(
        vertices: [SIMD2(108.5, 0), SIMD2(0, 108.5), SIMD2(-108.5, 0), SIMD2(0, -108.5)],
        incoming: [SIMD2(0, -59.9), SIMD2(59.9, 0), SIMD2(0, 59.9), SIMD2(-59.9, 0)],
        outgoing: [SIMD2(0, 59.9), SIMD2(-59.9, 0), SIMD2(0, -59.9), SIMD2(59.9, 0)])
    private static let smallCore = Outline(
        vertices: [SIMD2(0, -53.2), SIMD2(53.2, 0), SIMD2(0, 53.2), SIMD2(-53.2, 0)],
        incoming: [SIMD2(-3.1, 50.4), SIMD2(-50.8, -2.9), SIMD2(2.1, -49.7), SIMD2(50.1, 3.5)],
        outgoing: [SIMD2(2.5, 50.2), SIMD2(-50.8, 3.5), SIMD2(-3.1, -49.7), SIMD2(50.1, -2.7)])
    private static let streak = Outline(
        vertices: [SIMD2(-7.2, -261), SIMD2(349.5, -86.1), SIMD2(2.5, 89.6), SIMD2(-354.2, -85.3)],
        incoming: [SIMD2(-194.3, 0.2), SIMD2(-2.7, -96.8), SIMD2(194.3, -0.2), SIMD2(2.7, 96.8)],
        outgoing: [SIMD2(194.3, -0.2), SIMD2(2.7, 96.8), SIMD2(-194.3, 0.2), SIMD2(-2.7, -96.8)])
}

struct DiamondSilhouette {
    fileprivate let widths: [Float]

    fileprivate init(widths: [Float]) {
        self.widths = widths
    }

    init(geometry: DiamondGeometry) {
        let points = Array(Set(geometry.vertices.map(\.position)))
        widths = (0...90).map { i in
            let model = DiamondMath.rotation(x: DiamondMotion.referencePitch, y: Float(i) * .pi / 360)
            var left: Float = .infinity, right: Float = -.infinity
            for p in points {
                let x = DiamondMath.cameraPoint(model * p).x
                left = min(left, x)
                right = max(right, x)
            }
            return (right-left)/2
        }
    }

    func horizontalScale(yaw: Float, pitch: Float) -> Float {
        let quadrant = abs(yaw.remainder(dividingBy: .pi / 2))
        let sample = min(90, quadrant * 360 / .pi)
        let i = min(89, Int(sample)), t = sample - Float(i)
        let a = widths[i], b = widths[i+1]
        let da = i == 0 ? 0 : (b - widths[i-1]) / 2
        let db = i == 89 ? 0 : (widths[i+2] - a) / 2
        let width = a + t * (da + t * (3*(b-a) - 2*da - db + t*(2*(a-b) + da + db)))
        let turn = sin(2 * quadrant)
        let targetWidth = widths[0] * (1 - 0.035 * turn * turn)
        let tilt = min(1, max(0, (abs(sin(pitch)) - sin(Float(0.25)))
            / (sin(Float(0.96)) - sin(Float(0.25)))))
        let reveal = tilt * tilt * (3 - 2 * tilt)
        return 1 + (targetWidth / width - 1) * (1 - reveal)
    }
}

struct DiamondRenderData {
    let geometry: DiamondGeometry
    let sparkles: DiamondSparkleGeometry
    let anchors: [DiamondSparkleGeometry.Anchor]
    let silhouette: DiamondSilhouette
    let facetProjection: SIMD4<Float>
    let lensVertices: [SIMD4<Float>]

    init() {
        let geometry = DiamondGeometry()
        self.geometry = geometry
        self.sparkles = DiamondSparkleGeometry()
        self.anchors = DiamondSparkleGeometry.anchors(on: geometry)
        self.silhouette = DiamondSilhouette(geometry: geometry)
        self.facetProjection = {
            let model = DiamondMath.rotation(x: DiamondMotion.referencePitch, y: 0)
            let points = geometry.vertices.map { DiamondMath.cameraPoint(model * $0.position) }
            let width = points.reduce(Float(0)) { max($0, abs($1.x)) }
            let top = points.reduce(-Float.infinity) { max($0, $1.y) }
            return SIMD4(cos(DiamondMotion.referencePitch), sin(DiamondMotion.referencePitch), 223.95 / width, top)
        }()
        self.lensVertices = {
            var seen = Set<SIMD3<Int32>>()
            return geometry.vertices.compactMap { vertex in
                let p = vertex.position
                let key = SIMD3<Int32>(Int32((p.x * 40).rounded()), Int32((p.y * 40).rounded()), Int32((p.z * 40).rounded()))
                return seen.insert(key).inserted ? p : nil
            }
        }()
    }

    private static let cacheVersion = 1
    private static var cacheURL: URL {
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("GramDiamond_v\(self.cacheVersion)")
    }
    private static var cacheParameters: [Float] {
        return [
            Float(DiamondRounding.segments), DiamondRounding.edgeStep, Float(DiamondRounding.radialSteps),
            DiamondGeometry.roundingRadius, DiamondGeometry.crownRoundingRadius,
            DiamondGeometry.girdleRoundingRadius, DiamondGeometry.outlineBow,
            DiamondMotion.referencePitch, DiamondMath.cameraDistance, DiamondMath.cameraScale,
            Float(MemoryLayout<DiamondGeometry.Vertex>.stride), Float(MemoryLayout<DiamondSparkleGeometry.Vertex>.stride),
            Float(MemoryLayout<DiamondSparkleGeometry.Anchor>.stride), Float(MemoryLayout<SIMD4<Float>>.stride)
        ]
    }

    private struct Archive: Codable {
        let version: Int
        let parameters: [Float]
        let vertices: Data
        let planes: Data
        let mainSparkles: Data
        let smallSparkles: Data
        let streaks: Data
        let anchors: Data
        let widths: Data
        let facetProjection: Data
        let lensVertices: Data
    }

    private init(geometry: DiamondGeometry, sparkles: DiamondSparkleGeometry,
                 anchors: [DiamondSparkleGeometry.Anchor], silhouette: DiamondSilhouette,
                 facetProjection: SIMD4<Float>, lensVertices: [SIMD4<Float>]) {
        self.geometry = geometry
        self.sparkles = sparkles
        self.anchors = anchors
        self.silhouette = silhouette
        self.facetProjection = facetProjection
        self.lensVertices = lensVertices
    }

    static func load() -> DiamondRenderData? {
        guard let data = try? Data(contentsOf: Self.cacheURL, options: .mappedIfSafe), data.count <= 16 * 1024 * 1024,
              let archive = try? PropertyListDecoder().decode(Archive.self, from: data),
              archive.version == Self.cacheVersion, archive.parameters == Self.cacheParameters,
              let vertices = Self.array(archive.vertices, as: DiamondGeometry.Vertex.self), vertices.count.isMultiple(of: 3),
              let planes = Self.array(archive.planes, as: SIMD4<Float>.self), planes.count == 17,
              let main = Self.array(archive.mainSparkles, as: DiamondSparkleGeometry.Vertex.self), main.count.isMultiple(of: 3),
              let small = Self.array(archive.smallSparkles, as: DiamondSparkleGeometry.Vertex.self), small.count.isMultiple(of: 3),
              let streaks = Self.array(archive.streaks, as: DiamondSparkleGeometry.Vertex.self), streaks.count.isMultiple(of: 3),
              let anchors = Self.array(archive.anchors, as: DiamondSparkleGeometry.Anchor.self), anchors.count == 8,
              let widths = Self.array(archive.widths, as: Float.self), widths.count == 91,
              widths.allSatisfy({ $0.isFinite && $0 > 0 }),
              let projection = Self.array(archive.facetProjection, as: SIMD4<Float>.self), projection.count == 1,
              projection[0].x.isFinite, projection[0].y.isFinite, projection[0].z.isFinite, projection[0].z > 0, projection[0].w.isFinite,
              let lensVertices = Self.array(archive.lensVertices, as: SIMD4<Float>.self), lensVertices.count <= vertices.count else {
            return nil
        }
        return DiamondRenderData(
            geometry: DiamondGeometry(vertices: vertices, planes: planes),
            sparkles: DiamondSparkleGeometry(main: main, small: small, streakVertices: streaks),
            anchors: anchors, silhouette: DiamondSilhouette(widths: widths),
            facetProjection: projection[0], lensVertices: lensVertices
        )
    }

    func store() {
        DispatchQueue.global(qos: .utility).async {
            let archive = Archive(
                version: Self.cacheVersion, parameters: Self.cacheParameters,
                vertices: Self.bytes(self.geometry.vertices), planes: Self.bytes(self.geometry.planes),
                mainSparkles: Self.bytes(self.sparkles.main), smallSparkles: Self.bytes(self.sparkles.small),
                streaks: Self.bytes(self.sparkles.streakVertices), anchors: Self.bytes(self.anchors),
                widths: Self.bytes(self.silhouette.widths), facetProjection: Self.bytes([self.facetProjection]),
                lensVertices: Self.bytes(self.lensVertices)
            )
            do {
                let encoder = PropertyListEncoder()
                encoder.outputFormat = .binary
                let data = try encoder.encode(archive)
                let url = Self.cacheURL
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
                try data.write(to: url, options: .atomic)
            } catch {
                // The cache is optional; render data will be regenerated if needed.
            }
        }
    }

    // Only used for Float and structs containing SIMD4<Float>; no reference-valued fields.
    private static func bytes<T>(_ values: [T]) -> Data {
        return values.withUnsafeBytes { Data($0) }
    }

    private static func array<T>(_ data: Data, as type: T.Type) -> [T]? {
        let stride = MemoryLayout<T>.stride
        guard !data.isEmpty, data.count.isMultiple(of: stride) else { return nil }
        return Array(unsafeUninitializedCapacity: data.count / stride) { buffer, initializedCount in
            _ = data.copyBytes(to: UnsafeMutableRawBufferPointer(start: buffer.baseAddress, count: data.count))
            initializedCount = buffer.count
        }
    }
}

enum DiamondMath {
    static let cameraDistance: Float = 6
    static let cameraScale: Float = 0.948985

    static func cameraW(z: Float) -> Float {
        (1 - z / cameraDistance) / cameraScale
    }

    static func cameraPoint(_ world: SIMD4<Float>) -> SIMD2<Float> {
        SIMD2(world.x, world.y) / cameraW(z: world.z)
    }

    static func cameraRay(at point: SIMD2<Float>) -> (origin: SIMD4<Float>, direction: SIMD4<Float>) {
        (SIMD4(0, 0, cameraDistance, 1),
         SIMD4(simd_normalize(SIMD3(point.x / cameraScale, point.y / cameraScale, -cameraDistance)), 0))
    }

    static func rotation(x: Float, y: Float) -> simd_float4x4 {
        let pitch = simd_quatf(angle: x, axis: SIMD3(1, 0, 0))
        let yaw = simd_quatf(angle: y, axis: SIMD3(0, 1, 0))
        return simd_float4x4(pitch * yaw)
    }

    static func projection(aspect: Float, zoom: Float, perspective: Bool = true) -> simd_float4x4 {
        let halfHeight = Float(1.52) / zoom * max(1, 1 / max(aspect, 0.01))
        let halfWidth = halfHeight * aspect
        if perspective {
            let w0 = 1 / cameraScale, wz = -w0 / cameraDistance
            let framing = 0.12 / halfHeight
            return simd_float4x4(columns: (
                SIMD4(1 / halfWidth, 0, 0, 0), SIMD4(0, 1 / halfHeight, 0, 0),
                SIMD4(0, framing*wz, -w0/6, wz), SIMD4(0, framing*w0, 0.5*w0, w0)
            ))
        }
        return simd_float4x4(columns: (
            SIMD4(1 / halfWidth, 0, 0, 0), SIMD4(0, 1 / halfHeight, 0, 0),
            SIMD4(0, 0, -1 / 12, 0), SIMD4(0, 0.12 / halfHeight, 0.5, 1)
        ))
    }
}
