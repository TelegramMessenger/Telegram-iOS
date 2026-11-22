import Foundation
import UIKit

private let pointsCount: Int = 64
private let squareSize: Double = 250.0
private let diagonal = sqrt(squareSize * squareSize + squareSize * squareSize)
private let halfDiagonal = diagonal * 0.5
private let angleRange: Double = .pi / 4.0
private let anglePrecision: Double = .pi / 90.0

class Unistroke {
    let points: [CGPoint]
    
    init(points: [CGPoint]) {
        var points = resample(points: points, totalPoints: pointsCount)
        let radians = indicativeAngle(points: points)
        points = rotate(points: points, byRadians: -radians)
        points = scale(points: points, toSize: squareSize)
        points = translate(points: points, to: .zero)
        self.points = points
    }
    
    func match(templates: [UnistrokeTemplate], minThreshold: Double = 0.8) -> String? {
        var bestDistance = Double.infinity
        var bestTemplate: UnistrokeTemplate?
        for template in templates {
            let templateDistance = distanceAtBestAngle(points: self.points, strokeTemplate: template.points, fromAngle: -angleRange, toAngle: angleRange, threshold: anglePrecision)
            if templateDistance < bestDistance {
                bestDistance = templateDistance
                bestTemplate = template
            }
        }
        
        if let bestTemplate = bestTemplate {
            bestDistance = 1.0 - bestDistance / halfDiagonal
            if bestDistance < minThreshold {
                return nil
            }
            return bestTemplate.name
        } else {
            return nil
        }
    }
}

class UnistrokeTemplate : Unistroke {
    var name: String
    
    init(name: String, points: [CGPoint]) {
        self.name = name
        super.init(points: points)
    }
}

private struct Edge {
    var minX: Double
    var minY: Double
    var maxX: Double
    var maxY: Double
    
    init(minX: Double, maxX: Double, minY: Double, maxY: Double) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }
    
    mutating func addPoint(value: CGPoint) {
        self.minX = min(self.minX,value.x)
        self.maxX = max(self.maxX,value.x)
        self.minY = min(self.minY,value.y)
        self.maxY = max(self.maxY,value.y)
    }

}

private extension Double {
    func toRadians() -> Double {
        let res = self * .pi / 180.0
        return res
    }
}

private func resample(points: [CGPoint], totalPoints: Int) -> [CGPoint] {
    var initialPoints = points
    let interval = pathLength(points: initialPoints) / Double(totalPoints - 1)
    var totalLength: Double = 0.0
    var newPoints: [CGPoint] = [points[0]]
    for i in 1 ..< initialPoints.count {
        let currentLength = initialPoints[i - 1].distance(to: initialPoints[i])
        if totalLength + currentLength >= interval {
            let newPoint = CGPoint(
                x: initialPoints[i - 1].x + ((interval - totalLength) / currentLength) * (initialPoints[i].x - initialPoints[i - 1].x),
                y: initialPoints[i - 1].y + ((interval - totalLength) / currentLength) * (initialPoints[i].y - initialPoints[i - 1].y)
            )
            newPoints.append(newPoint)
            initialPoints.insert(newPoint, at: i)
            totalLength = 0.0
        } else {
            totalLength += currentLength
        }
    }
    if newPoints.count == totalPoints - 1 {
        newPoints.append(points.last!)
    }
    return newPoints
}

private func pathLength(points: [CGPoint]) -> Double {
    var distance: Double = 0.0
    for index in 1 ..< points.count {
        distance += points[index - 1].distance(to: points[index])
    }
    return distance
}

private func pathDistance(path1: [CGPoint], path2: [CGPoint]) -> Double {
    var d: Double = 0.0
    for idx in 0 ..< min(path1.count, path2.count) {
        d += path1[idx].distance(to: path2[idx])
    }
    return d / Double(path1.count)
}

private func centroid(points: [CGPoint]) -> CGPoint {
    var centroidPoint: CGPoint = .zero
    for point in points {
        centroidPoint.x = centroidPoint.x + point.x
        centroidPoint.y = centroidPoint.y + point.y
    }
    centroidPoint.x = (centroidPoint.x / Double(points.count))
    centroidPoint.y = (centroidPoint.y / Double(points.count))
    return centroidPoint
}

private func boundingBox(points: [CGPoint]) -> CGRect {
    var edge = Edge(minX: +Double.infinity, maxX: -Double.infinity, minY: +Double.infinity, maxY: -Double.infinity)
    for point in points {
        edge.addPoint(value: point)
    }
    return CGRect(x: edge.minX, y: edge.minY, width: (edge.maxX - edge.minX), height: (edge.maxY - edge.minY))
}

private func rotate(points: [CGPoint], byRadians radians: Double) -> [CGPoint] {
    let centroid = centroid(points: points)
    let cosinus = cos(radians)
    let sinus = sin(radians)
    var result: [CGPoint] = []
    for point in points {
        result.append(
            CGPoint(
                x: (point.x - centroid.x) * cosinus - (point.y - centroid.y) * sinus + centroid.x,
                y: (point.x - centroid.x) * sinus + (point.y - centroid.y) * cosinus + centroid.y
            )
        )
    }
    return result
}

private func scale(points: [CGPoint], toSize size: Double) -> [CGPoint] {
    let boundingBox = boundingBox(points: points)
    var result: [CGPoint] = []
    for point in points {
        result.append(
            CGPoint(
                x: point.x * (size / boundingBox.width),
                y: point.y * (size / boundingBox.height)
            )
        )
    }
    return result
}

private func translate(points: [CGPoint], to pt: CGPoint) -> [CGPoint] {
    let centroidPoint = centroid(points: points)
    var newPoints: [CGPoint] = []
    for point in points {
        newPoints.append(
            CGPoint(
                x: point.x + pt.x - centroidPoint.x,
                y: point.y + pt.y - centroidPoint.y
            )
        )
    }
    return newPoints
}

private func vectorize(points: [CGPoint]) -> [Double] {
    var sum: Double = 0.0
    var vector: [Double] = []
    for point in points {
        vector.append(point.x)
        vector.append(point.y)
        sum += (point.x * point.x) + (point.y * point.y)
    }
    let magnitude = sqrt(sum)
    for i in 0 ..< vector.count {
        vector[i] = vector[i] / magnitude
    }
    return vector
}

private func indicativeAngle(points: [CGPoint]) -> Double {
    let centroid = centroid(points: points)
    return atan2(centroid.y - points[0].y, centroid.x - points[0].x)
}

private func distanceAtBestAngle(points: [CGPoint], strokeTemplate: [CGPoint], fromAngle: Double, toAngle: Double, threshold: Double) -> Double {
    func distanceAtAngle(points: [CGPoint], strokeTemplate: [CGPoint], radians: Double) -> Double {
        let rotatedPoints = rotate(points: points, byRadians: radians)
        return pathDistance(path1: rotatedPoints, path2: strokeTemplate)
    }
    
    let phi: Double = (0.5 * (-1.0 + sqrt(5.0)))
    
    var fromAngle = fromAngle
    var toAngle = toAngle
    
    var x1 = phi * fromAngle + (1.0 - phi) * toAngle
    var f1 = distanceAtAngle(points: points, strokeTemplate: strokeTemplate, radians: x1)
    
    var x2 = (1.0 - phi) * fromAngle + phi * toAngle
    var f2 = distanceAtAngle(points: points, strokeTemplate: strokeTemplate, radians: x2)
    
    while abs(toAngle - fromAngle) > threshold {
        if f1 < f2 {
            toAngle = x2
            x2 = x1
            f2 = f1
            x1 = phi * fromAngle + (1.0 - phi) * toAngle
            f1 = distanceAtAngle(points: points, strokeTemplate: strokeTemplate, radians: x1)
        } else {
            fromAngle = x1
            x1 = x2
            f1 = f2
            x2 = (1.0 - phi) * fromAngle + phi * toAngle
            f2 = distanceAtAngle(points: points, strokeTemplate: strokeTemplate, radians: x2)
        }
    }
    return min(f1, f2)
}
