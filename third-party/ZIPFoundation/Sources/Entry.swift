//
//  Entry.swift
//  ZIPFoundation
//
//  Copyright © 2017-2020 Thomas Zoechling, https://www.peakstep.com and the ZIP Foundation project authors.
//  Released under the MIT License.
//
//  See https://github.com/weichsel/ZIPFoundation/blob/master/LICENSE for license information.
//

import Foundation
import CoreFoundation

/// A value that represents a file, a directory or a symbolic link within a ZIP `Archive`.
///
/// You can retrieve instances of `Entry` from an `Archive` via subscripting or iteration.
/// Entries are identified by their `path`.
public struct Entry: Equatable {
    /// The type of an `Entry` in a ZIP `Archive`.
    public enum EntryType: Int {
        /// Indicates a regular file.
        case file
        /// Indicates a directory.
        case directory
        /// Indicates a symbolic link.
        case symlink

        init(mode: mode_t) {
            switch mode & S_IFMT {
            case S_IFDIR:
                self = .directory
            case S_IFLNK:
                self = .symlink
            default:
                self = .file
            }
        }
    }

    enum OSType: UInt {
        case msdos = 0
        case unix = 3
        case osx = 19
        case unused = 20
    }

    struct LocalFileHeader: DataSerializable {
        let localFileHeaderSignature = UInt32(localFileHeaderStructSignature)
        let versionNeededToExtract: UInt16
        let generalPurposeBitFlag: UInt16
        let compressionMethod: UInt16
        let lastModFileTime: UInt16
        let lastModFileDate: UInt16
        let crc32: UInt32
        let compressedSize: UInt32
        let uncompressedSize: UInt32
        let fileNameLength: UInt16
        let extraFieldLength: UInt16
        static let size = 30
        let fileNameData: Data
        let extraFieldData: Data
    }

    struct DataDescriptor: DataSerializable {
        let data: Data
        let dataDescriptorSignature = UInt32(dataDescriptorStructSignature)
        let crc32: UInt32
        let compressedSize: UInt32
        let uncompressedSize: UInt32
        static let size = 16
    }

    struct CentralDirectoryStructure: DataSerializable {
        let centralDirectorySignature = UInt32(centralDirectoryStructSignature)
        let versionMadeBy: UInt16
        let versionNeededToExtract: UInt16
        let generalPurposeBitFlag: UInt16
        let compressionMethod: UInt16
        let lastModFileTime: UInt16
        let lastModFileDate: UInt16
        let crc32: UInt32
        let compressedSize: UInt32
        let uncompressedSize: UInt32
        let fileNameLength: UInt16
        let extraFieldLength: UInt16
        let fileCommentLength: UInt16
        let diskNumberStart: UInt16
        let internalFileAttributes: UInt16
        let externalFileAttributes: UInt32
        let relativeOffsetOfLocalHeader: UInt32
        static let size = 46
        let fileNameData: Data
        let extraFieldData: Data
        let fileCommentData: Data
        var usesDataDescriptor: Bool { return (self.generalPurposeBitFlag & (1 << 3 )) != 0 }
        var usesUTF8PathEncoding: Bool { return (self.generalPurposeBitFlag & (1 << 11 )) != 0 }
        var isEncrypted: Bool { return (self.generalPurposeBitFlag & (1 << 0)) != 0 }
        var isZIP64: Bool { return self.versionNeededToExtract >= 45 }
    }
    /// Returns the `path` of the receiver within a ZIP `Archive` using a given encoding.
    ///
    /// - Parameters:
    ///   - encoding: `String.Encoding`
    public func path(using encoding: String.Encoding) -> String {
        return String(data: self.centralDirectoryStructure.fileNameData, encoding: encoding) ?? ""
    }
    /// The `path` of the receiver within a ZIP `Archive`.
    public var path: String {
        let dosLatinUS = 0x400
        let dosLatinUSEncoding = CFStringEncoding(dosLatinUS)
        let dosLatinUSStringEncoding = CFStringConvertEncodingToNSStringEncoding(dosLatinUSEncoding)
        let codepage437 = String.Encoding(rawValue: dosLatinUSStringEncoding)
        let encoding = self.centralDirectoryStructure.usesUTF8PathEncoding ? .utf8 : codepage437
        return self.path(using: encoding)
    }
    /// The file attributes of the receiver as key/value pairs.
    ///
    /// Contains the modification date and file permissions.
    public var fileAttributes: [FileAttributeKey: Any] {
        return FileManager.attributes(from: self)
    }
    /// The `CRC32` checksum of the receiver.
    ///
    /// - Note: Always returns `0` for entries of type `EntryType.directory`.
    public var checksum: CRC32 {
        var checksum = self.centralDirectoryStructure.crc32
        if self.centralDirectoryStructure.usesDataDescriptor {
            guard let dataDescriptor = self.dataDescriptor else { return 0 }
            checksum = dataDescriptor.crc32
        }
        return checksum
    }
    /// The `EntryType` of the receiver.
    public var type: EntryType {
        // OS Type is stored in the upper byte of versionMadeBy
        let osTypeRaw = self.centralDirectoryStructure.versionMadeBy >> 8
        let osType = OSType(rawValue: UInt(osTypeRaw)) ?? .unused
        var isDirectory = self.path.hasSuffix("/")
        switch osType {
        case .unix, .osx:
            let mode = mode_t(self.centralDirectoryStructure.externalFileAttributes >> 16) & S_IFMT
            switch mode {
            case S_IFREG:
                return .file
            case S_IFDIR:
                return .directory
            case S_IFLNK:
                return .symlink
            default:
                return isDirectory ? .directory : .file
            }
        case .msdos:
            isDirectory = isDirectory || ((centralDirectoryStructure.externalFileAttributes >> 4) == 0x01)
            fallthrough // For all other OSes we can only guess based on the directory suffix char
        default: return isDirectory ? .directory : .file
        }
    }
    /// The size of the receiver's compressed data.
    public var compressedSize: Int {
        return Int(dataDescriptor?.compressedSize ?? localFileHeader.compressedSize)
    }
    /// The size of the receiver's uncompressed data.
    public var uncompressedSize: Int {
        return Int(dataDescriptor?.uncompressedSize ?? localFileHeader.uncompressedSize)
    }
    /// The combined size of the local header, the data and the optional data descriptor.
    var localSize: Int {
        let localFileHeader = self.localFileHeader
        var extraDataLength = Int(localFileHeader.fileNameLength)
        extraDataLength += Int(localFileHeader.extraFieldLength)
        var size = LocalFileHeader.size + extraDataLength
        let isCompressed = localFileHeader.compressionMethod != CompressionMethod.none.rawValue
        size += isCompressed ? self.compressedSize : self.uncompressedSize
        size += self.dataDescriptor != nil ? DataDescriptor.size : 0
        return size
    }
    var dataOffset: Int {
        var dataOffset = Int(self.centralDirectoryStructure.relativeOffsetOfLocalHeader)
        dataOffset += LocalFileHeader.size
        dataOffset += Int(self.localFileHeader.fileNameLength)
        dataOffset += Int(self.localFileHeader.extraFieldLength)
        return dataOffset
    }
    let centralDirectoryStructure: CentralDirectoryStructure
    let localFileHeader: LocalFileHeader
    let dataDescriptor: DataDescriptor?

    public static func == (lhs: Entry, rhs: Entry) -> Bool {
        return lhs.path == rhs.path
            && lhs.localFileHeader.crc32 == rhs.localFileHeader.crc32
            && lhs.centralDirectoryStructure.relativeOffsetOfLocalHeader
            == rhs.centralDirectoryStructure.relativeOffsetOfLocalHeader
    }

    init?(centralDirectoryStructure: CentralDirectoryStructure,
          localFileHeader: LocalFileHeader,
          dataDescriptor: DataDescriptor?) {
        // We currently don't support ZIP64 or encrypted archives
        guard !centralDirectoryStructure.isZIP64 else { return nil }
        guard !centralDirectoryStructure.isEncrypted else { return nil }
        self.centralDirectoryStructure = centralDirectoryStructure
        self.localFileHeader = localFileHeader
        self.dataDescriptor = dataDescriptor
    }
}

extension Entry.LocalFileHeader {
    var data: Data {
        var localFileHeaderSignature = self.localFileHeaderSignature
        var versionNeededToExtract = self.versionNeededToExtract
        var generalPurposeBitFlag = self.generalPurposeBitFlag
        var compressionMethod = self.compressionMethod
        var lastModFileTime = self.lastModFileTime
        var lastModFileDate = self.lastModFileDate
        var crc32 = self.crc32
        var compressedSize = self.compressedSize
        var uncompressedSize = self.uncompressedSize
        var fileNameLength = self.fileNameLength
        var extraFieldLength = self.extraFieldLength
        var data = Data()
        withUnsafePointer(to: &localFileHeaderSignature, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &versionNeededToExtract, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &generalPurposeBitFlag, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &compressionMethod, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &lastModFileTime, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &lastModFileDate, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &crc32, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &compressedSize, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &uncompressedSize, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &fileNameLength, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &extraFieldLength, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        data.append(self.fileNameData)
        data.append(self.extraFieldData)
        return data
    }

    init?(data: Data, additionalDataProvider provider: (Int) throws -> Data) {
        guard data.count == Entry.LocalFileHeader.size else { return nil }
        guard data.scanValue(start: 0) == localFileHeaderSignature else { return nil }
        self.versionNeededToExtract = data.scanValue(start: 4)
        self.generalPurposeBitFlag = data.scanValue(start: 6)
        self.compressionMethod = data.scanValue(start: 8)
        self.lastModFileTime = data.scanValue(start: 10)
        self.lastModFileDate = data.scanValue(start: 12)
        self.crc32 = data.scanValue(start: 14)
        self.compressedSize = data.scanValue(start: 18)
        self.uncompressedSize = data.scanValue(start: 22)
        self.fileNameLength = data.scanValue(start: 26)
        self.extraFieldLength = data.scanValue(start: 28)
        let additionalDataLength = Int(self.fileNameLength) + Int(self.extraFieldLength)
        guard let additionalData = try? provider(additionalDataLength) else { return nil }
        guard additionalData.count == additionalDataLength else { return nil }
        var subRangeStart = 0
        var subRangeEnd = Int(self.fileNameLength)
        self.fileNameData = additionalData.subdata(in: subRangeStart..<subRangeEnd)
        subRangeStart += Int(self.fileNameLength)
        subRangeEnd = subRangeStart + Int(self.extraFieldLength)
        self.extraFieldData = additionalData.subdata(in: subRangeStart..<subRangeEnd)
    }
}

extension Entry.CentralDirectoryStructure {
    var data: Data {
        var centralDirectorySignature = self.centralDirectorySignature
        var versionMadeBy = self.versionMadeBy
        var versionNeededToExtract = self.versionNeededToExtract
        var generalPurposeBitFlag = self.generalPurposeBitFlag
        var compressionMethod = self.compressionMethod
        var lastModFileTime = self.lastModFileTime
        var lastModFileDate = self.lastModFileDate
        var crc32 = self.crc32
        var compressedSize = self.compressedSize
        var uncompressedSize = self.uncompressedSize
        var fileNameLength = self.fileNameLength
        var extraFieldLength = self.extraFieldLength
        var fileCommentLength = self.fileCommentLength
        var diskNumberStart = self.diskNumberStart
        var internalFileAttributes = self.internalFileAttributes
        var externalFileAttributes = self.externalFileAttributes
        var relativeOffsetOfLocalHeader = self.relativeOffsetOfLocalHeader
        var data = Data()
        withUnsafePointer(to: &centralDirectorySignature, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &versionMadeBy, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &versionNeededToExtract, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &generalPurposeBitFlag, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &compressionMethod, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &lastModFileTime, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &lastModFileDate, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &crc32, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &compressedSize, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &uncompressedSize, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &fileNameLength, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &extraFieldLength, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &fileCommentLength, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &diskNumberStart, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &internalFileAttributes, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &externalFileAttributes, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &relativeOffsetOfLocalHeader, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        data.append(self.fileNameData)
        data.append(self.extraFieldData)
        data.append(self.fileCommentData)
        return data
    }

    init?(data: Data, additionalDataProvider provider: (Int) throws -> Data) {
        guard data.count == Entry.CentralDirectoryStructure.size else { return nil }
        guard data.scanValue(start: 0) == centralDirectorySignature else { return nil }
        self.versionMadeBy = data.scanValue(start: 4)
        self.versionNeededToExtract = data.scanValue(start: 6)
        self.generalPurposeBitFlag = data.scanValue(start: 8)
        self.compressionMethod = data.scanValue(start: 10)
        self.lastModFileTime = data.scanValue(start: 12)
        self.lastModFileDate = data.scanValue(start: 14)
        self.crc32 = data.scanValue(start: 16)
        self.compressedSize = data.scanValue(start: 20)
        self.uncompressedSize = data.scanValue(start: 24)
        self.fileNameLength = data.scanValue(start: 28)
        self.extraFieldLength = data.scanValue(start: 30)
        self.fileCommentLength = data.scanValue(start: 32)
        self.diskNumberStart = data.scanValue(start: 34)
        self.internalFileAttributes = data.scanValue(start: 36)
        self.externalFileAttributes = data.scanValue(start: 38)
        self.relativeOffsetOfLocalHeader = data.scanValue(start: 42)
        let additionalDataLength = Int(self.fileNameLength) + Int(self.extraFieldLength) + Int(self.fileCommentLength)
        guard let additionalData = try? provider(additionalDataLength) else { return nil }
        guard additionalData.count == additionalDataLength else { return nil }
        var subRangeStart = 0
        var subRangeEnd = Int(self.fileNameLength)
        self.fileNameData = additionalData.subdata(in: subRangeStart..<subRangeEnd)
        subRangeStart += Int(self.fileNameLength)
        subRangeEnd = subRangeStart + Int(self.extraFieldLength)
        self.extraFieldData = additionalData.subdata(in: subRangeStart..<subRangeEnd)
        subRangeStart += Int(self.extraFieldLength)
        subRangeEnd = subRangeStart + Int(self.fileCommentLength)
        self.fileCommentData = additionalData.subdata(in: subRangeStart..<subRangeEnd)
    }

    init(localFileHeader: Entry.LocalFileHeader, fileAttributes: UInt32, relativeOffset: UInt32) {
        versionMadeBy = UInt16(789)
        versionNeededToExtract = localFileHeader.versionNeededToExtract
        generalPurposeBitFlag = localFileHeader.generalPurposeBitFlag
        compressionMethod = localFileHeader.compressionMethod
        lastModFileTime = localFileHeader.lastModFileTime
        lastModFileDate = localFileHeader.lastModFileDate
        crc32 = localFileHeader.crc32
        compressedSize = localFileHeader.compressedSize
        uncompressedSize = localFileHeader.uncompressedSize
        fileNameLength = localFileHeader.fileNameLength
        extraFieldLength = UInt16(0)
        fileCommentLength = UInt16(0)
        diskNumberStart = UInt16(0)
        internalFileAttributes = UInt16(0)
        externalFileAttributes = fileAttributes
        relativeOffsetOfLocalHeader = relativeOffset
        fileNameData = localFileHeader.fileNameData
        extraFieldData = Data()
        fileCommentData = Data()
    }

    init(centralDirectoryStructure: Entry.CentralDirectoryStructure, offset: UInt32) {
        let relativeOffset = centralDirectoryStructure.relativeOffsetOfLocalHeader - offset
        relativeOffsetOfLocalHeader = relativeOffset
        versionMadeBy = centralDirectoryStructure.versionMadeBy
        versionNeededToExtract = centralDirectoryStructure.versionNeededToExtract
        generalPurposeBitFlag = centralDirectoryStructure.generalPurposeBitFlag
        compressionMethod = centralDirectoryStructure.compressionMethod
        lastModFileTime = centralDirectoryStructure.lastModFileTime
        lastModFileDate = centralDirectoryStructure.lastModFileDate
        crc32 = centralDirectoryStructure.crc32
        compressedSize = centralDirectoryStructure.compressedSize
        uncompressedSize = centralDirectoryStructure.uncompressedSize
        fileNameLength = centralDirectoryStructure.fileNameLength
        extraFieldLength = centralDirectoryStructure.extraFieldLength
        fileCommentLength = centralDirectoryStructure.fileCommentLength
        diskNumberStart = centralDirectoryStructure.diskNumberStart
        internalFileAttributes = centralDirectoryStructure.internalFileAttributes
        externalFileAttributes = centralDirectoryStructure.externalFileAttributes
        fileNameData = centralDirectoryStructure.fileNameData
        extraFieldData = centralDirectoryStructure.extraFieldData
        fileCommentData = centralDirectoryStructure.fileCommentData
    }
}

extension Entry.DataDescriptor {
    init?(data: Data, additionalDataProvider provider: (Int) throws -> Data) {
        guard data.count == Entry.DataDescriptor.size else { return nil }
        let signature: UInt32 = data.scanValue(start: 0)
        // The DataDescriptor signature is not mandatory so we have to re-arrange the input data if it is missing.
        var readOffset = 0
        if signature == self.dataDescriptorSignature { readOffset = 4 }
        self.crc32 = data.scanValue(start: readOffset + 0)
        self.compressedSize = data.scanValue(start: readOffset + 4)
        self.uncompressedSize = data.scanValue(start: readOffset + 8)
        // Our add(_ entry:) methods always maintain compressed & uncompressed
        // sizes and so we don't need a data descriptor for newly added entries.
        // Data descriptors of already existing entries are manually preserved
        // when copying those entries to the tempArchive during remove(_ entry:).
        self.data = Data()
    }
}
