import Foundation

func interpolateFloat(_ value1: Float, _ value2: Float, at factor: Float) -> Float {
    return value1 * (1.0 - factor) + value2 * factor
}

func interpolatePoints(_ point1: SIMD2<Float>, _ point2: SIMD2<Float>, at factor: Float) -> SIMD2<Float> {
    return SIMD2<Float>(x: interpolateFloat(point1.x, point2.x, at: factor), y: interpolateFloat(point1.y, point2.y, at: factor))
}
