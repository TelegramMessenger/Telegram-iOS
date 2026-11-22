import XCTest
@testable import TelegramCore

// Whether this test module was compiled with each parked API's condition (`submodules/TelegramApi/CLAUDE.md`,
// "Parked APIs").
#if TELEGRAM_NEWS_FEED_API
private let testsCompileTheFeedApi = true
#else
private let testsCompileTheFeedApi = false
#endif

#if TELEGRAM_AGENT_API
private let testsCompileTheAgentApi = true
#else
private let testsCompileTheAgentApi = false
#endif

/// Layer 233 as the server serves it has neither the feed API nor the agent API, so both are parked behind conditions
/// nothing defines. Each condition must be defined for this module exactly when TelegramCore has it: otherwise the
/// tests of the parked code (`FeedApiConversionTests`' Api cases) stay compiled out while TelegramCore talks the API.
final class ParkedApiTests: XCTestCase {
    func testTheTestsModuleCompilesTheSameFeedApiAsTelegramCore() {
        XCTAssertEqual(testsCompileTheFeedApi, newsFeedApiIsAvailable)
    }

    func testTheTestsModuleCompilesTheSameAgentApiAsTelegramCore() {
        XCTAssertEqual(testsCompileTheAgentApi, agentApiIsAvailable)
    }
}
