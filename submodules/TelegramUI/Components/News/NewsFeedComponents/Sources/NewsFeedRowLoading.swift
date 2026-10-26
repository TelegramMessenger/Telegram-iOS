import Foundation

/// Whether the post rows a list is building right now load their avatar on the main thread. The list's own
/// pass (new content, a programmatic scroll) builds rows that are on screen at once, so they load
/// synchronously. A row a scroll builds is built ahead of the viewport, so it loads in the background rather
/// than inside the scroll frame. The list sets this around its passes; a row reads it when it is updated.
public final class NewsFeedRowLoading {
    public var isSynchronous = false

    public init() {
    }
}
