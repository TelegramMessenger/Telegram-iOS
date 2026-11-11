import Foundation
import XCTest
@testable import TelegramCore

/// `SequenceSpan.classify(local:afterHole:)`, the one skip rule `finalStateWithUpdateGroups` (Sync/SyncSequencing.swift)
/// applies to pts, qts and seq, and the `updatesCombined` span `init(seqStart:seq:)` (UpdateMessageService.swift).
/// The pushed paths are pinned end to end by PushCharacterizationTests, PushOrderingPinTests and
/// SeqContainerEdgeTests; this pins the rule itself.
final class SequenceSpanTests: XCTestCase {
    /// `local >= end`, an exact duplicate included (G2).
    func testLocalAtOrPastTheEndIsAlreadyApplied() {
        XCTAssertEqual(SequenceSpan(end: 10, count: 1).classify(local: 10, afterHole: false), .alreadyApplied)
        XCTAssertEqual(SequenceSpan(end: 10, count: 1).classify(local: 12, afterHole: false), .alreadyApplied)
        XCTAssertEqual(SequenceSpan(end: 10, count: 0).classify(local: 10, afterHole: false), .alreadyApplied)
    }

    /// `local == end - count`.
    func testLocalAtTheStartApplies() {
        XCTAssertEqual(SequenceSpan(end: 10, count: 1).classify(local: 9, afterHole: false), .apply)
        XCTAssertEqual(SequenceSpan(end: 10, count: 2).classify(local: 8, afterHole: false), .apply)
    }

    /// Updates missing below the span, a span overlapping what is applied, and a zero-count span above the local
    /// value are all gaps.
    func testAnythingElseIsAGap() {
        XCTAssertEqual(SequenceSpan(end: 10, count: 1).classify(local: 5, afterHole: false), .gap)
        XCTAssertEqual(SequenceSpan(end: 11, count: 2).classify(local: 10, afterHole: false), .gap)
        XCTAssertEqual(SequenceSpan(end: 10, count: 0).classify(local: 9, afterHole: false), .gap)
    }

    /// `updatesCombined` covers `seq_start...seq`: count `seq - seq_start + 1`, so it applies when
    /// `local + 1 == seq_start`. `seq_start == 0` reads as a gap (SeqContainerEdgeTests), and a combined container
    /// of one seq is the plain `updates` span `(seq, 1)`.
    func testCombinedContainerCoversSeqStartThroughSeq() {
        let span = SequenceSpan(seqStart: 10, seq: 11)
        XCTAssertEqual(span.end, 11)
        XCTAssertEqual(span.count, 2)
        XCTAssertEqual(span.classify(local: 9, afterHole: false), .apply)
        XCTAssertEqual(span.classify(local: 10, afterHole: false), .gap)
        XCTAssertEqual(span.classify(local: 11, afterHole: false), .alreadyApplied)
        XCTAssertEqual(SequenceSpan(seqStart: 0, seq: 11).classify(local: 10, afterHole: false), .gap)
        XCTAssertEqual(SequenceSpan(seqStart: 11, seq: 11).count, 1)
    }

    /// After a hole nothing is applied, and `end - count` is not evaluated: `finalStateWithUpdateGroups` skips that
    /// subtraction once a hole was seen, and a span whose start is not an Int32 traps only as the first unapplied span.
    func testAfterAHoleNothingIsAppliedAndTheStartIsNotComputed() {
        XCTAssertEqual(SequenceSpan(end: 10, count: 1).classify(local: 9, afterHole: true), .gap)
        XCTAssertEqual(SequenceSpan(end: 10, count: 1).classify(local: 10, afterHole: true), .alreadyApplied)
        XCTAssertEqual(SequenceSpan(end: 10, count: 1).classify(local: 12, afterHole: true), .alreadyApplied)
        // `Int32.max - (-1)` overflows: evaluating the start would trap here. Already applied is still decided first,
        // with or without a hole.
        let malformed = SequenceSpan(end: Int32.max, count: -1)
        XCTAssertEqual(malformed.classify(local: 5, afterHole: true), .gap)
        XCTAssertEqual(malformed.classify(local: Int32.max, afterHole: true), .alreadyApplied)
        XCTAssertEqual(malformed.classify(local: Int32.max, afterHole: false), .alreadyApplied)
    }
}
