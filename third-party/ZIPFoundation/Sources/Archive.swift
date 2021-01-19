//
//  Archive.swift
//  ZIPFoundation
//
//  Copyright © 2017-2020 Thomas Zoechling, https://www.peakstep.com and the ZIP Foundation project authors.
//  Released under the MIT License.
//
//  See https://github.com/weichsel/ZIPFoundation/blob/master/LICENSE for license information.
//

import Foundation

/// The default chunk size when reading entry data from an archive.
public let defaultReadChunkSize = UInt32(16*1024)
/// The default chunk size when writing entry data to an archive.
public let defaultWriteChunkSize = defaultReadChunkSize
/// The default permissions for newly added entries.
public let defaultFilePermissions = UInt16(0o644)
public let defaultDirectoryPermissions = UInt16(0o755)
let defaultPOSIXBufferSize = defaultReadChunkSize
let defaultDirectoryUnitCount = Int64(1)
let minDirectoryEndOffset = 22
let maxDirectoryEndOffset = 66000
let endOfCentralDirectoryStructSignature = 0x06054b50
let localFileHeaderStructSignature = 0x04034b50
let dataDescriptorStructSignature = 0x08074b50
let centralDirectoryStructSignature = 0x02014b50

/// The compression method of an `Entry` in a ZIP `Archive`.
public enum CompressionMethod: UInt16 {
    /// Indicates that an `Entry` has no compression applied to its contents.
    case none = 0
    /// Indicates that contents of an `Entry` have been compressed with a zlib compatible Deflate algorithm.
    case deflate = 8
}

/// A sequence of uncompressed or compressed ZIP entries.
///
/// You use an `Archive` to create, read or update ZIP files.
/// To read an existing ZIP file, you have to pass in an existing file `URL` and `AccessMode.read`:
///
///     var archiveURL = URL(fileURLWithPath: "/path/file.zip")
///     var archive = Archive(url: archiveURL, accessMode: .read)
///
/// An `Archive` is a sequence of entries. You can
/// iterate over an archive using a `for`-`in` loop to get access to individual `Entry` objects:
///
///     for entry in archive {
///         print(entry.path)
///     }
///
/// Each `Entry` in an `Archive` is represented by its `path`. You can
/// use `path` to retrieve the corresponding `Entry` from an `Archive` via subscripting:
///
///     let entry = archive['/path/file.txt']
///
/// To create a new `Archive`, pass in a non-existing file URL and `AccessMode.create`. To modify an
/// existing `Archive` use `AccessMode.update`:
///
///     var archiveURL = URL(fileURLWithPath: "/path/file.zip")
///     var archive = Archive(url: archiveURL, accessMode: .update)
///     try archive?.addEntry("test.txt", relativeTo: baseURL, compressionMethod: .deflate)
public final class Archive: Sequence {
    typealias LocalFileHeader = Entry.LocalFileHeader
    typealias DataDescriptor = Entry.DataDescriptor
    typealias CentralDirectoryStructure = Entry.CentralDirectoryStructure

    /// An error that occurs during reading, creating or updating a ZIP file.
    public enum ArchiveError: Error {
        /// Thrown when an archive file is either damaged or inaccessible.
        case unreadableArchive
        /// Thrown when an archive is either opened with AccessMode.read or the destination file is unwritable.
        case unwritableArchive
        /// Thrown when the path of an `Entry` cannot be stored in an archive.
        case invalidEntryPath
        /// Thrown when an `Entry` can't be stored in the archive with the proposed compression method.
        case invalidCompressionMethod
        /// Thrown when the start of the central directory exceeds `UINT32_MAX`
        case invalidStartOfCentralDirectoryOffset
        /// Thrown when an archive does not contain the required End of Central Directory Record.
        case missingEndOfCentralDirectoryRecord
        /// Thrown when an extract, add or remove operation was canceled.
        case cancelledOperation
    }

    /// The access mode for an `Archive`.
    public enum AccessMode: UInt {
        /// Indicates that a newly instantiated `Archive` should create its backing file.
        case create
        /// Indicates that a newly instantiated `Archive` should read from an existing backing file.
        case read
        /// Indicates that a newly instantiated `Archive` should update an existing backing file.
        case update
    }

    struct EndOfCentralDirectoryRecord: DataSerializable {
        let endOfCentralDirectorySignature = UInt32(endOfCentralDirectoryStructSignature)
        let numberOfDisk: UInt16
        let numberOfDiskStart: UInt16
        let totalNumberOfEntriesOnDisk: UInt16
        let totalNumberOfEntriesInCentralDirectory: UInt16
        let sizeOfCentralDirectory: UInt32
        let offsetToStartOfCentralDirectory: UInt32
        let zipFileCommentLength: UInt16
        let zipFileCommentData: Data
        static let size = 22
    }

    private var preferredEncoding: String.Encoding?
    /// URL of an Archive's backing file.
    public let url: URL
    /// Access mode for an archive file.
    public let accessMode: AccessMode
    var archiveFile: UnsafeMutablePointer<FILE>
    var endOfCentralDirectoryRecord: EndOfCentralDirectoryRecord

    /// Initializes a new ZIP `Archive`.
    ///
    /// You can use this initalizer to create new archive files or to read and update existing ones.
    /// The `mode` parameter indicates the intended usage of the archive: `.read`, `.create` or `.update`.
    /// - Parameters:
    ///   - url: File URL to the receivers backing file.
    ///   - mode: Access mode of the receiver.
    ///   - preferredEncoding: Encoding for entry paths. Overrides the encoding specified in the archive.
    ///                        This encoding is only used when _decoding_ paths from the receiver.
    ///                        Paths of entries added with `addEntry` are always UTF-8 encoded.
    /// - Returns: An archive initialized with a backing file at the passed in file URL and the given access mode
    ///   or `nil` if the following criteria are not met:
    /// - Note:
    ///   - The file URL _must_ point to an existing file for `AccessMode.read`.
    ///   - The file URL _must_ point to a non-existing file for `AccessMode.create`.
    ///   - The file URL _must_ point to an existing file for `AccessMode.update`.
    public init?(url: URL, accessMode mode: AccessMode, preferredEncoding: String.Encoding? = nil) {
        self.url = url
        self.accessMode = mode
        self.preferredEncoding = preferredEncoding
        guard let (archiveFile, endOfCentralDirectoryRecord) = Archive.configureFileBacking(for: url, mode: mode) else {
            return nil
        }
        self.archiveFile = archiveFile
        self.endOfCentralDirectoryRecord = endOfCentralDirectoryRecord
        setvbuf(self.archiveFile, nil, _IOFBF, Int(defaultPOSIXBufferSize))
    }

    #if swift(>=5.0)
    var memoryFile: MemoryFile?

    /// Initializes a new in-memory ZIP `Archive`.
    ///
    /// You can use this initalizer to create new in-memory archive files or to read and update existing ones.
    ///
    /// - Parameters:
    ///   - data: `Data` object used as backing for in-memory archives.
    ///   - mode: Access mode of the receiver.
    ///   - preferredEncoding: Encoding for entry paths. Overrides the encoding specified in the archive.
    ///                        This encoding is only used when _decoding_ paths from the receiver.
    ///                        Paths of entries added with `addEntry` are always UTF-8 encoded.
    /// - Returns: An in-memory archive initialized with passed in backing data.
    /// - Note:
    ///   - The backing `data` _must_ contain a valid ZIP archive for `AccessMode.read` and `AccessMode.update`.
    ///   - The backing `data` _must_ be empty (or omitted) for `AccessMode.create`.
    public init?(data: Data = Data(), accessMode mode: AccessMode, preferredEncoding: String.Encoding? = nil) {
        guard let url = URL(string: "memory:"),
            let (archiveFile, memoryFile) = Archive.configureMemoryBacking(for: data, mode: mode) else {
            return nil
        }

        self.url = url
        self.accessMode = mode
        self.preferredEncoding = preferredEncoding
        self.archiveFile = archiveFile
        self.memoryFile = memoryFile
        guard let endOfCentralDirectoryRecord = Archive.scanForEndOfCentralDirectoryRecord(in: archiveFile)
            else {
                fclose(self.archiveFile)
                return nil
        }
        self.endOfCentralDirectoryRecord = endOfCentralDirectoryRecord
    }
    #endif

    deinit {
        fclose(self.archiveFile)
    }

    public func makeIterator() -> AnyIterator<Entry> {
        let endOfCentralDirectoryRecord = self.endOfCentralDirectoryRecord
        var directoryIndex = Int(endOfCentralDirectoryRecord.offsetToStartOfCentralDirectory)
        var index = 0
        return AnyIterator {
            guard index < Int(endOfCentralDirectoryRecord.totalNumberOfEntriesInCentralDirectory) else { return nil }
            guard let centralDirStruct: CentralDirectoryStructure = Data.readStruct(from: self.archiveFile,
                                                                                    at: directoryIndex) else {
                                                                                        return nil
            }
            let offset = Int(centralDirStruct.relativeOffsetOfLocalHeader)
            guard let localFileHeader: LocalFileHeader = Data.readStruct(from: self.archiveFile,
                                                                         at: offset) else { return nil }
            var dataDescriptor: DataDescriptor?
            if centralDirStruct.usesDataDescriptor {
                let additionalSize = Int(localFileHeader.fileNameLength) + Int(localFileHeader.extraFieldLength)
                let isCompressed = centralDirStruct.compressionMethod != CompressionMethod.none.rawValue
                let dataSize = isCompressed ? centralDirStruct.compressedSize : centralDirStruct.uncompressedSize
                let descriptorPosition = offset + LocalFileHeader.size + additionalSize + Int(dataSize)
                dataDescriptor = Data.readStruct(from: self.archiveFile, at: descriptorPosition)
            }
            defer {
                directoryIndex += CentralDirectoryStructure.size
                directoryIndex += Int(centralDirStruct.fileNameLength)
                directoryIndex += Int(centralDirStruct.extraFieldLength)
                directoryIndex += Int(centralDirStruct.fileCommentLength)
                index += 1
            }
            return Entry(centralDirectoryStructure: centralDirStruct,
                         localFileHeader: localFileHeader, dataDescriptor: dataDescriptor)
        }
    }

    /// Retrieve the ZIP `Entry` with the given `path` from the receiver.
    ///
    /// - Note: The ZIP file format specification does not enforce unique paths for entries.
    ///   Therefore an archive can contain multiple entries with the same path. This method
    ///   always returns the first `Entry` with the given `path`.
    ///
    /// - Parameter path: A relative file path identifiying the corresponding `Entry`.
    /// - Returns: An `Entry` with the given `path`. Otherwise, `nil`.
    public subscript(path: String) -> Entry? {
        if let encoding = preferredEncoding {
            return self.first { $0.path(using: encoding) == path }
        }
        return self.first { $0.path == path }
    }

    // MARK: - Helpers

    private static func configureFileBacking(for url: URL, mode: AccessMode)
        -> (UnsafeMutablePointer<FILE>, EndOfCentralDirectoryRecord)? {
        let fileManager = FileManager()
        switch mode {
        case .read:
            let fileSystemRepresentation = fileManager.fileSystemRepresentation(withPath: url.path)
            guard let archiveFile = fopen(fileSystemRepresentation, "rb"),
                let endOfCentralDirectoryRecord = Archive.scanForEndOfCentralDirectoryRecord(in: archiveFile) else {
                    return nil
            }
            return (archiveFile, endOfCentralDirectoryRecord)
        case .create:
            let endOfCentralDirectoryRecord = EndOfCentralDirectoryRecord(numberOfDisk: 0, numberOfDiskStart: 0,
                                                                          totalNumberOfEntriesOnDisk: 0,
                                                                          totalNumberOfEntriesInCentralDirectory: 0,
                                                                          sizeOfCentralDirectory: 0,
                                                                          offsetToStartOfCentralDirectory: 0,
                                                                          zipFileCommentLength: 0,
                                                                          zipFileCommentData: Data())
            do {
                try endOfCentralDirectoryRecord.data.write(to: url, options: .withoutOverwriting)
            } catch { return nil }
            fallthrough
        case .update:
            let fileSystemRepresentation = fileManager.fileSystemRepresentation(withPath: url.path)
            guard let archiveFile = fopen(fileSystemRepresentation, "rb+"),
                let endOfCentralDirectoryRecord = Archive.scanForEndOfCentralDirectoryRecord(in: archiveFile) else {
                    return nil
            }
            fseek(archiveFile, 0, SEEK_SET)
            return (archiveFile, endOfCentralDirectoryRecord)
        }
    }

    private static func scanForEndOfCentralDirectoryRecord(in file: UnsafeMutablePointer<FILE>)
        -> EndOfCentralDirectoryRecord? {
        var directoryEnd = 0
        var index = minDirectoryEndOffset
        fseek(file, 0, SEEK_END)
        let archiveLength = ftell(file)
        while directoryEnd == 0 && index < maxDirectoryEndOffset && index <= archiveLength {
            fseek(file, archiveLength - index, SEEK_SET)
            var potentialDirectoryEndTag: UInt32 = UInt32()
            fread(&potentialDirectoryEndTag, 1, MemoryLayout<UInt32>.size, file)
            if potentialDirectoryEndTag == UInt32(endOfCentralDirectoryStructSignature) {
                directoryEnd = archiveLength - index
                return Data.readStruct(from: file, at: directoryEnd)
            }
            index += 1
        }
        return nil
    }
}

extension Archive {
    /// The number of the work units that have to be performed when
    /// removing `entry` from the receiver.
    ///
    /// - Parameter entry: The entry that will be removed.
    /// - Returns: The number of the work units.
    public func totalUnitCountForRemoving(_ entry: Entry) -> Int64 {
        return Int64(self.endOfCentralDirectoryRecord.offsetToStartOfCentralDirectory
                   - UInt32(entry.localSize))
    }

    func makeProgressForRemoving(_ entry: Entry) -> Progress {
        return Progress(totalUnitCount: self.totalUnitCountForRemoving(entry))
    }

    /// The number of the work units that have to be performed when
    /// reading `entry` from the receiver.
    ///
    /// - Parameter entry: The entry that will be read.
    /// - Returns: The number of the work units.
    public func totalUnitCountForReading(_ entry: Entry) -> Int64 {
        switch entry.type {
        case .file, .symlink:
            return Int64(entry.uncompressedSize)
        case .directory:
            return defaultDirectoryUnitCount
        }
    }

    func makeProgressForReading(_ entry: Entry) -> Progress {
        return Progress(totalUnitCount: self.totalUnitCountForReading(entry))
    }

    /// The number of the work units that have to be performed when
    /// adding the file at `url` to the receiver.
    /// - Parameter entry: The entry that will be removed.
    /// - Returns: The number of the work units.
    public func totalUnitCountForAddingItem(at url: URL) -> Int64 {
        var count = Int64(0)
        do {
            let type = try FileManager.typeForItem(at: url)
            switch type {
            case .file, .symlink:
                count = Int64(try FileManager.fileSizeForItem(at: url))
            case .directory:
                count = defaultDirectoryUnitCount
            }
        } catch { count = -1 }
        return count
    }

    func makeProgressForAddingItem(at url: URL) -> Progress {
        return Progress(totalUnitCount: self.totalUnitCountForAddingItem(at: url))
    }
}

extension Archive.EndOfCentralDirectoryRecord {
    var data: Data {
        var endOfCDSignature = self.endOfCentralDirectorySignature
        var numberOfDisk = self.numberOfDisk
        var numberOfDiskStart = self.numberOfDiskStart
        var totalNumberOfEntriesOnDisk = self.totalNumberOfEntriesOnDisk
        var totalNumberOfEntriesInCD = self.totalNumberOfEntriesInCentralDirectory
        var sizeOfCentralDirectory = self.sizeOfCentralDirectory
        var offsetToStartOfCD = self.offsetToStartOfCentralDirectory
        var zipFileCommentLength = self.zipFileCommentLength
        var data = Data()
        withUnsafePointer(to: &endOfCDSignature, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &numberOfDisk, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &numberOfDiskStart, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &totalNumberOfEntriesOnDisk, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &totalNumberOfEntriesInCD, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &sizeOfCentralDirectory, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &offsetToStartOfCD, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        withUnsafePointer(to: &zipFileCommentLength, { data.append(UnsafeBufferPointer(start: $0, count: 1))})
        data.append(self.zipFileCommentData)
        return data
    }

    init?(data: Data, additionalDataProvider provider: (Int) throws -> Data) {
        guard data.count == Archive.EndOfCentralDirectoryRecord.size else { return nil }
        guard data.scanValue(start: 0) == endOfCentralDirectorySignature else { return nil }
        self.numberOfDisk = data.scanValue(start: 4)
        self.numberOfDiskStart = data.scanValue(start: 6)
        self.totalNumberOfEntriesOnDisk = data.scanValue(start: 8)
        self.totalNumberOfEntriesInCentralDirectory = data.scanValue(start: 10)
        self.sizeOfCentralDirectory = data.scanValue(start: 12)
        self.offsetToStartOfCentralDirectory = data.scanValue(start: 16)
        self.zipFileCommentLength = data.scanValue(start: 20)
        guard let commentData = try? provider(Int(self.zipFileCommentLength)) else { return nil }
        guard commentData.count == Int(self.zipFileCommentLength) else { return nil }
        self.zipFileCommentData = commentData
    }

    init(record: Archive.EndOfCentralDirectoryRecord,
         numberOfEntriesOnDisk: UInt16,
         numberOfEntriesInCentralDirectory: UInt16,
         updatedSizeOfCentralDirectory: UInt32,
         startOfCentralDirectory: UInt32) {
        numberOfDisk = record.numberOfDisk
        numberOfDiskStart = record.numberOfDiskStart
        totalNumberOfEntriesOnDisk = numberOfEntriesOnDisk
        totalNumberOfEntriesInCentralDirectory = numberOfEntriesInCentralDirectory
        sizeOfCentralDirectory = updatedSizeOfCentralDirectory
        offsetToStartOfCentralDirectory = startOfCentralDirectory
        zipFileCommentLength = record.zipFileCommentLength
        zipFileCommentData = record.zipFileCommentData
    }
}
