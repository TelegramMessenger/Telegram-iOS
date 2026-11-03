import Foundation

private func intersect(seg1: [CGPoint], seg2: [CGPoint]) -> Bool {
    func ccw(_ seg1: CGPoint, _ seg2: CGPoint, _ seg3: CGPoint) -> Bool {
        let ccw = ((seg3.y - seg1.y) * (seg2.x - seg1.x)) - ((seg2.y - seg1.y) * (seg3.x - seg1.x))
        return ccw > 0 ? true : ccw < 0 ? false : true
    }
    let segment1 = seg1[0]
    let segment2 = seg1[1]
    let segment3 = seg2[0]
    let segment4 = seg2[1]
    return ccw(segment1, segment3, segment4) != ccw(segment2, segment3, segment4)
        && ccw(segment1, segment2, segment3) != ccw(segment1, segment2, segment4)
}

private func convex(points: [CGPoint]) -> [CGPoint] {
    func cross(_ o: CGPoint, _ a: CGPoint, _ b: CGPoint) -> Double {
        return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
    }

    func upperTangent(_ points: [CGPoint]) -> [CGPoint] {
        var lower: [CGPoint] = []
        for point in points {
            while lower.count >= 2 && (cross(lower[lower.count - 2], lower[lower.count - 1], point) <= 0) {
                _ = lower.popLast()
            }
            lower.append(point)
        }
        _ = lower.popLast()
        return lower
    }

    func lowerTangent(_ points: [CGPoint]) -> [CGPoint] {
        let reversed = points.reversed()
        var upper: [CGPoint] = []
        for point in reversed {
            while upper.count >= 2 && (cross(upper[upper.count - 2], upper[upper.count - 1], point) <= 0) {
                _ = upper.popLast()
            }
            upper.append(point)
        }
        _ = upper.popLast()
        return upper
    }
    
    var convex: [CGPoint] = []
    convex.append(contentsOf: upperTangent(points))
    convex.append(contentsOf: lowerTangent(points))
    return convex
}

private class Grid {
    var cells = [Int: [Int: [CGPoint]]]()
    var cellSize: Double = 0

    init(_ points: [CGPoint], _ cellSize: Double) {
        self.cellSize = cellSize
        for point in points {
            let cellXY = point2CellXY(point)
            let x = cellXY[0]
            let y = cellXY[1]
            if self.cells[x] == nil {
                self.cells[x] = [Int: [CGPoint]]()
            }
            if self.cells[x]![y] == nil {
                self.cells[x]![y] = [CGPoint]()
            }
            self.cells[x]![y]!.append(point)
        }
    }

    func point2CellXY(_ point: CGPoint) -> [Int] {
        let x = Int(point.x / self.cellSize)
        let y = Int(point.y / self.cellSize)
        return [x, y]
    }

    func extendBbox(_ bbox: [Double], _ scaleFactor: Double) -> [Double] {
        return [
            bbox[0] - (scaleFactor * self.cellSize),
            bbox[1] - (scaleFactor * self.cellSize),
            bbox[2] + (scaleFactor * self.cellSize),
            bbox[3] + (scaleFactor * self.cellSize)
        ]
    }

    func removePoint(_ point: CGPoint) {
        let cellXY = point2CellXY(point)
        let cell = self.cells[cellXY[0]]![cellXY[1]]!
        var pointIdxInCell = 0
        for idx in 0 ..< cell.count {
            if cell[idx].x == point.x && cell[idx].y == point.y {
                pointIdxInCell = idx
                break
            }
        }
        self.cells[cellXY[0]]![cellXY[1]]!.remove(at: pointIdxInCell)
    }

    func rangePoints(_ bbox: [Double]) -> [CGPoint] {
        let tlCellXY = point2CellXY(CGPoint(x: bbox[0], y: bbox[1]))
        let brCellXY = point2CellXY(CGPoint(x: bbox[2], y: bbox[3]))
        var points: [CGPoint] = []
        for x in tlCellXY[0]..<brCellXY[0]+1 {
            for y in tlCellXY[1]..<brCellXY[1]+1 {
                points += cellPoints(x, y)
            }
        }
        return points
    }

    func cellPoints(_ xAbs: Int, _ yOrd: Int) -> [CGPoint] {
        if let x = self.cells[xAbs] {
            if let y = x[yOrd] {
                return y
            }
        }
        return []
    }

}

private let maxConcaveAngleCos = cos(90.0 / (180.0 / Double.pi))

private func filterDuplicates(_ pointSet: [CGPoint]) -> [CGPoint] {
    let sortedSet = sortByX(pointSet)
    return sortedSet.filter { (point: CGPoint) -> Bool in
        let index = pointSet.firstIndex(where: {(idx: CGPoint) -> Bool in
            return idx.x == point.x && idx.y == point.y
        })
        if index == 0 {
            return true
        } else {
            let prevEl = pointSet[index! - 1]
            if prevEl.x != point.x || prevEl.y != point.y {
                return true
            }
            return false
        }
    }
}

private func sortByX(_ pointSet: [CGPoint]) -> [CGPoint] {
    return pointSet.sorted(by: { (lhs, rhs) -> Bool in
        if lhs.x == rhs.x {
            return lhs.y < rhs.y
        } else {
            return lhs.x < rhs.x
        }
    })
}

private func squaredLength(_ a: CGPoint, _ b: CGPoint) -> Double {
    return pow(b.x - a.x, 2) + pow(b.y - a.y, 2)
}

private func cosFunc(_ o: CGPoint, _ a: CGPoint, _ b: CGPoint) -> Double {
    let aShifted = [a.x - o.x, a.y - o.y]
    let bShifted = [b.x - o.x, b.y - o.y]
    let sqALen = squaredLength(o, a)
    let sqBLen = squaredLength(o, b)
    let dot = aShifted[0] * bShifted[0] + aShifted[1] * bShifted[1]
    return dot / sqrt(sqALen * sqBLen)
}

private func intersectFunc(_ segment: [CGPoint], _ pointSet: [CGPoint]) -> Bool {
    for idx in 0..<pointSet.count - 1 {
        let seg = [pointSet[idx], pointSet[idx + 1]]
        if segment[0].x == seg[0].x && segment[0].y == seg[0].y ||
            segment[0].x == seg[1].x && segment[0].y == seg[1].y {
            continue
        }
        if intersect(seg1: segment, seg2: seg) {
            return true
        }
    }
    return false
}

private func occupiedAreaFunc(_ points: [CGPoint]) -> CGPoint {
    var minX = Double.infinity
    var minY = Double.infinity
    var maxX = -Double.infinity
    var maxY = -Double.infinity
    for idx in 0 ..< points.reversed().count {
        if points[idx].x < minX {
            minX = points[idx].x
        }
        if points[idx].y < minY {
            minY = points[idx].y
        }
        if points[idx].x > maxX {
            maxX = points[idx].x
        }
        if points[idx].y > maxY {
            maxY = points[idx].y
        }
    }
    return CGPoint(x: maxX - minX, y: maxY - minY)
}

private func bBoxAroundFunc(_ edge: [CGPoint]) -> [Double] {
    return [min(edge[0].x, edge[1].x),
            min(edge[0].y, edge[1].y),
            max(edge[0].x, edge[1].x),
            max(edge[0].y, edge[1].y)]
}

private func midPointFunc(_ edge: [CGPoint], _ innerPoints: [CGPoint], _ convex: [CGPoint]) -> CGPoint? {
    var point: CGPoint?
    var angle1Cos = maxConcaveAngleCos
    var angle2Cos = maxConcaveAngleCos
    var a1Cos: Double = 0
    var a2Cos: Double = 0
    for innerPoint in innerPoints {
        a1Cos = cosFunc(edge[0], edge[1], innerPoint)
        a2Cos = cosFunc(edge[1], edge[0], innerPoint)
        if a1Cos > angle1Cos &&
            a2Cos > angle2Cos &&
            !intersectFunc([edge[0], innerPoint], convex) &&
            !intersectFunc([edge[1], innerPoint], convex) {
            angle1Cos = a1Cos
            angle2Cos = a2Cos
            point = innerPoint
        }
    }
    return point
}

private func concaveFunc(_ convex: inout [CGPoint], _ maxSqEdgeLen: Double, _ maxSearchArea: [Double], _ grid: Grid, _ edgeSkipList: inout [String: Bool]) -> [CGPoint] {
    var edge: [CGPoint]
    var keyInSkipList: String = ""
    var scaleFactor: Double
    var midPoint: CGPoint?
    var bBoxAround: [Double]
    var bBoxWidth: Double = 0
    var bBoxHeight: Double = 0
    var midPointInserted: Bool = false

    for idx in 0..<convex.count - 1 {
        edge = [convex[idx], convex[idx+1]]
        keyInSkipList = edge[0].key.appending(", ").appending(edge[1].key)

        scaleFactor = 0
        bBoxAround = bBoxAroundFunc(edge)

        if squaredLength(edge[0], edge[1]) < maxSqEdgeLen || edgeSkipList[keyInSkipList] == true {
            continue
        }

        repeat {
            bBoxAround = grid.extendBbox(bBoxAround, scaleFactor)
            bBoxWidth = bBoxAround[2] - bBoxAround[0]
            bBoxHeight = bBoxAround[3] - bBoxAround[1]
            midPoint = midPointFunc(edge, grid.rangePoints(bBoxAround), convex)
            scaleFactor += 1
        } while midPoint == nil && (maxSearchArea[0] > bBoxWidth || maxSearchArea[1] > bBoxHeight)

        if bBoxWidth >= maxSearchArea[0] && bBoxHeight >= maxSearchArea[1] {
            edgeSkipList[keyInSkipList] = true
        }
        if let midPoint = midPoint {
            convex.insert(midPoint, at: idx + 1)
            grid.removePoint(midPoint)
            midPointInserted = true
        }
    }

    if midPointInserted {
        return concaveFunc(&convex, maxSqEdgeLen, maxSearchArea, grid, &edgeSkipList)
    }

    return convex
}

private extension CGPoint {
    var key: String {
        return "\(self.x),\(self.y)"
    }
}

func getHull(_ points: [CGPoint], concavity: Double) -> [CGPoint] {
    let points = filterDuplicates(points)
    let occupiedArea = occupiedAreaFunc(points)
    let maxSearchArea: [Double] = [
        occupiedArea.x * 0.6,
        occupiedArea.y * 0.6
    ]

    var convex = convex(points: points)

    var innerPoints = points.filter { (point: CGPoint) -> Bool in
        let idx = convex.firstIndex(where: { (idx: CGPoint) -> Bool in
            return idx.x == point.x && idx.y == point.y
        })
        return idx == nil
    }

    innerPoints.sort(by: { (lhs: CGPoint, rhs: CGPoint) -> Bool in
        return lhs.x == rhs.x ? lhs.y > rhs.y : lhs.x > rhs.x
    })

    let cellSize = ceil(occupiedArea.x * occupiedArea.y / Double(points.count))
    let grid = Grid(innerPoints, cellSize)

    var skipList: [String: Bool] = [String: Bool]()
    return concaveFunc(&convex, pow(concavity, 2), maxSearchArea, grid, &skipList)
}
