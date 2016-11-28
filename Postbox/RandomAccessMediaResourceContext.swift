import Foundation
#if os(macOS)
    import SwiftSignalKitMac
#else
    import SwiftSignalKit
#endif

public struct RandomAccessResourceStoreRange {
    fileprivate let offset: Int
    fileprivate let data: Data
    
    public init(offset: Int, data: Data) {
        self.offset = offset
        self.data = data
    }
}

public enum RandomAccessResourceDataRangeMode {
    case Complete
    case Partial
    case Incremental
    case None
}

private final class RandomAccessBlockRangeListener: Hashable {
    fileprivate let id: Int32
    private let range: Range<Int>
    private let blockSize: Int
    private let blocks: Range<Int>
    private let mode: RandomAccessResourceDataRangeMode
    private let updated: (Data) -> Void
    
    fileprivate var missingBlocks: Set<Int>
    
    init(id: Int32, range: Range<Int>, blockSize: Int, blocks: Range<Int>, missingBlocks: Set<Int>, mode: RandomAccessResourceDataRangeMode, updated: @escaping(Data) -> Void) {
        self.id = id
        self.range = range
        self.blockSize = blockSize
        self.blocks = blocks
        self.mode = mode
        self.updated = updated
        self.missingBlocks = missingBlocks
    }
    
    var hashValue: Int {
        return Int(self.id)
    }
    
    func updateMissingBlocks(addedBlocks: Set<Int>, fetchData: (Range<Int>) -> Data) {
        if self.missingBlocks.isEmpty {
            return
        }
        
        switch self.mode {
            case .Complete:
                self.missingBlocks.subtract(addedBlocks)
                if self.missingBlocks.isEmpty {
                    self.updated(fetchData(self.range))
                }
            case .Incremental, .Partial:
                var continuousBlockCount = 0
                for index in CountableRange(self.blocks) {
                    if self.missingBlocks.contains(index) {
                        break
                    }
                    continuousBlockCount += 1
                }
                
                self.missingBlocks.subtract(addedBlocks)
                
                var updatedContinuousBlockCount = 0
                for index in CountableRange(self.blocks) {
                    if self.missingBlocks.contains(index) {
                        break
                    }
                    updatedContinuousBlockCount += 1
                }
                
                if updatedContinuousBlockCount > continuousBlockCount {
                    if self.mode == .Partial {
                        self.updated(fetchData(self.range))
                    } else {
                        let firstBlock = self.blocks.lowerBound + continuousBlockCount
                        let lastBlock = self.blocks.lowerBound + updatedContinuousBlockCount
                        
                        var startOffset = firstBlock * self.blockSize
                        if firstBlock == 0 {
                            startOffset = self.range.lowerBound
                        }
                        var endOffset = lastBlock * self.blockSize
                        if lastBlock == self.blocks.upperBound {
                            endOffset = self.range.upperBound
                        }
                        
                        self.updated(fetchData(startOffset ..< endOffset))
                    }
                }
            case .None:
                break
        }
    }
}

private func ==(lhs: RandomAccessBlockRangeListener, rhs: RandomAccessBlockRangeListener) -> Bool {
    return lhs.id == rhs.id
}

private struct FetchRange: Hashable {
    let range: Range<Int>
    
    var hashValue: Int {
        return self.range.lowerBound ^ self.range.upperBound
    }
}

private func ==(lhs: FetchRange, rhs: FetchRange) -> Bool {
    return lhs.range == rhs.range
}

public final class RandomAccessMediaResourceContext {
    private let path: String
    private let size: Int
    
    private var file: MappedFile
    private var readyBlocks = Set<Int>()
    let blockSize: Int
    private let fragmentBlockCount: Int
    let blockCount: Int
    
    private var nextBlockRangeListenerId: Int32 = 0
    private var blockRangeListenersByBlockIndex: [Int: [RandomAccessBlockRangeListener]] = [:]
    private var blockRangeListenerSet: [Int32: RandomAccessBlockRangeListener] = [:]
    private var fetchedBlockRangeListenerSet: [Int32: Range<Int>] = [:]
    
    private var fetchRanges = Set<FetchRange>()
    private var fetchDisposables: [FetchRange: Disposable] = [:]
    
    private var fetchRange: (Range<Int>) -> Disposable
    
    public init(path: String, size: Int, fetchRange: @escaping(Range<Int>) -> Disposable) {
        self.path = path
        self.size = size
        self.fetchRange = fetchRange
        
        let metadataPath = path + ".meta"
        self.file = MappedFile(path: metadataPath)
        
        self.blockSize = 64 * 1024
        self.fragmentBlockCount = 16
        self.blockCount = size / self.blockSize + (size % self.blockSize == 0 ? 0 : 1)
        let expectedSize = 4 + self.blockCount * 1
        
        if self.file.size != expectedSize {
            self.file.size = expectedSize
            var version: Int32 = 1
            self.file.write(at: 0 ..< 4, from: &version)
        }
        
        var version: Int32 = 0
        self.file.read(at: 0 ..< 4, to: &version)
        precondition(version == 1)
        
        for i in 0 ..< blockCount {
            var blockStatus: Int8 = 0
            self.file.read(at: (4 + i) ..< (4 + i + 1), to: &blockStatus)
            if blockStatus != 0 {
                self.readyBlocks.insert(i)
            }
        }
    }
    
    public func storeRanges(_ ranges: [RandomAccessResourceStoreRange]) {
        var blockStatus: Int8 = 1
        
        var blocksWithListeners = Set<Int>()
        
        for range in ranges.sorted(by: { $0.offset < $1.offset }) {
            var offset = range.offset
            let endOffset = offset + range.data.count
            assert(offset % self.blockSize == 0 || (endOffset == self.size && range.data.count == 0))
            assert(offset >= 0)
            
            assert(endOffset == self.size || (endOffset < self.size && endOffset % self.blockSize == 0))
            
            var fragmentCache: (Int, MappedFile)?
            
            var blockIndex = offset / self.blockSize
            while offset < endOffset {
                let fragmentIndex = blockIndex / self.fragmentBlockCount
                
                let currentFragmentSize = min(self.size - fragmentIndex * self.fragmentBlockCount * self.blockSize, self.fragmentBlockCount * self.blockSize)
                let currentBlockSize = min(self.size - blockIndex * self.blockSize, self.blockSize)
                
                let fragmentFile: MappedFile
                if let fragmentCache = fragmentCache, fragmentCache.0 == fragmentIndex {
                    fragmentFile = fragmentCache.1
                } else {
                    fragmentCache?.1.synchronize()
                    fragmentFile = MappedFile(path: self.path + ".\(fragmentIndex)")
                    fragmentFile.size = currentFragmentSize
                    fragmentCache = (fragmentIndex, fragmentFile)
                }
                
                let fragmentBlockIndex = blockIndex % self.fragmentBlockCount
                let fragmentBlockOffset = fragmentBlockIndex * self.blockSize
                
                range.data.withUnsafeBytes { (bytes: UnsafePointer<Void>) -> Void in
                    fragmentFile.write(at: fragmentBlockOffset ..< (fragmentBlockOffset + currentBlockSize), from: bytes.advanced(by: offset - range.offset))
                }
                
                self.readyBlocks.insert(blockIndex)
                if let listeners = self.blockRangeListenersByBlockIndex[blockIndex], !listeners.isEmpty {
                    blocksWithListeners.insert(blockIndex)
                }
                
                self.file.write(at: (4 + blockIndex) ..< (4 + blockIndex + 1), from: &blockStatus)
                
                offset += blockSize
                blockIndex += 1
            }
            
            fragmentCache?.1.synchronize()
        }
        self.file.synchronize()
        
        var updateListeners = Set<RandomAccessBlockRangeListener>()
        
        for index in blocksWithListeners {
            if let listeners = self.blockRangeListenersByBlockIndex.removeValue(forKey: index) {
                for listener in listeners {
                    updateListeners.insert(listener)
                }
            }
        }
        
        for listener in updateListeners {
            listener.updateMissingBlocks(addedBlocks: blocksWithListeners, fetchData: { range in
                return self.fetchContiguousReadyData(in: range)
            })
        }
    }
    
    public func fetchContiguousReadyData(in dataRange: Range<Int>) -> Data {
        var data = Data()
        
        var fragmentCache: (Int, MappedFile)?
        
        let firstBlock = dataRange.lowerBound / self.blockSize
        let lastBlock = dataRange.upperBound / self.blockSize + (dataRange.upperBound % self.blockSize == 0 ? 0 : 1)
        
        let range = firstBlock ..< lastBlock
        
        var hadNonReadyBlock = false
        for blockIndex in range {
            if !self.readyBlocks.contains(blockIndex) {
                hadNonReadyBlock = true
                break
            }
            
            let fragmentIndex = blockIndex / self.fragmentBlockCount
            
            let currentFragmentSize = min(self.size - fragmentIndex * self.fragmentBlockCount * self.blockSize, self.fragmentBlockCount * self.blockSize)
            let currentBlockSize = min(self.size - blockIndex * self.blockSize, self.blockSize)
            
            let fragmentFile: MappedFile
            if let fragmentCache = fragmentCache, fragmentCache.0 == fragmentIndex {
                fragmentFile = fragmentCache.1
            } else {
                //fragmentCache?.1.synchronize()
                fragmentFile = MappedFile(path: self.path + ".\(fragmentIndex)")
                assert(fragmentFile.size == currentFragmentSize)
                fragmentCache = (fragmentIndex, fragmentFile)
            }
            
            let fragmentBlockIndex = blockIndex % self.fragmentBlockCount
            let fragmentBlockOffset = fragmentBlockIndex * self.blockSize
            
            var currentBlockStart = 0
            if blockIndex == firstBlock {
                currentBlockStart = dataRange.lowerBound % self.blockSize
            }
            
            var currentBlockEnd = currentBlockSize
            if blockIndex == lastBlock - 1 && (dataRange.upperBound % self.blockSize) != 0 {
                currentBlockEnd = dataRange.upperBound % self.blockSize
            }
            
            data.count += currentBlockEnd - currentBlockStart
            data.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<Void>) -> Void in
                fragmentFile.read(at: (fragmentBlockOffset + currentBlockStart) ..< (fragmentBlockOffset + currentBlockEnd), to: bytes.advanced(by: data.count - (currentBlockEnd - currentBlockStart)))
            }
        }
        
        if !hadNonReadyBlock {
            assert(data.count == dataRange.count, "\(data.count) != \(dataRange.count)")
        }
        
        return data
    }
    
    public func missingBlocks(in set: Set<Int>) -> Set<Int> {
        return set.subtracting(self.readyBlocks)
    }
    
    private func missingBlocks(in range: Range<Int>) -> Set<Int> {
        var result = Set<Int>()
        for index in CountableRange(range) {
            if !self.readyBlocks.contains(index) {
                result.insert(index)
            }
        }
        return result
    }
    
    public func addListenerForData(in range: Range<Int>, mode: RandomAccessResourceDataRangeMode, updated: @escaping (Data) -> Void) -> Int32 {
        let firstBlock = range.lowerBound / self.blockSize
        let lastBlock = range.upperBound / self.blockSize + (range.upperBound % self.blockSize == 0 ? 0 : 1)
        
        let missingBlocks = self.missingBlocks(in: firstBlock ..< lastBlock)
        
        if missingBlocks.isEmpty {
            updated(self.fetchContiguousReadyData(in: range))
            return -1
        } else {
            if missingBlocks.count < (firstBlock ..< lastBlock).count {
                switch mode {
                    case .Complete:
                        break
                    case .Incremental, .Partial:
                        updated(self.fetchContiguousReadyData(in: range))
                    case .None:
                        break
                }
            }
            
            let id = self.nextBlockRangeListenerId
            self.nextBlockRangeListenerId += 1
            let listener = RandomAccessBlockRangeListener(id: id, range: range, blockSize: self.blockSize, blocks: firstBlock ..< lastBlock, missingBlocks: missingBlocks, mode: mode, updated: { data in
                updated(data)
            })
            
            for index in missingBlocks {
                if self.blockRangeListenersByBlockIndex[index] == nil {
                    self.blockRangeListenersByBlockIndex[index] = [listener]
                } else {
                    self.blockRangeListenersByBlockIndex[index]!.append(listener)
                }
            }
            
            self.blockRangeListenerSet[listener.id] = listener
            
            return listener.id
        }
    }
    
    public func removeListenerForData(_ id: Int32) {
        if id == -1 {
            return
        }
        
        if let listener = self.blockRangeListenerSet.removeValue(forKey: id) {
            for index in listener.missingBlocks {
                if self.blockRangeListenersByBlockIndex[index] != nil {
                    if let listenerIndex = self.blockRangeListenersByBlockIndex[index]?.index(where: { $0 === listener }) {
                        self.blockRangeListenersByBlockIndex[index]?.remove(at: listenerIndex)
                        if let isEmpty = self.blockRangeListenersByBlockIndex[index]?.isEmpty, isEmpty {
                            self.blockRangeListenersByBlockIndex.removeValue(forKey: index)
                        }
                    }
                }
            }
        }
    }
    
    public func addListenerForFetchedData(in range: Range<Int>) -> Int32 {
        let firstBlock = range.lowerBound / self.blockSize
        let lastBlock = range.upperBound / self.blockSize + (range.upperBound % self.blockSize == 0 ? 0 : 1)
        
        let missingBlocks = self.missingBlocks(in: firstBlock ..< lastBlock)
        
        if missingBlocks.isEmpty {
            return -1
        } else {
            let id = self.nextBlockRangeListenerId
            self.nextBlockRangeListenerId += 1
            
            self.fetchedBlockRangeListenerSet[id] = firstBlock ..< lastBlock
            
            self.updateFetchDisposables()
            
            return id
        }
    }
    
    public func removeListenerForFetchedData(_ id: Int32) {
        let _ = self.fetchedBlockRangeListenerSet.removeValue(forKey: id)
        
        self.updateFetchDisposables()
    }
    
    public func hasDataListeners() -> Bool {
        return !self.blockRangeListenerSet.isEmpty || !self.fetchedBlockRangeListenerSet.isEmpty
    }
    
    private func updateFetchDisposables() {
        var fetchRangeList: [Range<Int>] = []
        
        for listener in self.fetchedBlockRangeListenerSet.values.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if !fetchRangeList.isEmpty {
                if fetchRangeList[fetchRangeList.count - 1].upperBound >= listener.lowerBound {
                    let upperBound = max(fetchRangeList[fetchRangeList.count - 1].upperBound, listener.upperBound)
                    fetchRangeList[fetchRangeList.count - 1] = fetchRangeList[fetchRangeList.count - 1].lowerBound ..< upperBound
                } else {
                    fetchRangeList.append(listener)
                }
            } else {
                fetchRangeList.append(listener)
            }
        }
        
        for listener in self.fetchedBlockRangeListenerSet.values {
            for i in 0 ..< fetchRangeList.count {
                if fetchRangeList[i].contains(listener.lowerBound) {
                    if fetchRangeList[i].lowerBound < listener.lowerBound {
                        fetchRangeList.insert(listener.lowerBound ..< fetchRangeList[i].upperBound, at: i + 1)
                        fetchRangeList[i] = fetchRangeList[i].lowerBound ..< listener.lowerBound
                    }
                    break
                }
            }
        }
        
        let blockRanges = Set(fetchRangeList.map({ FetchRange(range: $0) }))
        
        let removedRanges = self.fetchRanges.subtracting(blockRanges)
        let addedRanges = blockRanges.subtracting(self.fetchRanges)
        
        for blockRange in removedRanges {
            self.fetchDisposables.removeValue(forKey: blockRange)?.dispose()
        }
        
        for blockRange in addedRanges {
            let disposables = DisposableSet()
            
            let blocksToFetch = self.missingBlocks(in: blockRange.range)
            
            var contiguousBlockRanges: [Range<Int>] = []
            
            for blockIndex in blocksToFetch.sorted() {
                if !contiguousBlockRanges.isEmpty {
                    if contiguousBlockRanges[contiguousBlockRanges.count - 1].upperBound == blockIndex {
                        contiguousBlockRanges[contiguousBlockRanges.count - 1] = contiguousBlockRanges[contiguousBlockRanges.count - 1].lowerBound ..< (blockIndex + 1)
                    } else {
                        contiguousBlockRanges.append(blockIndex ..< (blockIndex + 1))
                    }
                } else {
                    contiguousBlockRanges.append(blockIndex ..< (blockIndex + 1))
                }
            }
            
            for blockRange in contiguousBlockRanges {
                let lowerBoundOffset = blockRange.lowerBound * self.blockSize
                let upperBoundOffset = min(self.size, blockRange.upperBound * self.blockSize)
                
                disposables.add(self.fetchRange(lowerBoundOffset ..< upperBoundOffset))
            }
            
            self.fetchDisposables[blockRange] = disposables
        }
        
        self.fetchRanges = blockRanges
    }
}
