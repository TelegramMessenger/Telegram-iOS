import Foundation
import XCTest
import UrlWhitelist

final class UrlWhitelistTests: XCTestCase {
    // Each of these opens evil.org while reading as a link to telegram.org or t.me.
    func testLoginPartInFrontOfTheHostIsDetected() {
        let urls = [
            "https://telegram.org\u{2215}test\u{2215}@evil.org", // U+2215 DIVISION SLASH is not a slash
            "https://telegram.org\u{2044}test\u{2044}@evil.org", // U+2044 FRACTION SLASH is not a slash
            "https://telegram.org@evil.org",
            "https://telegram.org:443@evil.org",
            "HTTPS://t.me@evil.org",
            // No scheme: the opener supplies "http://", so these still open evil.org.
            "telegram.org\u{2215}test\u{2215}@evil.org",
            "telegram.org:443@evil.org",
            // The resolver recognises "tel:" and "mailto:" only in lower case and supplies "http://" otherwise,
            // so these reach the opener as web addresses with a login part (the opener matches "mailto:" in
            // lower case too, so the second is one even unresolved).
            "http://TEL:t.me:443@evil.org",
            "Mailto:telegram.org@evil.org",
        ]
        for url in urls {
            let loginPartUrl = externalUrlWithLoginPart(url)
            XCTAssertNotNil(loginPartUrl, url)
            XCTAssertEqual(loginPartUrl?.host, "evil.org", url)
        }
    }

    func testAtSignOutsideTheAuthorityIsNotALoginPart() {
        let urls = [
            "https://telegram.org/test/@evil.org", // a real slash ends the authority first
            "https://example.com/?q=user@example.com",
            "https://example.com/#user@example.com",
            "https://example.com#@evil.org",
            "mailto:user@example.com",
            "tel:+123456789",
            // The opener dials any "tel:" link, in any case, before parsing it as a web address.
            "tel:t.me:443@evil.org",
            "TEL:t.me:443@evil.org",
            "calshow:t.me@evil.org",
            "tg://resolve?domain=durov",
            "t.me/durov",
            "https://evil.org",
        ]
        for url in urls {
            XCTAssertNil(externalUrlWithLoginPart(url), url)
        }
    }

    // The check must report a login part whenever the opener's own parse of an address it opens as a web
    // address has one.
    func testCheckAgreesWithTheOpenersParse() {
        let urls = [
            "https://telegram.org\u{2215}test\u{2215}@evil.org",
            "https://telegram.org@evil.org",
            "telegram.org:443@evil.org",
            "http://TEL:t.me:443@evil.org",
            "Mailto:telegram.org@evil.org",
            "https://example.com/#user@example.com",
            "https://evil.org",
        ]
        for url in urls {
            guard let opened = canonicalExternalUrl(from: url) else {
                XCTFail(url)
                continue
            }
            let openerSeesLoginPart = opened.user != nil || opened.password != nil
            XCTAssertEqual(externalUrlWithLoginPart(url) != nil, openerSeesLoginPart, url)
            XCTAssertEqual(externalUrlWithLoginPart(url)?.host, openerSeesLoginPart ? opened.host : nil, url)
        }
    }

    // The prompt shows the address with the login part removed, which is the address that opens.
    func testRemovingTheLoginPartKeepsTheRestOfTheAddress() {
        let cases: [(String, String)] = [
            ("https://telegram.org\u{2215}test\u{2215}@evil.org", "https://evil.org"),
            ("https://t.me:durov@evil.org/login?next=1#top", "https://evil.org/login?next=1#top"),
            ("telegram.org:443@evil.org/path", "http://evil.org/path"),
        ]
        for (url, shown) in cases {
            guard let loginPartUrl = externalUrlWithLoginPart(url) else {
                XCTFail(url)
                continue
            }
            XCTAssertEqual(urlRemovingLoginPart(loginPartUrl).absoluteString, shown, url)
        }
    }

    // Menus and prompts that name a link show where it really goes, and leave every other link's text alone.
    func testDisplayUrlRevealsOnlyALoginPart() {
        XCTAssertEqual(displayUrlRevealingLoginPart("https://telegram.org\u{2215}test\u{2215}@evil.org"), "https://evil.org")
        XCTAssertEqual(displayUrlRevealingLoginPart("https://t.me@evil.org/login"), "https://evil.org/login")
        XCTAssertNil(displayUrlRevealingLoginPart("https://telegram.org/test/@evil.org"))
        XCTAssertNil(displayUrlRevealingLoginPart("mailto:user@example.com"))
        XCTAssertNil(displayUrlRevealingLoginPart("#section"))
    }

    // An accepted prompt lets exactly one following open of the same address through without asking again.
    func testAcceptedConfirmationIsConsumedOnce() {
        guard let accepted = externalUrlWithLoginPart("https://telegram.org@confirmed.example"),
              let other = externalUrlWithLoginPart("https://t.me@confirmed.example") else {
            XCTFail()
            return
        }
        XCTAssertFalse(consumeLoginPartConfirmation(accepted))

        noteLoginPartConfirmed(accepted)
        XCTAssertFalse(consumeLoginPartConfirmation(other))
        XCTAssertTrue(consumeLoginPartConfirmation(accepted))
        XCTAssertFalse(consumeLoginPartConfirmation(accepted))
    }

    // `parseUrl`'s flag also picks a shared-links list title: a concealed link is titled with its whole
    // address, any other with its host. A link with a login part must keep its real host there, so the
    // login-part check belongs to the open confirmation, not to `parseUrl`.
    func testParseUrlKeepsTheRealHostForALinkWithALoginPart() {
        let url = "https://telegram.org\u{2215}test\u{2215}@evil.org"
        let (displayUrl, concealed) = parseUrl(url: url, wasConcealed: false)
        XCTAssertFalse(concealed)
        XCTAssertEqual(URL(string: displayUrl)?.host, "evil.org")
    }
}
