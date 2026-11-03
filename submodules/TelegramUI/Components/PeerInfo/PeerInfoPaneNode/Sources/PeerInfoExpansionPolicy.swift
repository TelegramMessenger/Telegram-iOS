import Foundation
import UIKit

/// Which way a profile arrives in an expansion: out of the chat's pill onto its avatar, or onto its expanded photo.
public enum PeerInfoExpansionPathKind: Equatable {
    case origin
    case photo
}

/// Whether the profile expands out of the chat (a profile opened from a chat's header, scrolled at most 8 pt, not
/// Settings, not editing or searching; everything else slides).
public func peerInfoExpansionAllowed(isOpenedFromChat: Bool, isSettings: Bool, scrollOffset: CGFloat, isEditing: Bool, isSearching: Bool) -> Bool {
    return isOpenedFromChat && !isSettings && !isEditing && !isSearching && scrollOffset <= 8.0
}

public func peerInfoExpansionPath(isAvatarExpanded: Bool) -> PeerInfoExpansionPathKind {
    return isAvatarExpanded ? .photo : .origin
}
