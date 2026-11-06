import XCTest
import Foundation
import ObjectiveC
import AppBundle
import PresentationStrings
import UIKit
import CoreText

final class AllMentionLocalizationTests: XCTestCase {
    private let languages = ["en", "ar", "be", "ca", "de", "es", "fa", "fr", "id", "it", "ko", "ms", "nl", "pl", "pt", "ru", "tr", "uk", "uz"]

    override class func setUp() {
        super.setUp()
        exchangeResourceLookup()
    }

    override class func tearDown() {
        exchangeResourceLookup()
        super.tearDown()
    }

    private class func exchangeResourceLookup() {
        method_exchangeImplementations(
            class_getInstanceMethod(Bundle.self, #selector(Bundle.path(forResource:ofType:)))!,
            class_getInstanceMethod(Bundle.self, #selector(Bundle.allMentionTestResourcePath(_:ofType:)))!
        )
    }

    private func component(_ code: String, dict: [String: String] = [:]) -> _PresentationStringsComponent {
        return _PresentationStringsComponent(languageCode: code, localizedName: code, pluralizationRulesCode: nil, dict: dict)
    }

    private func strings(_ code: String, dict: [String: String] = [:], secondary: _PresentationStringsComponent? = nil) -> _PresentationStrings {
        return _PresentationStrings(primaryComponent: component(code, dict: dict), secondaryComponent: secondary, groupingSeparator: "")
    }

    func testAllDeclaredLanguagesResolveEveryFeatureKey() throws {
        for language in languages {
            let value = strings(language)
            let path = try XCTUnwrap(Bundle(for: Self.self).path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: language))
            let resource = try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String])
            let resolved = [
                "AllMention.SuggestionTitle": value.AllMention_SuggestionTitle,
                "AllMention.PermissionTitle": value.AllMention_PermissionTitle,
                "AllMention.PermissionInfo": value.AllMention_PermissionInfo,
                "AllMention.AccessibilityMessage": value.AllMention_AccessibilityMessage,
                "AllMention.SendError.TopicDeleted": value.AllMention_SendError_TopicDeleted,
                "AllMention.SendError.TopicClosed": value.AllMention_SendError_TopicClosed,
                "AllMention.SendError.PermissionDenied": value.AllMention_SendError_PermissionDenied,
                "AllMention.SendError.GroupUnavailable": value.AllMention_SendError_GroupUnavailable,
                "AllMention.SendError.ScheduledPermissionDisabled": value.AllMention_SendError_ScheduledPermissionDisabled,
                "AllMention.SendError.ScheduledRateLimited": value.AllMention_SendError_ScheduledRateLimited,
                "AllMention.SendError.RateLimited": value.AllMention_SendError_RateLimited,
                "ScheduledMessages.Title": value.ScheduledMessages_Title
            ]
            for (key, translation) in resolved {
                XCTAssertEqual(translation, resource[key], "\(language): \(key)")
                XCTAssertFalse(translation.isEmpty)
                XCTAssertNotEqual(translation, key)
            }
            XCTAssertTrue(value.AllMention_PermissionInfo.contains("@all"), language)
        }
    }

    func testPrimaryRemoteTranslationOverridesBundledTranslations() {
        let value = strings("ru", dict: ["AllMention.SuggestionTitle": "Primary translation"], secondary: component("de", dict: ["AllMention.SuggestionTitle": "Secondary translation"]))
        XCTAssertEqual(value.AllMention_SuggestionTitle, "Primary translation")
    }

    func testSecondaryRemoteTranslationOverridesPrimaryBundle() {
        let value = strings("ru", secondary: component("de", dict: ["AllMention.SuggestionTitle": "Secondary translation"]))
        XCTAssertEqual(value.AllMention_SuggestionTitle, "Secondary translation")
    }

    func testCustomLanguageInheritsBundledBaseLanguage() {
        let value = strings("proposal-custom", secondary: component("ru"))
        XCTAssertEqual(value.baseLanguageCode, "ru")
        XCTAssertEqual(value.AllMention_SuggestionTitle, "Все участники")
    }

    func testUnsupportedLanguageFallsBackToEnglish() {
        let value = strings("zz")
        XCTAssertEqual(value.AllMention_SuggestionTitle, "All members")
        XCTAssertEqual(value.AllMention_SendError_RateLimited, "Too many calls. Please wait before trying again.")
    }

    func testPartialBundleKeepsEnglishFallbackForExistingKeys() {
        XCTAssertEqual(strings("ru").Common_OK, strings("en").Common_OK)
        XCTAssertEqual(strings("ru").AllMention_SuggestionTitle, "Все участники")
    }

    func testRegionalLanguageUsesBundledParent() {
        for language in ["ru-RU", "ru_RU"] {
            XCTAssertEqual(strings(language).AllMention_SuggestionTitle, "Все участники")
        }
        XCTAssertEqual(strings("pt-BR").AllMention_SuggestionTitle, "Todos os membros")
    }

    func testScheduledFailureFormatsLocalizedCauseAndUTF16Range() {
        let cause = "🙂 Тема."
        for language in languages {
            let value = strings(language).AllMention_SendError_ScheduledDestination(cause)
            XCTAssertFalse(value.string.contains("%@"), language)
            XCTAssertEqual(value.ranges.count, 1, language)
            if let range = value.ranges.first {
                XCTAssertEqual((value.string as NSString).substring(with: range.range), cause, language)
            }
        }
    }

    func testNativeRussianAndArabicMemberPlurals() {
        let russian = strings("ru")
        for (count, expected) in [(1, "1 участник"), (2, "2 участника"), (5, "5 участников"), (21, "21 участник"), (24, "24 участника")] {
            XCTAssertEqual(russian.Conversation_StatusMembers(Int32(count)), expected)
        }
        let arabic = strings("ar")
        for (count, expected) in [(0, "لا أعضاء"), (1, "عضو واحد"), (2, "عضوان"), (3, "3 أعضاء"), (11, "11 عضوًا")] {
            XCTAssertEqual(arabic.Conversation_StatusMembers(Int32(count)), expected)
        }
    }

    func testMentionLiteralKeepsVisualOrderInsideRTLText() {
        for language in ["ar", "fa"] {
            let text = strings(language).AllMention_PermissionInfo
            let range = (text as NSString).range(of: "@all")
            XCTAssertNotEqual(range.location, NSNotFound)
            guard range.location != NSNotFound else { continue }
            let paragraph = NSMutableParagraphStyle()
            paragraph.baseWritingDirection = .rightToLeft
            let attributed = NSAttributedString(string: text, attributes: [.font: UIFont.systemFont(ofSize: 17.0), .paragraphStyle: paragraph])
            let line = CTLineCreateWithAttributedString(attributed)
            let offsets = (0 ..< range.length).map { CTLineGetOffsetForStringIndex(line, range.location + $0, nil) }
            for (left, right) in zip(offsets, offsets.dropFirst()) {
                XCTAssertLessThan(left, right, "\(language): @all must read left to right inside the RTL paragraph")
            }
        }
    }
}

private extension Bundle {
    // Unhosted XCTest resources live in the test bundle, rather than the runner.
    @objc func allMentionTestResourcePath(_ name: String?, ofType type: String?) -> String? {
        if self == getAppBundle(), (name == "PresentationStrings" && type == "data") || type == "lproj" {
            return Bundle(for: AllMentionLocalizationTests.self).allMentionTestResourcePath(name, ofType: type)
        }
        return self.allMentionTestResourcePath(name, ofType: type)
    }
}
