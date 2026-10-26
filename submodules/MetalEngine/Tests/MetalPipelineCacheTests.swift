import Foundation
import Metal
import XCTest

final class MetalPipelineCacheTests: XCTestCase {
    private var directoryUrl: URL!

    override func setUpWithError() throws {
        self.directoryUrl = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("MetalPipelineCacheTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: self.directoryUrl, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        for item in (try? FileManager.default.contentsOfDirectory(atPath: self.directoryUrl.path)) ?? [] {
            let _ = chflags(self.directoryUrl.appendingPathComponent(item).path, 0)
        }
        let _ = try? FileManager.default.removeItem(at: self.directoryUrl)
    }

    private func makeDevice() throws -> MTLDevice {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device")
        }
        return device
    }

    /// A pipeline no archive has seen: its code is new to this process.
    private func makeNewComputeDescriptor(device: MTLDevice) throws -> MTLComputePipelineDescriptor {
        let source = """
        #include <metal_stdlib>
        using namespace metal;
        kernel void testKernel(device float *values [[buffer(0)]], uint index [[thread_position_in_grid]]) {
            values[index] = values[index] * 2.0 + \(UInt32.random(in: 0 ..< UInt32.max)).0;
        }
        """
        let library = try device.makeLibrary(source: source, options: nil)
        let descriptor = MTLComputePipelineDescriptor()
        descriptor.computeFunction = try XCTUnwrap(library.makeFunction(name: "testKernel"))
        return descriptor
    }

    private func archiveUrl(device: MTLDevice) -> URL {
        return self.directoryUrl.appendingPathComponent(MetalPipelineCache.archiveFileName(device: device))
    }

    private func waitUntil(timeout: TimeInterval = 10.0, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                return false
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return true
    }

    /// Makes a pipeline through a fresh cache and waits for the cache to save its archive.
    private func saveArchive(device: MTLDevice) throws {
        let cache = MetalPipelineCache(device: device, directoryUrl: self.directoryUrl)
        XCTAssertNotNil(cache.makeComputePipelineState(descriptor: try self.makeNewComputeDescriptor(device: device)))
        let archiveUrl = self.archiveUrl(device: device)
        let markerUrl = MetalPipelineCache.saveMarkerUrl(archiveUrl: archiveUrl)
        XCTAssertTrue(self.waitUntil {
            FileManager.default.fileExists(atPath: archiveUrl.path) && !FileManager.default.fileExists(atPath: markerUrl.path)
        })
    }

    // MARK: - Metal's use of a freed error

    /// Metal ends a serialization by moving its output over the target; when that move fails, Metal frees the error before
    /// returning it, and the caller crashes retaining it (iOS 26.3, macOS 27). A target that cannot be replaced makes the
    /// move fail.
    func testFailedMoveIsThrownInsteadOfCrashing() throws {
        let device = try self.makeDevice()
        let archive = try device.makeBinaryArchive(descriptor: MTLBinaryArchiveDescriptor())
        try archive.addComputePipelineFunctions(descriptor: try self.makeNewComputeDescriptor(device: device))

        let targetUrl = self.directoryUrl.appendingPathComponent("target.tmp")
        XCTAssertTrue(FileManager.default.createFile(atPath: targetUrl.path, contents: Data([0])))
        XCTAssertEqual(chflags(targetUrl.path, UInt32(UF_IMMUTABLE)), 0)

        XCTAssertThrowsError(try MetalBinaryArchiveSerialization.serialize(archive, to: targetUrl)) { error in
            // The move's own error: the serialization got as far as the step that crashes.
            XCTAssertEqual((error as NSError).domain, NSCocoaErrorDomain)
        }
    }

    func testFailedMoveIntoSerializationTargetIsKeptUntilItEnds() throws {
        let failedMoveErrors = try XCTUnwrap(FailedMoveErrors.shared)
        let targetUrl = self.directoryUrl.appendingPathComponent("target.tmp")
        let otherUrl = self.directoryUrl.appendingPathComponent("other.tmp")
        let missingUrl = self.directoryUrl.appendingPathComponent("missing")

        weak var targetError: NSError?
        weak var otherError: NSError?
        failedMoveErrors.beginKeeping(forTarget: targetUrl)
        autoreleasepool {
            do {
                let _ = try FileManager.default.replaceItemAt(targetUrl, withItemAt: missingUrl)
            } catch {
                targetError = error as NSError
            }
            do {
                let _ = try FileManager.default.replaceItemAt(otherUrl, withItemAt: missingUrl)
            } catch {
                otherError = error as NSError
            }
        }
        XCTAssertNotNil(targetError, "an error of a move into the target must outlive the pool it was autoreleased into")
        XCTAssertNil(otherError, "other moves must be left alone")

        failedMoveErrors.endKeeping(forTarget: targetUrl)
        XCTAssertNil(targetError, "a kept error must be released when the serialization ends")
    }

    // MARK: - Saves that never finished

    func testSaveLeavesArchiveAndNoMarker() throws {
        let device = try self.makeDevice()
        try self.saveArchive(device: device)

        let reopened = MetalPipelineCache(device: device, directoryUrl: self.directoryUrl)
        XCTAssertFalse(reopened.isFresh)
        XCTAssertTrue(reopened.isSaveEnabled)
    }

    /// The marker of a save is only left behind when the process died inside it.
    func testUnfinishedSaveStopsSavingThatArchive() throws {
        let device = try self.makeDevice()
        try self.saveArchive(device: device)
        let markerUrl = MetalPipelineCache.saveMarkerUrl(archiveUrl: self.archiveUrl(device: device))
        XCTAssertTrue(FileManager.default.createFile(atPath: markerUrl.path, contents: nil))

        let cache = MetalPipelineCache(device: device, directoryUrl: self.directoryUrl)
        XCTAssertFalse(cache.isSaveEnabled)
        XCTAssertFalse(cache.isFresh, "the archive that was saved is still used")
        XCTAssertNotNil(cache.makeComputePipelineState(descriptor: try self.makeNewComputeDescriptor(device: device)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: markerUrl.path), "later launches must not save it either")

        let relaunched = MetalPipelineCache(device: device, directoryUrl: self.directoryUrl)
        XCTAssertFalse(relaunched.isSaveEnabled)
    }

    func testSwitchedOffCacheCompilesDirectlyAndDeletesArchives() throws {
        let device = try self.makeDevice()
        try self.saveArchive(device: device)

        let cache = MetalPipelineCache(device: device, directoryUrl: self.directoryUrl, isSwitchedOff: true)
        XCTAssertFalse(cache.isSaveEnabled)
        XCTAssertFalse(cache.isFresh, "nothing to fill without an archive")
        XCTAssertFalse(FileManager.default.fileExists(atPath: self.directoryUrl.path))
        XCTAssertNotNil(cache.makeComputePipelineState(descriptor: try self.makeNewComputeDescriptor(device: device)))
    }

    func testUnfinishedSaveOfAnotherVersionIsForgotten() throws {
        let device = try self.makeDevice()
        let otherMarkerUrl = MetalPipelineCache.saveMarkerUrl(archiveUrl: self.directoryUrl.appendingPathComponent("pipelines-0.metallib"))
        XCTAssertTrue(FileManager.default.createFile(atPath: otherMarkerUrl.path, contents: nil))

        let cache = MetalPipelineCache(device: device, directoryUrl: self.directoryUrl)
        XCTAssertTrue(cache.isSaveEnabled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: otherMarkerUrl.path))
    }
}
