import Foundation

struct MediaGridThumbnailIndexFile {
    struct Entry {
        var id: String
        var version: String
        var slot: Int
        var x: Int
        var y: Int
        var width: Int
        var height: Int
    }

    static let magic: UInt32 = 0x4954_474D
    static let formatVersion: UInt32 = 1

    var slotPixelSize: Int
    var pageSide: Int
    var nextStamp: UInt64
    var pages: [Int: UInt64]
    var entries: [Entry]

    func encoded() -> Data {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(32 + self.pages.count * 12 + self.entries.count * 96)
        func append32(_ value: UInt32) {
            withUnsafeBytes(of: value.littleEndian) { bytes.append(contentsOf: $0) }
        }
        func append64(_ value: UInt64) {
            withUnsafeBytes(of: value.littleEndian) { bytes.append(contentsOf: $0) }
        }
        func append16(_ value: UInt16) {
            withUnsafeBytes(of: value.littleEndian) { bytes.append(contentsOf: $0) }
        }
        func appendString(_ value: String) {
            let utf8 = Array(value.utf8.prefix(Int(UInt16.max)))
            append16(UInt16(utf8.count))
            bytes.append(contentsOf: utf8)
        }
        append32(MediaGridThumbnailIndexFile.magic)
        append32(MediaGridThumbnailIndexFile.formatVersion)
        append32(UInt32(self.slotPixelSize))
        append32(UInt32(self.pageSide))
        append64(self.nextStamp)
        append32(UInt32(self.pages.count))
        for page in self.pages.keys.sorted() {
            append32(UInt32(page))
            append64(self.pages[page]!)
        }
        append32(UInt32(self.entries.count))
        for entry in self.entries {
            append32(UInt32(entry.slot))
            append16(UInt16(entry.x))
            append16(UInt16(entry.y))
            append16(UInt16(entry.width))
            append16(UInt16(entry.height))
            appendString(entry.id)
            appendString(entry.version)
        }
        return Data(bytes)
    }

    static func decode(_ data: Data, slotPixelSize: Int, pageSide: Int) -> MediaGridThumbnailIndexFile? {
        return data.withUnsafeBytes { raw -> MediaGridThumbnailIndexFile? in
            var reader = Reader(raw: raw)
            guard reader.read32() == MediaGridThumbnailIndexFile.magic, reader.read32() == MediaGridThumbnailIndexFile.formatVersion, reader.read32().map(Int.init) == slotPixelSize, reader.read32().map(Int.init) == pageSide, slotPixelSize > 0, pageSide > 0 else {
                return nil
            }
            guard let nextStamp = reader.read64(), let pageCount = reader.read32().map(Int.init), pageCount * 12 <= reader.remaining else {
                return nil
            }
            var pages: [Int: UInt64] = [:]
            pages.reserveCapacity(pageCount)
            for _ in 0 ..< pageCount {
                guard let page = reader.read32().map(Int.init), let stamp = reader.read64(), stamp < nextStamp, pages[page] == nil else {
                    return nil
                }
                pages[page] = stamp
            }
            guard let entryCount = reader.read32().map(Int.init), entryCount * 16 <= reader.remaining else {
                return nil
            }
            let slotsPerPage = pageSide * pageSide
            var entries: [Entry] = []
            entries.reserveCapacity(entryCount)
            var slots = Set<Int>()
            slots.reserveCapacity(entryCount)
            var ids = Set<String>()
            ids.reserveCapacity(entryCount)
            for _ in 0 ..< entryCount {
                guard let slot = reader.read32().map(Int.init), let x = reader.read16().map(Int.init), let y = reader.read16().map(Int.init), let width = reader.read16().map(Int.init), let height = reader.read16().map(Int.init), let id = reader.readString(), let version = reader.readString() else {
                    return nil
                }
                let local = slot % slotsPerPage
                let originX = (local % pageSide) * slotPixelSize
                let originY = (local / pageSide) * slotPixelSize
                guard width > 0, height > 0, x >= originX, y >= originY, x + width <= originX + slotPixelSize, y + height <= originY + slotPixelSize, slots.insert(slot).inserted, ids.insert(id).inserted else {
                    return nil
                }
                entries.append(Entry(id: id, version: version, slot: slot, x: x, y: y, width: width, height: height))
            }
            guard reader.remaining == 0 else {
                return nil
            }
            return MediaGridThumbnailIndexFile(slotPixelSize: slotPixelSize, pageSide: pageSide, nextStamp: nextStamp, pages: pages, entries: entries)
        }
    }

    private struct Reader {
        let raw: UnsafeRawBufferPointer
        var offset = 0

        init(raw: UnsafeRawBufferPointer) {
            self.raw = raw
        }

        var remaining: Int {
            return self.raw.count - self.offset
        }

        mutating func read16() -> UInt16? {
            guard self.remaining >= 2 else {
                return nil
            }
            let value = self.raw.loadUnaligned(fromByteOffset: self.offset, as: UInt16.self)
            self.offset += 2
            return UInt16(littleEndian: value)
        }

        mutating func read32() -> UInt32? {
            guard self.remaining >= 4 else {
                return nil
            }
            let value = self.raw.loadUnaligned(fromByteOffset: self.offset, as: UInt32.self)
            self.offset += 4
            return UInt32(littleEndian: value)
        }

        mutating func read64() -> UInt64? {
            guard self.remaining >= 8 else {
                return nil
            }
            let value = self.raw.loadUnaligned(fromByteOffset: self.offset, as: UInt64.self)
            self.offset += 8
            return UInt64(littleEndian: value)
        }

        mutating func readString() -> String? {
            guard let length = self.read16().map(Int.init), self.remaining >= length else {
                return nil
            }
            let value = String(decoding: UnsafeRawBufferPointer(rebasing: self.raw[self.offset ..< self.offset + length]), as: UTF8.self)
            self.offset += length
            return value
        }
    }
}
