import Foundation
import Display
import Postbox
import SwiftSignalKit
import AccountContext
import TelegramCore
import TelegramUIPreferences
import GalleryUI
import LocationUI

/// Routes a media tap (originating from V1's full-page Instant View, or from V2's in-bubble preview)
/// to the appropriate viewer:
///   - `.geo(map)` → pushes `LocationViewController` via `push`.
///   - `.webpage(webPage)` cover → single-entry `InstantPageGalleryController`.
///   - `.file(file)` with `isAnimated` → single-entry gallery in "playing video" mode.
///   - Default → multi-entry gallery built from `allMedias` (filtered to `.image` and non-audio
///     `.file` — audio/music siblings are excluded), centered on the tapped media; "playing
///     video" mode is on.
///
/// Behavior matches V1's `InstantPageControllerNode.openMedia(_:)` bit-for-bit.
///
/// - Parameters:
///   - allMedias: every laid-out media on the page, in laid-out order. Used to build sibling
///     entries when the gallery needs them. Callers may pass `[]` for paths that don't need
///     siblings (e.g. webpage-cover single-entry gallery), but it's safer to always pass the
///     full list — the helper filters/uses it only on the default branch.
///   - transitionArgsForMedia: invoked by the gallery presentation to find the source rect for
///     the swipe-back animation; return `nil` if the source view is not on screen.
///   - hiddenMediaCallback: invoked while the gallery is foregrounded so callers can hide the
///     source so the gallery's transitioning image isn't double-visible.
///   - captureProtected: open a SECURE gallery — screenshot-excluded content, no share/save. Passed
///     through by the chat bubble for a copy-protected rich message; defaults to `false` for V1
///     Instant View and web IV, whose pages are public web content.
public func openInstantPageMedia(
    media: InstantPageMedia,
    allMedias: [InstantPageMedia],
    webPage: TelegramMediaWebpage,
    context: AccountContext,
    userLocation: MediaResourceUserLocation,
    captureProtected: Bool = false,
    present: (ViewController, Any?) -> Void,
    push: (ViewController) -> Void,
    openUrl: @escaping (InstantPageUrlItem) -> Void,
    baseNavigationController: () -> NavigationController?,
    transitionArgsForMedia: @escaping (InstantPageMedia) -> GalleryTransitionArguments?,
    hiddenMediaCallback: @escaping (InstantPageMedia?) -> Void
) {
    if case let .geo(map) = media.media {
        let controllerParams = LocationViewParams(sendLiveLocation: { _ in
        }, stopLiveLocation: { _ in
        }, openUrl: { _ in }, openPeer: { _ in
        }, showAll: false)

        let peer = TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(0)), accessHash: nil, firstName: "", lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
        let message = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: 0, id: 0), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: peer, text: "", attributes: [], media: [map], peers: SimpleDictionary(), associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])

        let controller = LocationViewController(context: context, subject: EngineMessage(message), params: controllerParams)
        push(controller)
        return
    }

    var fromPlayingVideo = false

    var entries: [InstantPageGalleryEntry] = []
    if case let .webpage(webPage) = media.media {
        entries.append(InstantPageGalleryEntry(index: 0, pageId: webPage.webpageId, media: media, caption: nil, credit: nil, location: nil))
    } else if case let .file(file) = media.media, file.isAnimated {
        fromPlayingVideo = true
        entries.append(InstantPageGalleryEntry(index: Int32(media.index), pageId: webPage.webpageId, media: media, caption: media.caption, credit: media.credit, location: nil))
    } else {
        fromPlayingVideo = true
        let filteredMedias = allMedias.filter { item in
            switch item.media {
            case .image:
                return true
            case let .file(file):
                // Audio/music files are enrolled in `allMedias()` only so the audio playlist can
                // gather its siblings (see `handleOpenAudioTap`); they are not visual gallery
                // content, so keep videos/gifs/documents but exclude music and voice.
                return !file.isMusic && !file.isVoice
            default:
                return false
            }
        }

        for media in filteredMedias {
            entries.append(InstantPageGalleryEntry(index: Int32(media.index), pageId: webPage.webpageId, media: media, caption: media.caption, credit: media.credit, location: InstantPageGalleryEntryLocation(position: Int32(entries.count), totalCount: Int32(filteredMedias.count))))
        }
    }

    var centralIndex: Int?
    for i in 0 ..< entries.count {
        if entries[i].media == media {
            centralIndex = i
            break
        }
    }
    if centralIndex == nil {
        // `media` is the value the TAPPED view holds, and `entries` come from the CURRENT layout, so
        // a strict `==` here means every field of `InstantPageMedia` (caption, credit, url, and a
        // deep media compare) has to still agree. When it doesn't, this function returns having done
        // nothing at all — the tap is swallowed with no gallery, no error and no visible state, and
        // it stays that way until the item view is rebuilt. That is too sharp an edge for a
        // presentation lookup, so fall back to the identity notion the REST of the pipeline already
        // uses for exactly this cross-reference: `transitionNode` and `updateHiddenMedia` both match
        // on `instantPageMediaMatchesNodeIdentity`, which keeps the index/url/caption/credit checks
        // but compares the media itself by id instead of deeply.
        for i in 0 ..< entries.count {
            if instantPageMediaMatchesNodeIdentity(entries[i].media, media) {
                centralIndex = i
                break
            }
        }
    }

    if let centralIndex = centralIndex {
        let controller = InstantPageGalleryController(context: context, userLocation: userLocation, webPage: webPage, entries: entries, centralIndex: centralIndex, fromPlayingVideo: fromPlayingVideo, captureProtected: captureProtected, replaceRootController: { _, _ in
        }, baseNavigationController: baseNavigationController())
        let hiddenMediaDisposable = MetaDisposable()
        hiddenMediaDisposable.set((controller.hiddenMedia |> deliverOnMainQueue).start(next: { entry in
            hiddenMediaCallback(entry?.media)
        }))
        controller.openUrl = openUrl

        // The disposable lives as long as the gallery controller. Bind its lifetime to the
        // controller by attaching it as an associated object so it survives until dismissal.
        InstantPageMediaOpenDisposableBox.attach(disposable: hiddenMediaDisposable, to: controller)

        present(controller, InstantPageGalleryControllerPresentationArguments(transitionArguments: { entry -> GalleryTransitionArguments? in
            return transitionArgsForMedia(entry.media)
        }))
    }
}

// MARK: - Disposable lifetime helper

/// Holds a `MetaDisposable` that subscribes to the gallery controller's `hiddenMedia` signal.
/// Without this, the disposable would deallocate after `openInstantPageMedia` returns and the
/// subscription would stop firing. We attach it to the gallery controller via objc associated
/// objects so it lives as long as the controller does.
private final class InstantPageMediaOpenDisposableBox {
    private static var key: UInt8 = 0
    let disposable: MetaDisposable
    init(_ disposable: MetaDisposable) { self.disposable = disposable }
    deinit { self.disposable.dispose() }

    static func attach(disposable: MetaDisposable, to controller: ViewController) {
        let box = InstantPageMediaOpenDisposableBox(disposable)
        objc_setAssociatedObject(controller, &key, box, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
