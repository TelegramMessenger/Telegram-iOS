import Foundation
import UIKit
import TelegramCore
import MessageWidget

private final class WidgetDebugBundleAnchor {}

/// A resource bundle the DEBUG app carries in its framework (TelegramUI's `data`), nil in release builds.
private func widgetDebugBundleRoot(_ name: String) -> URL? {
    let outer = Bundle(for: WidgetDebugBundleAnchor.self)
    return Bundle(path: outer.bundlePath + "/\(name).bundle")?.resourceURL
}

/// widget-sandbox v0.1.0's conformance set as its test channel posts it (`channel.json`): each widget with its anchors and
/// caption, then its reference pictures. Empty without `WidgetConformance.bundle`.
func widgetConformanceDebugPosts() -> [EngineLocalWidgetPost] {
    guard let root = widgetDebugBundleRoot("WidgetConformance"), let data = try? Data(contentsOf: root.appendingPathComponent("channel.json")), let posts = try? MessageWidgetChannel.posts(fromJSON: data) else {
        return []
    }
    return posts.compactMap { post in
        guard let html = try? String(contentsOf: root.appendingPathComponent(post.widget), encoding: .utf8) else {
            return nil
        }
        let photos = post.photos.compactMap { path -> EngineLocalWidgetPost.Photo? in
            guard let png = try? Data(contentsOf: root.appendingPathComponent(path)), let image = UIImage(data: png)?.cgImage else {
                return nil
            }
            return EngineLocalWidgetPost.Photo(png: png, width: Int32(image.width), height: Int32(image.height))
        }
        // widget-sandbox v0.2.1: the post's message kind and state, so the inserted widget runs with them. Its requests
        // fail (a local message means nothing to the server) and nothing polls it.
        let context = post.message?.kind.context(viewer: nil)
        // widget-sandbox v0.4.0: a widget the client draws its time over is posted without a caption, then with it above.
        return EngineLocalWidgetPost(html: html, width: post.width, height: post.height, caption: post.captionPlacement == .none ? "" : post.caption, photos: photos, isCopy: context?.isCopy ?? false, canQuery: context?.canQuery ?? false, backgroundQuery: context?.backgroundQuery ?? false, chatData: post.message?.chatData.map { Data($0.utf8) }, publicData: post.message?.publicData.map { Data($0.utf8) }, captionAbove: post.captionPlacement == .above)
    }
}

/// widget-sandbox v0.3.0's renderer stress kit (manifest.json and widgets/), nil without `WidgetStress.bundle`.
func widgetStressDebugKitRoot() -> URL? {
    return widgetDebugBundleRoot("WidgetStress")
}

/// The client's game examples (`MessageWidget/Fixtures` 11–14), to play with several fingers: each a widget with auto
/// anchors and its file name as caption. Empty without `WidgetGames.bundle`.
func widgetGamesDebugPosts() -> [EngineLocalWidgetPost] {
    guard let root = widgetDebugBundleRoot("WidgetGames"), let names = try? FileManager.default.contentsOfDirectory(atPath: root.path) else {
        return []
    }
    return names.filter { $0.hasSuffix(".html") }.sorted().compactMap { name in
        guard let html = try? String(contentsOf: root.appendingPathComponent(name), encoding: .utf8) else {
            return nil
        }
        return EngineLocalWidgetPost(html: html, width: 0, height: 0, caption: name, photos: [])
    }
}

