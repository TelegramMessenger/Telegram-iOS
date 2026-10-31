import XCTest
@testable import TelegramCore

// channels.editAdmin refusals must reach the admin editor as the case its alert explains, not as .generic
// (issue #47: adding a channel admin failed with no error shown).
final class UpdateChannelAdminRightsErrorTests: XCTestCase {
    private func describe(_ error: UpdateChannelAdminRightsError) -> String {
        switch error {
        case .generic:
            return "generic"
        case .adminsTooMuch:
            return "adminsTooMuch"
        case .notMemberCannotInvite:
            return "notMemberCannotInvite"
        case .userBlocked:
            return "userBlocked"
        case let .addMemberError(addMemberError):
            switch addMemberError {
            case .generic:
                return "addMember.generic"
            case let .restricted(forbiddenPeer):
                return forbiddenPeer == nil ? "addMember.restricted" : "addMember.restricted(peer)"
            case .notMutualContact:
                return "addMember.notMutualContact"
            case .limitExceeded:
                return "addMember.limitExceeded"
            case .tooMuchJoined:
                return "addMember.tooMuchJoined"
            case .bot:
                return "addMember.bot"
            case .botDoesntSupportGroups:
                return "addMember.botDoesntSupportGroups"
            case .tooMuchBots:
                return "addMember.tooMuchBots"
            case .kicked:
                return "addMember.kicked"
            }
        }
    }

    private func mapped(_ errorDescription: String) -> String {
        return self.describe(updateChannelAdminRightsError(errorDescription: errorDescription))
    }

    func testPreviouslyMappedErrorsKeepTheirCase() {
        XCTAssertEqual(self.mapped("USER_NOT_MUTUAL_CONTACT"), "addMember.notMutualContact")
        XCTAssertEqual(self.mapped("USER_PRIVACY_RESTRICTED"), "addMember.restricted")
        XCTAssertEqual(self.mapped("USER_CHANNELS_TOO_MUCH"), "addMember.tooMuchJoined")
        XCTAssertEqual(self.mapped("ADMINS_TOO_MUCH"), "adminsTooMuch")
    }

    func testMemberLimitErrorsAreNotGeneric() {
        XCTAssertEqual(self.mapped("USERS_TOO_MUCH"), "addMember.limitExceeded")
        XCTAssertEqual(self.mapped("BOTS_TOO_MUCH"), "addMember.tooMuchBots")
    }

    func testBotRefusingGroupsIsNotGeneric() {
        XCTAssertEqual(self.mapped("BOT_GROUPS_BLOCKED"), "addMember.botDoesntSupportGroups")
    }

    func testRemovedUserIsNotGeneric() {
        XCTAssertEqual(self.mapped("USER_KICKED"), "addMember.kicked")
        XCTAssertEqual(self.mapped("CHAT_ADMIN_BAN_REQUIRED"), "addMember.kicked")
    }

    func testNonMemberAndBlockedUserAreNotGeneric() {
        XCTAssertEqual(self.mapped("CHAT_ADMIN_INVITE_REQUIRED"), "notMemberCannotInvite")
        XCTAssertEqual(self.mapped("USER_BLOCKED"), "userBlocked")
    }

    func testUnknownErrorIsGeneric() {
        XCTAssertEqual(self.mapped("FLOOD_WAIT_30"), "generic")
        XCTAssertEqual(self.mapped(""), "generic")
    }
}
