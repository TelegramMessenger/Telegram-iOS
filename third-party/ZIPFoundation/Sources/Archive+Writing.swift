//
//  Archive+Writing.swift
//  ZIPFoundation
//
//  Copyright © 2017-2020 Thomas Zoechling, https://www.peakstep.com and the ZIP Foundation project authors.
//  Released under the MIT License.
//
//  See https://github.com/weichsel/ZIPFoundation/blob/master/LICENSE for license information.
//

import Foundation

extension Archive {
    private enum ModifyOperation: Int {
        case remove = -1
        case add = 1
    }

    /// Write files, directories or symlinks to the receiver.
    ///
    /// - Parameters:
    ///   - path: The path that is used to identify an `Entry` within the `Archive` file.
    ///   - baseURL: The base URL of the `Entry` to add.
    ///              The `baseURL` combined with `path` must form a fully qualified file URL.
    ///   - compressionMethod: Indicates the `CompressionMethod` that should be applied to `Entry`.
    ///                        By default, no compression will be applied.
    ///   - bufferSize: The maximum size of the write buffer and the compression buffer (if needed).
    ///   - progress: A progress object that can be used to track or cancel the add operation.
    /// - Throws: An error if the source file cannot be read or the receiver is not writable.
    public func addEntry(with path: String, relativeTo baseURL: URL, compressionMethod: CompressionMethod = .none,
                         bufferSize: UInt32 = defaultWriteChunkSize, progress: Progress? = nil) throws {
        let fileManager = FileManager()
        let entryURL = baseURL.appendingPathComponent(path)
        guard fileManager.itemExists(at: entryURL) else {
            throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: entryURL.path])
        }
        let type = try FileManager.typeForItem(at: entryURL)
        // symlinks do not need to be readable
        guard type == .symlink || fileManager.isReadableFile(atPath: entryURL.path) else {
            throw CocoaError(.fileReadNoPermission, userInfo: [NSFilePathErrorKey: url.path])
        }
        let modDate = try FileManager.fileModificationDateTimeForItem(at: entryURL)
        let uncompressedSize = type == .directory ? 0 : try FileManager.fileSizeForItem(at: entryURL)
        let permissions = try FileManager.permissionsForItem(at: entryURL)
        var provider: Provider
        switch type {
        case .file:
            let entryFileSystemRepresentation = fileManager.fileSystemRepresentation(withPath: entryURL.path)
            guard let entryFile: UnsafeMutablePointer<FILE> = fopen(entryFileSystemRepresentation, "rb") else {
                throw CocoaError(.fileNoSuchFile)
            }
            defer { fclose(entryFile) }
            provider = { _, _ in return try Data.readChunk(of: Int(bufferSize), from: entryFile) }
            try self.addEntry(with: path, type: type, uncompressedSize: uncompressedSize,
                              modificationDate: modDate, permissions: permissions,
                              compressionMethod: compressionMethod, bufferSize: bufferSize,
                              progress: progress, provider: provider)
        case .directory:
            provider = { _, _ in return Data() }
            try self.addEntry(with: path.hasSuffix("/") ? path : path + "/",
                              type: type, uncompressedSize: uncompressedSize,
                              modificationDate: modDate, permissions: permissions,
                              compressionMethod: compressionMethod, bufferSize: bufferSize,
                              progress: progress, provider: provider)
        case .symlink:
            provider = { _, _ -> Data in
                let linkDestination = try fileManager.destinationOfSymbolicLink(atPath: entryURL.path)
                let linkFileSystemRepresentation = fileManager.fileSystemRepresentation(withPath: linkDestination)
                let linkLength = Int(strlen(linkFileSystemRepresentation))
                let linkBuffer = UnsafeBufferPointer(start: linkFileSystemRepresentation, count: linkLength)
                return Data(buffer: linkBuffer)
            }
            try self.addEntry(with: path, type: type, uncompressedSize: uncompressedSize,
                              modificationDate: modDate, permissions: permissions,
                              compressionMethod: compressionMethod, bufferSize: bufferSize,
                              progress: progress, provider: provider)
        }
    }

    /// Write files, directories or symlinks to the receiver.
    ///
    /// - Parameters:
    ///   - path: The path that is used to identify an `Entry` within the `Archive` file.
    ///   - type: Indicates the `Entry.EntryType` of the added content.
    ///   - uncompressedSize: The uncompressed size of the data that is going to be added with `provider`.
    ///   - modificationDate: A `Date` describing the file modification date of the `Entry`.
    ///                       Default is the current `Date`.
    ///   - permissions: POSIX file permissions for the `Entry`.
    ///                  Default is `0`o`644` for files and symlinks and `0`o`755` for directories.
    ///   - compressionMethod: Indicates the `CompressionMethod` that should be applied to `Entry`.
    ///                        By default, no compression will be applied.
    ///   - bufferSize: The maximum size of the write buffer and the compression buffer (if needed).
    ///   - progress: A progress object that can be used to track or cancel the add operation.
    ///   - provider: A closure that accepts a position and a chunk size. Returns a `Data` chunk.
    /// - Throws: An error if the source data is invalid or the receiver is not writable.
    public func addEntry(with path: String, type: Entry.EntryType, uncompressedSize: UInt32,
                         modificationDate: Date = Date(), permissions: UInt16? = nil,
                         compressionMethod: CompressionMethod = .none, bufferSize: UInt32 = defaultWriteChunkSize,
                         progress: Progress? = nil, provider: Provider) throws {
        guard self.accessMode != .read else { throw ArchiveError.unwritableArchive }
        // Directories and symlinks cannot be compressed
        let compressionMethod = type == .file ? compressionMethod : .none
        progress?.totalUnitCount = type == .directory ? defaultDirectoryUnitCount : Int64(uncompressedSize)
        var endOfCentralDirRecord = self.endOfCentralDirectoryRecord
        var startOfCD = Int(endOfCentralDirRecord.offsetToStartOfCentralDirectory)
        fseek(self.archiveFile, startOfCD, SEEK_SET)
        let existingCentralDirData = try Data.readChunk(of: Int(endOfCentralDirRecord.sizeOfCentralDirectory),
                                                        from: self.archiveFile)
        fseek(self.archiveFile, startOfCD, SEEK_SET)
        let localFileHeaderStart = ftell(self.archiveFile)
        let modDateTime = modificationDate.fileModificationDateTime
        defer { fflush(self.archiveFile) }
        do {
            var localFileHeader = try self.writeLocalFileHeader(path: path, compressionMethod: compressionMethod,
                                                                size: (uncompressedSize, 0), checksum: 0,
                                                                modificationDateTime: modDateTime)
            let (written, checksum) = try self.writeEntry(localFileHeader: localFileHeader, type: type,
                                                          compressionMethod: compressionMethod, bufferSize: bufferSize,
                                                          progress: progress, provider: provider)
            startOfCD = ftell(self.archiveFile)
            fseek(self.archiveFile, localFileHeaderStart, SEEK_SET)
            // Write the local file header a second time. Now with compressedSize (if applicable) and a valid checksum.
            localFileHeader = try self.writeLocalFileHeader(path: path, compressionMethod: compressionMethod,
                                                            size: (uncompressedSize, written),
                                                            checksum: checksum, modificationDateTime: modDateTime)
            fseek(self.archiveFile, startOfCD, SEEK_SET)
            _ = try Data.write(chunk: existingCentralDirData, to: self.archiveFile)
            let permissions = permissions ?? (type == .directory ? defaultDirectoryPermissions :defaultFilePermissions)
            let externalAttributes = FileManager.externalFileAttributesForEntry(of: type, permissions: permissions)
            let offset = UInt32(localFileHeaderStart)
            let centralDir = try self.writeCentralDirectoryStructure(localFileHeader: localFileHeader,
                                                                     relativeOffset: offset,
                                                                     externalFileAttributes: externalAttributes)
            if startOfCD > UINT32_MAX { throw ArchiveError.invalidStartOfCentralDirectoryOffset }
            endOfCentralDirRecord = try self.writeEndOfCentralDirectory(centralDirectoryStructure: centralDir,
                                                                        startOfCentralDirectory: UInt32(startOfCD),
                                                                        operation: .add)
            self.endOfCentralDirectoryRecord = endOfCentralDirRecord
        } catch ArchiveError.cancelledOperation {
            try rollback(localFileHeaderStart, existingCentralDirData, endOfCentralDirRecord)
            throw ArchiveError.cancelledOperation
        }
    }

    /// Remove a ZIP `Entry` from the receiver.
    ///
    /// - Parameters:
    ///   - entry: The `Entry` to remove.
    ///   - bufferSize: The maximum size for the read and write buffers used during removal.
    ///   - progress: A progress object that can be used to track or cancel the remove operation.
    /// - Throws: An error if the `Entry` is malformed or the receiver is not writable.
    public func remove(_ entry: Entry, bufferSize: UInt32 = defaultReadChunkSize, progress: Progress? = nil) throws {
		let manager = FileManager()
        let tempDir = self.uniqueTemporaryDirectoryURL()
        defer { try? manager.removeItem(at: tempDir) }
		let uniqueString = ProcessInfo.processInfo.globallyUniqueString
		let tempArchiveURL =  tempDir.appendingPathComponent(uniqueString)
        do { try manager.createParentDirectoryStructure(for: tempArchiveURL) } catch {
			throw ArchiveError.unwritableArchive }
        guard let tempArchive = Archive(url: tempArchiveURL, accessMode: .create) else {
            throw ArchiveError.unwritableArchive
        }
        progress?.totalUnitCount = self.totalUnitCountForRemoving(entry)
        var centralDirectoryData = Data()
        var offset = 0
        for currentEntry in self {
            let centralDirectoryStructure = currentEntry.centralDirectoryStructure
            if currentEntry != entry {
                let entryStart = Int(currentEntry.centralDirectoryStructure.relativeOffsetOfLocalHeader)
                fseek(self.archiveFile, entryStart, SEEK_SET)
                let provider: Provider = { (_, chunkSize) -> Data in
                    return try Data.readChunk(of: Int(chunkSize), from: self.archiveFile)
                }
                let consumer: Consumer = {
                    if progress?.isCancelled == true { throw ArchiveError.cancelledOperation }
                    _ = try Data.write(chunk: $0, to: tempArchive.archiveFile)
                    progress?.completedUnitCount += Int64($0.count)
                }
                _ = try Data.consumePart(of: Int(currentEntry.localSize), chunkSize: Int(bufferSize),
                                         provider: provider, consumer: consumer)
                let centralDir = CentralDirectoryStructure(centralDirectoryStructure: centralDirectoryStructure,
                                                           offset: UInt32(offset))
                centralDirectoryData.append(centralDir.data)
            } else { offset = currentEntry.localSize }
        }
        let startOfCentralDirectory = ftell(tempArchive.archiveFile)
        _ = try Data.write(chunk: centralDirectoryData, to: tempArchive.archiveFile)
        tempArchive.endOfCentralDirectoryRecord = self.endOfCentralDirectoryRecord
        let endOfCentralDirectoryRecord = try
            tempArchive.writeEndOfCentralDirectory(centralDirectoryStructure: entry.centralDirectoryStructure,
                                                   startOfCentralDirectory: UInt32(startOfCentralDirectory),
                                                   operation: .remove)
        tempArchive.endOfCentralDirectoryRecord = endOfCentralDirectoryRecord
        self.endOfCentralDirectoryRecord = endOfCentralDirectoryRecord
        fflush(tempArchive.archiveFile)
        try self.replaceCurrentArchiveWithArchive(at: tempArchive.url)
    }

    // MARK: - Helpers

    func uniqueTemporaryDirectoryURL() -> URL {
        #if swift(>=5.0) || os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
        if let tempDir = try? FileManager().url(for: .itemReplacementDirectory, in: .userDomainMask,
                                                appropriateFor: self.url, create: true) {
            return tempDir
        }
        #endif

        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
            ProcessInfo.processInfo.globallyUniqueString)
    }

    func replaceCurrentArchiveWithArchive(at URL: URL) throws {
        fclose(self.archiveFile)
        let fileManager = FileManager()
        #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
        do {
            _ = try fileManager.replaceItemAt(self.url, withItemAt: URL)
        } catch {
            _ = try fileManager.removeItem(at: self.url)
            _ = try fileManager.moveItem(at: URL, to: self.url)
        }
        #else
        _ = try fileManager.removeItem(at: self.url)
        _ = try fileManager.moveItem(at: URL, to: self.url)
        #endif
        let fileSystemRepresentation = fileManager.fileSystemRepresentation(withPath: self.url.path)
        self.archiveFile = fopen(fileSystemRepresentation, "rb+")
    }

    private func writeLocalFileHeader(path: String, compressionMethod: CompressionMethod,
                                      size: (uncompressed: UInt32, compressed: UInt32),
                                      checksum: CRC32,
                                      modificationDateTime: (UInt16, UInt16)) throws -> LocalFileHeader {
        // We always set Bit 11 in generalPurposeBitFlag, which indicates an UTF-8 encoded path.
        guard let fileNameData = path.data(using: .utf8) else { throw ArchiveError.invalidEntryPath }

        let localFileHeader = LocalFileHeader(versionNeededToExtract: UInt16(20), generalPurposeBitFlag: UInt16(2048),
                                              compressionMethod: compressionMethod.rawValue,
                                              lastModFileTime: modificationDateTime.1,
                                              lastModFileDate: modificationDateTime.0, crc32: checksum,
                                              compressedSize: size.compressed, uncompressedSize: size.uncompressed,
                                              fileNameLength: UInt16(fileNameData.count), extraFieldLength: UInt16(0),
                                              fileNameData: fileNameData, extraFieldData: Data())
        _ = try Data.write(chunk: localFileHeader.data, to: self.archiveFile)
        return localFileHeader
    }

    private func writeEntry(localFileHeader: LocalFileHeader, type: Entry.EntryType,
                            compressionMethod: CompressionMethod, bufferSize: UInt32, progress: Progress? = nil,
                            provider: Provider) throws -> (sizeWritten: UInt32, crc32: CRC32) {
        var checksum = CRC32(0)
        var sizeWritten = UInt32(0)
        switch type {
        case .file:
            switch compressionMethod {
            case .none:
                (sizeWritten, checksum) = try self.writeUncompressed(size: localFileHeader.uncompressedSize,
                                                                     bufferSize: bufferSize,
                                                                     progress: progress, provider: provider)
            case .deflate:
                (sizeWritten, checksum) = try self.writeCompressed(size: localFileHeader.uncompressedSize,
                                                                   bufferSize: bufferSize,
                                                                   progress: progress, provider: provider)
            }
        case .directory:
            _ = try provider(0, 0)
            if let progress = progress { progress.completedUnitCount = progress.totalUnitCount }
        case .symlink:
            (sizeWritten, checksum) = try self.writeSymbolicLink(size: localFileHeader.uncompressedSize,
                                                                 provider: provider)
            if let progress = progress { progress.completedUnitCount = progress.totalUnitCount }
        }
        return (sizeWritten, checksum)
    }

    private func writeUncompressed(size: UInt32, bufferSize: UInt32, progress: Progress? = nil,
                                   provider: Provider) throws -> (sizeWritten: UInt32, checksum: CRC32) {
        var position = 0
        var sizeWritten = 0
        var checksum = CRC32(0)
        while position < size {
            if progress?.isCancelled == true { throw ArchiveError.cancelledOperation }
            let readSize = (Int(size) - position) >= bufferSize ? Int(bufferSize) : (Int(size) - position)
            let entryChunk = try provider(Int(position), Int(readSize))
            checksum = entryChunk.crc32(checksum: checksum)
            sizeWritten += try Data.write(chunk: entryChunk, to: self.archiveFile)
            position += Int(bufferSize)
            progress?.completedUnitCount = Int64(sizeWritten)
        }
        return (UInt32(sizeWritten), checksum)
    }

    private func writeCompressed(size: UInt32, bufferSize: UInt32, progress: Progress? = nil,
                                 provider: Provider) throws -> (sizeWritten: UInt32, checksum: CRC32) {
        var sizeWritten = 0
        let consumer: Consumer = { data in sizeWritten += try Data.write(chunk: data, to: self.archiveFile) }
        let checksum = try Data.compress(size: Int(size), bufferSize: Int(bufferSize),
                                         provider: { (position, size) -> Data in
                                            if progress?.isCancelled == true { throw ArchiveError.cancelledOperation }
                                            let data = try provider(position, size)
                                            progress?.completedUnitCount += Int64(data.count)
                                            return data
                                         }, consumer: consumer)
        return(UInt32(sizeWritten), checksum)
    }

    private func writeSymbolicLink(size: UInt32, provider: Provider) throws -> (sizeWritten: UInt32, checksum: CRC32) {
        let linkData = try provider(0, Int(size))
        let checksum = linkData.crc32(checksum: 0)
        let sizeWritten = try Data.write(chunk: linkData, to: self.archiveFile)
        return (UInt32(sizeWritten), checksum)
    }

    private func writeCentralDirectoryStructure(localFileHeader: LocalFileHeader, relativeOffset: UInt32,
                                                externalFileAttributes: UInt32) throws -> CentralDirectoryStructure {
        let centralDirectory = CentralDirectoryStructure(localFileHeader: localFileHeader,
                                                         fileAttributes: externalFileAttributes,
                                                         relativeOffset: relativeOffset)
        _ = try Data.write(chunk: centralDirectory.data, to: self.archiveFile)
        return centralDirectory
    }

    private func writeEndOfCentralDirectory(centralDirectoryStructure: CentralDirectoryStructure,
                                            startOfCentralDirectory: UInt32,
                                            operation: ModifyOperation) throws -> EndOfCentralDirectoryRecord {
        var record = self.endOfCentralDirectoryRecord
        let countChange = operation.rawValue
        var dataLength = Int(centralDirectoryStructure.extraFieldLength)
        dataLength += Int(centralDirectoryStructure.fileNameLength)
        dataLength += Int(centralDirectoryStructure.fileCommentLength)
        let centralDirectoryDataLengthChange = operation.rawValue * (dataLength + CentralDirectoryStructure.size)
        var updatedSizeOfCentralDirectory = Int(record.sizeOfCentralDirectory)
        updatedSizeOfCentralDirectory += centralDirectoryDataLengthChange
        let numberOfEntriesOnDisk = UInt16(Int(record.totalNumberOfEntriesOnDisk) + countChange)
        let numberOfEntriesInCentralDirectory = UInt16(Int(record.totalNumberOfEntriesInCentralDirectory) + countChange)
        record = EndOfCentralDirectoryRecord(record: record, numberOfEntriesOnDisk: numberOfEntriesOnDisk,
                                             numberOfEntriesInCentralDirectory: numberOfEntriesInCentralDirectory,
                                             updatedSizeOfCentralDirectory: UInt32(updatedSizeOfCentralDirectory),
                                             startOfCentralDirectory: startOfCentralDirectory)
        _ = try Data.write(chunk: record.data, to: self.archiveFile)
        return record
    }

    private func rollback(_ localFileHeaderStart: Int,
                          _ existingCentralDirectoryData: Data,
                          _ endOfCentralDirRecord: EndOfCentralDirectoryRecord) throws {
        fflush(self.archiveFile)
        ftruncate(fileno(self.archiveFile), off_t(localFileHeaderStart))
        fseek(self.archiveFile, localFileHeaderStart, SEEK_SET)
        _ = try Data.write(chunk: existingCentralDirectoryData, to: self.archiveFile)
        _ = try Data.write(chunk: endOfCentralDirRecord.data, to: self.archiveFile)
    }
}
