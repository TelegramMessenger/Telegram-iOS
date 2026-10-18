import Foundation
import UIKit
import Display

/// The profile's navigation buttons (spec 2026-10-16-peer-info-navigation-bar-design.md). `.back` is the bar's own
/// now; `.select`, `.editPhoto` and `.editVideo` are produced by no set.
public enum PeerInfoHeaderNavigationButtonKey {
    case back
    case edit
    case done
    case cancel
    case select
    case selectionDone
    case search
    case searchWithTags
    case standaloneSearch
    case editPhoto
    case editVideo
    case more
    case sort
    case qrCode
    case moreSearchSort
    case postStory
}

/// iPhone Duo: whether a navigation button is an icon (it goes into the side column); text buttons stay in the row
/// (Apple: text-only items stay horizontal).
public func peerInfoNavigationButtonIsIcon(_ key: PeerInfoHeaderNavigationButtonKey) -> Bool {
    switch key {
    case .back, .qrCode, .search, .searchWithTags, .standaloneSearch, .more, .sort, .moreSearchSort, .postStory:
        return true
    case .edit, .done, .cancel, .select, .selectionDone, .editPhoto, .editVideo:
        return false
    }
}

/// Whether a key is drawn by the one more/search/sort item, whose icon animates between the three.
public func peerInfoNavigationKeyUsesSlot(_ key: PeerInfoHeaderNavigationButtonKey) -> Bool {
    switch key {
    case .more, .search, .sort, .moreSearchSort:
        return true
    default:
        return false
    }
}

/// One set of the profile's bar buttons. `right` is listed leftmost first, as the profile has always listed it.
public struct PeerInfoNavigationButtonSet: Equatable {
    public var left: [PeerInfoHeaderNavigationButtonKey]
    public var right: [PeerInfoHeaderNavigationButtonKey]

    public init(left: [PeerInfoHeaderNavigationButtonKey], right: [PeerInfoHeaderNavigationButtonKey]) {
        self.left = left
        self.right = right
    }
}

/// What the button sets depend on.
public struct PeerInfoNavigationFlags: Equatable {
    public var isEditing = false
    public var isSettings = false
    public var isMyProfile = false
    /// `peerInfoCanEdit(...)`.
    public var canEdit = false
    /// A channel the account may post stories to (and Premium allows it).
    public var channelCanPostStories = false
    /// The shared-media pane shown, if any.
    public var paneKey: PeerInfoPaneKey?
    /// Messages or stories selected, or a pane reordering.
    public var isSelectingOrReordering = false
    public var hasSavedMessageTags = false
    /// A bot whose previews the account may edit, with previews to edit.
    public var canEditBotPreviews = false
    /// The stories pane shows the account's own stories.
    public var isOwnStories = false

    public init() {
    }
}

/// The normal set, and the one shown while the shared-media pane fills the screen. Moved from `PeerInfoScreen`'s
/// layout (2026-10-16) without a change of rule.
public func peerInfoNavigationButtonSets(_ flags: PeerInfoNavigationFlags) -> (normal: PeerInfoNavigationButtonSet, expanded: PeerInfoNavigationButtonSet) {
    var normal = PeerInfoNavigationButtonSet(left: [], right: [])
    var expanded = PeerInfoNavigationButtonSet(left: [], right: [])
    if flags.isEditing {
        normal.left.append(.cancel)
        normal.right.append(.done)
        return (normal, expanded)
    }
    if flags.isSettings {
        normal.left.append(.qrCode)
        normal.right.append(.search)
        normal.right.append(.edit)
    } else if flags.isMyProfile || flags.canEdit {
        normal.right.append(.edit)
    }
    if flags.channelCanPostStories || flags.isMyProfile {
        normal.right.insert(.postStory, at: 0)
    }
    if flags.isSelectingOrReordering {
        expanded.right.append(.selectionDone)
    } else if let paneKey = flags.paneKey {
        switch paneKey {
        case .files, .music, .links, .members:
            expanded.right.append(.search)
        case .savedMessagesChats:
            expanded.right.append(flags.hasSavedMessageTags ? .searchWithTags : .standaloneSearch)
            expanded.right.append(.more)
        case .savedMessages:
            expanded.right.append(flags.hasSavedMessageTags ? .searchWithTags : .search)
        case .media:
            expanded.right.append(.more)
        case .botPreview:
            if flags.canEditBotPreviews {
                expanded.right.append(.more)
            }
        case .stories:
            if flags.isOwnStories {
                expanded.right.append(.more)
            }
        case .gifts:
            expanded.right.append(.sort)
        default:
            break
        }
    }
    return (normal, expanded)
}

/// Which set the bar shows, from the pane's expansion (0 → 1 over the 32 pt band; 1 when its tabs pin under the bar).
/// UIKit has no scroll-scrubbed set, so the sets swap at a point (ruling, spec 2026-10-16): into the pane's set when the
/// tabs pin, back once below half the band, so a finger resting at the boundary does not flicker the row.
public struct PeerInfoPaneSetLatch {
    public static let enterFraction: CGFloat = 1.0
    public static let leaveFraction: CGFloat = 0.5

    public private(set) var isExpanded = false

    public init() {
    }

    public mutating func update(fraction: CGFloat) -> Bool {
        if self.isExpanded {
            if fraction < PeerInfoPaneSetLatch.leaveFraction {
                self.isExpanded = false
            }
        } else if fraction >= PeerInfoPaneSetLatch.enterFraction {
            self.isExpanded = true
        }
        return self.isExpanded
    }
}

/// The glass under the profile's buttons: the theme's panel glass, or white glyphs on glass of the header's colour
/// (over a cover colour, or the expanded avatar). It steps at a point, never per scroll frame.
public enum PeerInfoNavigationGlass: Equatable {
    case plain
    case tinted(UIColor)
}

/// The profile bar's theme: `base` (the regular bar's) without an edge effect, its glyphs and glass by `glass`.
public func peerInfoNavigationBarTheme(glass: PeerInfoNavigationGlass, base: NavigationBarTheme) -> NavigationBarTheme {
    let buttonColor: UIColor
    let glassTintColor: UIColor?
    switch glass {
    case .plain:
        buttonColor = base.buttonColor
        glassTintColor = nil
    case let .tinted(color):
        buttonColor = .white
        glassTintColor = color
    }
    return NavigationBarTheme(overallDarkAppearance: base.overallDarkAppearance, buttonColor: buttonColor, disabledButtonColor: base.disabledButtonColor, primaryTextColor: base.primaryTextColor, badgeBackgroundColor: base.badgeBackgroundColor, badgeTextColor: base.badgeTextColor, edgeEffectColor: .clear, accentButtonColor: base.accentButtonColor, accentDisabledButtonColor: base.accentDisabledButtonColor, accentForegroundColor: base.accentForegroundColor, glassStyle: base.glassStyle, glassTintColor: glassTintColor)
}

/// How many of `keys` the row holds: on iPhone Duo the side column takes the icons.
public func peerInfoNavigationRowButtonCount(_ keys: [PeerInfoHeaderNavigationButtonKey], iconsInSideColumn: Bool) -> Int {
    return keys.filter({ !iconsInSideColumn || !peerInfoNavigationButtonIsIcon($0) }).count
}
