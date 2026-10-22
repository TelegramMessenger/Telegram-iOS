import XCTest
@testable import HLSPlayback

final class HLSMediaPlaylistTests: XCTestCase {
    private func assertParseError(_ text: String, _ expected: HLSPlaylistError, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try HLSMediaPlaylist.parse(text), file: file, line: line) { error in
            XCTAssertEqual(error as? HLSPlaylistError, expected, file: file, line: line)
        }
    }
    
    func testParsesRealShapeWithoutEXTINFCommas() throws {
        let p = try HLSMediaPlaylist.parse(Fixtures.realShape)
        XCTAssertEqual(p.targetDuration, 5)
        XCTAssertEqual(p.mediaSequence, 1)
        XCTAssertEqual(p.initSegment, 0 ..< 1420)
        XCTAssertEqual(p.segments.count, 6)
        XCTAssertEqual(p.segments[0].byteRange, 1552 ..< 437905)
        XCTAssertEqual(p.segments[5].byteRange, 2088414 ..< 2163625)
        XCTAssertEqual(p.segments[5].start, 25.0, accuracy: 1e-9)
        XCTAssertEqual(p.segments[5].duration, 1.75, accuracy: 1e-9)
        XCTAssertEqual(p.totalDuration, 26.75, accuracy: 1e-9)
        XCTAssertEqual(p.averageSegmentDuration, 26.75 / 6.0, accuracy: 1e-9)
        XCTAssertEqual(p.resourceURI, "mtproto:1234567890123456789")
        XCTAssertEqual(p.segments.map(\.index), [0, 1, 2, 3, 4, 5])
    }
    
    func testFractionalDurationsAccumulateAsDouble() throws {
        let p = try HLSMediaPlaylist.parse(Fixtures.fractional)
        XCTAssertEqual(p.segments[1].start, 5.005, accuracy: 1e-12)
        XCTAssertEqual(p.segments[2].start, 5.005 + 4.83333, accuracy: 1e-12)
        XCTAssertEqual(p.totalDuration, 5.005 + 4.83333 + 0.333333, accuracy: 1e-12)
        XCTAssertEqual(p.segments[2].end, p.totalDuration, accuracy: 1e-12)
    }
    
    func testTitlesAreAccepted() throws {
        let p = try HLSMediaPlaylist.parse(Fixtures.withTitles)
        XCTAssertEqual(p.segments.count, 2)
        XCTAssertEqual(p.segments[0].duration, 5.0, accuracy: 1e-12)
        XCTAssertEqual(p.segments[1].duration, 4.5, accuracy: 1e-12)
    }
    
    func testImplicitOffsetContinuesFromPreviousSegment() throws {
        let p = try HLSMediaPlaylist.parse(Fixtures.implicitOffsets)
        XCTAssertEqual(p.initSegment, 0 ..< 1000)
        XCTAssertEqual(p.segments[1].byteRange.lowerBound, p.segments[0].byteRange.upperBound)
        XCTAssertEqual(p.segments[1].byteRange, 201100 ..< 381100)
        XCTAssertEqual(p.segments[2].byteRange, 381100 ..< 531100)
    }
    
    // A playlist stored in a message is a whole file: without ENDLIST it is still complete, not live.
    func testAcceptsMissingEndList() throws {
        let p = try HLSMediaPlaylist.parse(Fixtures.noEndList)
        XCTAssertFalse(p.segments.isEmpty)
    }
    
    // The old playlist readers never needed these tags; the parser does not either. Without TARGETDURATION it is the
    // longest segment rounded up.
    func testDerivesTargetDurationWhenMissing() throws {
        let text = Fixtures.realShape.replacingOccurrences(of: "#EXT-X-TARGETDURATION:5\n", with: "")
        let p = try HLSMediaPlaylist.parse(text)
        XCTAssertEqual(p.targetDuration, 5)
        XCTAssertEqual(p.segments.count, 6)
    }
    
    // Without the init's byte range, or without EXT-X-MAP, the init is everything before the first segment, as the old
    // readers took it.
    func testInitWithoutByteRangeIsEverythingBeforeTheFirstSegment() throws {
        let noRange = Fixtures.realShape.replacingOccurrences(of: ",BYTERANGE=\"1420@0\"", with: "")
        XCTAssertEqual(try HLSMediaPlaylist.parse(noRange).initSegment, 0 ..< 1552)
        let noMap = Fixtures.realShape.replacingOccurrences(of: "#EXT-X-MAP:URI=\"mtproto:1234567890123456789\",BYTERANGE=\"1420@0\"\n", with: "")
        XCTAssertEqual(try HLSMediaPlaylist.parse(noMap).initSegment, 0 ..< 1552)
    }
    
    func testRejectsDuplicateTargetDuration() {
        self.assertParseError(Fixtures.duplicateTarget, .duplicateTag("EXT-X-TARGETDURATION"))
    }
    
    func testRejectsTwoResources() {
        self.assertParseError(Fixtures.twoResources, .multipleResources)
    }
    
    // hls.js skips a UTF-8 BOM and blank lines before #EXTM3U.
    func testAcceptsLeadingBOMAndBlankLines() throws {
        let p = try HLSMediaPlaylist.parse(Fixtures.bom)
        XCTAssertEqual(p.segments.count, 6)
    }
    
    func testRejectsMissingHeader() {
        self.assertParseError(Fixtures.missingHeader, .notM3U8)
        self.assertParseError("#EXTM3U trailing\n" + Fixtures.missingHeader, .notM3U8)
    }
    
    func testSegmentIndexAtBoundaryIsTheSegmentStartingThere() throws {
        let p = try HLSMediaPlaylist.parse(Fixtures.realShape)
        XCTAssertEqual(p.segmentIndex(containing: 5.0), 1)
        XCTAssertEqual(p.segmentIndex(containing: 4.999), 0)
        XCTAssertEqual(p.segmentIndex(containing: 26.749), 5)
        XCTAssertNil(p.segmentIndex(containing: 26.75))
        XCTAssertEqual(p.segmentIndex(containing: -1.0), 0)
    }
    
    func testPrefixRangeCoversTenSeconds() throws {
        let p = try HLSMediaPlaylist.parse(Fixtures.realShape)
        XCTAssertEqual(p.prefixRange(seconds: 10.0), 0 ..< 874711)
    }
    
    func testPrefixRangeWithFractionalDurations() throws {
        let p = try HLSMediaPlaylist.parse(Fixtures.fractional)
        XCTAssertEqual(p.prefixRange(seconds: 10.0), 0 ..< 396100)
    }
    
    func testFirstFrameRange() throws {
        let p = try HLSMediaPlaylist.parse(Fixtures.realShape)
        XCTAssertEqual(p.firstFrameRange(), 0 ..< 437905)
    }
}
