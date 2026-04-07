import XCTest
import SubcodecObjC

final class MuxSurfaceTests: XCTestCase {
    func testDecodedFrameCreation() throws {
        let y = Data(repeating: 128, count: 16)
        let cb = Data(repeating: 128, count: 4)
        let cr = Data(repeating: 128, count: 4)
        let frame = SCDecodedFrame(width: 4, height: 4, y: y, cb: cb, cr: cr)
        XCTAssertEqual(frame.width, 4)
        XCTAssertEqual(frame.height, 4)
        XCTAssertEqual(frame.y.count, 16)
    }

    func testSpriteExtractor() throws {
        let fixtureURL = try XCTUnwrap(
            Bundle.module.url(forResource: "Fixtures/sprite0", withExtension: "yuv"))
        let yuvData = try Data(contentsOf: fixtureURL)

        let spriteSize = 64
        let frameSize = spriteSize * spriteSize + 2 * (spriteSize / 2) * (spriteSize / 2)
        let numFrames = yuvData.count / frameSize
        XCTAssertEqual(numFrames, 160)

        let outputPath = NSTemporaryDirectory() + "test_extractor_sprite0.mbs"
        let sprite = try SCSprite.extractor(
            withSpriteSize: 64, qp: 26, outputPath: outputPath)

        let ySize = spriteSize * spriteSize
        let cSize = (spriteSize / 2) * (spriteSize / 2)
        let opaqueAlpha = Data(repeating: 255, count: ySize)

        for f in 0..<numFrames {
            let offset = f * frameSize
            let y = Data(yuvData[offset..<(offset + ySize)])
            let cb = Data(yuvData[(offset + ySize)..<(offset + ySize + cSize)])
            let cr = Data(yuvData[(offset + ySize + cSize)..<(offset + frameSize)])
            try sprite.addFrameY(y, yStride: Int32(spriteSize),
                                 cb: cb, cbStride: Int32(spriteSize / 2),
                                 cr: cr, crStride: Int32(spriteSize / 2),
                                 alpha: opaqueAlpha, alphaStride: Int32(spriteSize))
        }

        try sprite.finalizeExtraction()

        let mbsData = try Data(contentsOf: URL(fileURLWithPath: outputPath))
        XCTAssertGreaterThan(mbsData.count, 0, "MBS file should not be empty")
    }

    func testSpriteEncoder() throws {
        let fixtureURL = try XCTUnwrap(
            Bundle.module.url(forResource: "Fixtures/sprite0", withExtension: "yuv"))
        let yuvData = try Data(contentsOf: fixtureURL)

        let spriteSize = 64
        let paddedSize = 96
        let frameSize = spriteSize * spriteSize + 2 * (spriteSize / 2) * (spriteSize / 2)
        let numFrames = yuvData.count / frameSize

        let encoder = try SCSprite.encoder(withWidth: Int32(spriteSize),
                                           height: Int32(spriteSize),
                                           qp: 26)

        let ySize = spriteSize * spriteSize
        let cSize = (spriteSize / 2) * (spriteSize / 2)

        for f in 0..<numFrames {
            let offset = f * frameSize

            // Pad to canvas (Y=0 black, Cb/Cr=128 neutral)
            var canvasY = Data(repeating: 0, count: paddedSize * paddedSize)
            var canvasCb = Data(repeating: 128, count: (paddedSize / 2) * (paddedSize / 2))
            var canvasCr = Data(repeating: 128, count: (paddedSize / 2) * (paddedSize / 2))

            // Copy sprite into center of canvas (offset by 16px = 1 MB padding)
            for row in 0..<spriteSize {
                let srcStart = offset + row * spriteSize
                let dstStart = (row + 16) * paddedSize + 16
                canvasY.replaceSubrange(dstStart..<(dstStart + spriteSize),
                                        with: yuvData[srcStart..<(srcStart + spriteSize)])
            }
            let chromaPadded = paddedSize / 2
            let chromaSprite = spriteSize / 2
            for row in 0..<chromaSprite {
                let srcCbStart = offset + ySize + row * chromaSprite
                let srcCrStart = offset + ySize + cSize + row * chromaSprite
                let dstStart = (row + 8) * chromaPadded + 8
                canvasCb.replaceSubrange(dstStart..<(dstStart + chromaSprite),
                                         with: yuvData[srcCbStart..<(srcCbStart + chromaSprite)])
                canvasCr.replaceSubrange(dstStart..<(dstStart + chromaSprite),
                                         with: yuvData[srcCrStart..<(srcCrStart + chromaSprite)])
            }

            try encoder.encodeFrameY(canvasY, yStride: Int32(paddedSize),
                                     cb: canvasCb, cbStride: Int32(chromaPadded),
                                     cr: canvasCr, crStride: Int32(chromaPadded),
                                     frameIndex: Int32(f))
        }

        let stream = try encoder.buildStream()
        XCTAssertGreaterThan(stream.count, 0, "H.264 stream should not be empty")
    }

    func testMuxSurfaceBasic() throws {
        // Create a sprite .mbs file from fixture
        let fixtureURL = try XCTUnwrap(
            Bundle.module.url(forResource: "Fixtures/sprite0", withExtension: "yuv"))
        let yuvData = try Data(contentsOf: fixtureURL)

        let spriteSize = 64
        let frameSize = spriteSize * spriteSize + 2 * (spriteSize / 2) * (spriteSize / 2)
        let numFrames = 8

        let mbsPath = NSTemporaryDirectory() + "test_mux_basic_sprite0.mbs"
        let extractor = try SCSprite.extractor(
            withSpriteSize: 64, qp: 26, outputPath: mbsPath)

        let ySize = spriteSize * spriteSize
        let cSize = (spriteSize / 2) * (spriteSize / 2)
        let opaqueAlpha = Data(repeating: 255, count: ySize)
        for f in 0..<numFrames {
            let offset = f * frameSize
            let y = Data(yuvData[offset..<(offset + ySize)])
            let cb = Data(yuvData[(offset + ySize)..<(offset + ySize + cSize)])
            let cr = Data(yuvData[(offset + ySize + cSize)..<(offset + frameSize)])
            try extractor.addFrameY(y, yStride: Int32(spriteSize),
                                    cb: cb, cbStride: Int32(spriteSize / 2),
                                    cr: cr, crStride: Int32(spriteSize / 2),
                                    alpha: opaqueAlpha, alphaStride: Int32(spriteSize))
        }
        try extractor.finalizeExtraction()

        // Create mux surface
        var headerBytes = Data()
        let surface = try SCMuxSurface.create(
            withSpriteWidth: 64, spriteHeight: 64,
            maxSlots: 4, qp: 26, sink: { headerBytes.append($0 as Data) })

        XCTAssertGreaterThan(headerBytes.count, 0, "Header should contain SPS+PPS+IDR")

        // Add sprite
        let region = try surface.addSprite(atPath: mbsPath)
        XCTAssertGreaterThanOrEqual(region.slot, 0)

        // Advance one frame
        var frameBytes = Data()
        try surface.advanceFrame { frameBytes.append($0 as Data) }
        XCTAssertGreaterThan(frameBytes.count, 0, "P-frame should have content")
    }

    // MARK: - Constants for staggered test

    private static let kSpriteSize = 64
    private static let kPaddedSize = 96
    private static let kPaddedMbs: Int32 = 6
    private static let kPaddingMbs: Int32 = 1
    private static let kNumFrames = 160
    private static let kQP: Int32 = 26
    private static let kFrameSize = 64 * 64 + 2 * 32 * 32  // 6144

    // MARK: - Helper methods

    private func loadFixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: "yuv"))
        return try Data(contentsOf: url)
    }

    private func extractYUVFrame(from data: Data, frame: Int) -> (y: Data, cb: Data, cr: Data) {
        let spriteSize = Self.kSpriteSize
        let ySize = spriteSize * spriteSize
        let cSize = (spriteSize / 2) * (spriteSize / 2)
        let offset = frame * Self.kFrameSize
        let y = Data(data[offset..<(offset + ySize)])
        let cb = Data(data[(offset + ySize)..<(offset + ySize + cSize)])
        let cr = Data(data[(offset + ySize + cSize)..<(offset + Self.kFrameSize)])
        return (y, cb, cr)
    }

    private func padToCanvas(y: Data, cb: Data, cr: Data) -> (y: Data, cb: Data, cr: Data) {
        let spriteSize = Self.kSpriteSize
        let paddedSize = Self.kPaddedSize
        let chromaPadded = paddedSize / 2
        let chromaSprite = spriteSize / 2

        var canvasY = Data(repeating: 0, count: paddedSize * paddedSize)
        var canvasCb = Data(repeating: 128, count: chromaPadded * chromaPadded)
        var canvasCr = Data(repeating: 128, count: chromaPadded * chromaPadded)

        for row in 0..<spriteSize {
            let srcStart = row * spriteSize
            let dstStart = (row + 16) * paddedSize + 16
            canvasY.replaceSubrange(dstStart..<(dstStart + spriteSize),
                                    with: y[srcStart..<(srcStart + spriteSize)])
        }
        for row in 0..<chromaSprite {
            let srcCbStart = row * chromaSprite
            let srcCrStart = row * chromaSprite
            let dstStart = (row + 8) * chromaPadded + 8
            canvasCb.replaceSubrange(dstStart..<(dstStart + chromaSprite),
                                     with: cb[srcCbStart..<(srcCbStart + chromaSprite)])
            canvasCr.replaceSubrange(dstStart..<(dstStart + chromaSprite),
                                     with: cr[srcCrStart..<(srcCrStart + chromaSprite)])
        }

        return (canvasY, canvasCb, canvasCr)
    }

    private func encodeSpriteMbs(fixture: String, index: Int) throws -> String {
        let yuvData = try loadFixture(fixture)
        let numFrames = Self.kNumFrames
        let spriteSize = Self.kSpriteSize

        let outputPath = NSTemporaryDirectory() + "test_staggered_sprite\(index).mbs"
        let extractor = try SCSprite.extractor(
            withSpriteSize: Int32(spriteSize), qp: Self.kQP,
            outputPath: outputPath)

        let opaqueAlpha = Data(repeating: 255, count: spriteSize * spriteSize)
        for f in 0..<numFrames {
            let (y, cb, cr) = extractYUVFrame(from: yuvData, frame: f)
            try extractor.addFrameY(y, yStride: Int32(spriteSize),
                                    cb: cb, cbStride: Int32(spriteSize / 2),
                                    cr: cr, crStride: Int32(spriteSize / 2),
                                    alpha: opaqueAlpha, alphaStride: Int32(spriteSize))
        }

        try extractor.finalizeExtraction()
        return outputPath
    }

    private func encodeReferenceStream(fixture: String) throws -> Data {
        let yuvData = try loadFixture(fixture)
        let numFrames = Self.kNumFrames
        let paddedSize = Self.kPaddedSize

        let encoder = try SCSprite.encoder(
            withWidth: Int32(Self.kSpriteSize),
            height: Int32(Self.kSpriteSize), qp: Self.kQP)

        for f in 0..<numFrames {
            let (y, cb, cr) = extractYUVFrame(from: yuvData, frame: f)
            let (canvasY, canvasCb, canvasCr) = padToCanvas(y: y, cb: cb, cr: cr)
            try encoder.encodeFrameY(canvasY, yStride: Int32(paddedSize),
                                     cb: canvasCb, cbStride: Int32(paddedSize / 2),
                                     cr: canvasCr, crStride: Int32(paddedSize / 2),
                                     frameIndex: Int32(f))
        }

        return try encoder.buildStream()
    }

    private func slotOffset(slot: Int32, cols: Int) -> (x: Int, y: Int) {
        let slotW = Int(Self.kPaddedMbs) * 2 - Int(Self.kPaddingMbs)  // 11
        let strideX = (slotW - Int(Self.kPaddingMbs)) * 16  // 160
        let strideY = Int(Self.kPaddedMbs - Self.kPaddingMbs) * 16  // 80
        let x = Int(slot) % cols * strideX
        let y = Int(slot) / cols * strideY
        return (x, y)
    }

    private func assertSpriteRegion(composite: SCDecodedFrame, ox: Int, oy: Int,
                                     reference: SCDecodedFrame, message: String,
                                     file: StaticString = #filePath, line: UInt = #line) {
        let paddedSize = Self.kPaddedSize
        let compW = Int(composite.width)
        let compCW = compW / 2
        let refW = Int(reference.width)
        let refCW = refW / 2
        var mismatches = 0

        // Y plane
        for py in 0..<paddedSize {
            for px in 0..<paddedSize {
                let cx = ox + px
                let cy = oy + py
                let compIdx = cy * compW + cx
                let refIdx = py * refW + px
                if composite.y[compIdx] != reference.y[refIdx] {
                    mismatches += 1
                }
            }
        }

        // Cb plane
        for py in 0..<(paddedSize / 2) {
            for px in 0..<(paddedSize / 2) {
                let cx = ox / 2 + px
                let cy = oy / 2 + py
                if composite.cb[cy * compCW + cx] != reference.cb[py * refCW + px] {
                    mismatches += 1
                }
            }
        }

        // Cr plane
        for py in 0..<(paddedSize / 2) {
            for px in 0..<(paddedSize / 2) {
                let cx = ox / 2 + px
                let cy = oy / 2 + py
                if composite.cr[cy * compCW + cx] != reference.cr[py * refCW + px] {
                    mismatches += 1
                }
            }
        }

        XCTAssertEqual(mismatches, 0, "\(message): \(mismatches) pixel mismatches",
                       file: file, line: line)
    }

    private func assertBlackRegion(composite: SCDecodedFrame, ox: Int, oy: Int,
                                    message: String,
                                    file: StaticString = #filePath, line: UInt = #line) {
        let spriteSize = Self.kSpriteSize
        let compW = Int(composite.width)
        var mismatches = 0

        // Check inner sprite content area (skip padding, just check the 64x64 sprite region)
        for py in 16..<(16 + spriteSize) {
            for px in 16..<(16 + spriteSize) {
                let cx = ox + px
                let cy = oy + py
                if composite.y[cy * compW + cx] != 0 {
                    mismatches += 1
                }
            }
        }

        XCTAssertEqual(mismatches, 0, "\(message): \(mismatches) non-black pixels",
                       file: file, line: line)
    }

    // MARK: - Staggered Add/Remove Test

    func testStaggeredAddRemove() throws {
        let numFrames = Self.kNumFrames
        let sprites = ["sprite0", "sprite1", "sprite2"]

        // Phase 1: Encode sprites via both paths
        var mbsPaths: [String] = []
        var refStreams: [Data] = []

        for (i, name) in sprites.enumerated() {
            let path = try encodeSpriteMbs(fixture: name, index: i)
            mbsPaths.append(path)
            let stream = try encodeReferenceStream(fixture: name)
            refStreams.append(stream)
        }

        // Phase 2: Decode reference streams
        let decoder = try SCOpenH264Decoder.createDecoder()
        var refFrames: [[SCDecodedFrame]] = []
        for (i, stream) in refStreams.enumerated() {
            let frames = try decoder.decodeStream(stream)
            XCTAssertEqual(frames.count, numFrames,
                           "Sprite \(i) should decode \(numFrames) reference frames")
            refFrames.append(frames)
        }

        // Phase 3: Build composite via MuxSurface
        var compositeData = Data()
        let sink: (Data) -> Void = { compositeData.append($0) }

        let surface = try SCMuxSurface.create(
            withSpriteWidth: Int32(Self.kSpriteSize), spriteHeight: Int32(Self.kSpriteSize),
            maxSlots: 4, qp: Self.kQP,
            sink: sink)

        // Add sprite 0 before frame 1
        let region0 = try surface.addSprite(atPath: mbsPaths[0])
        let slot0 = region0.slot
        XCTAssertGreaterThanOrEqual(slot0, 0, "Sprite 0 should get a slot")

        // Frames 1-39: sprite 0 alone
        for _ in 1...39 {
            try surface.advanceFrame(sink: sink)
        }

        // Frame 40: add sprite 1
        let region1 = try surface.addSprite(atPath: mbsPaths[1])
        let slot1 = region1.slot
        XCTAssertGreaterThanOrEqual(slot1, 0, "Sprite 1 should get a slot")

        // Frames 40-99: sprite 0 + sprite 1
        for _ in 40...99 {
            try surface.advanceFrame(sink: sink)
        }

        // Frame 100: remove sprite 0
        surface.removeSprite(atSlot: slot0)

        // Frame 100: sprite 1 only, slot 0 is SKIP (frozen)
        try surface.advanceFrame(sink: sink)

        // Frame 101: add sprite 2 (reuses slot)
        let region2 = try surface.addSprite(atPath: mbsPaths[2])
        let slot2 = region2.slot
        XCTAssertGreaterThanOrEqual(slot2, 0, "Sprite 2 should get a slot")

        // Frames 101-159: sprite 2 + sprite 1
        for _ in 101...159 {
            try surface.advanceFrame(sink: sink)
        }

        // Phase 4: Decode composite
        let decoder2 = try SCOpenH264Decoder.createDecoder()
        let compFrames = try decoder2.decodeStream(compositeData)
        XCTAssertEqual(compFrames.count, numFrames,
                       "Composite should decode \(numFrames) frames")

        guard compFrames.count == numFrames else { return }

        // Phase 5: Pixel verification
        let cols = 2
        let (ox0, oy0) = slotOffset(slot: slot0, cols: cols)
        let (ox1, oy1) = slotOffset(slot: slot1, cols: cols)
        let (ox2, oy2) = slotOffset(slot: slot2, cols: cols)

        // Frame 0: all slots black (IDR)
        assertBlackRegion(composite: compFrames[0], ox: ox0, oy: oy0,
                          message: "Frame 0 slot 0 should be black")
        assertBlackRegion(composite: compFrames[0], ox: ox1, oy: oy1,
                          message: "Frame 0 slot 1 should be black")

        // Frames 1-39: slot 0 = sprite 0 frame (f-1), slot 1 = empty/black
        for f in 1...39 {
            assertSpriteRegion(composite: compFrames[f], ox: ox0, oy: oy0,
                               reference: refFrames[0][f - 1],
                               message: "Frame \(f) slot 0 sprite0[\(f - 1)]")
            assertBlackRegion(composite: compFrames[f], ox: ox1, oy: oy1,
                              message: "Frame \(f) slot 1 should be black")
        }

        // Frames 40-99: slot 0 = sprite 0 frame (f-1), slot 1 = sprite 1 frame (f-40)
        for f in 40...99 {
            assertSpriteRegion(composite: compFrames[f], ox: ox0, oy: oy0,
                               reference: refFrames[0][f - 1],
                               message: "Frame \(f) slot 0 sprite0[\(f - 1)]")
            assertSpriteRegion(composite: compFrames[f], ox: ox1, oy: oy1,
                               reference: refFrames[1][f - 40],
                               message: "Frame \(f) slot 1 sprite1[\(f - 40)]")
        }

        // Frame 100: slot 0 = sprite 0 frame 98 (frozen), slot 1 = sprite 1 frame 60
        assertSpriteRegion(composite: compFrames[100], ox: ox0, oy: oy0,
                           reference: refFrames[0][98],
                           message: "Frame 100 slot 0 sprite0[98] (frozen)")
        assertSpriteRegion(composite: compFrames[100], ox: ox1, oy: oy1,
                           reference: refFrames[1][60],
                           message: "Frame 100 slot 1 sprite1[60]")

        // Frames 101-159: slot 0 = sprite 2 frame (f-101), slot 1 = sprite 1 frame (f-40)
        for f in 101...159 {
            assertSpriteRegion(composite: compFrames[f], ox: ox2, oy: oy2,
                               reference: refFrames[2][f - 101],
                               message: "Frame \(f) slot 0 sprite2[\(f - 101)]")
            assertSpriteRegion(composite: compFrames[f], ox: ox1, oy: oy1,
                               reference: refFrames[1][f - 40],
                               message: "Frame \(f) slot 1 sprite1[\(f - 40)]")
        }
    }

    func testSpriteLooping() throws {
        let numFrames = Self.kNumFrames  // 160 frames per sprite

        // Phase 1: Encode sprite 0
        let mbsPath = try encodeSpriteMbs(fixture: "sprite0", index: 0)
        let refStream = try encodeReferenceStream(fixture: "sprite0")

        // Phase 2: Decode reference
        let decoder = try SCOpenH264Decoder.createDecoder()
        let refFrames = try decoder.decodeStream(refStream)
        XCTAssertEqual(refFrames.count, numFrames)
        guard refFrames.count == numFrames else { return }

        // Phase 3: Build composite — 1 sprite, 2× num_frames (320 P-frames)
        let loopFrames = numFrames * 2
        var compositeData = Data()
        let sink: (Data) -> Void = { compositeData.append($0) }

        let surface = try SCMuxSurface.create(
            withSpriteWidth: Int32(Self.kSpriteSize), spriteHeight: Int32(Self.kSpriteSize),
            maxSlots: 1, qp: Self.kQP,
            sink: sink)

        let region = try surface.addSprite(atPath: mbsPath)
        let slot = region.slot
        XCTAssertGreaterThanOrEqual(slot, 0)

        for _ in 1...loopFrames {
            try surface.advanceFrame(sink: sink)
        }

        // Phase 4: Decode composite
        let decoder2 = try SCOpenH264Decoder.createDecoder()
        let compFrames = try decoder2.decodeStream(compositeData)
        let expectedFrames = 1 + loopFrames  // IDR + 320 P-frames
        XCTAssertEqual(compFrames.count, expectedFrames,
                       "Should decode \(expectedFrames) frames")
        guard compFrames.count == expectedFrames else { return }

        // Phase 5: Verify cycle 2 is pixel-identical to cycle 1
        let (ox, oy) = slotOffset(slot: slot, cols: 1)

        for f in 0..<numFrames {
            let c1 = 1 + f              // cycle 1: composite frames 1..160
            let c2 = 1 + numFrames + f  // cycle 2: composite frames 161..320

            // Compare sprite region in cycle 1 against reference
            assertSpriteRegion(composite: compFrames[c1], ox: ox, oy: oy,
                               reference: refFrames[f],
                               message: "Cycle 1 frame \(f)")

            // Compare sprite region in cycle 2 against same reference (looped)
            assertSpriteRegion(composite: compFrames[c2], ox: ox, oy: oy,
                               reference: refFrames[f],
                               message: "Cycle 2 frame \(f) (looped)")
        }
    }

    func testVideoToolboxDecoder() throws {
        let fixtureURL = try XCTUnwrap(
            Bundle.module.url(forResource: "Fixtures/sprite0", withExtension: "yuv"))
        let yuvData = try Data(contentsOf: fixtureURL)

        let spriteSize = 64
        let paddedSize = 96
        let frameSize = spriteSize * spriteSize + 2 * (spriteSize / 2) * (spriteSize / 2)
        let numFrames = 8

        let encoder = try SCSprite.encoder(withWidth: Int32(spriteSize),
                                           height: Int32(spriteSize), qp: 26)

        let ySize = spriteSize * spriteSize
        let cSize = (spriteSize / 2) * (spriteSize / 2)

        for f in 0..<numFrames {
            let offset = f * frameSize
            var canvasY = Data(repeating: 0, count: paddedSize * paddedSize)
            var canvasCb = Data(repeating: 128, count: (paddedSize / 2) * (paddedSize / 2))
            var canvasCr = Data(repeating: 128, count: (paddedSize / 2) * (paddedSize / 2))

            for row in 0..<spriteSize {
                let srcStart = offset + row * spriteSize
                let dstStart = (row + 16) * paddedSize + 16
                canvasY.replaceSubrange(dstStart..<(dstStart + spriteSize),
                                        with: yuvData[srcStart..<(srcStart + spriteSize)])
            }
            let chromaPadded = paddedSize / 2
            let chromaSprite = spriteSize / 2
            for row in 0..<chromaSprite {
                let srcCbStart = offset + ySize + row * chromaSprite
                let srcCrStart = offset + ySize + cSize + row * chromaSprite
                let dstStart = (row + 8) * chromaPadded + 8
                canvasCb.replaceSubrange(dstStart..<(dstStart + chromaSprite),
                                         with: yuvData[srcCbStart..<(srcCbStart + chromaSprite)])
                canvasCr.replaceSubrange(dstStart..<(dstStart + chromaSprite),
                                         with: yuvData[srcCrStart..<(srcCrStart + chromaSprite)])
            }

            try encoder.encodeFrameY(canvasY, yStride: Int32(paddedSize),
                                     cb: canvasCb, cbStride: Int32(chromaPadded),
                                     cr: canvasCr, crStride: Int32(chromaPadded),
                                     frameIndex: Int32(f))
        }

        let stream = try encoder.buildStream()

        let decoder = try SCVideoToolboxDecoder.createDecoder()
        let frames = try decoder.decodeStream(stream)
        XCTAssertEqual(frames.count, numFrames, "Should decode \(numFrames) frames")
        XCTAssertEqual(Int(frames[0].width), paddedSize * 2)  // double-wide canvas
        XCTAssertEqual(Int(frames[0].height), paddedSize)
    }

    func testDecoderCrossComparison() throws {
        let fixtureURL = try XCTUnwrap(
            Bundle.module.url(forResource: "Fixtures/sprite0", withExtension: "yuv"))
        let yuvData = try Data(contentsOf: fixtureURL)

        let spriteSize = 64
        let paddedSize = 96
        let frameSize = spriteSize * spriteSize + 2 * (spriteSize / 2) * (spriteSize / 2)
        let numFrames = 8

        // Encode
        let encoder = try SCSprite.encoder(withWidth: Int32(spriteSize),
                                           height: Int32(spriteSize), qp: 26)

        let ySize = spriteSize * spriteSize
        let cSize = (spriteSize / 2) * (spriteSize / 2)

        for f in 0..<numFrames {
            let offset = f * frameSize
            var canvasY = Data(repeating: 0, count: paddedSize * paddedSize)
            var canvasCb = Data(repeating: 128, count: (paddedSize / 2) * (paddedSize / 2))
            var canvasCr = Data(repeating: 128, count: (paddedSize / 2) * (paddedSize / 2))

            for row in 0..<spriteSize {
                let srcStart = offset + row * spriteSize
                let dstStart = (row + 16) * paddedSize + 16
                canvasY.replaceSubrange(dstStart..<(dstStart + spriteSize),
                                        with: yuvData[srcStart..<(srcStart + spriteSize)])
            }
            let chromaPadded = paddedSize / 2
            let chromaSprite = spriteSize / 2
            for row in 0..<chromaSprite {
                let srcCbStart = offset + ySize + row * chromaSprite
                let srcCrStart = offset + ySize + cSize + row * chromaSprite
                let dstStart = (row + 8) * chromaPadded + 8
                canvasCb.replaceSubrange(dstStart..<(dstStart + chromaSprite),
                                         with: yuvData[srcCbStart..<(srcCbStart + chromaSprite)])
                canvasCr.replaceSubrange(dstStart..<(dstStart + chromaSprite),
                                         with: yuvData[srcCrStart..<(srcCrStart + chromaSprite)])
            }

            try encoder.encodeFrameY(canvasY, yStride: Int32(paddedSize),
                                     cb: canvasCb, cbStride: Int32(chromaPadded),
                                     cr: canvasCr, crStride: Int32(chromaPadded),
                                     frameIndex: Int32(f))
        }

        let stream = try encoder.buildStream()

        // Decode with both decoders
        let oh264 = try SCOpenH264Decoder.createDecoder()
        let vt = try SCVideoToolboxDecoder.createDecoder()

        let oh264Frames = try oh264.decodeStream(stream)
        let vtFrames = try vt.decodeStream(stream)

        XCTAssertEqual(oh264Frames.count, vtFrames.count,
                       "Both decoders should produce same frame count")
        guard oh264Frames.count == vtFrames.count else { return }

        // Compare each frame with +/-1 tolerance
        for f in 0..<oh264Frames.count {
            let ref = oh264Frames[f]
            let test = vtFrames[f]

            XCTAssertEqual(ref.width, test.width, "Frame \(f) width mismatch")
            XCTAssertEqual(ref.height, test.height, "Frame \(f) height mismatch")

            let w = Int(ref.width)
            let h = Int(ref.height)

            // Y plane
            var yMismatches = 0
            for i in 0..<(w * h) {
                let diff = Int(ref.y[i]) - Int(test.y[i])
                if abs(diff) > 1 { yMismatches += 1 }
            }
            XCTAssertEqual(yMismatches, 0,
                           "Frame \(f) Y plane: \(yMismatches) pixels differ by more than +/-1")

            // Cb plane
            let cw = w / 2
            let ch = h / 2
            var cbMismatches = 0
            for i in 0..<(cw * ch) {
                let diff = Int(ref.cb[i]) - Int(test.cb[i])
                if abs(diff) > 1 { cbMismatches += 1 }
            }
            XCTAssertEqual(cbMismatches, 0,
                           "Frame \(f) Cb plane: \(cbMismatches) pixels differ by more than +/-1")

            // Cr plane
            var crMismatches = 0
            for i in 0..<(cw * ch) {
                let diff = Int(ref.cr[i]) - Int(test.cr[i])
                if abs(diff) > 1 { crMismatches += 1 }
            }
            XCTAssertEqual(crMismatches, 0,
                           "Frame \(f) Cr plane: \(crMismatches) pixels differ by more than +/-1")
        }
    }

    func testVideoToolboxPartialFill() throws {
        // Regression test: partially-filled grids with long skip_runs must decode via VT.
        // Without write_skip_safe, VT rejects valid H.264 at these configurations.
        let fixtureURL = try XCTUnwrap(
            Bundle.module.url(forResource: "Fixtures/sprite0", withExtension: "yuv"))
        let yuvData = try Data(contentsOf: fixtureURL)

        let spriteSize = 64
        let ySize = spriteSize * spriteSize
        let cSize = (spriteSize / 2) * (spriteSize / 2)
        let frameSize = ySize + 2 * cSize
        let numSpriteFrames = 160

        let mbsPath = NSTemporaryDirectory() + "test_vt_partial.mbs"
        let extractor = try SCSprite.extractor(
            withSpriteSize: Int32(spriteSize), qp: 26, outputPath: mbsPath)
        let opaqueAlpha = Data(repeating: 255, count: ySize)
        for f in 0..<numSpriteFrames {
            let offset = f * frameSize
            let y = Data(yuvData[offset..<(offset + ySize)])
            let cb = Data(yuvData[(offset + ySize)..<(offset + ySize + cSize)])
            let cr = Data(yuvData[(offset + ySize + cSize)..<(offset + frameSize)])
            try extractor.addFrameY(y, yStride: Int32(spriteSize),
                                     cb: cb, cbStride: Int32(spriteSize / 2),
                                     cr: cr, crStride: Int32(spriteSize / 2),
                                     alpha: opaqueAlpha, alphaStride: Int32(spriteSize))
        }
        try extractor.finalizeExtraction()

        // Test partial fills: 10 sprites in a 361-slot grid (191x96, mostly empty)
        let numSprites = 10
        let maxSlots: Int32 = 361
        let numFrames = 5

        var stream = Data()
        let sink: (Data) -> Void = { data in stream.append(data) }

        let surface = try SCMuxSurface.create(
            withSpriteWidth: Int32(spriteSize), spriteHeight: Int32(spriteSize),
            maxSlots: maxSlots, qp: 26, sink: sink)

        for _ in 0..<numSprites {
            let _ = try surface.addSprite(atPath: mbsPath)
        }

        for _ in 0..<numFrames {
            try surface.advanceFrame(sink: sink)
        }

        let decoder = try SCVideoToolboxDecoder.createDecoder()
        let frames = try decoder.decodeStream(stream)
        XCTAssertEqual(frames.count, numFrames + 1,
                       "Partial fill (\(numSprites)/\(maxSlots)) should decode all \(numFrames + 1) frames")
    }

    func testVideoToolboxIPCM() throws {
        // Create a small MuxSurface, add a sprite, advance, resize, decode with VT
        let fixtureURL = try XCTUnwrap(
            Bundle.module.url(forResource: "Fixtures/sprite0", withExtension: "yuv"))
        let yuvData = try Data(contentsOf: fixtureURL)

        let spriteSize = 64
        let ySize = spriteSize * spriteSize
        let cSize = (spriteSize / 2) * (spriteSize / 2)
        let frameSize = ySize + 2 * cSize
        let numFrames = 8

        // Create .mbs file
        let mbsPath = NSTemporaryDirectory() + "test_vt_ipcm.mbs"
        let extractor = try SCSprite.extractor(
            withSpriteSize: Int32(spriteSize), qp: 26, outputPath: mbsPath)
        let opaqueAlpha = Data(repeating: 255, count: ySize)
        for f in 0..<numFrames {
            let offset = f * frameSize
            let y = Data(yuvData[offset..<(offset + ySize)])
            let cb = Data(yuvData[(offset + ySize)..<(offset + ySize + cSize)])
            let cr = Data(yuvData[(offset + ySize + cSize)..<(offset + frameSize)])
            try extractor.addFrameY(y, yStride: Int32(spriteSize),
                                     cb: cb, cbStride: Int32(spriteSize / 2),
                                     cr: cr, crStride: Int32(spriteSize / 2),
                                     alpha: opaqueAlpha, alphaStride: Int32(spriteSize))
        }
        try extractor.finalizeExtraction()

        // Phase 1: Create surface with 2 slots, add 1 sprite, advance 3 frames
        var stream1 = Data()
        let sink1: (Data) -> Void = { data in stream1.append(data) }

        let surface = try SCMuxSurface.create(
            withSpriteWidth: Int32(spriteSize), spriteHeight: Int32(spriteSize),
            maxSlots: 2, qp: 26, sink: sink1)

        let _ = try surface.addSprite(atPath: mbsPath)
        for _ in 0..<3 {
            try surface.advanceFrame(sink: sink1)
        }

        // Decode phase 1 to get last frame pixels
        let decoder1 = try SCVideoToolboxDecoder.createDecoder()
        let frames1 = try decoder1.decodeStream(stream1)
        XCTAssertGreaterThanOrEqual(frames1.count, 4, "Should decode IDR + 3 P-frames")
        let lastFrame = frames1.last!

        // Phase 2: Resize to 4 slots (emits new SPS/PPS + I_PCM IDR)
        var stream2 = Data()
        let sink2: (Data) -> Void = { data in stream2.append(data) }

        let resizeResult = try surface.resize(
            toMaxSlots: 4,
            yPlane: lastFrame.y,
            cbPlane: lastFrame.cb,
            crPlane: lastFrame.cr,
            decodedWidth: lastFrame.width,
            decodedHeight: lastFrame.height,
            strideY: lastFrame.width,
            strideCb: lastFrame.width / 2,
            strideCr: lastFrame.width / 2,
            withSink: sink2)

        XCTAssertEqual(resizeResult.regions.count, 1)

        // Advance 2 more P-frames after resize
        for _ in 0..<2 {
            try surface.advanceFrame(sink: sink2)
        }

        // Try to decode the post-resize stream with VideoToolbox
        let decoder2 = try SCVideoToolboxDecoder.createDecoder()
        let frames2 = try decoder2.decodeStream(stream2)

        // If VT supports I_PCM, we should get IDR + 2 P-frames = 3 frames
        print("[testVideoToolboxIPCM] Post-resize decoded \(frames2.count) frames")
        XCTAssertEqual(frames2.count, 3,
                       "VideoToolbox should decode I_PCM IDR + 2 P-frames = 3 frames, got \(frames2.count)")
    }

    func testResizePerformance() throws {
        // Performance test: resize 420 -> 882 slots, measuring wall-clock time.
        // Uses real decoded pixels (via OpenH264) to exercise the non-black I_PCM path.
        let spriteSize = 64
        let ySize = spriteSize * spriteSize
        let cSize = (spriteSize / 2) * (spriteSize / 2)
        let frameSize = ySize + 2 * cSize

        // Encode one .mbs sprite from fixture
        let fixtureURL = try XCTUnwrap(
            Bundle.module.url(forResource: "Fixtures/sprite0", withExtension: "yuv"))
        let yuvData = try Data(contentsOf: fixtureURL)
        let numSpriteFrames = yuvData.count / frameSize

        let mbsPath = NSTemporaryDirectory() + "test_resize_perf.mbs"
        let extractor = try SCSprite.extractor(
            withSpriteSize: Int32(spriteSize), qp: Self.kQP, outputPath: mbsPath)
        let opaqueAlpha = Data(repeating: 255, count: ySize)
        for f in 0..<numSpriteFrames {
            let offset = f * frameSize
            let y = Data(yuvData[offset..<(offset + ySize)])
            let cb = Data(yuvData[(offset + ySize)..<(offset + ySize + cSize)])
            let cr = Data(yuvData[(offset + ySize + cSize)..<(offset + frameSize)])
            try extractor.addFrameY(y, yStride: Int32(spriteSize),
                                     cb: cb, cbStride: Int32(spriteSize / 2),
                                     cr: cr, crStride: Int32(spriteSize / 2),
                                     alpha: opaqueAlpha, alphaStride: Int32(spriteSize))
        }
        try extractor.finalizeExtraction()

        // Create surface with 420 slots
        let initialSlots: Int32 = 420
        let targetSlots: Int32 = 882

        var stream = Data()
        let sink: (Data) -> Void = { data in stream.append(data) }

        let surface = try SCMuxSurface.create(
            withSpriteWidth: Int32(spriteSize), spriteHeight: Int32(spriteSize),
            maxSlots: initialSlots, qp: Self.kQP, sink: sink)

        // Add 420 sprites
        for _ in 0..<initialSlots {
            let _ = try surface.addSprite(atPath: mbsPath)
        }

        // Advance one frame to get real pixel content
        try surface.advanceFrame(sink: sink)

        // Decode the stream to get real pixel data for resize input
        let decoder = try SCOpenH264Decoder.createDecoder()
        let frames = try decoder.decodeStream(stream)
        let lastFrame = try XCTUnwrap(frames.last)

        let w = Int(lastFrame.width)
        let h = Int(lastFrame.height)

        // Timed resize: 420 -> 882 slots
        // Use counting sink to avoid Data.append copy overhead in timing
        var resizeBytes = 0
        let resizeSink: (Data) -> Void = { data in resizeBytes += data.count }

        let start = CFAbsoluteTimeGetCurrent()

        let result = try surface.resize(
            toMaxSlots: targetSlots,
            yPlane: lastFrame.y,
            cbPlane: lastFrame.cb,
            crPlane: lastFrame.cr,
            decodedWidth: Int32(w),
            decodedHeight: Int32(h),
            strideY: Int32(w),
            strideCb: Int32(w / 2),
            strideCr: Int32(w / 2),
            withSink: resizeSink)

        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0

        print("[testResizePerformance] Resized \(initialSlots) -> \(targetSlots) slots in \(elapsed) ms (\(result.regions.count) regions, \(resizeBytes) bytes)")
        XCTAssertEqual(result.regions.count, Int(initialSlots))

        // Verify post-resize P-frame works
        try surface.advanceFrame(sink: resizeSink)

        // Performance gate: resize should complete in under 200ms even in debug
        XCTAssertLessThan(elapsed, 200.0,
                          "Resize \(initialSlots)->\(targetSlots) took \(elapsed) ms, expected < 200 ms")
    }

    func testEncoderDecodeRoundTrip() throws {
        let fixtureURL = try XCTUnwrap(
            Bundle.module.url(forResource: "Fixtures/sprite0", withExtension: "yuv"))
        let yuvData = try Data(contentsOf: fixtureURL)

        let spriteSize = 64
        let paddedSize = 96
        let frameSize = spriteSize * spriteSize + 2 * (spriteSize / 2) * (spriteSize / 2)
        let numFrames = 8  // Use just 8 frames for this unit test

        // Encode
        let encoder = try SCSprite.encoder(withWidth: Int32(spriteSize),
                                           height: Int32(spriteSize), qp: 26)

        let ySize = spriteSize * spriteSize
        let cSize = (spriteSize / 2) * (spriteSize / 2)

        for f in 0..<numFrames {
            let offset = f * frameSize
            var canvasY = Data(repeating: 0, count: paddedSize * paddedSize)
            var canvasCb = Data(repeating: 128, count: (paddedSize / 2) * (paddedSize / 2))
            var canvasCr = Data(repeating: 128, count: (paddedSize / 2) * (paddedSize / 2))

            for row in 0..<spriteSize {
                let srcStart = offset + row * spriteSize
                let dstStart = (row + 16) * paddedSize + 16
                canvasY.replaceSubrange(dstStart..<(dstStart + spriteSize),
                                        with: yuvData[srcStart..<(srcStart + spriteSize)])
            }
            let chromaPadded = paddedSize / 2
            let chromaSprite = spriteSize / 2
            for row in 0..<chromaSprite {
                let srcCbStart = offset + ySize + row * chromaSprite
                let srcCrStart = offset + ySize + cSize + row * chromaSprite
                let dstStart = (row + 8) * chromaPadded + 8
                canvasCb.replaceSubrange(dstStart..<(dstStart + chromaSprite),
                                         with: yuvData[srcCbStart..<(srcCbStart + chromaSprite)])
                canvasCr.replaceSubrange(dstStart..<(dstStart + chromaSprite),
                                         with: yuvData[srcCrStart..<(srcCrStart + chromaSprite)])
            }

            try encoder.encodeFrameY(canvasY, yStride: Int32(paddedSize),
                                     cb: canvasCb, cbStride: Int32(chromaPadded),
                                     cr: canvasCr, crStride: Int32(chromaPadded),
                                     frameIndex: Int32(f))
        }

        let stream = try encoder.buildStream()

        // Decode
        let decoder = try SCOpenH264Decoder.createDecoder()
        let frames = try decoder.decodeStream(stream)
        XCTAssertEqual(frames.count, numFrames, "Should decode \(numFrames) frames")
        XCTAssertEqual(Int(frames[0].width), paddedSize * 2)  // double-wide canvas
        XCTAssertEqual(Int(frames[0].height), paddedSize)
    }

    func testAdvanceSpriteIndependent() throws {
        // Verify per-sprite advancement: advance sprite 0 independently of sprite 1.
        // After 4 frames, sprite 0 should be at frame 4, sprite 1 still at frame 1.

        let sprites = ["sprite0", "sprite1"]

        // Phase 1: Encode sprites via both paths
        var mbsPaths: [String] = []
        var refStreams: [Data] = []

        for (i, name) in sprites.enumerated() {
            let path = try encodeSpriteMbs(fixture: name, index: 100 + i)
            mbsPaths.append(path)
            let stream = try encodeReferenceStream(fixture: name)
            refStreams.append(stream)
        }

        // Phase 2: Decode reference streams
        let refDecoder = try SCOpenH264Decoder.createDecoder()
        var refFrames: [[SCDecodedFrame]] = []
        for (i, stream) in refStreams.enumerated() {
            let frames = try refDecoder.decodeStream(stream)
            XCTAssertGreaterThanOrEqual(frames.count, 5,
                                        "Sprite \(i) needs at least 5 reference frames")
            refFrames.append(frames)
        }

        // Phase 3: Build composite via MuxSurface with per-sprite advancement
        var compositeData = Data()
        let sink: (Data) -> Void = { compositeData.append($0) }

        let surface = try SCMuxSurface.create(
            withSpriteWidth: Int32(Self.kSpriteSize), spriteHeight: Int32(Self.kSpriteSize),
            maxSlots: 4, qp: Self.kQP,
            sink: sink)

        let region0 = try surface.addSprite(atPath: mbsPaths[0])
        let slot0 = region0.slot
        let region1 = try surface.addSprite(atPath: mbsPaths[1])
        let slot1 = region1.slot

        // Frame 1: use advanceFrame to emit both sprites' intro (current_frame=0)
        // advanceFrame emits at current state, then advances all sprites to frame 1
        try surface.advanceFrame(sink: sink)

        // Frames 2-4: advance ONLY sprite 0, emit
        // Each advanceSprite increments sprite 0: frame 1->2, 2->3, 3->4
        // Sprite 1 stays at frame 1 (not advanced)
        for _ in 2...4 {
            surface.advanceSprite(atSlot: slot0)
            try surface.emitFrameIfNeeded(sink: sink)
        }

        // Phase 4: Decode composite
        let compDecoder = try SCOpenH264Decoder.createDecoder()
        let compFrames = try compDecoder.decodeStream(compositeData)

        // Expected: IDR (frame 0) + 4 P-frames = 5 total
        XCTAssertEqual(compFrames.count, 5,
                       "Should decode 5 frames (IDR + 4 P-frames), got \(compFrames.count)")
        guard compFrames.count == 5 else { return }

        // Phase 5: Pixel verification
        // advanceFrame: emits current_frame=0 for both, then advances both to 1
        // Per-sprite advancement: advanceSprite(slot0) marks slot0 for emit,
        //   emitFrameIfNeeded emits slot0 at current_frame=1 then advances to 2,
        //   sprite1 is SKIP (frozen).
        // Composite frame mapping:
        //   compFrames[1]: both at ref[0] (intro frame, current_frame=0)
        //   compFrames[2]: sprite0 at ref[1] (current_frame=1), sprite1 frozen at ref[0]
        //   compFrames[3]: sprite0 at ref[2] (current_frame=2), sprite1 frozen at ref[0]
        //   compFrames[4]: sprite0 at ref[3] (current_frame=3), sprite1 frozen at ref[0]
        let cols = 2  // 4 slots -> 2x2 grid
        let (ox0, oy0) = slotOffset(slot: slot0, cols: cols)
        let (ox1, oy1) = slotOffset(slot: slot1, cols: cols)

        // Frame 1 (compFrames[1]): both sprites at ref[0] (intro)
        assertSpriteRegion(composite: compFrames[1], ox: ox0, oy: oy0,
                           reference: refFrames[0][0],
                           message: "Frame 1 sprite0 should be at ref frame 0")
        assertSpriteRegion(composite: compFrames[1], ox: ox1, oy: oy1,
                           reference: refFrames[1][0],
                           message: "Frame 1 sprite1 should be at ref frame 0")

        // Frame 4 (compFrames[4]): sprite 0 at ref[3] (3 per-sprite advances),
        //   sprite 1 frozen (SKIP) -> still shows ref[0] from frame 1
        assertSpriteRegion(composite: compFrames[4], ox: ox0, oy: oy0,
                           reference: refFrames[0][3],
                           message: "Frame 4 sprite0 should be at ref frame 3")
        assertSpriteRegion(composite: compFrames[4], ox: ox1, oy: oy1,
                           reference: refFrames[1][0],
                           message: "Frame 4 sprite1 should still be at ref frame 0 (frozen)")

        // Frame 2 (compFrames[2]): sprite0 at ref[1], sprite1 frozen at ref[0]
        assertSpriteRegion(composite: compFrames[2], ox: ox0, oy: oy0,
                           reference: refFrames[0][1],
                           message: "Frame 2 sprite0 should be at ref frame 1")
        assertSpriteRegion(composite: compFrames[2], ox: ox1, oy: oy1,
                           reference: refFrames[1][0],
                           message: "Frame 2 sprite1 should still be at ref frame 0 (frozen)")
    }
}
