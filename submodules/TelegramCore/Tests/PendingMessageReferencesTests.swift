import XCTest
import Postbox
@testable import TelegramCore

/// A message draws its missing references (a reply target, a story) as loading exactly while a fill that stored it
/// is still fetching them. The registry is keyed by the referencing message, so the set that draws skeletons is the
/// set the fills redraw: overlapping fills keep a message loading until the last one releases it, and every release
/// ends it whatever the fetch's outcome.
final class PendingMessageReferencesTests: XCTestCase {
    private let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(1003073997))
    private var x: MessageId { MessageId(peerId: self.peerId, namespace: Namespaces.Message.Cloud, id: 10) }
    private var y: MessageId { MessageId(peerId: self.peerId, namespace: Namespaces.Message.Cloud, id: 11) }
    
    func testRegisteredIsLoading() {
        let references = PendingMessageReferences()
        let _ = references.register(sourceIds: [self.x])
        XCTAssertTrue(references.hasLoadingReferences(messageId: self.x))
    }
    
    func testUnregisteredIsNotLoading() {
        let references = PendingMessageReferences()
        let _ = references.register(sourceIds: [self.x])
        XCTAssertFalse(references.hasLoadingReferences(messageId: self.y))
    }
    
    func testReleaseOnFailureEndsLoading() {
        let references = PendingMessageReferences()
        let registration = references.register(sourceIds: [self.x])!
        references.release(registration)
        XCTAssertFalse(references.hasLoadingReferences(messageId: self.x))
    }
    
    func testOverlappingRegistrationsKeepLoading() {
        let references = PendingMessageReferences()
        let first = references.register(sourceIds: [self.x])!
        let second = references.register(sourceIds: [self.x])!
        references.release(first)
        XCTAssertTrue(references.hasLoadingReferences(messageId: self.x))
        references.release(second)
        XCTAssertFalse(references.hasLoadingReferences(messageId: self.x))
    }
    
    func testLaterReleaseEndsEarlierSkeleton() {
        // Fills A and B both stored X; A releases first, B last: B's release ends X's skeleton, and B redraws X
        // because X is one of B's own sources.
        let references = PendingMessageReferences()
        let a = references.register(sourceIds: [self.x, self.y])!
        let b = references.register(sourceIds: [self.x])!
        references.release(a)
        XCTAssertFalse(references.hasLoadingReferences(messageId: self.y))
        XCTAssertTrue(references.hasLoadingReferences(messageId: self.x))
        references.release(b)
        XCTAssertFalse(references.hasLoadingReferences(messageId: self.x))
        XCTAssertEqual(b.sourceIds, [self.x])
    }
    
    func testDoubleReleaseIsIgnored() {
        let references = PendingMessageReferences()
        let first = references.register(sourceIds: [self.x])!
        let _ = references.register(sourceIds: [self.x])!
        references.release(first)
        references.release(first)
        XCTAssertTrue(references.hasLoadingReferences(messageId: self.x))
    }
    
    func testEmptyRegistrationIsNil() {
        let references = PendingMessageReferences()
        XCTAssertNil(references.register(sourceIds: []))
    }
}
