import XCTest
@testable import ComposerHarnessLib

/// The dump is a TEST CONTRACT: Tier-2 cases assert on this exact string through an accessibility
/// value. Changing the format is a breaking change — bump `formatVersion` and fix every caller.
final class ComposerModelDumpTests: XCTestCase {
    private func host() throws -> HarnessPanelHost {
        let root = try XCTUnwrap(AppDelegate.harnessRootViewController)
        root.loadViewIfNeeded()
        root.view.frame = CGRect(x: 0.0, y: 0.0, width: 402.0, height: 874.0)
        let deadline = Date().addingTimeInterval(30.0)
        while root.panelHost == nil && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
        root.view.layoutIfNeeded()
        return try XCTUnwrap(root.panelHost)
    }

    func testTheDumpCarriesItsHeader() throws {
        let text = ComposerModelDump.text(for: try self.host())
        XCTAssertTrue(text.hasPrefix("dump v\(ComposerModelDump.formatVersion) "), text)
        XCTAssertTrue(text.contains("blocks="), text)
    }

    /// The dump must report the backend it READ from the node, never the one requested.
    func testTheDumpNamesTheLiveBackend() throws {
        let value = try self.host()
        let backend = try XCTUnwrap(value.liveBackend)
        XCTAssertTrue(ComposerModelDump.text(for: value).contains("backend=\(backend.rawValue)"))
    }

    func testTheDumpIsStableAcrossTwoReadsOfAnUnchangedComposer() throws {
        let value = try self.host()
        XCTAssertEqual(ComposerModelDump.text(for: value), ComposerModelDump.text(for: value))
    }

    /// Seeded content must show up as blocks and runs, or the readout is decorative.
    func testSeededContentAppearsInTheDump() throws {
        let value = try self.host()
        value.setInputContent(HarnessContent.plainText("alpha"))
        value.updateLayout(width: 402.0, bottomInset: 0.0)
        let text = ComposerModelDump.text(for: value)
        XCTAssertTrue(text.contains("paragraph"), text)
        XCTAssertTrue(text.contains("\"alpha\""), text)
        XCTAssertTrue(text.contains("hasText=true"), text)
    }
}
