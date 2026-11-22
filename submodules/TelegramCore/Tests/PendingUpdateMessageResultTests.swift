import XCTest
import Postbox
import SwiftSignalKit
@testable import TelegramCore

final class PendingUpdateMessageResultTests: XCTestCase {
    private final class Source {
        var next: ((RequestEditMessageResult) -> Void)?
        var error: ((RequestEditMessageError) -> Void)?
        var complete: (() -> Void)?
        var onSubscribe: ((Source) -> Void)?
        var disposalCount = 0

        var signal: Signal<RequestEditMessageResult, RequestEditMessageError> {
            return Signal { subscriber in
                self.next = { subscriber.putNext($0) }
                self.error = { subscriber.putError($0) }
                self.complete = { subscriber.putCompletion() }
                self.onSubscribe?(self)
                return ActionDisposable { self.disposalCount += 1 }
            }
        }
    }

    private final class Fixture {
        let queue = Queue()
        let messageId = MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1)), namespace: Namespaces.Message.Cloud, id: 1)
        var manager: PendingUpdateMessageManagerImpl?
        var sources: [Source] = []
        var onSubscribe: ((Source) -> Void)?
        var requests: [PendingUpdateMessageRequest] = []
        var results: [String] = []
        var snapshots: [[MessageId: ChatUpdatingMessageMedia]] = []
        var errors: [RequestEditMessageError] = []
        var observation: Disposable?
        var errorObservation: Disposable?

        init() {
            queue.sync {
                manager = PendingUpdateMessageManagerImpl(queue: queue, makeRequest: { [unowned self] request, _ in
                    requests.append(request)
                    let source = Source()
                    source.onSubscribe = onSubscribe
                    sources.append(source)
                    return source.signal
                })
                observation = manager!.updatingMessageMedia.start(next: { [unowned self] value in snapshots.append(value) })
                errorObservation = manager!.errors.start(next: { [unowned self] _, error in errors.append(error) })
            }
        }

        deinit {
            close()
        }

        func close() {
            queue.sync {
                manager = nil
                observation?.dispose()
                errorObservation?.dispose()
            }
        }

        func add(_ text: String, completion: ((PendingUpdateMessageResult) -> Void)? = nil) {
            queue.sync {
                manager!.add(messageId: messageId, text: text, media: .keep, entities: nil, richText: nil, inlineStickers: [:], webpagePreviewAttribute: nil, invertMediaAttribute: nil, disableUrlPreview: true, completion: { [weak self] result in
                    guard let self else { return }
                    let value: String
                    switch result {
                    case .applied: value = "applied"
                    case .unconfirmed: value = "unconfirmed"
                    case .failed: value = "failed"
                    case .cancelled: value = "cancelled"
                    case .superseded: value = "superseded"
                    case .interrupted: value = "interrupted"
                    }
                    self.results.append(text + ":" + value)
                    completion?(result)
                })
            }
        }

        func emit(_ action: () -> Void) {
            queue.sync(action)
            queue.sync {}
        }
    }

    func testOptimisticStateAndProgressAreNotAcceptance() {
        let fixture = Fixture()
        fixture.add("first")
        XCTAssertEqual(fixture.snapshots.last?[fixture.messageId]?.text, "first")
        XCTAssertEqual(fixture.requests.first?.value.disableUrlPreview, true)
        XCTAssertTrue(fixture.results.isEmpty)
        fixture.emit { fixture.sources[0].next?(.progress(0.4)) }
        XCTAssertEqual(fixture.snapshots.last?[fixture.messageId]?.progress, 0.4)
        XCTAssertTrue(fixture.results.isEmpty)
        fixture.emit {
            fixture.sources[0].next?(.done(true))
            fixture.sources[0].complete?()
            fixture.sources[0].next?(.done(false))
        }
        XCTAssertEqual(fixture.results, ["first:applied"])
        XCTAssertTrue(fixture.snapshots.last?.isEmpty == true)
        XCTAssertEqual(fixture.sources[0].disposalCount, 1)
    }

    func testFalseDoneAndEmptyCompletionAreUnconfirmed() {
        let fixture = Fixture()
        fixture.add("unchangedOrMissing")
        fixture.emit { fixture.sources[0].next?(.done(false)) }
        fixture.add("empty")
        fixture.emit { fixture.sources[1].complete?() }
        XCTAssertEqual(fixture.results, ["unchangedOrMissing:unconfirmed", "empty:unconfirmed"])
        XCTAssertTrue(fixture.snapshots.last?.isEmpty == true)
        XCTAssertEqual(fixture.sources.map { $0.disposalCount }, [1, 1])
    }

    func testSupersededAttemptCannotResolveOrOverwriteReplacement() {
        let fixture = Fixture()
        fixture.add("old")
        fixture.add("new")
        fixture.emit {
            fixture.sources[0].next?(.done(true))
            fixture.sources[0].error?(.restricted)
            fixture.sources[0].complete?()
        }
        XCTAssertEqual(fixture.results, ["old:superseded"])
        XCTAssertEqual(fixture.snapshots.last?[fixture.messageId]?.text, "new")
        XCTAssertTrue(fixture.errors.isEmpty)
        fixture.emit { fixture.sources[1].next?(.done(true)) }
        XCTAssertEqual(fixture.results, ["old:superseded", "new:applied"])
        XCTAssertEqual(fixture.sources.map { $0.disposalCount }, [1, 1])
    }

    func testFailurePreservesErrorDeliveryAndResolvesOnce() {
        let fixture = Fixture()
        var reportedError: RequestEditMessageError?
        fixture.add("failed", completion: { result in
            if case let .failed(error) = result { reportedError = error }
        })
        fixture.emit {
            fixture.sources[0].error?(.invalidGrouping)
            fixture.sources[0].complete?()
        }
        guard case .invalidGrouping? = reportedError, case .invalidGrouping? = fixture.errors.first else {
            return XCTFail("The observer and existing error stream must receive the request error")
        }
        XCTAssertEqual(fixture.results, ["failed:failed"])
        XCTAssertTrue(fixture.snapshots.last?.isEmpty == true)
        XCTAssertEqual(fixture.sources[0].disposalCount, 1)
    }

    func testCancellationAndManagerDestructionAreDistinctFromAcceptance() {
        let fixture = Fixture()
        fixture.add("cancelled")
        fixture.emit {
            fixture.manager?.cancel(messageId: fixture.messageId)
            fixture.manager?.cancel(messageId: fixture.messageId)
            fixture.sources[0].next?(.done(true))
        }
        fixture.add("interrupted")
        fixture.close()
        fixture.emit { fixture.sources[1].next?(.done(true)) }
        XCTAssertEqual(fixture.results, ["cancelled:cancelled", "interrupted:interrupted"])
        XCTAssertEqual(fixture.sources.map { $0.disposalCount }, [1, 1])
    }

    func testCompletionCanStartAnotherEditWithoutOldCleanupRemovingIt() {
        let fixture = Fixture()
        fixture.add("first", completion: { [weak fixture] _ in fixture?.add("second") })
        fixture.emit { fixture.sources[0].next?(.done(true)) }
        XCTAssertEqual(fixture.snapshots.last?[fixture.messageId]?.text, "second")
        fixture.emit { fixture.sources[1].next?(.done(true)) }
        XCTAssertEqual(fixture.results, ["first:applied", "second:applied"])
        XCTAssertEqual(fixture.sources.map { $0.disposalCount }, [1, 1])
    }

    func testSynchronousCompletionDisposesSourceInstalledAfterResult() {
        let fixture = Fixture()
        fixture.onSubscribe = { source in
            source.next?(.progress(0.2))
            source.next?(.done(true))
            source.complete?()
        }
        fixture.add("synchronous")
        XCTAssertEqual(fixture.results, ["synchronous:applied"])
        XCTAssertTrue(fixture.snapshots.last?.isEmpty == true)
        XCTAssertEqual(fixture.sources[0].disposalCount, 1)
    }

    func testSupersededCompletionCanCancelTheInstalledReplacement() {
        let fixture = Fixture()
        fixture.add("old", completion: { [weak fixture] _ in
            guard let fixture else { return }
            fixture.manager?.cancel(messageId: fixture.messageId)
        })
        fixture.add("new")
        XCTAssertEqual(fixture.results, ["old:superseded", "new:cancelled"])
        XCTAssertTrue(fixture.snapshots.last?.isEmpty == true)
        XCTAssertEqual(fixture.sources.map { $0.disposalCount }, [1, 1])
    }

    func testLegacyUnobservedEditStillPublishesAndClearsPendingState() {
        let fixture = Fixture()
        fixture.emit {
            fixture.manager?.add(messageId: fixture.messageId, text: "legacy", media: .keep, entities: nil, richText: nil, inlineStickers: [:], webpagePreviewAttribute: nil, invertMediaAttribute: nil, disableUrlPreview: false)
        }
        XCTAssertEqual(fixture.snapshots.last?[fixture.messageId]?.text, "legacy")
        fixture.emit { fixture.sources[0].next?(.done(true)) }
        XCTAssertTrue(fixture.results.isEmpty)
        XCTAssertTrue(fixture.snapshots.last?.isEmpty == true)
        XCTAssertEqual(fixture.sources[0].disposalCount, 1)
    }
}
