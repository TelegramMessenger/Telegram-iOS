import Foundation
import CryptoKit
import WalletEngineFFI

@available(macOS 10.15, *)
enum WalletBocMessageKind: Equatable, Sendable {
    case external
    case internalMessage
}

@available(macOS 10.15, *)
enum WalletBocError: String, Error, Equatable {
    case invalidSize
    case truncated
    case invalidHeader
    case unsupportedFormat
    case invalidChecksum
    case invalidIndex
    case unsupportedCell
    case invalidCell
    case invalidReference
    case invalidMessage
    case unexpectedMessageKind
}

@available(macOS 10.15, *)
func walletBocBodyHash(_ data: Data, kind: WalletBocMessageKind) throws -> String {
    let boc = try WalletBoc(data)
    var reader = WalletBocBitReader(cell: boc.cells[boc.root])
    switch kind {
    case .external:
        guard try reader.read(2) == 2 else {
            throw WalletBocError.unexpectedMessageKind
        }
        try reader.skipAddress(internalOnly: false)
        try reader.skipAddress(internalOnly: true)
        try reader.skipCoins()
    case .internalMessage:
        guard try reader.read(1) == 0 else {
            throw WalletBocError.unexpectedMessageKind
        }
        try reader.skip(3) // ihr_disabled, bounce, bounced
        try reader.skipAddress(internalOnly: false) // relaxed source may be addr_none
        try reader.skipAddress(internalOnly: true)
        try reader.skipCoins()
        try reader.skipOptionalReference() // extra currencies
        try reader.skipCoins() // ihr_fee
        try reader.skipCoins() // fwd_fee
        try reader.skip(64 + 32) // created_lt, created_at
    }
    if try reader.read(1) != 0 {
        if try reader.read(1) != 0 {
            _ = try reader.reference() // StateInit in a reference
        } else {
            // Inline StateInit: split_depth, special, code, data, library.
            if try reader.read(1) != 0 { try reader.skip(5) }
            if try reader.read(1) != 0 { try reader.skip(2) }
            try reader.skipOptionalReference()
            try reader.skipOptionalReference()
            try reader.skipOptionalReference()
        }
    }

    let body: WalletBocCell
    if try reader.read(1) != 0 {
        body = boc.cells[try reader.reference()]
        guard reader.isEmpty else { throw WalletBocError.invalidMessage }
    } else {
        body = try reader.remainingCell()
    }
    let hashes = boc.hashes()
    return body.hash(using: hashes).hash.base64EncodedString()
}

@available(macOS 10.15, *)
struct WalletBocCell {
    let bytes: [UInt8]
    let bitCount: Int
    let refs: [Int]

    struct HashAndDepth {
        let hash: Data
        let depth: UInt16
    }

    func hash(using hashes: [HashAndDepth]) -> HashAndDepth {
        var representation = Data([UInt8(self.refs.count), UInt8(self.bitCount / 8 + (self.bitCount + 7) / 8)])
        representation.append(contentsOf: self.bytes)
        for ref in self.refs {
            let depth = hashes[ref].depth
            representation.append(UInt8(depth >> 8))
            representation.append(UInt8(depth & 0xff))
        }
        for ref in self.refs {
            representation.append(hashes[ref].hash)
        }
        // The parser bounds cell count so a valid DAG depth fits UInt16.
        let depth = self.refs.map { hashes[$0].depth }.max().map { $0 + 1 } ?? 0
        return HashAndDepth(hash: Data(SHA256.hash(data: representation)), depth: depth)
    }
}

@available(macOS 10.15, *)
struct WalletBoc {
    let cells: [WalletBocCell]
    let root: Int

    init(_ data: Data, maximumBytes: Int = 16 * 1024) throws {
        guard !data.isEmpty, data.count <= maximumBytes else {
            throw WalletBocError.invalidSize
        }
        let bytes = Array(data)
        var reader = WalletBocByteReader(bytes: bytes)
        guard try reader.integer(4) == 0xb5ee9c72 else {
            throw WalletBocError.unsupportedFormat
        }
        let flags = try reader.integer(1)
        let sizeBytes = flags & 7
        let offsetBytes = try reader.integer(1)
        guard flags & 0x38 == 0 else { throw WalletBocError.unsupportedFormat }
        guard (1 ... 4).contains(sizeBytes), (1 ... 8).contains(offsetBytes) else {
            throw WalletBocError.invalidHeader
        }
        let hasIndex = flags & 0x80 != 0
        let hasCRC = flags & 0x40 != 0
        let cellCount = try reader.integer(sizeBytes)
        let rootCount = try reader.integer(sizeBytes)
        let absentCount = try reader.integer(sizeBytes)
        let cellBytes = try reader.integer(offsetBytes)
        guard rootCount == 1, absentCount == 0 else { throw WalletBocError.unsupportedFormat }
        guard cellCount > 0, cellCount < Int(UInt16.max), cellBytes <= bytes.count, cellCount <= cellBytes / 2 else {
            throw WalletBocError.invalidHeader
        }
        let root = try reader.integer(sizeBytes)
        guard root < cellCount else { throw WalletBocError.invalidReference }
        var index: [Int] = []
        if hasIndex {
            for _ in 0 ..< cellCount { index.append(try reader.integer(offsetBytes)) }
        }
        let cellStart = reader.offset
        guard cellBytes == bytes.count - cellStart - (hasCRC ? 4 : 0) else {
            throw WalletBocError.invalidHeader
        }
        if hasCRC {
            let checksum = walletBocCRC32C(bytes.dropLast(4))
            let expected = (0 ..< 4).map { UInt8(truncatingIfNeeded: checksum >> ($0 * 8)) }
            guard Array(bytes.suffix(4)) == expected else { throw WalletBocError.invalidChecksum }
        }
        reader = WalletBocByteReader(bytes: Array(bytes[cellStart ..< cellStart + cellBytes]))
        var cells: [WalletBocCell] = []
        for cellIndex in 0 ..< cellCount {
            let descriptor = try reader.integer(1)
            let bitsDescriptor = try reader.integer(1)
            guard descriptor & 0xf8 == 0 else { throw WalletBocError.unsupportedCell }
            let refCount = descriptor & 7
            guard refCount <= 4 else { throw WalletBocError.invalidCell }
            let contents = try reader.take((bitsDescriptor + 1) / 2)
            var bitCount = contents.count * 8
            if bitsDescriptor & 1 != 0 {
                guard let last = contents.last, last != 0, last.trailingZeroBitCount < 7 else {
                    throw WalletBocError.invalidCell
                }
                bitCount -= last.trailingZeroBitCount + 1
            }
            var refs: [Int] = []
            for _ in 0 ..< refCount {
                let ref = try reader.integer(sizeBytes)
                // BOC cells are topologically ordered. Reject cycles and back references.
                guard ref > cellIndex, ref < cellCount else { throw WalletBocError.invalidReference }
                refs.append(ref)
            }
            if hasIndex, index[cellIndex] != reader.offset {
                throw WalletBocError.invalidIndex
            }
            cells.append(WalletBocCell(bytes: contents, bitCount: bitCount, refs: refs))
        }
        guard reader.offset == cellBytes else { throw WalletBocError.invalidHeader }
        self.cells = cells
        self.root = root
    }

    func hashes() -> [WalletBocCell.HashAndDepth] {
        var hashes = Array(repeating: WalletBocCell.HashAndDepth(hash: Data(), depth: 0), count: self.cells.count)
        for index in self.cells.indices.reversed() {
            hashes[index] = self.cells[index].hash(using: hashes)
        }
        return hashes
    }
}

@available(macOS 10.15, *)
private struct WalletBocByteReader {
    let bytes: [UInt8]
    private(set) var offset = 0

    init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    mutating func take(_ count: Int) throws -> [UInt8] {
        guard count >= 0, count <= self.bytes.count - self.offset else {
            throw WalletBocError.truncated
        }
        let start = self.offset
        self.offset += count
        return Array(self.bytes[start ..< self.offset])
    }

    mutating func integer(_ count: Int) throws -> Int {
        guard (1 ... 8).contains(count) else { throw WalletBocError.invalidHeader }
        var value: UInt64 = 0
        for byte in try self.take(count) { value = (value << 8) | UInt64(byte) }
        guard let result = Int(exactly: value) else { throw WalletBocError.invalidHeader }
        return result
    }
}

@available(macOS 10.15, *)
private struct WalletBocBitReader {
    let cell: WalletBocCell
    private var bitOffset = 0
    private var refOffset = 0

    init(cell: WalletBocCell) {
        self.cell = cell
    }

    var isEmpty: Bool {
        return self.bitOffset == self.cell.bitCount && self.refOffset == self.cell.refs.count
    }

    mutating func read(_ count: Int) throws -> Int {
        guard (0 ... 32).contains(count), count <= self.cell.bitCount - self.bitOffset else {
            throw WalletBocError.invalidMessage
        }
        var result = 0
        for _ in 0 ..< count {
            result = (result << 1) | Int((self.cell.bytes[self.bitOffset / 8] >> (7 - self.bitOffset % 8)) & 1)
            self.bitOffset += 1
        }
        return result
    }

    mutating func skip(_ count: Int) throws {
        guard count >= 0, count <= self.cell.bitCount - self.bitOffset else {
            throw WalletBocError.invalidMessage
        }
        self.bitOffset += count
    }

    mutating func reference() throws -> Int {
        guard self.refOffset < self.cell.refs.count else { throw WalletBocError.invalidReference }
        defer { self.refOffset += 1 }
        return self.cell.refs[self.refOffset]
    }

    mutating func skipOptionalReference() throws {
        if try self.read(1) != 0 { _ = try self.reference() }
    }

    mutating func skipCoins() throws {
        let byteCount = try self.read(4)
        try self.skip(byteCount * 8)
    }

    mutating func skipAddress(internalOnly: Bool) throws {
        let tag = try self.read(2)
        switch tag {
        case 0:
            guard !internalOnly else { throw WalletBocError.invalidMessage }
        case 1:
            guard !internalOnly else { throw WalletBocError.invalidMessage }
            let bits = try self.read(9)
            try self.skip(bits)
        case 2, 3:
            if try self.read(1) != 0 {
                let depth = try self.read(5)
                guard (1 ... 30).contains(depth) else { throw WalletBocError.invalidMessage }
                try self.skip(depth)
            }
            if tag == 2 {
                try self.skip(8 + 256)
            } else {
                let bits = try self.read(9)
                try self.skip(32 + bits)
            }
        default:
            throw WalletBocError.invalidMessage
        }
    }

    mutating func remainingCell() throws -> WalletBocCell {
        let bitCount = self.cell.bitCount - self.bitOffset
        var bytes = [UInt8](repeating: 0, count: (bitCount + 7) / 8)
        for bit in 0 ..< bitCount {
            if try self.read(1) != 0 { bytes[bit / 8] |= UInt8(1 << (7 - bit % 8)) }
        }
        if bitCount % 8 != 0 { bytes[bytes.count - 1] |= UInt8(1 << (7 - bitCount % 8)) }
        return WalletBocCell(bytes: bytes, bitCount: bitCount, refs: Array(self.cell.refs.dropFirst(self.refOffset)))
    }
}

@available(macOS 10.15, *)
private func walletBocCRC32C(_ bytes: ArraySlice<UInt8>) -> UInt32 {
    var crc: UInt32 = 0xffffffff
    for byte in bytes {
        crc ^= UInt32(byte)
        for _ in 0 ..< 8 {
            crc = (crc >> 1) ^ (crc & 1 != 0 ? 0x82f63b78 : 0)
        }
    }
    return ~crc
}

@available(macOS 10.15, *)
struct WalletRequestCoalescingKey: Hashable, Sendable {
    struct Header: Hashable, Sendable {
        let name: String
        let value: String
    }

    let url: String
    let headers: [Header]
    let body: Data
    let timeoutMs: UInt64

    init?(isGet: Bool, url: String, headers: [Header], body: Data, timeoutMs: UInt64) {
        guard isGet,
              let components = URLComponents(string: url),
              components.scheme?.lowercased() == "https",
              components.host != nil,
              components.user == nil,
              components.password == nil,
              components.fragment == nil,
              components.path == "/api/v2/getAddressInformation" else {
            return nil
        }
        self.url = url
        self.headers = headers
        self.body = body
        self.timeoutMs = timeoutMs
    }
}

@available(macOS 10.15, *)
final class WalletRequestCoalescer: @unchecked Sendable {
    final class Request: @unchecked Sendable {
        private let lock = NSLock()
        private let onCancel: @Sendable () -> Void
        private var result: Result<Data, Error>?
        private var continuation: CheckedContinuation<Data, Error>?

        fileprivate init(onCancel: @escaping @Sendable () -> Void) {
            self.onCancel = onCancel
        }

        var value: Data {
            get async throws {
                return try await withTaskCancellationHandler(operation: {
                    try await withCheckedThrowingContinuation { continuation in
                        self.lock.lock()
                        let result = self.result
                        if result == nil {
                            precondition(self.continuation == nil)
                            self.continuation = continuation
                        }
                        self.lock.unlock()
                        if let result {
                            continuation.resume(with: result)
                        }
                    }
                }, onCancel: {
                    self.cancel()
                })
            }
        }

        func cancel() {
            self.onCancel()
        }

        fileprivate func complete(_ result: Result<Data, Error>) {
            self.lock.lock()
            guard self.result == nil else {
                self.lock.unlock()
                return
            }
            self.result = result
            let continuation = self.continuation
            self.continuation = nil
            self.lock.unlock()
            continuation?.resume(with: result)
        }
    }

    private final class Operation {
        let id = UUID()
        var task: Task<Void, Never>?
        var requests: [UUID: Request] = [:]
    }

    private let lock = NSLock()
    private var operations: [WalletRequestCoalescingKey: Operation] = [:]

    func execute(
        key: WalletRequestCoalescingKey,
        operation: @escaping @Sendable () async throws -> Data
    ) async throws -> Data {
        try Task.checkCancellation()
        let request = self.start(key: key, operation: operation)
        return try await request.value
    }

    func start(
        key: WalletRequestCoalescingKey,
        operation: @escaping @Sendable () async throws -> Data
    ) -> Request {
        self.lock.lock()
        let existing = self.operations[key]
        let shared = existing ?? Operation()
        let operationId = shared.id
        let requestId = UUID()
        let request = Request(onCancel: { [weak self] in
            self?.cancel(key: key, operationId: operationId, requestId: requestId)
        })
        shared.requests[requestId] = request
        if existing == nil {
            self.operations[key] = shared
            shared.task = Task {
                let result: Result<Data, Error>
                do {
                    try Task.checkCancellation()
                    result = .success(try await operation())
                } catch {
                    result = .failure(error)
                }
                self.complete(key: key, operationId: operationId, result: result)
            }
        }
        self.lock.unlock()
        return request
    }

    private func cancel(key: WalletRequestCoalescingKey, operationId: UUID, requestId: UUID) {
        self.lock.lock()
        guard let shared = self.operations[key], shared.id == operationId,
              let request = shared.requests.removeValue(forKey: requestId) else {
            self.lock.unlock()
            return
        }
        let task: Task<Void, Never>?
        if shared.requests.isEmpty {
            self.operations.removeValue(forKey: key)
            task = shared.task
        } else {
            task = nil
        }
        self.lock.unlock()
        task?.cancel()
        request.complete(.failure(CancellationError()))
    }

    private func complete(key: WalletRequestCoalescingKey, operationId: UUID, result: Result<Data, Error>) {
        self.lock.lock()
        guard let shared = self.operations[key], shared.id == operationId else {
            self.lock.unlock()
            return
        }
        self.operations.removeValue(forKey: key)
        let requests = Array(shared.requests.values)
        self.lock.unlock()
        for request in requests {
            request.complete(result)
        }
    }
}

@available(macOS 10.15, *)
func walletMnemonicSigningPublicKey(words: [String]) throws -> Data {
    var words = normalizedEngineMnemonic(words)
    defer { words.removeAll(keepingCapacity: false) }
    do {
        _ = try rotationMnemonicPublicKey(phrase: words.joined(separator: " "))
        return try rotationMnemonicPublicKey(phrase: words.suffix(12).joined(separator: " "))
    } catch {
        throw WalletContext.WalletError.invalidMnemonic
    }
}
