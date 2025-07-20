import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import PassKit
import Lottie
import TelegramUIPreferences
import TelegramPresentationData
import AccountContext
import GalleryUI
import InstantPageUI
import LocationUI
import StickerPackPreviewUI
import PeerAvatarGalleryUI
import PeerInfoUI
import SettingsUI
import AlertUI
import PresentationDataUtils
import ShareController
import UndoUI
import WebsiteType
import GalleryData
import StoryContainerScreen
import WallpaperGalleryScreen
import BrowserUI

func openChatMessageImpl(_ params: OpenChatMessageParams) -> Bool {
    var story: TelegramMediaStory?
    for media in params.message.media {
        if let media = media as? TelegramMediaStory {
            story = media
        } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content, content.story != nil {
            story = content.story
        }
    }
    
    if let story {
        let navigationController = params.navigationController
        let context = params.context
        let storyContent = SingleStoryContentContextImpl(context: params.context, storyId: story.storyId, readGlobally: true)
        let _ = (storyContent.state
        |> take(1)
        |> deliverOnMainQueue).startStandalone(next: { [weak navigationController] _ in
            var transitionIn: StoryContainerScreen.TransitionIn? = nil
            
            var selectedTransitionNode: (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
            selectedTransitionNode = params.transitionNode(params.message.id, story, true)
            
            if let selectedTransitionNode {
                var cornerRadius: CGFloat = 0.0
                if let imageNode = selectedTransitionNode.0 as? TransformImageNode, let currentArguments = imageNode.currentArguments {
                    cornerRadius = currentArguments.corners.topLeft.radius
                }
                transitionIn = StoryContainerScreen.TransitionIn(
                    sourceView: selectedTransitionNode.0.view,
                    sourceRect: selectedTransitionNode.1,
                    sourceCornerRadius: cornerRadius,
                    sourceIsAvatar: false
                )
            }
            
            let hiddenMediaSource = params.context.sharedContext.mediaManager.galleryHiddenMediaManager.addSource(.single(GalleryHiddenMediaId.chat(params.context.account.id, params.message.id, story)))
            
            let storyContainerScreen = StoryContainerScreen(
                context: context,
                content: storyContent,
                transitionIn: transitionIn,
                transitionOut: { _, _ in
                    var transitionOut: StoryContainerScreen.TransitionOut? = nil
                    
                    var selectedTransitionNode: (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
                    selectedTransitionNode = params.transitionNode(params.message.id, story, true)
                    if let selectedTransitionNode {
                        var cornerRadius: CGFloat = 0.0
                        if let imageNode = selectedTransitionNode.0 as? TransformImageNode, let currentArguments = imageNode.currentArguments {
                            cornerRadius = currentArguments.corners.topLeft.radius
                        }
                        
                        transitionOut = StoryContainerScreen.TransitionOut(
                            destinationView: selectedTransitionNode.0.view,
                            transitionView: StoryContainerScreen.TransitionView(
                                makeView: {
                                    let view = UIView()
                                    if let transitionView = selectedTransitionNode.2().0 {
                                        transitionView.layer.anchorPoint = CGPoint()
                                        view.addSubview(transitionView)
                                    }
                                    return view
                                },
                                updateView: { view, state, transition in
                                    guard let view = view.subviews.first else {
                                        return
                                    }
                                    if state.progress == 0.0 {
                                        view.frame = CGRect(origin: CGPoint(), size: state.destinationSize)
                                    }
                                    
                                    let toScaleX = state.sourceSize.width / state.destinationSize.width
                                    let toScaleY = state.sourceSize.height / state.destinationSize.height
                                    let fromScaleX: CGFloat = 1.0
                                    let fromScaleY: CGFloat = 1.0
                                    let scaleX = toScaleX.interpolate(to: fromScaleX, amount: state.progress)
                                    let scaleY = toScaleY.interpolate(to: fromScaleY, amount: state.progress)
                                    transition.setTransform(view: view, transform: CATransform3DMakeScale(scaleX, scaleY, 1.0))
                                },
                                insertCloneTransitionView: { view in
                                    params.addToTransitionSurface(view)
                                }
                            ),
                            destinationRect: selectedTransitionNode.1,
                            destinationCornerRadius: cornerRadius,
                            destinationIsAvatar: false,
                            completed: {
                                params.context.sharedContext.mediaManager.galleryHiddenMediaManager.removeSource(hiddenMediaSource)
                            }
                        )
                    } else {
                        params.context.sharedContext.mediaManager.galleryHiddenMediaManager.removeSource(hiddenMediaSource)
                    }
                    
                    return transitionOut
                }
            )
            navigationController?.pushViewController(storyContainerScreen)
        })
        return true
    }
    
    if let mediaData = chatMessageGalleryControllerData(context: params.context, chatLocation: params.chatLocation, chatFilterTag: params.chatFilterTag, chatLocationContextHolder: params.chatLocationContextHolder, message: params.message, mediaIndex: params.mediaIndex, navigationController: params.navigationController, standalone: params.standalone, reverseMessageGalleryOrder: params.reverseMessageGalleryOrder, mode: params.mode, source: params.gallerySource, synchronousLoad: false, actionInteraction: params.actionInteraction) {
        switch mediaData {
            case let .url(url):
                params.openUrl(url)
                return true
            case let .pass(file):
                let _ = (params.context.account.postbox.mediaBox.resourceData(file.resource, option: .complete(waitUntilFetchStatus: true))
                |> take(1)
                |> deliverOnMainQueue).startStandalone(next: { data in
                    guard let navigationController = params.navigationController else {
                        return
                    }
                    if data.complete, let content = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                        if let pass = try? PKPass(data: content), let controller = PKAddPassesViewController(pass: pass) {
                            if let window = navigationController.view.window {
                                controller.popoverPresentationController?.sourceView = window
                                controller.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: window.bounds.width / 2.0, y: window.bounds.size.height - 1.0), size: CGSize(width: 1.0, height: 1.0))
                                window.rootViewController?.present(controller, animated: true)
                            }
                        }
                    }
                })
                return true
            case let .instantPage(gallery, centralIndex, galleryMedia):
                params.setupTemporaryHiddenMedia(gallery.hiddenMedia |> map { a -> Any? in a }, centralIndex, galleryMedia)
                
                params.dismissInput()
                params.present(gallery, InstantPageGalleryControllerPresentationArguments(transitionArguments: { entry in
                    var selectedTransitionNode: (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
                    if entry.index == centralIndex {
                        selectedTransitionNode = params.transitionNode(params.message.id, galleryMedia, false)
                    }
                    if let selectedTransitionNode = selectedTransitionNode {
                        return GalleryTransitionArguments(transitionNode: selectedTransitionNode, addToTransitionSurface: params.addToTransitionSurface)
                    }
                    return nil
                }), .window(.root))
                return true
            case .map:
                params.dismissInput()
                
                let controllerParams = LocationViewParams(sendLiveLocation: { location in
                    let outMessage: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: location), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                    params.enqueueMessage(outMessage)
                }, stopLiveLocation: { messageId in
                    params.context.liveLocationManager?.cancelLiveLocation(peerId: messageId?.peerId ?? params.message.id.peerId)
                }, openUrl: params.openUrl, openPeer: { peer in
                    params.openPeer(peer._asPeer(), .info(nil))
                }, showAll: params.modal)
                let controller = LocationViewController(context: params.context, updatedPresentationData: params.updatedPresentationData, subject: EngineMessage(params.message), params: controllerParams)
                controller.navigationPresentation = .modal
                params.navigationController?.pushViewController(controller)
                return true
            case let .stickerPack(reference, previewIconFile):
                let controller = StickerPackScreen(context: params.context, updatedPresentationData: params.updatedPresentationData, mainStickerPack: reference, stickerPacks: [reference], previewIconFile: previewIconFile, parentNavigationController: params.navigationController, sendSticker: params.sendSticker, sendEmoji: params.sendEmoji, actionPerformed: { actions in
                    let presentationData = params.context.sharedContext.currentPresentationData.with { $0 }
                    
                    if actions.count > 1, let first = actions.first {
                        if case .add = first.2 {
                            params.navigationController?.presentOverlay(controller: UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: presentationData.strings.EmojiPackActionInfo_AddedTitle, text: presentationData.strings.EmojiPackActionInfo_MultipleAddedText(Int32(actions.count)), undo: false, info: first.0, topItem: first.1.first, context: params.context), elevatedLayout: false, animateInAsReplacement: false, action: { _ in
                                return true
                            }))
                        }
                    } else if let (info, items, action) = actions.first {
                        let isEmoji = info.id.namespace == Namespaces.ItemCollection.CloudEmojiPacks
                        
                        var animateInAsReplacement = false
                        if let navigationController = params.navigationController {
                            for controller in navigationController.overlayControllers {
                                if let controller = controller as? UndoOverlayController {
                                    controller.dismissWithCommitActionAndReplacementAnimation()
                                    animateInAsReplacement = true
                                }
                            }
                        }
                        switch action {
                        case .add:
                            let controller = UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: isEmoji ? presentationData.strings.EmojiPackActionInfo_AddedTitle : presentationData.strings.StickerPackActionInfo_AddedTitle, text: isEmoji ? presentationData.strings.EmojiPackActionInfo_AddedText(info.title).string : presentationData.strings.StickerPackActionInfo_AddedText(info.title).string, undo: false, info: info, topItem: items.first, context: params.context), elevatedLayout: false, animateInAsReplacement: animateInAsReplacement, action: { _ in
                                return true
                            })
                            (params.navigationController?.topViewController as? ViewController)?.present(controller, in: .current)
                        case let .remove(positionInList):
                            let controller = UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: isEmoji ? presentationData.strings.EmojiPackActionInfo_RemovedTitle : presentationData.strings.StickerPackActionInfo_RemovedTitle, text: isEmoji ? presentationData.strings.EmojiPackActionInfo_RemovedText(info.title).string : presentationData.strings.StickerPackActionInfo_RemovedText(info.title).string, undo: true, info: info, topItem: items.first, context: params.context), elevatedLayout: false, animateInAsReplacement: animateInAsReplacement, action: { action in
                                if case .undo = action {
                                    let _ = params.context.engine.stickers.addStickerPackInteractively(info: info, items: items, positionInList: positionInList).startStandalone()
                                }
                                return true
                            })
                            (params.navigationController?.topViewController as? ViewController)?.present(controller, in: .current)
                        }
                    }
                }, getSourceRect: params.getSourceRect)
                params.dismissInput()
                params.present(controller, nil, .window(.root))
                return true
            case let .document(file, immediateShare):
                params.dismissInput()
                let presentationData = params.context.sharedContext.currentPresentationData.with { $0 }
                if immediateShare {
                    let controller = ShareController(context: params.context, subject: .media(.standalone(media: file), nil), immediateExternalShare: true)
                    params.present(controller, nil, .window(.root))
                } else if let rootController = params.navigationController?.view.window?.rootViewController {
                    let proceed = {
                        let canShare = !params.message.isCopyProtected()
                        var useBrowserScreen = false
                        if BrowserScreen.supportedDocumentMimeTypes.contains(file.mimeType) {
                            useBrowserScreen = true
                        } else if let fileName = file.fileName as? NSString, BrowserScreen.supportedDocumentExtensions.contains(fileName.pathExtension.lowercased())  {
                            useBrowserScreen = true
                        }
                        if useBrowserScreen {
                            if let navigationController = params.navigationController, let minimizedContainer = navigationController.minimizedContainer {
                                for controller in minimizedContainer.controllers {
                                    if let controller = controller as? BrowserScreen, controller.subject.fileId == file.fileId {
                                        navigationController.maximizeViewController(controller, animated: true)
                                        return
                                    }
                                }
                            }
                            
                            let subject: BrowserScreen.Subject
                            if file.mimeType == "application/pdf" {
                                subject = .pdfDocument(file: .message(message: MessageReference(params.message), media: file), canShare: canShare)
                            } else {
                                subject = .document(file: .message(message: MessageReference(params.message), media: file), canShare: canShare)
                            }
                            let controller = BrowserScreen(context: params.context, subject: subject)
                            controller.openDocument = { [weak controller] file, canShare in
                                guard let controller else {
                                    return
                                }
                                controller.dismiss()
                                
                                presentDocumentPreviewController(rootController: rootController, theme: presentationData.theme, strings: presentationData.strings, postbox: params.context.account.postbox, file: file, canShare: canShare)
                            }
                            params.navigationController?.pushViewController(controller)
                        } else {
                            presentDocumentPreviewController(rootController: rootController, theme: presentationData.theme, strings: presentationData.strings, postbox: params.context.account.postbox, file: file, canShare: canShare)
                        }
                    }
                    if file.mimeType.contains("image/svg") {
                        let presentationData = params.context.sharedContext.currentPresentationData.with { $0 }
                        params.present(textAlertController(context: params.context, title: nil, text: presentationData.strings.OpenFile_PotentiallyDangerousContentAlert, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.OpenFile_Proceed, action: { proceed() })] ), nil, .window(.root))
                    } else {
                        proceed()
                    }
                }
                return true
            case let .audio(file):
                let location: PeerMessagesPlaylistLocation
                let playerType: MediaManagerPlayerType
                var control = SharedMediaPlayerControlAction.playback(.play)
                if case let .timecode(time) = params.mode {
                    control = .seek(time)
                }
                if (file.isVoice || file.isInstantVideo) && params.message.tags.contains(.voiceOrInstantVideo) {
                    if let playlistLocation = params.playlistLocation {
                        location = playlistLocation
                    } else if params.standalone {
                        location = .recentActions(params.message)
                    } else {
                        location = .messages(chatLocation: params.chatLocation ?? .peer(id: params.message.id.peerId), tagMask: .voiceOrInstantVideo, at: params.message.id)
                    }
                    playerType = .voice
                } else if file.isMusic && params.message.tags.contains(.music) {
                    if let playlistLocation = params.playlistLocation {
                        location = playlistLocation
                    } else if params.standalone {
                        location = .recentActions(params.message)
                    } else {
                        location = .messages(chatLocation: params.chatLocation ?? .peer(id: params.message.id.peerId), tagMask: .music, at: params.message.id)
                    }
                    playerType = .music
                } else {
                    if let playlistLocation = params.playlistLocation {
                        location = playlistLocation
                    } else if params.standalone {
                        location = .recentActions(params.message)
                    } else {
                        location = .singleMessage(params.message.id)
                    }
                    playerType = (file.isVoice || file.isInstantVideo) ? .voice : .file
                }
                params.context.sharedContext.mediaManager.setPlaylist((params.context, PeerMessagesMediaPlaylist(context: params.context, location: location, chatLocationContextHolder: params.chatLocationContextHolder)), type: playerType, control: control)
                return true
            case let .story(storyController):
                params.dismissInput()
                let _ = (storyController
                |> deliverOnMainQueue).startStandalone(next: { storyController in
                    params.navigationController?.pushViewController(storyController)
                })
            case let .gallery(gallery):
                params.dismissInput()
            
                if GalleryController.maybeExpandPIP(context: params.context, messageId: params.message.id) {
                    return true
                }
            
                params.blockInteraction.set(.single(true))
            
                var presentInCurrent = false
                if let channel = params.message.peers[params.message.id.peerId] as? TelegramChannel, case .broadcast = channel.info {
                    if let layout = params.navigationController?.validLayout, case .regular = layout.metrics.widthClass {   
                    } else {
                        presentInCurrent = true
                    }
                }

                let _ = (gallery
                |> deliverOnMainQueue).startStandalone(next: { gallery in
                    params.blockInteraction.set(.single(false))
                    
                    gallery.centralItemUpdated = { messageId in
                        params.centralItemUpdated?(messageId)
                    }
                    
                    let arguments = GalleryControllerPresentationArguments(transitionArguments: { messageId, media in
                        let selectedTransitionNode = params.transitionNode(messageId, media, false)
                        if let selectedTransitionNode = selectedTransitionNode {
                            return GalleryTransitionArguments(transitionNode: selectedTransitionNode, addToTransitionSurface: params.addToTransitionSurface)
                        }
                        return nil
                    })
                    
                    params.present(gallery, arguments, presentInCurrent ? .current : .window(.root))
                })
                return true
            case let .secretGallery(gallery):
                params.dismissInput()
                params.present(gallery, GalleryControllerPresentationArguments(transitionArguments: { messageId, media in
                    let selectedTransitionNode = params.transitionNode(messageId, media, false)
                    if let selectedTransitionNode = selectedTransitionNode {
                        return GalleryTransitionArguments(transitionNode: selectedTransitionNode, addToTransitionSurface: params.addToTransitionSurface)
                    }
                    return nil
                }), .window(.root))
                return true
            case let .other(otherMedia):
                params.dismissInput()
                if let contact = otherMedia as? TelegramMediaContact {
                    let paramsSignal: Signal<(EnginePeer?, Bool), NoError>
                    if let peerId = contact.peerId {
                        paramsSignal = params.context.engine.data.get(
                            TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
                            TelegramEngine.EngineData.Item.Peer.IsContact(id: peerId)
                        )
                    } else {
                        paramsSignal = .single((nil, false))
                    }
                    
                    let _ = (paramsSignal
                    |> deliverOnMainQueue).startStandalone(next: { peer, isContact in
                        let contactData: DeviceContactExtendedData
                        if let vCard = contact.vCardData, let vCardData = vCard.data(using: .utf8), let parsed = DeviceContactExtendedData(vcard: vCardData) {
                            contactData = parsed
                        } else {
                            contactData = DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: contact.firstName, lastName: contact.lastName, phoneNumbers: [DeviceContactPhoneNumberData(label: "_$!<Mobile>!$_", value: contact.phoneNumber)]), middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: "")
                        }
                        let controller = deviceContactInfoController(context: ShareControllerAppAccountContext(context: params.context), environment: ShareControllerAppEnvironment(sharedContext: params.context.sharedContext), updatedPresentationData: params.updatedPresentationData, subject: .vcard(peer?._asPeer(), nil, contactData), completed: nil, cancelled: nil)
                        params.navigationController?.pushViewController(controller)
                    })
                    return true
                }
            case let .chatAvatars(controller, media):
                params.dismissInput()
                params.chatAvatarHiddenMedia(controller.hiddenMedia |> map { value -> MessageId? in
                    if value != nil {
                        return params.message.id
                    } else {
                        return nil
                    }
                }, media)
                
                params.present(controller, AvatarGalleryControllerPresentationArguments(transitionArguments: { entry in
                    if let selectedTransitionNode = params.transitionNode(params.message.id, media, false) {
                        return GalleryTransitionArguments(transitionNode: selectedTransitionNode, addToTransitionSurface: params.addToTransitionSurface)
                    }
                    return nil
                }), .window(.root))
            case let .theme(media):
                params.dismissInput()
                let path = params.context.account.postbox.mediaBox.completedResourcePath(media.resource)
                var previewTheme: PresentationTheme?
                if let path = path, let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe) {
                    previewTheme = makePresentationTheme(data: data)
                }
                
                guard let theme = previewTheme else {
                    return false
                }
                let controller = ThemePreviewController(context: params.context, previewTheme: theme, source: .media(.message(message: MessageReference(params.message), media: media)))
                params.navigationController?.pushViewController(controller)
        }
    }
    return false
}

func makeInstantPageControllerImpl(context: AccountContext, message: Message, sourcePeerType: MediaAutoDownloadPeerType?) -> ViewController? {
    guard let (webpage, anchor) = instantPageAndAnchor(message: message) else {
        return nil
    }
    let sourceLocation = InstantPageSourceLocation(userLocation: .peer(message.id.peerId), peerType: sourcePeerType ?? .channel)
    return makeInstantPageControllerImpl(context: context, webPage: webpage, anchor: anchor, sourceLocation: sourceLocation)
}

func makeInstantPageControllerImpl(context: AccountContext, webPage: TelegramMediaWebpage, anchor: String?, sourceLocation: InstantPageSourceLocation) -> ViewController {
    return BrowserScreen(context: context, subject: .instantPage(webPage: webPage, anchor: anchor, sourceLocation: sourceLocation, preloadedResources: nil))
}

func openChatWallpaperImpl(context: AccountContext, message: Message, present: @escaping (ViewController, Any?) -> Void) {
    for media in message.media {
        if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
            let _ = (context.sharedContext.resolveUrl(context: context, peerId: nil, url: content.url, skipUrlAuth: true)
            |> deliverOnMainQueue).startStandalone(next: { resolvedUrl in
                if case let .wallpaper(parameter) = resolvedUrl {
                    let source: WallpaperListSource
                    switch parameter {
                        case let .slug(slug, options, colors, intensity, rotation):
                            source = .slug(slug, content.file, options, colors, intensity, rotation, message)
                        case let .color(color):
                            source = .wallpaper(.color(color.argb), nil, [], nil, nil, message)
                        case let .gradient(colors, rotation):
                            source = .wallpaper(.gradient(TelegramWallpaper.Gradient(id: nil, colors: colors, settings: WallpaperSettings(rotation: rotation))), nil, [], nil, rotation, message)
                    }
                    
                    let controller = WallpaperGalleryController(context: context, source: source)
                    present(controller, nil)
                }
            })
        }
    }
}

func openChatTheme(context: AccountContext, message: Message, pushController: @escaping (ViewController) -> Void, present: @escaping (ViewController, Any?) -> Void) {
    for media in message.media {
        if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
            let _ = (context.sharedContext.resolveUrl(context: context, peerId: nil, url: content.url, skipUrlAuth: true)
            |> deliverOnMainQueue).startStandalone(next: { resolvedUrl in
                var file: TelegramMediaFile?
                var settings: TelegramThemeSettings?
                let themeMimeType = "application/x-tgtheme-ios"
                
                for attribute in content.attributes {
                    if case let .theme(attribute) = attribute {
                        if let attributeSettings = attribute.settings {
                            settings = attributeSettings
                        } else if let filteredFile = attribute.files.filter({ $0.mimeType == themeMimeType }).first {
                            file = filteredFile
                        }
                    }
                }
                
                if file == nil && settings == nil, let contentFile = content.file, contentFile.mimeType == themeMimeType {
                    file = contentFile
                }
                let displayUnsupportedAlert: () -> Void = {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    present(textAlertController(context: context, title: nil, text: presentationData.strings.Theme_Unsupported, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                }
                if case let .theme(slug) = resolvedUrl {
                    if let file = file {
                        if let path = context.sharedContext.accountManager.mediaBox.completedResourcePath(file.resource), let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead) {
                            if let theme = makePresentationTheme(data: data) {
                                let controller = ThemePreviewController(context: context, previewTheme: theme, source: .slug(slug, file))
                                pushController(controller)
                            } else {
                                displayUnsupportedAlert()
                            }
                        }
                    } else if let settings = settings {
                        if let theme = makePresentationTheme(settings: settings, title: content.title) {
                            let controller = ThemePreviewController(context: context, previewTheme: theme, source: .themeSettings(slug, settings))
                            pushController(controller)
                        } else {
                            displayUnsupportedAlert()
                        }
                    } else {
                        displayUnsupportedAlert()
                    }
                } else {
                    displayUnsupportedAlert()
                }
            })
        }
    }
}
