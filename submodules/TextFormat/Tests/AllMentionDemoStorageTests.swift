import Foundation
import XCTest
import Postbox

final class AllMentionDemoStorageTests: XCTestCase {
    private var group: URL!

    override func setUpWithError() throws {
        self.group = FileManager.default.temporaryDirectory.appendingPathComponent("all-mention-storage-test-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: self.group, withIntermediateDirectories: true)
        self.group = self.group.standardizedFileURL.resolvingSymlinksInPath()
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: self.group)
    }

    private var container: URL { self.group.appendingPathComponent("all-mention-demo", isDirectory: true) }
    private var manifest: URL { self.container.appendingPathComponent("session.json") }

    private func legacy(created: TimeInterval, complete: Bool = true) throws -> URL {
        let root = self.container.appendingPathComponent("launch-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("accounts-metadata"), withIntermediateDirectories: true)
        try Data("local-demo-key".utf8).write(to: root.appendingPathComponent(".tempkey"))
        if complete { try Data("{}".utf8).write(to: root.appendingPathComponent("accounts-metadata/atomic-state")) }
        try FileManager.default.setAttributes([.creationDate: Date(timeIntervalSince1970: created)], ofItemAtPath: root.path)
        return root
    }

    private func writeManifest(directory: String, version: Int = 1) throws {
        let data = try JSONSerialization.data(withJSONObject: ["version": version, "directory": directory])
        try data.write(to: self.manifest)
    }

    func testReopeningUsesSameDirectoryAndLeavesExistingFilesIntact() throws {
        let first = try AllMentionDemoStorage.root(in: self.group.path)
        let payload = URL(fileURLWithPath: first).appendingPathComponent("postbox-fixture")
        let content = Data("permission, quota, queue and read state".utf8)
        try content.write(to: payload)
        let second = try AllMentionDemoStorage.root(in: self.group.path)
        XCTAssertEqual(first, second)
        XCTAssertEqual(try Data(contentsOf: payload), content)
        XCTAssertTrue(AllMentionDemoStorage.contains(rootPath: second, in: self.group.path))
        XCTAssertFalse(AllMentionDemoStorage.contains(rootPath: second, in: self.group.deletingLastPathComponent().path))
    }

    func testShowcaseSessionIsSeparateAndPreservesExistingQAStore() throws {
        let original = try AllMentionDemoStorage.root(in: self.group.path)
        let originalManifest = try Data(contentsOf: self.manifest)
        let originalFile = URL(fileURLWithPath: original).appendingPathComponent("saved-qa-state")
        try Data("permission, quota, queue and read state".utf8).write(to: originalFile)

        let showcase = try AllMentionDemoStorage.root(in: self.group.path, showcase: true)
        XCTAssertNotEqual(showcase, original)
        let metadata = URL(fileURLWithPath: showcase).appendingPathComponent("accounts-metadata/atomic-state")
        let state = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: metadata)) as? [String: Any])
        XCTAssertEqual(try XCTUnwrap(state["records"] as? [Any]).count, 0)
        XCTAssertEqual(try Data(contentsOf: self.manifest), originalManifest)
        XCTAssertEqual(try AllMentionDemoStorage.root(in: self.group.path), original)
        XCTAssertEqual(try AllMentionDemoStorage.root(in: self.group.path, showcase: true), showcase)
        XCTAssertEqual(try String(contentsOf: originalFile, encoding: .utf8), "permission, quota, queue and read state")
        XCTAssertTrue(AllMentionDemoStorage.contains(rootPath: showcase, in: self.group.path))
    }

    func testAdoptsNewestCompleteLegacyStoreWithoutMovingItsKey() throws {
        let older = try self.legacy(created: 1000)
        let newest = try self.legacy(created: 2000)
        let incomplete = try self.legacy(created: 3000, complete: false)
        let adopted = try AllMentionDemoStorage.root(in: self.group.path)
        // Simulator Foundation can expose the same directory through /var and
        // /private/var. Verify the selected store identity within our namespace.
        XCTAssertEqual(URL(fileURLWithPath: adopted).lastPathComponent, newest.lastPathComponent)
        XCTAssertTrue(AllMentionDemoStorage.contains(rootPath: adopted, in: self.group.path))
        XCTAssertEqual(try Data(contentsOf: newest.appendingPathComponent(".tempkey")), Data("local-demo-key".utf8))
        XCTAssertTrue(FileManager.default.fileExists(atPath: older.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: incomplete.path))
        XCTAssertEqual(try AllMentionDemoStorage.root(in: self.group.path), adopted)
    }

    func testExplicitResetSelectsNewStoreAndKeepsPreviousStore() throws {
        let first = try AllMentionDemoStorage.root(in: self.group.path)
        let saved = URL(fileURLWithPath: first).appendingPathComponent("saved")
        try Data("keep".utf8).write(to: saved)
        let second = try AllMentionDemoStorage.root(in: self.group.path, reset: true)
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(try Data(contentsOf: saved), Data("keep".utf8))
        XCTAssertEqual(try AllMentionDemoStorage.root(in: self.group.path), second)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: self.container.path).filter { $0.hasPrefix("session-backup-") }.count, 1)
    }

    func testCorruptManifestDoesNotSilentlyCreateAnotherStore() throws {
        let original = try AllMentionDemoStorage.root(in: self.group.path)
        let corrupt = Data("invalid-json".utf8)
        try corrupt.write(to: self.manifest)
        XCTAssertThrowsError(try AllMentionDemoStorage.root(in: self.group.path))
        XCTAssertEqual(try Data(contentsOf: self.manifest), corrupt)
        let replacement = try AllMentionDemoStorage.root(in: self.group.path, reset: true)
        XCTAssertNotEqual(replacement, original)
        XCTAssertTrue(FileManager.default.fileExists(atPath: original))
    }

    func testManifestCannotSelectNormalAccountsOrOutsideDirectory() throws {
        let _ = try AllMentionDemoStorage.root(in: self.group.path)
        for name in ["../accounts-metadata", self.group.path, "accounts-metadata", "launch-../outside"] {
            try self.writeManifest(directory: name)
            XCTAssertThrowsError(try AllMentionDemoStorage.root(in: self.group.path), name)
        }
    }

    func testMissingSavedStoreIsReportedInsteadOfReseeded() throws {
        let _ = try AllMentionDemoStorage.root(in: self.group.path)
        let name = "store-" + UUID().uuidString
        try self.writeManifest(directory: name)
        XCTAssertThrowsError(try AllMentionDemoStorage.root(in: self.group.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: self.container.appendingPathComponent(name).path))
    }

    func testSessionSymlinkCannotEscapeDemoDirectory() throws {
        let _ = try AllMentionDemoStorage.root(in: self.group.path)
        let name = "store-" + UUID().uuidString
        try FileManager.default.createSymbolicLink(at: self.container.appendingPathComponent(name), withDestinationURL: self.group)
        try self.writeManifest(directory: name)
        XCTAssertThrowsError(try AllMentionDemoStorage.root(in: self.group.path))
    }

    func testDemoContainerSymlinkCannotWriteIntoNormalAccountDirectory() throws {
        let normal = self.group.appendingPathComponent("accounts-metadata", isDirectory: true)
        try FileManager.default.createDirectory(at: normal, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: self.container, withDestinationURL: normal)
        XCTAssertThrowsError(try AllMentionDemoStorage.root(in: self.group.path))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: normal.path).isEmpty)
    }

    func testUnknownManifestVersionLeavesExistingStoreUnchanged() throws {
        let first = try AllMentionDemoStorage.root(in: self.group.path)
        try self.writeManifest(directory: URL(fileURLWithPath: first).lastPathComponent, version: 2)
        XCTAssertThrowsError(try AllMentionDemoStorage.root(in: self.group.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: first))
    }

    func testLaunchWithoutArgumentsRestoresModeAndExplicitChoiceOverridesIt() {
        XCTAssertEqual(AllMentionDemoLaunchMode.selected(arguments: [], previous: "recipient"), .recipient)
        XCTAssertEqual(AllMentionDemoLaunchMode.selected(arguments: ["--all-mention-demo-sender"], previous: "recipient"), .sender)
        XCTAssertEqual(AllMentionDemoLaunchMode.selected(arguments: ["--all-mention-demo-recipient"], previous: "sender"), .recipient)
        XCTAssertEqual(AllMentionDemoLaunchMode.selected(arguments: [], previous: "unknown"), .sender)
    }

    func testRecipientIntroMarkerSurvivesPostboxSerialization() throws {
        let first = AllMentionDemoStoreState()
        XCTAssertFalse(first.recipientIntroDelivered)
        let delivered = first.recordingRecipientIntro()
        let data = try AdaptedPostboxEncoder().encode(delivered)
        let reopened = try AdaptedPostboxDecoder().decode(AllMentionDemoStoreState.self, from: data)
        XCTAssertEqual(reopened, delivered)
        XCTAssertTrue(reopened.recipientIntroDelivered)
        XCTAssertEqual(reopened.recordingRecipientIntro(), reopened)
    }
}
