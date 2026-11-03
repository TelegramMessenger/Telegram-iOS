import XCTest
import UIKit
import Display
import PeerInfoPaneNode

final class PeerInfoNavigationButtonSetsTests: XCTestCase {
    private func sets(_ configure: (inout PeerInfoNavigationFlags) -> Void) -> (normal: PeerInfoNavigationButtonSet, expanded: PeerInfoNavigationButtonSet) {
        var flags = PeerInfoNavigationFlags()
        configure(&flags)
        return peerInfoNavigationButtonSets(flags)
    }

    func test_profile_editable_andNot() {
        XCTAssertEqual(self.sets({ $0.canEdit = true }).normal, PeerInfoNavigationButtonSet(left: [], right: [.edit]))
        XCTAssertEqual(self.sets({ _ in }).normal, PeerInfoNavigationButtonSet(left: [], right: []))
    }

    func test_channelThatPostsStories_andMyProfile() {
        XCTAssertEqual(self.sets({ $0.canEdit = true; $0.channelCanPostStories = true }).normal.right, [.postStory, .edit])
        XCTAssertEqual(self.sets({ $0.channelCanPostStories = true }).normal.right, [.postStory])
        XCTAssertEqual(self.sets({ $0.isMyProfile = true }).normal.right, [.postStory, .edit])
    }

    func test_settings() {
        XCTAssertEqual(self.sets({ $0.isSettings = true }).normal, PeerInfoNavigationButtonSet(left: [.qrCode], right: [.search, .edit]))
    }

    func test_editing_hasNoPaneSet() {
        let sets = self.sets({ $0.isEditing = true; $0.isSettings = true; $0.paneKey = .media })
        XCTAssertEqual(sets.normal, PeerInfoNavigationButtonSet(left: [.cancel], right: [.done]))
        XCTAssertEqual(sets.expanded, PeerInfoNavigationButtonSet(left: [], right: []))
    }

    func test_paneSets() {
        let table: [(PeerInfoPaneKey, (inout PeerInfoNavigationFlags) -> Void, [PeerInfoHeaderNavigationButtonKey])] = [
            (.files, { _ in }, [.search]), (.music, { _ in }, [.search]), (.links, { _ in }, [.search]), (.members, { _ in }, [.search]),
            (.savedMessagesChats, { _ in }, [.standaloneSearch, .more]),
            (.savedMessagesChats, { $0.hasSavedMessageTags = true }, [.searchWithTags, .more]),
            (.savedMessages, { _ in }, [.search]),
            (.savedMessages, { $0.hasSavedMessageTags = true }, [.searchWithTags]),
            (.media, { _ in }, [.more]),
            (.botPreview, { _ in }, []), (.botPreview, { $0.canEditBotPreviews = true }, [.more]),
            (.stories, { _ in }, []), (.stories, { $0.isOwnStories = true }, [.more]),
            (.gifts, { _ in }, [.sort]),
            (.voice, { _ in }, []), (.gifs, { _ in }, []), (.groupsInCommon, { _ in }, [])
        ]
        for (paneKey, configure, expected) in table {
            let sets = self.sets({ $0.paneKey = paneKey; configure(&$0) })
            XCTAssertEqual(sets.expanded, PeerInfoNavigationButtonSet(left: [], right: expected), "\(paneKey)")
        }
    }

    func test_selectingOrReordering_paneSetIsDone() {
        XCTAssertEqual(self.sets({ $0.paneKey = .media; $0.isSelectingOrReordering = true }).expanded.right, [.selectionDone])
        XCTAssertEqual(self.sets({ $0.isSelectingOrReordering = true }).expanded.right, [.selectionDone])
    }

    // The more/search/sort slot is one item: no set may show two of its keys.
    func test_noSetHoldsTwoSlotKeys() {
        let panes: [PeerInfoPaneKey?] = [nil, .botPreview, .members, .stories, .gifts, .media, .savedMessagesChats, .savedMessages, .files, .music, .voice, .links, .gifs, .polls, .groupsInCommon, .similarChannels, .similarBots, .storyArchive]
        for paneKey in panes {
            for bits in 0 ..< 64 {
                let sets = self.sets({
                    $0.paneKey = paneKey
                    $0.isSettings = bits & 1 != 0
                    $0.hasSavedMessageTags = bits & 2 != 0
                    $0.canEditBotPreviews = bits & 4 != 0
                    $0.isOwnStories = bits & 8 != 0
                    $0.isMyProfile = bits & 16 != 0
                    $0.isSelectingOrReordering = bits & 32 != 0
                })
                for set in [sets.normal, sets.expanded] {
                    XCTAssertLessThanOrEqual((set.left + set.right).filter(peerInfoNavigationKeyUsesSlot).count, 1, "\(String(describing: paneKey)) \(bits)")
                }
            }
        }
    }
}

final class PeerInfoPaneSetLatchTests: XCTestCase {
    func test_entersWhenTheTabsPin() {
        var latch = PeerInfoPaneSetLatch()
        for fraction: CGFloat in [0.0, 0.5, 0.99] {
            XCTAssertFalse(latch.update(fraction: fraction))
        }
        XCTAssertTrue(latch.update(fraction: 1.0))
    }

    func test_holdsBetween_leavesBelowHalf() {
        var latch = PeerInfoPaneSetLatch()
        _ = latch.update(fraction: 1.0)
        XCTAssertTrue(latch.update(fraction: 0.9))
        XCTAssertTrue(latch.update(fraction: 0.5))
        XCTAssertFalse(latch.update(fraction: 0.49))
        XCTAssertFalse(latch.update(fraction: 0.9))
        XCTAssertTrue(latch.update(fraction: 1.0))
    }

    // A finger resting at either threshold does not flicker the row.
    func test_restingAtAThreshold_doesNotFlicker() {
        var latch = PeerInfoPaneSetLatch()
        var changes = 0
        var previous = latch.isExpanded
        for fraction: CGFloat in [1.0, 0.999, 1.0, 0.999, 1.0, 0.5, 0.5001, 0.5, 0.5001] {
            let value = latch.update(fraction: fraction)
            if value != previous {
                changes += 1
                previous = value
            }
        }
        XCTAssertEqual(changes, 1)
    }
}

final class PeerInfoNavigationThemeTests: XCTestCase {
    private func base(dark: Bool) -> NavigationBarTheme {
        return NavigationBarTheme(overallDarkAppearance: dark, buttonColor: .gray, disabledButtonColor: .lightGray, primaryTextColor: .black, badgeBackgroundColor: .red, badgeTextColor: .white, edgeEffectColor: .white, accentButtonColor: .blue, accentDisabledButtonColor: .darkGray, accentForegroundColor: .white)
    }

    func test_plain_isTheBaseWithoutAnEdgeEffect() {
        let theme = peerInfoNavigationBarTheme(glass: .plain, base: self.base(dark: false))
        XCTAssertEqual(theme.buttonColor, .gray)
        XCTAssertNil(theme.glassTintColor)
        XCTAssertEqual(theme.edgeEffectColor, UIColor.clear)
        XCTAssertEqual(theme.accentButtonColor, .blue)
    }

    func test_tinted_isWhiteOnTheTint() {
        let theme = peerInfoNavigationBarTheme(glass: .tinted(.orange), base: self.base(dark: false))
        XCTAssertEqual(theme.buttonColor, .white)
        XCTAssertEqual(theme.glassTintColor, UIColor.orange)
        XCTAssertEqual(theme.edgeEffectColor, UIColor.clear)
    }

    func test_theme_keepsTheBasesAppearance() {
        let base = self.base(dark: true)
        for glass in [PeerInfoNavigationGlass.plain, .tinted(.orange)] {
            let theme = peerInfoNavigationBarTheme(glass: glass, base: base)
            XCTAssertTrue(theme.overallDarkAppearance)
            XCTAssertEqual(theme.accentForegroundColor, base.accentForegroundColor)
            XCTAssertEqual(theme.badgeBackgroundColor, base.badgeBackgroundColor)
            XCTAssertEqual(theme.glassStyle, base.glassStyle)
        }
    }
}

final class PeerInfoNavigationRowCountTests: XCTestCase {
    func test_iconsInTheColumnLeaveTheRow() {
        XCTAssertEqual(peerInfoNavigationRowButtonCount([.postStory, .edit], iconsInSideColumn: false), 2)
        XCTAssertEqual(peerInfoNavigationRowButtonCount([.postStory, .edit], iconsInSideColumn: true), 1)
        XCTAssertEqual(peerInfoNavigationRowButtonCount([.search, .more], iconsInSideColumn: true), 0)
    }
}
