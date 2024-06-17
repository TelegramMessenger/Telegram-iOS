import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import ContextUI
import ChatPresentationInterfaceState
import AccountContext
import TelegramPresentationData
import WebsiteType

private enum OptionsId: Hashable {
    case link
}

func presentLinkOptionsController(context: AccountContext, selfController: CreateLinkScreen, snapshotImage: UIImage?, isDark: Bool, sourceNode: ASDisplayNode, url: String, name: String, positionBelowText: Bool, largeMedia: Bool?, webPage: TelegramMediaWebpage, completion: @escaping (Bool, Bool?) -> Void, remove: @escaping () -> Void) {
    var sources: [ContextController.Source] = []
    
    if let source = linkOptions(context: context, selfController: selfController, snapshotImage: snapshotImage, isDark: isDark, sourceNode: sourceNode, url: url, text: name, positionBelowText: positionBelowText, largeMedia: largeMedia, webPage: webPage, completion: completion, remove: remove) {
        sources.append(source)
    }
    if sources.isEmpty {
        return
    }
        
    let contextController = ContextController(
        presentationData: context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkColorPresentationTheme),
        configuration: ContextController.Configuration(
            sources: sources,
            initialId: AnyHashable(OptionsId.link)
        )
    )
    selfController.presentInGlobalOverlay(contextController)
}

private func linkOptions(context: AccountContext, selfController: CreateLinkScreen, snapshotImage: UIImage?, isDark: Bool, sourceNode: ASDisplayNode, url: String, text: String, positionBelowText: Bool, largeMedia: Bool?, webPage: TelegramMediaWebpage, completion: @escaping (Bool, Bool?) -> Void, remove: @escaping () -> Void) -> ContextController.Source? {
    let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1))
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkColorPresentationTheme)
    
    let initialUrlPreview = ChatPresentationInterfaceState.UrlPreview(url: url, webPage: webPage, positionBelowText: positionBelowText, largeMedia: largeMedia)
    let urlPreview = ValuePromise<ChatPresentationInterfaceState.UrlPreview>(initialUrlPreview)
    
    let linkOptions = urlPreview.get()
    |> deliverOnMainQueue
    |> map { urlPreview -> ChatControllerSubject.LinkOptions in
        var webpageHasLargeMedia = false
        if case let .Loaded(content) = webPage.content {
            if let isMediaLargeByDefault = content.isMediaLargeByDefault {
                if isMediaLargeByDefault {
                    webpageHasLargeMedia = true
                }
            } else {
                webpageHasLargeMedia = true
            }
        }
        

        let entities = [MessageTextEntity(range: 0 ..< (text as NSString).length, type: .Url)]
      
        var largeMedia = false
        if webpageHasLargeMedia {
            if let value = urlPreview.largeMedia {
                largeMedia = value
            } else if case .Loaded = webPage.content {
                largeMedia = false //!defaultWebpageImageSizeIsSmall(webpage: content)
            } else {
                largeMedia = true
            }
        } else {
            largeMedia = false
        }
        
        return ChatControllerSubject.LinkOptions(
            messageText: text,
            messageEntities: entities,
            hasAlternativeLinks: false,
            replyMessageId: nil,
            replyQuote: nil,
            url: urlPreview.url,
            webpage: urlPreview.webPage,
            linkBelowText: urlPreview.positionBelowText,
            largeMedia: largeMedia
        )
    }
    |> distinctUntilChanged
    
    let wallpaper: TelegramWallpaper?
    if let image = snapshotImage {
        let wallpaperResource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
        if let wallpaperData = image.jpegData(compressionQuality: 0.87) {
            context.account.postbox.mediaBox.storeResourceData(wallpaperResource.id, data: wallpaperData, synchronous: true)
        }
        let wallpaperRepresentation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(image.size), resource: wallpaperResource, progressiveSizes: [], immediateThumbnailData: nil)
        wallpaper = .image([wallpaperRepresentation], WallpaperSettings())
    } else {
        wallpaper = nil
    }
    
    let chatController = context.sharedContext.makeChatController(
        context: context,
        chatLocation: .peer(id: peerId),
        subject: .messageOptions(peerIds: [peerId], ids: [], info: .link(ChatControllerSubject.MessageOptionsInfo.Link(options: linkOptions, isCentered: true))),
        botStart: nil,
        mode: .standard(.previewing),
        params: ChatControllerParams(
            forcedTheme: isDark ? defaultDarkColorPresentationTheme : defaultPresentationTheme,
            forcedNavigationBarTheme: defaultDarkColorPresentationTheme,
            forcedWallpaper: wallpaper
        )
    )
    chatController.canReadHistory.set(false)
    
    let items = linkOptions
    |> deliverOnMainQueue
    |> map { linkOptions -> ContextController.Items in
        var items: [ContextMenuItem] = []
        
        do {
            items.append(.action(ContextMenuActionItem(text: linkOptions.linkBelowText ? presentationData.strings.Conversation_MessageOptionsLinkMoveUp : presentationData.strings.Conversation_MessageOptionsLinkMoveDown, icon: { theme in
                return nil
            }, iconAnimation: ContextMenuActionItem.IconAnimation(
                name: linkOptions.linkBelowText ? "message_preview_sort_above" : "message_preview_sort_below"
            ), action: { _, f in
                let _ = (urlPreview.get()
                |> take(1)).start(next: { current in
                    var updatedUrlPreview = current
                    updatedUrlPreview.positionBelowText = !current.positionBelowText
                    urlPreview.set(updatedUrlPreview)
                })
            })))
        }
        
        if case let .Loaded(content) = linkOptions.webpage.content, let isMediaLargeByDefault = content.isMediaLargeByDefault, isMediaLargeByDefault {
            let shrinkTitle: String
            let enlargeTitle: String
            if let file = content.file, file.isVideo {
                shrinkTitle = presentationData.strings.Conversation_MessageOptionsShrinkVideo
                enlargeTitle = presentationData.strings.Conversation_MessageOptionsEnlargeVideo
            } else {
                shrinkTitle = presentationData.strings.Conversation_MessageOptionsShrinkImage
                enlargeTitle = presentationData.strings.Conversation_MessageOptionsEnlargeImage
            }
            
            items.append(.action(ContextMenuActionItem(text: linkOptions.largeMedia ? shrinkTitle : enlargeTitle, icon: { _ in
                return nil
            }, iconAnimation: ContextMenuActionItem.IconAnimation(
                name: !linkOptions.largeMedia ? "message_preview_media_large" : "message_preview_media_small"
            ), action: { _, f in
                let _ = (urlPreview.get()
                |> take(1)).start(next: { current in
                    var updatedUrlPreview = current
                    if let largeMedia = current.largeMedia {
                        updatedUrlPreview.largeMedia = !largeMedia
                    } else {
                        updatedUrlPreview.largeMedia = false
                    }
                    urlPreview.set(updatedUrlPreview)
                })
            })))
        }
        
        if !items.isEmpty {
            items.append(.separator)
        }
        
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_MessageOptionsApplyChanges, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Select"), color: theme.contextMenu.primaryColor) }, action: { _, f in
            f(.default)
            
            let _ = (urlPreview.get()
            |> take(1)).start(next: { current in
                completion(current.positionBelowText, current.largeMedia)
            })
        })))
        
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_LinkOptionsCancel, textColor: .destructive, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { _, f in
            remove()
                        
            f(.default)
        })))
        
        return ContextController.Items(id: AnyHashable(linkOptions.url), content: .list(items))
    }
        
    return ContextController.Source(
        id: AnyHashable(OptionsId.link),
        title: presentationData.strings.Conversation_MessageOptionsTabLink,
        source: .controller(ChatContextControllerContentSourceImpl(controller: chatController, sourceNode: sourceNode, passthroughTouches: true)),
        items: items
    )
}

final class ChatContextControllerContentSourceImpl: ContextControllerContentSource {
    let controller: ViewController
    weak var sourceNode: ASDisplayNode?
    weak var sourceView: UIView?
    let sourceRect: CGRect?
    
    let navigationController: NavigationController? = nil

    let passthroughTouches: Bool
    
    init(controller: ViewController, sourceNode: ASDisplayNode?, sourceRect: CGRect? = nil, passthroughTouches: Bool) {
        self.controller = controller
        self.sourceNode = sourceNode
        self.sourceRect = sourceRect
        self.passthroughTouches = passthroughTouches
    }
    
    init(controller: ViewController, sourceView: UIView?, sourceRect: CGRect? = nil, passthroughTouches: Bool) {
        self.controller = controller
        self.sourceView = sourceView
        self.sourceRect = sourceRect
        self.passthroughTouches = passthroughTouches
    }
    
    func transitionInfo() -> ContextControllerTakeControllerInfo? {
        let sourceView = self.sourceView
        let sourceNode = self.sourceNode
        let sourceRect = self.sourceRect
        return ContextControllerTakeControllerInfo(contentAreaInScreenSpace: CGRect(origin: CGPoint(), size: CGSize(width: 10.0, height: 10.0)), sourceNode: { [weak sourceNode] in
            if let sourceView = sourceView {
                return (sourceView, sourceRect ?? sourceView.bounds)
            } else if let sourceNode = sourceNode {
                return (sourceNode.view, sourceRect ?? sourceNode.bounds)
            } else {
                return nil
            }
        })
    }
    
    func animatedIn() {
    }
}
