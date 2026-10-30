import XCTest
import Postbox
import SwiftSignalKit
@testable import TelegramCore

final class MultipartUploadTests: XCTestCase {
    /// A file uploaded while it is still being written (a recorded video) sends its first part last,
    /// once the file is complete. If the file can no longer be read by then, the upload failed silently
    /// and waited for ever.
    func testAnUnreadableFileFailsTheLastHeaderPartInsteadOfHanging() {
        let path = NSTemporaryDirectory() + "multipart-upload-\(UUID().uuidString)"
        let size = 256 * 1024
        XCTAssertTrue(FileManager.default.createFile(atPath: path, contents: Data(count: size)))
        defer {
            try? FileManager.default.removeItem(atPath: path)
        }
        let data = Promise<MultipartUploadData>()
        let uploadedParts = Atomic<[Int]>(value: [])
        let finished = expectation(description: "the upload finished")
        let result = Atomic<MultipartIntermediateResult??>(value: nil)
        let manager = MultipartUploadManager(headerSize: { 32 }, data: data.get(), encryptionKey: nil, hintFileSize: nil, hintFileIsLarge: false, forceNoBigParts: false, useLargerParts: false, increaseParallelParts: false, uploadPart: { part in
            let _ = uploadedParts.modify { $0 + [part.index] }
            return .complete()
        }, progress: { _ in
        }, completed: { value in
            let _ = result.swap(.some(value))
            finished.fulfill()
        })
        manager.start()

        data.set(.single(.resourceData(MediaResourceData(path: path, offset: 0, size: Int64(size), complete: false))))
        let deadline = Date().addingTimeInterval(5.0)
        while uploadedParts.with({ $0 }) != [1] && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        XCTAssertEqual(uploadedParts.with { $0 }, [1], "every part but the first goes while the file grows")

        try? FileManager.default.removeItem(atPath: path)
        data.set(.single(.resourceData(MediaResourceData(path: path, offset: 0, size: Int64(size), complete: true))))

        wait(for: [finished], timeout: 5.0)
        XCTAssertNotNil(result.with { $0 })
        XCTAssertNil(result.with { $0 } ?? nil, "the upload fails")
        XCTAssertEqual(uploadedParts.with { $0 }, [1])
    }

    /// A video handed to the uploader while it is still being exported reaches it only once it is past the small-file
    /// limit; the uploader must then use big parts, since small parts cannot carry a file over 10 MB, and still send the
    /// first part (the file's head, rewritten at the end) last.
    func testAGrowingFilePastTheSmallFileLimitUploadsInBigPartsWithTheHeadLast() {
        let path = NSTemporaryDirectory() + "multipart-upload-\(UUID().uuidString)"
        let partSize = 512 * 1024
        let finalSize = 11 * 1024 * 1024 + 100 * 1024
        XCTAssertTrue(FileManager.default.createFile(atPath: path, contents: Data(count: finalSize)))
        defer {
            try? FileManager.default.removeItem(atPath: path)
        }
        let data = Promise<MultipartUploadData>()
        let uploadedParts = Atomic<[(index: Int, size: Int, bigPart: Bool, bigTotalParts: Int?)]>(value: [])
        let finished = expectation(description: "the upload finished")
        let result = Atomic<MultipartIntermediateResult??>(value: nil)
        let manager = MultipartUploadManager(headerSize: { 32 }, data: data.get(), encryptionKey: nil, hintFileSize: nil, hintFileIsLarge: false, forceNoBigParts: false, useLargerParts: false, increaseParallelParts: false, uploadPart: { part in
            let _ = uploadedParts.modify { $0 + [(part.index, part.data.count, part.bigPart, part.bigTotalParts)] }
            return .complete() |> delay(0.001, queue: Queue.concurrentDefaultQueue())
        }, progress: { _ in
        }, completed: { value in
            let _ = result.swap(.some(value))
            finished.fulfill()
        })
        manager.start()

        data.set(.single(.resourceData(MediaResourceData(path: path, offset: 0, size: 0, complete: false))))
        let grownSize = 10 * 1024 * 1024 + 600 * 1024
        data.set(.single(.resourceData(MediaResourceData(path: path, offset: 0, size: Int64(grownSize), complete: false))))
        let partsWhileGrowing = grownSize / partSize - 1
        let deadline = Date().addingTimeInterval(5.0)
        while uploadedParts.with({ $0.count }) < partsWhileGrowing && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        let growing = uploadedParts.with { $0 }
        XCTAssertEqual(growing.map(\.index).sorted(), Array(1 ... partsWhileGrowing), "every full part but the first goes while the file grows")
        XCTAssertTrue(growing.allSatisfy { $0.bigPart && $0.size == partSize && $0.bigTotalParts == nil })

        data.set(.single(.resourceData(MediaResourceData(path: path, offset: 0, size: Int64(finalSize), complete: true))))
        wait(for: [finished], timeout: 5.0)

        let totalParts = (finalSize + partSize - 1) / partSize
        let all = uploadedParts.with { $0 }
        XCTAssertEqual(all.map(\.index).sorted(), Array(0 ..< totalParts))
        XCTAssertEqual(all.last?.index, 0, "the head goes last")
        XCTAssertTrue(all.allSatisfy { $0.bigPart })
        XCTAssertEqual(all.last?.bigTotalParts, totalParts)
        XCTAssertEqual((result.with { $0 } ?? nil)?.bigTotalParts, totalParts)
    }

    /// A head longer than one part (a long video's reserved `moov`) keeps every part it touches until the file is
    /// complete, and those parts carry the head as it is then, not as it was while the file grew.
    func testAHeadSpanningSeveralPartsIsHeldBackWholeAndSentAsFinallyWritten() {
        let path = NSTemporaryDirectory() + "multipart-upload-\(UUID().uuidString)"
        let partSize = 512 * 1024
        let headerSize = 2 * partSize + 100 * 1024
        let finalSize = 12 * 1024 * 1024 + 300 * 1024
        XCTAssertTrue(FileManager.default.createFile(atPath: path, contents: Data(count: finalSize)))
        defer {
            try? FileManager.default.removeItem(atPath: path)
        }
        let data = Promise<MultipartUploadData>()
        let uploadedParts = Atomic<[(index: Int, data: Data)]>(value: [])
        let finished = expectation(description: "the upload finished")
        let result = Atomic<MultipartIntermediateResult??>(value: nil)
        let currentHeaderSize = Atomic<Int64>(value: 32 * 1024)
        let manager = MultipartUploadManager(headerSize: { currentHeaderSize.with { $0 } }, data: data.get(), encryptionKey: nil, hintFileSize: nil, hintFileIsLarge: false, forceNoBigParts: false, useLargerParts: false, increaseParallelParts: false, uploadPart: { part in
            let _ = uploadedParts.modify { $0 + [(part.index, part.data)] }
            return .complete() |> delay(0.001, queue: Queue.concurrentDefaultQueue())
        }, progress: { _ in
        }, completed: { value in
            let _ = result.swap(.some(value))
            finished.fulfill()
        })
        manager.start()

        data.set(.single(.resourceData(MediaResourceData(path: path, offset: 0, size: 0, complete: false))))
        let _ = currentHeaderSize.swap(Int64(headerSize))
        let grownSize = 11 * 1024 * 1024
        data.set(.single(.resourceData(MediaResourceData(path: path, offset: 0, size: Int64(grownSize), complete: false))))
        let partsWhileGrowing = grownSize / partSize - 3
        let deadline = Date().addingTimeInterval(5.0)
        while uploadedParts.with({ $0.count }) < partsWhileGrowing && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        Thread.sleep(forTimeInterval: 0.05)
        XCTAssertEqual(uploadedParts.with { $0.map(\.index).sorted() }, Array(3 ..< grownSize / partSize), "the parts the head touches wait")

        guard let handle = FileHandle(forWritingAtPath: path) else {
            XCTFail()
            return
        }
        handle.write(Data(repeating: 0xab, count: headerSize))
        handle.closeFile()
        data.set(.single(.resourceData(MediaResourceData(path: path, offset: 0, size: Int64(finalSize), complete: true))))
        wait(for: [finished], timeout: 5.0)

        let totalParts = (finalSize + partSize - 1) / partSize
        let all = uploadedParts.with { $0 }
        XCTAssertEqual(all.map(\.index).sorted(), Array(0 ..< totalParts))
        XCTAssertEqual(Set(all.suffix(3).map(\.index)), [0, 1, 2], "the head goes last")
        for part in all where part.index < 3 {
            let start = part.index * partSize
            let expected = Data(repeating: 0xab, count: min(headerSize - start, partSize)) + Data(count: partSize - min(headerSize - start, partSize))
            XCTAssertEqual(part.data, expected, "part \(part.index) carries the final head")
        }
        XCTAssertEqual((result.with { $0 } ?? nil)?.bigTotalParts, totalParts)
        XCTAssertEqual((result.with { $0 } ?? nil)?.partCount, Int32(totalParts))
    }

    func testAGrowingFileWithoutBigPartsKeepsSmallPartsAndSendsTheHeadLast() {
        let path = NSTemporaryDirectory() + "multipart-upload-\(UUID().uuidString)"
        let partSize = 128 * 1024
        let headerSize = partSize + 50 * 1024
        let finalSize = 10 * 1024 * 1024 + 300 * 1024
        XCTAssertTrue(FileManager.default.createFile(atPath: path, contents: Data(count: finalSize)))
        defer {
            try? FileManager.default.removeItem(atPath: path)
        }
        let data = Promise<MultipartUploadData>()
        let uploadedParts = Atomic<[(index: Int, size: Int, bigPart: Bool)]>(value: [])
        let finished = expectation(description: "the upload finished")
        let result = Atomic<MultipartIntermediateResult??>(value: nil)
        let manager = MultipartUploadManager(headerSize: { Int64(headerSize) }, data: data.get(), encryptionKey: nil, hintFileSize: nil, hintFileIsLarge: false, forceNoBigParts: true, useLargerParts: false, increaseParallelParts: false, uploadPart: { part in
            let _ = uploadedParts.modify { $0 + [(part.index, part.data.count, part.bigPart)] }
            return .complete() |> delay(0.001, queue: Queue.concurrentDefaultQueue())
        }, progress: { _ in
        }, completed: { value in
            let _ = result.swap(.some(value))
            finished.fulfill()
        })
        manager.start()

        let grownSize = 1024 * 1024
        data.set(.single(.resourceData(MediaResourceData(path: path, offset: 0, size: Int64(grownSize), complete: false))))
        let deadline = Date().addingTimeInterval(5.0)
        while uploadedParts.with({ $0.count }) < grownSize / partSize - 2 && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        Thread.sleep(forTimeInterval: 0.05)
        XCTAssertEqual(uploadedParts.with { $0.map(\.index).sorted() }, Array(2 ..< grownSize / partSize), "the parts the head touches wait")

        data.set(.single(.resourceData(MediaResourceData(path: path, offset: 0, size: Int64(finalSize), complete: true))))
        wait(for: [finished], timeout: 5.0)

        let totalParts = (finalSize + partSize - 1) / partSize
        let all = uploadedParts.with { $0 }
        XCTAssertEqual(all.map(\.index).sorted(), Array(0 ..< totalParts))
        XCTAssertEqual(Set(all.suffix(2).map(\.index)), [0, 1], "the head goes last")
        XCTAssertTrue(all.allSatisfy { !$0.bigPart })
        XCTAssertTrue(all.allSatisfy { $0.size == partSize || $0.index == totalParts - 1 })
        XCTAssertNil((result.with { $0 } ?? nil)?.bigTotalParts)
        XCTAssertEqual((result.with { $0 } ?? nil)?.partCount, Int32(totalParts))
    }
}
