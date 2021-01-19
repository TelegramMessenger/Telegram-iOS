//
//  Archive+Reading.swift
//  ZIPFoundation
//
//  Copyright © 2017-2020 Thomas Zoechling, https://www.peakstep.com and the ZIP Foundation project authors.
//  Released under the MIT License.
//
//  See https://github.com/weichsel/ZIPFoundation/blob/master/LICENSE for license information.
//

import Foundation

extension Archive {
    /// Read a ZIP `Entry` from the receiver and write it to `url`.
    ///
    /// - Parameters:
    ///   - entry: The ZIP `Entry` to read.
    ///   - url: The destination file URL.
    ///   - bufferSize: The maximum size of the read buffer and the decompression buffer (if needed).
    ///   - skipCRC32: Optional flag to skip calculation of the CRC32 checksum to improve performance.
    ///   - progress: A progress object that can be used to track or cancel the extract operation.
    /// - Returns: The checksum of the processed content or 0 if the `skipCRC32` flag was set to `true`.
    /// - Throws: An error if the destination file cannot be written or the entry contains malformed content.
    public func extract(_ entry: Entry, to url: URL, bufferSize: UInt32 = defaultReadChunkSize, skipCRC32: Bool = false,
                        progress: Progress? = nil) throws -> CRC32 {
        let fileManager = FileManager()
        var checksum = CRC32(0)
        switch entry.type {
        case .file:
            guard !fileManager.itemExists(at: url) else {
                throw CocoaError(.fileWriteFileExists, userInfo: [NSFilePathErrorKey: url.path])
            }
            try fileManager.createParentDirectoryStructure(for: url)
            let destinationRepresentation = fileManager.fileSystemRepresentation(withPath: url.path)
            guard let destinationFile: UnsafeMutablePointer<FILE> = fopen(destinationRepresentation, "wb+") else {
                throw CocoaError(.fileNoSuchFile)
            }
            defer { fclose(destinationFile) }
            let consumer = { _ = try Data.write(chunk: $0, to: destinationFile) }
            checksum = try self.extract(entry, bufferSize: bufferSize, skipCRC32: skipCRC32,
                                        progress: progress, consumer: consumer)
        case .directory:
            let consumer = { (_: Data) in
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            }
            checksum = try self.extract(entry, bufferSize: bufferSize, skipCRC32: skipCRC32,
                                        progress: progress, consumer: consumer)
        case .symlink:
            guard !fileManager.itemExists(at: url) else {
                throw CocoaError(.fileWriteFileExists, userInfo: [NSFilePathErrorKey: url.path])
            }
            let consumer = { (data: Data) in
                guard let linkPath = String(data: data, encoding: .utf8) else { throw ArchiveError.invalidEntryPath }
                try fileManager.createParentDirectoryStructure(for: url)
                try fileManager.createSymbolicLink(atPath: url.path, withDestinationPath: linkPath)
            }
            checksum = try self.extract(entry, bufferSize: bufferSize, skipCRC32: skipCRC32,
                                        progress: progress, consumer: consumer)
        }
        let attributes = FileManager.attributes(from: entry)
        try fileManager.setAttributes(attributes, ofItemAtPath: url.path)
        return checksum
    }

    /// Read a ZIP `Entry` from the receiver and forward its contents to a `Consumer` closure.
    ///
    /// - Parameters:
    ///   - entry: The ZIP `Entry` to read.
    ///   - bufferSize: The maximum size of the read buffer and the decompression buffer (if needed).
    ///   - skipCRC32: Optional flag to skip calculation of the CRC32 checksum to improve performance.
    ///   - progress: A progress object that can be used to track or cancel the extract operation.
    ///   - consumer: A closure that consumes contents of `Entry` as `Data` chunks.
    /// - Returns: The checksum of the processed content or 0 if the `skipCRC32` flag was set to `true`..
    /// - Throws: An error if the destination file cannot be written or the entry contains malformed content.
    public func extract(_ entry: Entry, bufferSize: UInt32 = defaultReadChunkSize, skipCRC32: Bool = false,
                        progress: Progress? = nil, consumer: Consumer) throws -> CRC32 {
        var checksum = CRC32(0)
        let localFileHeader = entry.localFileHeader
        fseek(self.archiveFile, entry.dataOffset, SEEK_SET)
        progress?.totalUnitCount = self.totalUnitCountForReading(entry)
        switch entry.type {
        case .file:
            guard let compressionMethod = CompressionMethod(rawValue: localFileHeader.compressionMethod) else {
                throw ArchiveError.invalidCompressionMethod
            }
            switch compressionMethod {
            case .none: checksum = try self.readUncompressed(entry: entry, bufferSize: bufferSize,
                                                             skipCRC32: skipCRC32, progress: progress, with: consumer)
            case .deflate: checksum = try self.readCompressed(entry: entry, bufferSize: bufferSize,
                                                              skipCRC32: skipCRC32, progress: progress, with: consumer)
            }
        case .directory:
            try consumer(Data())
            progress?.completedUnitCount = self.totalUnitCountForReading(entry)
        case .symlink:
            let localFileHeader = entry.localFileHeader
            let size = Int(localFileHeader.compressedSize)
            let data = try Data.readChunk(of: size, from: self.archiveFile)
            checksum = data.crc32(checksum: 0)
            try consumer(data)
            progress?.completedUnitCount = self.totalUnitCountForReading(entry)
        }
        return checksum
    }

    // MARK: - Helpers

    private func readUncompressed(entry: Entry, bufferSize: UInt32, skipCRC32: Bool,
                                  progress: Progress? = nil, with consumer: Consumer) throws -> CRC32 {
        let size = Int(entry.centralDirectoryStructure.uncompressedSize)
        return try Data.consumePart(of: size, chunkSize: Int(bufferSize), skipCRC32: skipCRC32,
                                    provider: { (_, chunkSize) -> Data in
            return try Data.readChunk(of: Int(chunkSize), from: self.archiveFile)
        }, consumer: { (data) in
            if progress?.isCancelled == true { throw ArchiveError.cancelledOperation }
            try consumer(data)
            progress?.completedUnitCount += Int64(data.count)
        })
    }

    private func readCompressed(entry: Entry, bufferSize: UInt32, skipCRC32: Bool,
                                progress: Progress? = nil, with consumer: Consumer) throws -> CRC32 {
        let size = Int(entry.centralDirectoryStructure.compressedSize)
        return try Data.decompress(size: size, bufferSize: Int(bufferSize), skipCRC32: skipCRC32,
                                   provider: { (_, chunkSize) -> Data in
            return try Data.readChunk(of: chunkSize, from: self.archiveFile)
        }, consumer: { (data) in
            if progress?.isCancelled == true { throw ArchiveError.cancelledOperation }
            try consumer(data)
            progress?.completedUnitCount += Int64(data.count)
        })
    }
}
