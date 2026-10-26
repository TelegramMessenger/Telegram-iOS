import XCTest
import TelegramCore
@testable import ChatInterfaceState

/// A chat's compose state is written by `ChatInterfaceState.update(engine:peerId:threadId:_:)`
/// with `EngineEncoder` and read back by `ChatInterfaceState.parse(_:)` when the chat reopens.
final class ChatInterfaceStatePersistenceTests: XCTestCase {
    private func reopened(_ data: Data?) -> ChatInterfaceState {
        return ChatInterfaceState.parse(OpaqueChatInterfaceState(
            opaqueData: data,
            historyScrollMessageIndex: nil,
            mediaDraftState: nil,
            synchronizeableInputState: nil
        ))
    }

    func testDismissedLinkPreviewsSurviveReopeningTheChat() throws {
        let state = ChatInterfaceState().withUpdatedComposeDisableUrlPreviews(["https://okinawaguide.org/", "https://telegram.org/"])

        let restored = self.reopened(try EngineEncoder.encode(state))

        XCTAssertEqual(restored.composeDisableUrlPreviews, ["https://okinawaguide.org/", "https://telegram.org/"])
    }

    /// Every version since 2023-10 reads the list from "dupl" first, so writing it there is what
    /// keeps it across a downgrade; the fallback below would hide a regression in `encode`.
    func testDismissedLinkPreviewsAreWrittenUnderTheKeyEveryVersionReads() throws {
        struct CurrentKeyReader: Decodable {
            let urls: [String]?

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: StringCodingKey.self)
                self.urls = try container.decodeIfPresent([String].self, forKey: "dupl")
            }
        }

        let state = ChatInterfaceState().withUpdatedComposeDisableUrlPreviews(["https://okinawaguide.org/"])

        let written = try EngineDecoder.decode(CurrentKeyReader.self, from: try EngineEncoder.encode(state))

        XCTAssertEqual(written.urls, ["https://okinawaguide.org/"])
    }

    /// Versions from 2023-10 to 2026-09 wrote the list under a mistyped key that nothing read.
    func testDismissalsWrittenUnderTheMistypedKeyAreRestored() throws {
        struct MistypedKeyState: Encodable {
            let urls: [String]

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: StringCodingKey.self)
                try container.encode(self.urls, forKey: "dup;")
            }
        }

        let restored = self.reopened(try EngineEncoder.encode(MistypedKeyState(urls: ["https://okinawaguide.org/"])))

        XCTAssertEqual(restored.composeDisableUrlPreviews, ["https://okinawaguide.org/"])
    }
}
