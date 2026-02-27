import Foundation
import RangeSet
import Crc32

final class MediaBoxFileMap {
    enum FileMapError: Error {
        case generic
    }
    
    private(set) var sum: Int64
    private(set) var ranges: RangeSet<Int64>
    private(set) var truncationSize: Int64?
    private(set) var progress: Float?

    init() {
        self.sum = 0
        self.ranges = RangeSet<Int64>()
        self.truncationSize = nil
        self.progress = nil
    }
    
    private init(
        sum: Int64,
        ranges: RangeSet<Int64>,
        truncationSize: Int64?,
        progress: Float?
    ) {
        self.sum = sum
        self.ranges = ranges
        self.truncationSize = truncationSize
        self.progress = progress
    }
    
    static func read(manager: MediaBoxFileManager, path: String) throws -> MediaBoxFileMap {
        guard let length = fileSize(path) else {
            throw FileMapError.generic
        }
        guard let fileItem = manager.open(path: path, mode: .readwrite) else {
            throw FileMapError.generic
        }
        
        var result: MediaBoxFileMap?
        
        try fileItem.access { fd in
            var firstUInt32: UInt32 = 0
            guard fd.read(&firstUInt32, 4) == 4 else {
                throw FileMapError.generic
            }
            
            if firstUInt32 == 0x7bac1487 {
                var crc: UInt32 = 0
                guard fd.read(&crc, 4) == 4 else {
                    throw FileMapError.generic
                }
                
                var count: Int32 = 0
                var sum: Int64 = 0
                var ranges = RangeSet<Int64>()
                
                guard fd.read(&count, 4) == 4 else {
                    throw FileMapError.generic
                }
                
                if count < 0 {
                    throw FileMapError.generic
                }
                
                if count < 0 || length < 4 + 4 + 4 + 8 + count * 2 * 8 {
                    throw FileMapError.generic
                }
                
                var truncationSizeValue: Int64 = 0
                
                var data = Data(count: Int(8 + count * 2 * 8))
                let dataCount = data.count
                if !(data.withUnsafeMutableBytes { rawBytes -> Bool in
                    let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)

                    guard fd.read(bytes, dataCount) == dataCount else {
                        return false
                    }
                    
                    memcpy(&truncationSizeValue, bytes, 8)
                    
                    let calculatedCrc = Crc32(bytes, Int32(dataCount))
                    if calculatedCrc != crc {
                        return false
                    }
                    
                    var offset = 8
                    for _ in 0 ..< count {
                        var intervalOffset: Int64 = 0
                        var intervalLength: Int64 = 0
                        memcpy(&intervalOffset, bytes.advanced(by: offset), 8)
                        memcpy(&intervalLength, bytes.advanced(by: offset + 8), 8)
                        offset += 8 * 2
                        
                        ranges.insert(contentsOf: intervalOffset ..< (intervalOffset + intervalLength))
                        
                        sum += intervalLength
                    }
                    
                    return true
                }) {
                    throw FileMapError.generic
                }
                
                let mappedTruncationSize: Int64?
                if truncationSizeValue == -1 {
                    mappedTruncationSize = nil
                } else if truncationSizeValue < 0 {
                    mappedTruncationSize = nil
                } else {
                    mappedTruncationSize = truncationSizeValue
                }

                result = MediaBoxFileMap(
                    sum: sum,
                    ranges: ranges,
                    truncationSize: mappedTruncationSize,
                    progress: nil
                )
            } else {
                let crc: UInt32 = firstUInt32
                var count: Int32 = 0
                var sum: Int32 = 0
                var ranges = RangeSet<Int64>()
                
                guard fd.read(&count, 4) == 4 else {
                    throw FileMapError.generic
                }
                
                if count < 0 {
                    throw FileMapError.generic
                }
                
                if count < 0 || UInt64(length) < 4 + 4 + UInt64(count) * 2 * 4 {
                    throw FileMapError.generic
                }
                
                var truncationSizeValue: Int32 = 0
                
                var data = Data(count: Int(4 + count * 2 * 4))
                let dataCount = data.count
                if !(data.withUnsafeMutableBytes { rawBytes -> Bool in
                    let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)

                    guard fd.read(bytes, dataCount) == dataCount else {
                        return false
                    }
                    
                    memcpy(&truncationSizeValue, bytes, 4)
                    
                    let calculatedCrc = Crc32(bytes, Int32(dataCount))
                    if calculatedCrc != crc {
                        return false
                    }
                    
                    var offset = 4
                    for _ in 0 ..< count {
                        var intervalOffset: Int32 = 0
                        var intervalLength: Int32 = 0
                        memcpy(&intervalOffset, bytes.advanced(by: offset), 4)
                        memcpy(&intervalLength, bytes.advanced(by: offset + 4), 4)
                        offset += 8
                        
                        ranges.insert(contentsOf: Int64(intervalOffset) ..< Int64(intervalOffset + intervalLength))
                        
                        sum += intervalLength
                    }
                    
                    return true
                }) {
                    throw FileMapError.generic
                }
                
                let mappedTruncationSize: Int64?
                if truncationSizeValue == -1 {
                    mappedTruncationSize = nil
                } else {
                    mappedTruncationSize = Int64(truncationSizeValue)
                }
                
                result = MediaBoxFileMap(
                    sum: Int64(sum),
                    ranges: ranges,
                    truncationSize: mappedTruncationSize,
                    progress: nil
                )
            }
        }
        
        guard let result = result else {
            throw FileMapError.generic
        }
        return result
    }
    
    func serialize(manager: MediaBoxFileManager, to path: String) {
        guard let fileItem = manager.open(path: path, mode: .readwrite) else {
            postboxLog("MediaBoxFile: serialize: cannot open file")
            return
        }
        
        let _ = try? fileItem.access { file in
            let _ = file.seek(position: 0)
            let buffer = WriteBuffer()
            var magic: UInt32 = 0x7bac1487
            buffer.write(&magic, offset: 0, length: 4)
            
            var zero: Int32 = 0
            buffer.write(&zero, offset: 0, length: 4)
            
            let rangeView = self.ranges.ranges
            var count: Int32 = Int32(rangeView.count)
            buffer.write(&count, offset: 0, length: 4)
            
            var truncationSizeValue: Int64 = self.truncationSize ?? -1
            buffer.write(&truncationSizeValue, offset: 0, length: 8)
            
            for range in rangeView {
                var intervalOffset = range.lowerBound
                var intervalLength = range.upperBound - range.lowerBound
                buffer.write(&intervalOffset, offset: 0, length: 8)
                buffer.write(&intervalLength, offset: 0, length: 8)
            }
            var crc: UInt32 = Crc32(buffer.memory.advanced(by: 4 + 4 + 4), Int32(buffer.length - (4 + 4 + 4)))
            memcpy(buffer.memory.advanced(by: 4), &crc, 4)
            let written = file.write(buffer.memory, count: buffer.length)
            assert(written == buffer.length)
        }
    }
    
    func fill(_ range: Range<Int64>) {
        var previousCount: Int64 = 0
        for intersectionRange in self.ranges.intersection(RangeSet<Int64>(range)).ranges {
            previousCount += intersectionRange.upperBound - intersectionRange.lowerBound
        }
        
        self.ranges.insert(contentsOf: range)
        self.sum += (range.upperBound - range.lowerBound) - previousCount
    }
    
    func truncate(_ size: Int64) {
        self.truncationSize = size
    }
    func progressUpdated(_ progress: Float) {
        self.progress = progress
    }
    
    func reset() {
        self.truncationSize = nil
        self.ranges = RangeSet<Int64>()
        self.sum = 0
        self.progress = nil
    }
    
    func contains(_ range: Range<Int64>) -> Range<Int64>? {
        let maxValue: Int64
        if let truncationSize = self.truncationSize {
            maxValue = truncationSize
        } else {
            maxValue = Int64.max
        }
        let clippedUpperBound = min(maxValue, range.upperBound)
        let clippedRange: Range<Int64> = min(range.lowerBound, clippedUpperBound) ..< clippedUpperBound
        let clippedRangeSet = RangeSet<Int64>(clippedRange)
        
        if self.ranges.isSuperset(of: clippedRangeSet) {
            return clippedRange
        } else {
            return nil
        }
    }
}
