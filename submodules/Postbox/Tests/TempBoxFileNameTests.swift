import Foundation
import XCTest
@testable import Postbox

/// Temp-box file names come from untrusted places (remote document names, web-app
/// download suggestions). A leading `..` must be neutralised without losing the rest
/// of the name, and no name may resolve outside its per-file directory.
final class TempBoxFileNameTests: XCTestCase {
    private static let sharedBasePath = NSTemporaryDirectory() + "TempBoxFileNameTests-TempBox"
    private static let tempBoxInitialized: Bool = {
        TempBox.initializeShared(basePath: sharedBasePath, processType: "tests", launchSpecificId: Int64(Date().timeIntervalSince1970 * 1000))
        return true
    }()

    private var files: [TempBoxFile] = []

    override func setUp() {
        super.setUp()
        XCTAssertTrue(TempBoxFileNameTests.tempBoxInitialized)
    }

    override func tearDown() {
        for file in self.files {
            TempBox.shared.dispose(file)
        }
        self.files = []
        super.tearDown()
    }

    // MARK: - Helpers

    private func tempFileName(for fileName: String) -> String {
        let file = TempBox.shared.tempFile(fileName: fileName)
        self.files.append(file)
        return (file.path as NSString).lastPathComponent
    }

    private func assertStaysInsideTempBox(_ file: TempBoxFile, file sourceFile: StaticString = #file, line: UInt = #line) {
        let standardized = (file.path as NSString).standardizingPath
        XCTAssertTrue(standardized.hasPrefix(TempBoxFileNameTests.sharedBasePath), "\(file.path) resolves outside the temp box", file: sourceFile, line: line)
        // The per-file directory is one component above the file.
        XCTAssertNotEqual(standardized, ((file.path as NSString).deletingLastPathComponent as NSString).standardizingPath, file: sourceFile, line: line)
    }

    // MARK: - Tests

    func testOrdinaryNameIsKept() {
        XCTAssertEqual(self.tempFileName(for: "report.pdf"), "report.pdf")
    }

    func testLeadingDotDotIsReplacedAndTheRestOfTheNameIsKept() {
        XCTAssertEqual(self.tempFileName(for: "..report.pdf"), "__report.pdf")
    }

    func testLeadingDotDotSlashCannotEscapeTheDirectory() {
        let file = TempBox.shared.tempFile(fileName: "../secret.txt")
        self.files.append(file)

        XCTAssertEqual((file.path as NSString).lastPathComponent, "___secret.txt")
        self.assertStaysInsideTempBox(file)
    }

    func testSlashesAreReplaced() {
        XCTAssertEqual(self.tempFileName(for: "a/b/c.txt"), "a_b_c.txt")
    }

    func testWholeNameOfDotDotIsRewrittenInsteadOfTrapping() {
        let file = TempBox.shared.tempFile(fileName: "..")
        self.files.append(file)

        XCTAssertEqual((file.path as NSString).lastPathComponent, "__")
        self.assertStaysInsideTempBox(file)
    }

    func testLinkedFileUsesTheSameSanitizedName() {
        let sourceDirectory = NSTemporaryDirectory() + "TempBoxFileNameTests-src-" + UUID().uuidString
        try? FileManager.default.createDirectory(atPath: sourceDirectory, withIntermediateDirectories: true)
        defer { let _ = try? FileManager.default.removeItem(atPath: sourceDirectory) }
        let sourcePath = sourceDirectory + "/source.bin"
        XCTAssertTrue(FileManager.default.createFile(atPath: sourcePath, contents: Data([1, 2, 3])))

        let file = TempBox.shared.file(path: sourcePath, fileName: "..document.pdf")
        self.files.append(file)

        XCTAssertEqual((file.path as NSString).lastPathComponent, "__document.pdf")
        XCTAssertEqual(try? Data(contentsOf: URL(fileURLWithPath: file.path)), Data([1, 2, 3]))
    }
}
