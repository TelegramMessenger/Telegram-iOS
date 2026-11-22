import XCTest
import TelegramCore

final class WalletSendPeerAddressResolutionTests: XCTestCase {
    private let peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(2))
    private let address = "UQCs-9jTqHhC1xYQ8dTnB8cKpXbR4ZtW2FgJ5nMvLe0aMITE"

    func testLookupInProgressDisplaysLoading() {
        var resolution = WalletSendPeerAddressResolution()
        XCTAssertEqual(resolution.display(recipientAddress: ""), .loading)
        XCTAssertNotNil(resolution.begin())
        XCTAssertEqual(resolution.display(recipientAddress: ""), .loading)
    }

    func testFailedLookupStopsLoading() {
        var resolution = WalletSendPeerAddressResolution()
        let generation = resolution.begin()!
        XCTAssertTrue(resolution.complete(generation: generation, recipient: nil))
        XCTAssertEqual(resolution.display(recipientAddress: ""), .unavailable)
    }

    func testLookupWithoutAddressStopsLoading() {
        var resolution = WalletSendPeerAddressResolution()
        let generation = resolution.begin()!
        XCTAssertTrue(resolution.complete(generation: generation, recipient: WalletUserAddress(userId: self.peerId, address: " ", publicKey: Data())))
        XCTAssertEqual(resolution.display(recipientAddress: ""), .unavailable)
    }

    func testLookupCancelledByClosingTheSheetIsNotAnError() {
        var resolution = WalletSendPeerAddressResolution()
        let _ = resolution.begin()
        resolution.state = .cancelled
        XCTAssertEqual(resolution.display(recipientAddress: ""), .loading)
    }

    func testResolvedLookupDisplaysTheAddress() {
        var resolution = WalletSendPeerAddressResolution()
        let generation = resolution.begin()!
        XCTAssertTrue(resolution.complete(generation: generation, recipient: WalletUserAddress(userId: self.peerId, address: self.address, publicKey: Data())))
        XCTAssertEqual(resolution.display(recipientAddress: self.address), .address)
    }

    func testPreresolvedAddressDisplaysTheAddress() {
        var resolution = WalletSendPeerAddressResolution()
        resolution.reset(resolvedAddress: WalletUserAddress(userId: self.peerId, address: self.address, publicKey: Data()))
        XCTAssertEqual(resolution.display(recipientAddress: self.address), .address)
    }
}
