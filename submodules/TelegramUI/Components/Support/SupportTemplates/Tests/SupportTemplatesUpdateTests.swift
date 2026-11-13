import XCTest
@testable import SupportTemplates

private func parse(_ text: String) -> SupportTemplatesFile {
    return parseSupportTemplatesFile(Data(text.utf8))
}

private let existingFile = """
{URL}
https://example.com/tl_main.txt

{QUESTION}
Reset password
{KEYS}
own reset
Own Pass
{VALUE}
Open Settings.

{QUESTION}
Refund
{KEYS}
own refund
{VALUE}
Write to billing.

{QUESTION}
Old question
{KEYS}
own old
{VALUE}
Old answer.
"""

private let downloadedFile = """
{URL}
https://attacker.example/other.txt

{QUESTION}
Reset password
{KEYS}
remote reset
{VALUE}
Open Settings, then Reset.

{QUESTION}
Refund
{KEYS}
remote refund
{VALUE}
Write to billing.

{QUESTION}
New question
{KEYS}
remote new
{VALUE}
New answer.
"""

final class SupportTemplatesDeltaTests: XCTestCase {
    func testDeltaListsAddedChangedAndRemovedByQuestion() {
        let existing = parse(existingFile)
        let merged = supportTemplatesFileKeepingOwnData(downloaded: parse(downloadedFile), existing: existing)
        let delta = supportTemplatesDelta(was: existing, now: merged)
        XCTAssertEqual(delta.added.map(\.question), ["New question"])
        XCTAssertEqual(delta.changed.map(\.question), ["Reset password"])
        XCTAssertEqual(delta.removed.map(\.question), ["Old question"])
        XCTAssertEqual(delta.keys["resetpassword"], ["own reset", "Own Pass"])
    }

    func testOnlyRemoteKeysChangingIsNoUpdate() {
        let existing = parse("{QUESTION}\nA\n{KEYS}\nown\n{VALUE}\nB")
        let merged = supportTemplatesFileKeepingOwnData(downloaded: parse("{QUESTION}\nA\n{KEYS}\nremote\n{VALUE}\nB"), existing: existing)
        XCTAssertTrue(supportTemplatesDelta(was: existing, now: merged).isEmpty)
    }

    func testOwnKeysAndUrlSurviveAndNewQuestionsKeepRemoteKeys() {
        let merged = supportTemplatesFileKeepingOwnData(downloaded: parse(downloadedFile), existing: parse(existingFile))
        XCTAssertEqual(merged.url, "https://example.com/tl_main.txt")
        XCTAssertEqual(merged.questions["resetpassword"]?.originalKeys, ["own reset", "Own Pass"])
        XCTAssertEqual(merged.questions["resetpassword"]?.normalizedKeys, ["own reset", "own pass"])
        XCTAssertEqual(merged.questions["resetpassword"]?.value, "Open Settings, then Reset.")
        XCTAssertEqual(merged.questions["newquestion"]?.originalKeys, ["remote new"])
    }

    func testDeltaListsAddedModifiedAndRemovedQuestions() {
        let existing = parse(existingFile)
        let merged = supportTemplatesFileKeepingOwnData(downloaded: parse(downloadedFile), existing: existing)
        let delta = supportTemplatesDelta(was: existing, now: merged)
        XCTAssertEqual(delta.added.map(\.question), ["New question"])
        XCTAssertEqual(delta.added.map(\.originalKeys), [["remote new"]])
        XCTAssertEqual(delta.added.map { trimmedString($0.value) }, ["New answer."])
        XCTAssertEqual(delta.changed.map(\.question), ["Reset password"])
        XCTAssertEqual(delta.changed.map { trimmedString($0.value) }, ["Open Settings, then Reset."])
        XCTAssertEqual(delta.removed.map(\.question), ["Old question"])
    }

    func testNotificationPartsCutAtNewlinesWithinTheLimit() {
        let parts = supportTemplatesNotificationParts("aaaa\nbbbb\ncccc", limit: 6)
        XCTAssertEqual(parts, ["aaaa", "bbbb", "cccc"])
        XCTAssertEqual(supportTemplatesNotificationParts("short"), ["short"])
    }

    func testNotificationPartsKeepASurrogatePairWhole() {
        let parts = supportTemplatesNotificationParts("abc\u{1F600}def", limit: 4)
        XCTAssertEqual(parts.joined(), "abc\u{1F600}def")
    }
}

final class SupportTemplatesRewriteTests: XCTestCase {
    private func rewritten(downloaded: String, existing: String) -> (text: String, parsed: SupportTemplatesFile, merged: SupportTemplatesFile) {
        let was = parse(existing)
        let merged = supportTemplatesFileKeepingOwnData(downloaded: parse(downloaded), existing: was)
        let delta = supportTemplatesDelta(was: was, now: merged)
        let data = supportTemplatesRewrittenFile(downloaded: Data(downloaded.utf8), url: was.url, ownKeys: delta.keys)
        return (String(decoding: data, as: UTF8.self), parseSupportTemplatesFile(data), merged)
    }

    func testRewriteHasOwnUrlAndKeysAndTheRemoteValues() {
        let result = self.rewritten(downloaded: downloadedFile, existing: existingFile)
        XCTAssertEqual(result.parsed, result.merged)
        XCTAssertFalse(result.text.contains("attacker.example"))
        XCTAssertFalse(result.text.contains("remote reset"))
        XCTAssertTrue(result.text.hasPrefix("{URL}\nhttps://example.com/tl_main.txt\n\n{QUESTION}\n"))
    }

    func testOwnKeysSurviveARemoteBlockWithoutKeys() {
        let result = self.rewritten(downloaded: "{QUESTION}\nA\n{VALUE}\nNew", existing: "{URL}\nu\n{QUESTION}\nA\n{KEYS}\nown\n{VALUE}\nOld")
        XCTAssertEqual(result.parsed.questions["a"]?.originalKeys, ["own"])
        XCTAssertEqual(result.parsed.questions["a"]?.value, "New")
    }

    func testOwnKeysSurviveKeysBeforeTheQuestion() {
        let result = self.rewritten(downloaded: "{KEYS}\nremote\n{QUESTION}\nA\n{VALUE}\nNew", existing: "{URL}\nu\n{QUESTION}\nA\n{KEYS}\nown\n{VALUE}\nOld")
        XCTAssertEqual(result.parsed.questions["a"]?.originalKeys, ["own"])
        XCTAssertFalse(result.text.contains("remote"))
    }

    func testEmptyOwnKeysStayEmpty() {
        let result = self.rewritten(downloaded: "{QUESTION}\nA\n{KEYS}\nremote\n{VALUE}\nNew", existing: "{URL}\nu\n{QUESTION}\nA\n{VALUE}\nOld")
        XCTAssertEqual(result.parsed.questions["a"]?.originalKeys, [])
        XCTAssertEqual(result.parsed, result.merged)
    }

    func testNewQuestionWritesRemoteKeysAndMultilineValueSurvives() {
        let result = self.rewritten(downloaded: "{QUESTION}\nB\n{KEYS}\nremote\n{VALUE}\nLine one\n\nLine two", existing: "{URL}\nu\n{QUESTION}\nA\n{VALUE}\nOld")
        XCTAssertEqual(result.parsed.questions["b"]?.originalKeys, ["remote"])
        XCTAssertEqual(result.parsed.questions["b"]?.value, "Line one\n\nLine two")
    }

    func testLeadingByteOrderMarkIsSkipped() {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data("{URL}\nhttps://example.com/a.txt\n{QUESTION}\nA\n{VALUE}\nB".utf8))
        let file = parseSupportTemplatesFile(data)
        XCTAssertEqual(file.url, "https://example.com/a.txt")
        XCTAssertEqual(file.questions["a"]?.value, "B")
    }
}

final class SupportTemplatesManagerTests: XCTestCase {
    private var folder: URL!
    private var source: URL!
    private var responses: [String: Result<Data, SupportTemplatesFetchError>] = [:]
    private var fetched: [String] = []
    private var notifications: [(name: String, delta: SupportTemplatesDelta)] = []
    private let lock = NSLock()

    override func setUp() {
        super.setUp()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        self.folder = root.appendingPathComponent("TEMPLATES")
        self.source = root.appendingPathComponent("picked")
        try! FileManager.default.createDirectory(at: self.source, withIntermediateDirectories: true)
        self.responses = [:]
        self.fetched = []
        self.notifications = []
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: self.folder.deletingLastPathComponent())
        super.tearDown()
    }

    private func makeManager() -> SupportTemplatesManager {
        return SupportTemplatesManager(folderPath: self.folder.path, fetch: { [unowned self] url, completion in
            self.lock.lock()
            self.fetched.append(url.absoluteString)
            let response = self.responses[url.absoluteString] ?? .failure(.network("no response"))
            self.lock.unlock()
            completion(response)
        }, notify: { [unowned self] name, delta in
            self.lock.lock()
            self.notifications.append((name: name, delta: delta))
            self.lock.unlock()
        }, log: { _ in
        })
    }

    private func picked(_ name: String, _ data: Data) -> URL {
        let url = self.source.appendingPathComponent(name)
        try! data.write(to: url)
        return url
    }

    private func picked(_ name: String, _ text: String) -> URL {
        return self.picked(name, Data(text.utf8))
    }

    private func importFiles(_ manager: SupportTemplatesManager, _ urls: [URL]) -> SupportTemplatesReloadResult {
        let done = self.expectation(description: "import")
        var result: SupportTemplatesReloadResult?
        manager.importFiles(urls, completion: {
            result = $0
            done.fulfill()
        })
        self.wait(for: [done], timeout: 10.0)
        return result!
    }

    private func reload(_ manager: SupportTemplatesManager) -> SupportTemplatesReloadResult {
        let done = self.expectation(description: "reload")
        var result: SupportTemplatesReloadResult?
        manager.reload(completion: {
            result = $0
            done.fulfill()
        })
        self.wait(for: [done], timeout: 10.0)
        return result!
    }

    private func stored(_ name: String) -> SupportTemplatesFile? {
        return (try? Data(contentsOf: self.folder.appendingPathComponent(name))).map(parseSupportTemplatesFile)
    }

    private func fileExists(_ name: String) -> Bool {
        return FileManager.default.fileExists(atPath: self.folder.appendingPathComponent(name).path)
    }

    func testNoFolderIsNoFilesNoErrorsAndNoFetch() {
        let manager = self.makeManager()
        let result = self.reload(manager)
        XCTAssertEqual(result.errors, [])
        XCTAssertEqual(manager.state.files, [])
        XCTAssertEqual(self.fetched, [])
    }

    func testImportLoadsTheFileAndAFileWithoutUrlFetchesNothing() {
        let manager = self.makeManager()
        let result = self.importFiles(manager, [self.picked("TL_one.TXT", "{QUESTION}\nA\n{KEYS}\nkey\n{VALUE}\nB")])
        XCTAssertEqual(result.errors, [])
        XCTAssertEqual(manager.state.files, [SupportTemplatesFileInfo(name: "TL_one.TXT", templateCount: 1, hasUrl: false)])
        XCTAssertEqual(manager.templates.matchExact("key")?.question.value, "B")
        XCTAssertEqual(self.fetched, [])
    }

    func testImportRefusesWrongNameBrokenFilesAndKeepsTheGoodOne() {
        let manager = self.makeManager()
        let result = self.importFiles(manager, [
            self.picked("notes.txt", "{QUESTION}\nA\n{VALUE}\nB"),
            self.picked("tl_garbage.txt", "just some words\nwith no tokens"),
            self.picked("tl_binary.txt", Data([0xFF, 0xFE, 0x00, 0x41])),
            self.picked("tl_good.txt", "{QUESTION}\nA\n{VALUE}\nB")
        ])
        XCTAssertEqual(result.errors, [
            .file(name: "notes.txt", problem: .wrongName),
            .file(name: "tl_garbage.txt", problem: .noTemplates),
            .file(name: "tl_binary.txt", problem: .notText)
        ])
        XCTAssertEqual(manager.state.files.map(\.name), ["tl_good.txt"])
        XCTAssertFalse(self.fileExists("tl_garbage.txt"))
        XCTAssertFalse(self.fileExists("notes.txt"))
    }

    func testAllRefusedStillCompletes() {
        let manager = self.makeManager()
        let result = self.importFiles(manager, [self.picked("notes.txt", "x")])
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertEqual(manager.state.files, [])
    }

    func testImportOverSameNameKeepsAnOldCopy() {
        let manager = self.makeManager()
        _ = self.importFiles(manager, [self.picked("tl_one.txt", "{QUESTION}\nFirst\n{VALUE}\nB")])
        _ = self.importFiles(manager, [self.picked("tl_one.txt", "{QUESTION}\nSecond\n{VALUE}\nB")])
        XCTAssertNotNil(self.stored("tl_one.txt")?.questions["second"])
        XCTAssertNotNil(self.stored("tl_one.txt.old")?.questions["first"])
        XCTAssertEqual(manager.state.files.map(\.name), ["tl_one.txt"])
    }

    func testUpdateRewritesKeepsOldCopyNotifiesAndUpdatesSearch() {
        let url = "https://example.com/tl_main.txt"
        self.responses[url] = .success(Data(downloadedFile.utf8))
        let manager = self.makeManager()
        let result = self.importFiles(manager, [self.picked("tl_main.txt", existingFile)])
        XCTAssertEqual(result.errors, [])
        XCTAssertEqual(result.updatedFiles, ["tl_main.txt"])
        XCTAssertEqual(self.fetched, [url])

        XCTAssertEqual(self.stored("tl_main.txt.old"), parse(existingFile))
        let stored = self.stored("tl_main.txt")
        XCTAssertEqual(stored?.url, url)
        XCTAssertEqual(stored?.questions["resetpassword"]?.originalKeys, ["own reset", "Own Pass"])
        XCTAssertNil(stored?.questions["oldquestion"])

        XCTAssertEqual(self.notifications.count, 1)
        XCTAssertEqual(self.notifications.first?.name, "tl_main.txt")
        XCTAssertEqual(self.notifications.first?.delta.added.map(\.question), ["New question"])
        XCTAssertEqual(self.notifications.first?.delta.changed.map(\.question), ["Reset password"])
        XCTAssertEqual(self.notifications.first?.delta.removed.map(\.question), ["Old question"])

        XCTAssertEqual(manager.templates.matchExact("own reset")?.question.value, "Open Settings, then Reset.")
        XCTAssertNil(manager.templates.matchExact("remote reset"))
        XCTAssertEqual(manager.templates.matchExact("remote new")?.question.value, "New answer.")
        XCTAssertNil(manager.templates.matchExact("own old"))
    }

    func testSecondUpdateWithSameContentChangesNothing() {
        let url = "https://example.com/tl_main.txt"
        self.responses[url] = .success(Data(downloadedFile.utf8))
        let manager = self.makeManager()
        _ = self.importFiles(manager, [self.picked("tl_main.txt", existingFile)])
        let result = self.reload(manager)
        XCTAssertEqual(result.errors, [])
        XCTAssertEqual(result.updatedFiles, [])
        XCTAssertEqual(self.notifications.count, 1)
        XCTAssertEqual(self.stored("tl_main.txt.old"), parse(existingFile))
    }

    func testFailedFetchChangesNothingReportsAndDoesNotBlockTheNextReload() {
        let url = "https://example.com/tl_main.txt"
        self.responses[url] = .failure(.http(404))
        let manager = self.makeManager()
        let result = self.importFiles(manager, [self.picked("tl_main.txt", existingFile)])
        XCTAssertEqual(result.errors, [.updateFailed(name: "tl_main.txt", url: url, problem: .fetch(.http(404)))])
        XCTAssertEqual(manager.state.errors, result.errors)
        XCTAssertEqual(self.notifications.count, 0)
        XCTAssertFalse(self.fileExists("tl_main.txt.old"))
        XCTAssertEqual(manager.templates.matchExact("own reset")?.question.value, "Open Settings.")

        self.responses[url] = .success(Data(downloadedFile.utf8))
        let second = self.reload(manager)
        XCTAssertEqual(second.errors, [])
        XCTAssertEqual(second.updatedFiles, ["tl_main.txt"])
        XCTAssertEqual(manager.state.errors, [])
    }

    func testDownloadWithoutQuestionsIsAFailureAndKeepsTheFile() {
        let url = "https://example.com/tl_main.txt"
        self.responses[url] = .success(Data("<html>Sign in to this network</html>".utf8))
        let manager = self.makeManager()
        let result = self.importFiles(manager, [self.picked("tl_main.txt", existingFile)])
        XCTAssertEqual(result.errors, [.updateFailed(name: "tl_main.txt", url: url, problem: .noTemplates)])
        XCTAssertEqual(self.stored("tl_main.txt"), parse(existingFile))
        XCTAssertEqual(self.notifications.count, 0)
    }

    func testUnsupportedUrlSchemeIsNotFetched() {
        let manager = self.makeManager()
        let result = self.importFiles(manager, [self.picked("tl_one.txt", "{URL}\nfile:///etc/hosts\n{QUESTION}\nA\n{VALUE}\nB")])
        XCTAssertEqual(result.errors, [.invalidUrl(name: "tl_one.txt", url: "file:///etc/hosts")])
        XCTAssertEqual(self.fetched, [])
    }

    func testRemovingAFileDropsItsOldCopyAndItsTemplates() {
        let manager = self.makeManager()
        _ = self.importFiles(manager, [self.picked("tl_one.txt", "{QUESTION}\nA\n{KEYS}\nkey\n{VALUE}\nB")])
        _ = self.importFiles(manager, [self.picked("tl_one.txt", "{QUESTION}\nA\n{KEYS}\nkey\n{VALUE}\nC")])
        manager.removeFile(name: "tl_one.txt")
        XCTAssertEqual(self.reload(manager).errors, [])
        XCTAssertFalse(self.fileExists("tl_one.txt"))
        XCTAssertFalse(self.fileExists("tl_one.txt.old"))
        XCTAssertNil(manager.templates.matchExact("key"))
        XCTAssertEqual(manager.state.files, [])
    }

    func testReloadDuringAFetchWaitsAndRunsOnceMore() {
        let url = "https://example.com/tl_one.txt"
        var pending: ((Result<Data, SupportTemplatesFetchError>) -> Void)?
        var fetchCount = 0
        let first = self.expectation(description: "first fetch")
        let manager = SupportTemplatesManager(folderPath: self.folder.path, fetch: { _, completion in
            fetchCount += 1
            if fetchCount == 1 {
                pending = completion
                first.fulfill()
            } else {
                completion(.success(Data("{QUESTION}\nA\n{VALUE}\nB".utf8)))
            }
        }, notify: { _, _ in }, log: { _ in })

        try! FileManager.default.createDirectory(at: self.folder, withIntermediateDirectories: true)
        try! Data("{URL}\n\(url)\n{QUESTION}\nA\n{VALUE}\nB".utf8).write(to: self.folder.appendingPathComponent("tl_one.txt"))

        manager.reload()
        self.wait(for: [first], timeout: 10.0)
        XCTAssertTrue(manager.state.isReloading)

        let done = self.expectation(description: "second reload")
        manager.reload(completion: { _ in
            done.fulfill()
        })
        pending?(.success(Data("{QUESTION}\nA\n{VALUE}\nB".utf8)))
        self.wait(for: [done], timeout: 10.0)
        XCTAssertEqual(fetchCount, 2)
        XCTAssertFalse(manager.state.isReloading)
    }
}
