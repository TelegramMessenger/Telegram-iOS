import Foundation
import MetalKit
import LottieCpp

final class PathRenderBuffer {
    private(set) var memory: UnsafeMutableRawPointer
    private(set) var capacity: Int = 8 * 1024 * 1024
    private(set) var length: Int = 0
    
    init() {
        self.memory = malloc(self.capacity)!
    }
    
    func reset() {
        self.length = 0
    }
    
    func append(bytes: UnsafeRawPointer, length: Int) {
        assert(length % 4 == 0)
        
        if self.length + length > self.capacity {
            self.capacity = self.capacity * 2
            preconditionFailure()
        }
        memcpy(self.memory.advanced(by: self.length), bytes, length)
        self.length += length
    }
    
    func appendZero(count: Int) {
        if self.length + length > self.capacity {
            self.capacity = self.capacity * 2
            preconditionFailure()
        }
        self.length += count
    }
    
    func append(float: Float) {
        var value: Float = float
        self.append(bytes: &value, length: 4)
    }
    
    func append(float2: SIMD2<Float>) {
        var value: SIMD2<Float> = float2
        self.append(bytes: &value, length: 4 * 2)
    }
    
    func append(float3: SIMD3<Float>) {
        var value = float3.x
        self.append(bytes: &value, length: 4)
        value = float3.y
        self.append(bytes: &value, length: 4)
        value = float3.z
        self.append(bytes: &value, length: 4)
    }
    
    func append(int: Int32) {
        var value = int
        self.append(bytes: &value, length: 4)
    }
    
    func appendBezierData(
        bufferOffset: Int,
        start: SIMD2<Float>,
        end: SIMD2<Float>,
        cp1: SIMD2<Float>,
        cp2: SIMD2<Float>,
        offset: Float
    ) {
        self.append(int: Int32(bufferOffset))
        self.append(float2: start)
        self.append(float2: end)
        self.append(float2: cp1)
        self.append(float2: cp2)
        self.append(float: offset)
    }
}

