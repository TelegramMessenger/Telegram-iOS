import Foundation

/// The track a profile's music strip shows: the first of the profile's saved-music list (`list`, nil where the screen
/// has none). While that list has not answered (loading with nothing in it, before its cache or the server replies:
/// a profile opened for the first time), the full user's track (`CachedUserData.savedMusic`), which the chat has usually
/// fetched already, so the strip is in the profile's first layout and arrives with the transition instead of after it.
/// A list that answered empty shows none, whatever the full user still says.
public func peerInfoProfileMusic<File>(list: (files: [File], isLoading: Bool)?, fullUserMusic: File?) -> File? {
    guard let list else {
        return fullUserMusic
    }
    if let first = list.files.first {
        return first
    }
    return list.isLoading ? fullUserMusic : nil
}
