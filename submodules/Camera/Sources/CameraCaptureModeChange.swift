import Foundation

public let cameraCaptureModeChangeTimeout: Double = 1.0

public final class CameraOneShot {
    private let lock = NSLock()
    private var isClaimed = false

    public init() {
    }

    public func claim() -> Bool {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        if self.isClaimed {
            return false
        }
        self.isClaimed = true
        return true
    }
}

public struct CameraCaptureModeChangeGeneration {
    private var current: Int = 0

    public init() {
    }

    public mutating func next() -> Int {
        self.current += 1
        return self.current
    }

    public func isCurrent(_ generation: Int) -> Bool {
        return self.current == generation
    }
}
