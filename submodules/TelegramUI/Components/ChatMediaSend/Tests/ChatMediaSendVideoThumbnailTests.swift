import Foundation
import UIKit
import AVFoundation
import XCTest
import SwiftSignalKit
@testable import ChatMediaSend

final class ChatMediaSendVideoThumbnailTests: XCTestCase {
    func testGeneratorCapsDecodedFrameSize() {
        let asset = AVURLAsset(url: URL(fileURLWithPath: NSTemporaryDirectory() + "missing-video.mp4"))
        let generator = chatMediaSendVideoThumbnailGenerator(asset: asset)
        XCTAssertEqual(generator.maximumSize, CGSize(width: 1024.0, height: 1024.0))
        XCTAssertGreaterThanOrEqual(chatMediaSendEditedVideoFrameMaxSide, chatMediaSendEditedVideoThumbnailMaxSide * 2.0)
        XCTAssertTrue(generator.appliesPreferredTrackTransform)
        XCTAssertEqual(generator.requestedTimeToleranceBefore, .zero)
        XCTAssertEqual(generator.requestedTimeToleranceAfter, .zero)
    }

    func testBoundedCombineKeepsOrderAndLimitsConcurrency() {
        let active = Atomic<Int>(value: 0)
        let maxActive = Atomic<Int>(value: 0)
        let started = Atomic<[Int]>(value: [])
        var subscribers: [Int: Subscriber<Int, NoError>] = [:]
        let lock = NSLock()
        var signals: [Signal<Int, NoError>] = []
        for index in 0 ..< 5 {
            signals.append(Signal { subscriber in
                let count = active.modify { $0 + 1 }
                let _ = maxActive.modify { max($0, count) }
                let _ = started.modify { $0 + [index] }
                lock.lock()
                subscribers[index] = subscriber
                lock.unlock()
                return EmptyDisposable
            })
        }
        var result: [Int?]?
        let disposable = chatMediaSendBoundedCombine(signals, maxConcurrent: 2).start(next: { value in
            result = value
        })
        XCTAssertEqual(started.with { $0 }, [0, 1])
        let complete: (Int) -> Void = { index in
            lock.lock()
            let subscriber = subscribers[index]
            lock.unlock()
            let _ = active.modify { $0 - 1 }
            subscriber?.putNext(index * 10)
            subscriber?.putCompletion()
        }
        complete(1)
        XCTAssertEqual(started.with { $0 }, [0, 1, 3])
        complete(0)
        XCTAssertEqual(Set(started.with { $0 }), Set([0, 1, 2, 3]))
        complete(3)
        complete(2)
        XCTAssertEqual(started.with { $0 }.count, 5)
        XCTAssertNil(result)
        complete(4)
        XCTAssertEqual(result, [0, 10, 20, 30, 40] as [Int?])
        XCTAssertLessThanOrEqual(maxActive.with { $0 }, 2)
        disposable.dispose()
    }

    func testBoundedCombineOfNothingIsEmpty() {
        var result: [Int?]?
        let _ = chatMediaSendBoundedCombine([Signal<Int, NoError>](), maxConcurrent: 2).start(next: { value in
            result = value
        })
        XCTAssertEqual(result, [])
    }

    func testBoundedCombineEmptyCompletionYieldsNil() {
        for maxConcurrent in [1, 2, 5] {
            var result: [Int?]?
            var completed = false
            let signals: [Signal<Int, NoError>] = [.single(1), .complete(), .single(3), .complete()]
            let _ = chatMediaSendBoundedCombine(signals, maxConcurrent: maxConcurrent).start(next: { value in
                result = value
            }, completed: {
                completed = true
            })
            XCTAssertEqual(result, [1, nil, 3, nil], "\(maxConcurrent)")
            XCTAssertTrue(completed)
        }
    }
}
