import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import MediaEditor
import MediaEditorScreen
import CameraScreen
import Photos
import PeerInfoAvatarListNode
import MapResourceToAvatarSizes
import AvatarEditorScreen
import OverlayStatusController
import UndoUI
import PeerAvatarGalleryUI
import PresentationDataUtils
import LegacyComponents

extension PeerInfoScreenImpl {
//    func newopenAvatarForEditing(mode: PeerInfoAvatarEditingMode = .generic, fromGallery: Bool = false, completion: @escaping (UIImage?) -> Void = { _ in }) {
//        guard let data = self.controllerNode.data, let peer = data.peer, mode != .generic || canEditPeerInfo(context: self.context, peer: peer, chatLocation: self.chatLocation, threadData: data.threadData) else {
//            return
//        }
//        self.view.endEditing(true)
//        
//        let peerId = self.peerId
//        var isForum = false
//        if let peer = peer as? TelegramChannel, peer.flags.contains(.isForum) {
//            isForum = true
//        }
//        
//        var currentIsVideo = false
//        var emojiMarkup: TelegramMediaImage.EmojiMarkup?
//        let item = self.controllerNode.headerNode.avatarListNode.listContainerNode.currentItemNode?.item
//        if let item = item, case let .image(_, _, videoRepresentations, _, _, emojiMarkupValue) = item {
//            currentIsVideo = !videoRepresentations.isEmpty
//            emojiMarkup = emojiMarkupValue
//        }
//        
//        let _ = isForum
//        let _ = currentIsVideo
//        
//        let _ = (self.context.engine.data.get(
//            TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
//        )
//        |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
//            guard let self, let peer else {
//                return
//            }
//            
//            let keyboardInputData = Promise<AvatarKeyboardInputData>()
//            keyboardInputData.set(AvatarEditorScreen.inputData(context: self.context, isGroup: peer.id.namespace != Namespaces.Peer.CloudUser))
//            
//            var hasPhotos = false
//            if !peer.profileImageRepresentations.isEmpty {
//                hasPhotos = true
//            }
//
//            var hasDeleteButton = false
//            if case .generic = mode {
//                hasDeleteButton = hasPhotos && !fromGallery
//            } else if case .custom = mode {
//                hasDeleteButton = peer.profileImageRepresentations.first?.isPersonal == true
//            } else if case .fallback = mode {
//                if let cachedData = data.cachedData as? CachedUserData, case let .known(photo) = cachedData.fallbackPhoto {
//                    hasDeleteButton = photo != nil
//                }
//            }
//            
//            let _ = hasDeleteButton
//            
//            let parentController = (self.context.sharedContext.mainWindow?.viewController as? NavigationController)?.topViewController as? ViewController
//            
//            var dismissImpl: (() -> Void)?
//            let mainController = self.context.sharedContext.makeAvatarMediaPickerScreen(context: self.context, getSourceRect: { return nil }, canDelete: hasDeleteButton, performDelete: { [weak self] in
//                self?.openAvatarRemoval(mode: mode, peer: peer, item: item)
//            }, completion: { result, transitionView, transitionRect, transitionImage, fromCamera, transitionOut, cancelled in
//                let subject: Signal<MediaEditorScreenImpl.Subject?, NoError>
//                if let asset = result as? PHAsset {
//                    subject = .single(.asset(asset))
//                } else if let image = result as? UIImage {
//                    subject = .single(.image(image: image, dimensions: PixelDimensions(image.size), additionalImage: nil, additionalImagePosition: .bottomRight))
//                } else if let result = result as? Signal<CameraScreenImpl.Result, NoError> {
//                    subject = result
//                    |> map { value -> MediaEditorScreenImpl.Subject? in
//                        switch value {
//                        case .pendingImage:
//                            return nil
//                        case let .image(image):
//                            return .image(image: image.image, dimensions: PixelDimensions(image.image.size), additionalImage: nil, additionalImagePosition: .topLeft)
//                        case let .video(video):
//                            return .video(videoPath: video.videoPath, thumbnail: video.coverImage, mirror: video.mirror, additionalVideoPath: nil, additionalThumbnail: nil, dimensions: video.dimensions, duration: video.duration, videoPositionChanges: [], additionalVideoPosition: .topLeft)
//                        default:
//                            return nil
//                        }
//                    }
//                } else {
//                    let peerType: AvatarEditorScreen.PeerType
//                    if mode == .suggest {
//                        peerType = .suggest
//                    } else if case .legacyGroup = peer {
//                        peerType = .group
//                    } else if case let .channel(channel) = peer {
//                        if case .group = channel.info {
//                            peerType = channel.flags.contains(.isForum) ? .forum : .group
//                        } else {
//                            peerType = .channel
//                        }
//                    } else {
//                        peerType = .user
//                    }
//                    let controller = AvatarEditorScreen(context: self.context, inputData: keyboardInputData.get(), peerType: peerType, markup: emojiMarkup)
//                    //controller.imageCompletion = imageCompletion
//                    //controller.videoCompletion = videoCompletion
//                    parentController?.push(controller)
//                    //isFromEditor = true
//                    return
//                }
//                
//                let editorController = MediaEditorScreenImpl(
//                    context: self.context,
//                    mode: .avatarEditor,
//                    subject: subject,
//                    transitionIn: fromCamera ? .camera : transitionView.flatMap({ .gallery(
//                        MediaEditorScreenImpl.TransitionIn.GalleryTransitionIn(
//                            sourceView: $0,
//                            sourceRect: transitionRect,
//                            sourceImage: transitionImage
//                        )
//                    ) }),
//                    transitionOut: { finished, isNew in
//                        if !finished, let transitionView {
//                            return MediaEditorScreenImpl.TransitionOut(
//                                destinationView: transitionView,
//                                destinationRect: transitionView.bounds,
//                                destinationCornerRadius: 0.0
//                            )
//                        }
//                        return nil
//                    }, completion: { [weak self] result, commit in
//                        dismissImpl?()
//                       
//                        switch result.media {
//                        case let .image(image, _):
//                            self?.updateProfilePhoto(image, mode: mode)
//                            commit({})
//                        case let .video(video, coverImage, values, _, _):
//                            if let coverImage {
//                                self?.updateProfileVideo(coverImage, asset: video, adjustments: values, mode: mode)
//                            }
//                            commit({})
//                        default:
//                            break
//                        }
//                    } as (MediaEditorScreenImpl.Result, @escaping (@escaping () -> Void) -> Void) -> Void
//                )
//                editorController.cancelled = { _ in
//                    cancelled()
//                }
//                self.push(editorController)
//            }, dismissed: {
//                
//            })
//            dismissImpl = { [weak mainController] in
//                if let mainController, let navigationController = mainController.navigationController {
//                    var viewControllers = navigationController.viewControllers
//                    viewControllers = viewControllers.filter { c in
//                        return !(c is CameraScreen) && c !== mainController
//                    }
//                    navigationController.setViewControllers(viewControllers, animated: false)
//                }
//            }
//            mainController.navigationPresentation = .flatModal
//            mainController.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
//            self.push(mainController)
//        })
//    }
    
    func openAvatarRemoval(mode: PeerInfoAvatarEditingMode, peer: EnginePeer? = nil, item: PeerInfoAvatarListItem? = nil, completion: @escaping () -> Void = {}) {
        let proceed = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            completion()
            
            if let item = item {
                strongSelf.controllerNode.deleteProfilePhoto(item)
            }
            if mode != .fallback {
                if let peer = peer, let _ = peer.smallProfileImage {
                    strongSelf.controllerNode.state = strongSelf.controllerNode.state.withUpdatingAvatar(nil)
                    if let (layout, navigationHeight) = strongSelf.controllerNode.validLayout {
                        strongSelf.controllerNode.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                    }
                }
            }
            let postbox = strongSelf.context.account.postbox
            let signal: Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError>
            if case .custom = mode {
                signal = strongSelf.context.engine.contacts.updateContactPhoto(peerId: strongSelf.peerId, resource: nil, videoResource: nil, videoStartTimestamp: nil, markup: nil, mode: .custom, mapResourceToAvatarSizes: { resource, representations in
                    return mapResourceToAvatarSizes(postbox: postbox, resource: resource, representations: representations)
                })
            } else if case .fallback = mode {
                signal = strongSelf.context.engine.accountData.removeFallbackPhoto(reference: nil)
                |> castError(UploadPeerPhotoError.self)
                |> map { _ in
                    return .complete([])
                }
            } else {
                signal = strongSelf.context.engine.peers.updatePeerPhoto(peerId: strongSelf.peerId, photo: nil, mapResourceToAvatarSizes: { resource, representations in
                    return mapResourceToAvatarSizes(postbox: postbox, resource: resource, representations: representations)
                })
            }
            strongSelf.controllerNode.updateAvatarDisposable.set((signal
            |> deliverOnMainQueue).startStrict(next: { result in
                guard let strongSelf = self else {
                    return
                }
                switch result {
                case .complete:
                    strongSelf.controllerNode.state = strongSelf.controllerNode.state.withUpdatingAvatar(nil)
                    if let (layout, navigationHeight) = strongSelf.controllerNode.validLayout {
                        strongSelf.controllerNode.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                    }
                case .progress:
                    break
                }
            }))
        }
        
        let presentationData = self.presentationData
        let actionSheet = ActionSheetController(presentationData: presentationData)
        let items: [ActionSheetItem] = [
            ActionSheetButtonItem(title: presentationData.strings.Settings_RemoveConfirmation, color: .destructive, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                proceed()
            })
        ]
        
        actionSheet.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])
        ])
        (self.navigationController?.topViewController as? ViewController)?.present(actionSheet, in: .window(.root))
    }
    
    public func updateProfilePhoto(_ image: UIImage, mode: PeerInfoAvatarEditingMode) {
        guard let data = image.jpegData(compressionQuality: 0.6) else {
            return
        }

        if self.controllerNode.headerNode.isAvatarExpanded {
            self.controllerNode.headerNode.ignoreCollapse = true
            self.controllerNode.headerNode.updateIsAvatarExpanded(false, transition: .immediate)
            self.controllerNode.updateNavigationExpansionPresentation(isExpanded: false, animated: true)
        }
        self.controllerNode.scrollNode.view.setContentOffset(CGPoint(), animated: false)
        
        let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
        self.context.account.postbox.mediaBox.storeResourceData(resource.id, data: data)
        let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 640, height: 640), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: mode == .custom ? true : false)
        
        if [.suggest, .fallback].contains(mode) {
        } else {
            self.controllerNode.state = self.controllerNode.state.withUpdatingAvatar(.image(representation))
        }
        
        if let (layout, navigationHeight) = self.controllerNode.validLayout {
            self.controllerNode.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: mode == .custom ? .animated(duration: 0.2, curve: .easeInOut) : .immediate, additive: false)
        }
        self.controllerNode.headerNode.ignoreCollapse = false
        
        let postbox = self.context.account.postbox
        let signal: Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError>
        if self.isSettings || self.isMyProfile {
            if case .fallback = mode {
                signal = self.context.engine.accountData.updateFallbackPhoto(resource: resource, videoResource: nil, videoStartTimestamp: nil, markup: nil, mapResourceToAvatarSizes: { resource, representations in
                    return mapResourceToAvatarSizes(postbox: postbox, resource: resource, representations: representations)
                })
            } else {
                signal = self.context.engine.accountData.updateAccountPhoto(resource: resource, videoResource: nil, videoStartTimestamp: nil, markup: nil, mapResourceToAvatarSizes: { resource, representations in
                    return mapResourceToAvatarSizes(postbox: postbox, resource: resource, representations: representations)
                })
            }
        } else if case .custom = mode {
            signal = self.context.engine.contacts.updateContactPhoto(peerId: self.peerId, resource: resource, videoResource: nil, videoStartTimestamp: nil, markup: nil, mode: .custom, mapResourceToAvatarSizes: { resource, representations in
                return mapResourceToAvatarSizes(postbox: postbox, resource: resource, representations: representations)
            })
        } else if case .suggest = mode {
            signal = self.context.engine.contacts.updateContactPhoto(peerId: self.peerId, resource: resource, videoResource: nil, videoStartTimestamp: nil, markup: nil, mode: .suggest, mapResourceToAvatarSizes: { resource, representations in
                return mapResourceToAvatarSizes(postbox: postbox, resource: resource, representations: representations)
            })
        } else {
            signal = self.context.engine.peers.updatePeerPhoto(peerId: self.peerId, photo: self.context.engine.peers.uploadedPeerPhoto(resource: resource), mapResourceToAvatarSizes: { resource, representations in
                return mapResourceToAvatarSizes(postbox: postbox, resource: resource, representations: representations)
            })
        }
        
        var dismissStatus: (() -> Void)?
        if [.suggest, .fallback, .accept].contains(mode) {
            let statusController = OverlayStatusController(theme: self.presentationData.theme, type: .loading(cancelled: { [weak self] in
                self?.controllerNode.updateAvatarDisposable.set(nil)
                dismissStatus?()
            }))
            dismissStatus = { [weak statusController] in
                statusController?.dismiss()
            }
            if let topController = self.navigationController?.topViewController as? ViewController {
                topController.presentInGlobalOverlay(statusController)
            } else if let topController = self.parentController?.topViewController as? ViewController {
                topController.presentInGlobalOverlay(statusController)
            } else {
                self.presentInGlobalOverlay(statusController)
            }
        }

        self.controllerNode.updateAvatarDisposable.set((signal
        |> deliverOnMainQueue).startStrict(next: { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            switch result {
            case .complete:
                strongSelf.controllerNode.state = strongSelf.controllerNode.state.withUpdatingAvatar(nil).withAvatarUploadProgress(nil)
            case let .progress(value):
                strongSelf.controllerNode.state = strongSelf.controllerNode.state.withAvatarUploadProgress(.value(CGFloat(value)))
            }
            if let (layout, navigationHeight) = strongSelf.controllerNode.validLayout {
                strongSelf.controllerNode.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
            }
            
            if case .complete = result {
                dismissStatus?()
                
                let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: strongSelf.peerId))
                |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
                    if let strongSelf = self, let peer {
                        switch mode {
                        case .fallback:
                            (strongSelf.parentController?.topViewController as? ViewController)?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .image(image: image, title: nil, text: strongSelf.presentationData.strings.Privacy_ProfilePhoto_PublicPhotoSuccess, round: true, undoText: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                        case .custom:
                            strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .invitedToVoiceChat(context: strongSelf.context, peer: peer, title: nil, text: strongSelf.presentationData.strings.UserInfo_SetCustomPhoto_SuccessPhotoText(peer.compactDisplayTitle).string, action: nil, duration: 5), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                            
                            let _ = (strongSelf.context.peerChannelMemberCategoriesContextsManager.profilePhotos(postbox: strongSelf.context.account.postbox, network: strongSelf.context.account.network, peerId: strongSelf.peerId, fetch: peerInfoProfilePhotos(context: strongSelf.context, peerId: strongSelf.peerId)) |> ignoreValues).startStandalone()
                        case .suggest:
                            if let navigationController = (strongSelf.navigationController as? NavigationController) {
                                strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peer), keepStack: .default, completion: { _ in
                                }))
                            }
                        case .accept:
                            (strongSelf.parentController?.topViewController as? ViewController)?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .image(image: image, title: strongSelf.presentationData.strings.Conversation_SuggestedPhotoSuccess, text: strongSelf.presentationData.strings.Conversation_SuggestedPhotoSuccessText, round: true, undoText: nil), elevatedLayout: false, animateInAsReplacement: true, action: { [weak self] action in
                                if case .info = action {
                                    self?.parentController?.openSettings()
                                }
                                return false
                            }), in: .current)
                        default:
                            break
                        }
                    }
                })
            }
        }))
    }
              
    public func updateProfileVideo(_ image: UIImage, asset: Any?, adjustments: TGVideoEditAdjustments?, mode: PeerInfoAvatarEditingMode) {
        guard let data = image.jpegData(compressionQuality: 0.6) else {
            return
        }
        
        if self.controllerNode.headerNode.isAvatarExpanded {
            self.controllerNode.headerNode.ignoreCollapse = true
            self.controllerNode.headerNode.updateIsAvatarExpanded(false, transition: .immediate)
            self.controllerNode.updateNavigationExpansionPresentation(isExpanded: false, animated: true)
        }
        self.controllerNode.scrollNode.view.setContentOffset(CGPoint(), animated: false)
        
        let photoResource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
        self.context.account.postbox.mediaBox.storeResourceData(photoResource.id, data: data)
//        let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 640, height: 640), resource: photoResource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: mode == .custom ? true : false)
//        
//        var markup: UploadPeerPhotoMarkup? = nil
//        if let fileId = adjustments?.documentId, let backgroundColors = adjustments?.colors as? [Int32], fileId != 0 {
//            if let packId = adjustments?.stickerPackId, let accessHash = adjustments?.stickerPackAccessHash, packId != 0 {
//                markup = .sticker(packReference: .id(id: packId, accessHash: accessHash), fileId: fileId, backgroundColors: backgroundColors)
//            } else {
//                markup = .emoji(fileId: fileId, backgroundColors: backgroundColors)
//            }
//        }
//        
//        var uploadVideo = true
//        if let _ = markup {
//            if let data = self.context.currentAppConfiguration.with({ $0 }).data, let uploadVideoValue = data["upload_markup_video"] as? Bool, uploadVideoValue {
//                uploadVideo = true
//            } else {
//                uploadVideo = false
//            }
//        }
//        
//        if [.suggest, .fallback].contains(mode) {
//        } else {
//            self.controllerNode.state = self.controllerNode.state.withUpdatingAvatar(.image(representation))
//            if !uploadVideo {
//                self.controllerNode.state = self.controllerNode.state.withAvatarUploadProgress(.indefinite)
//            }
//        }
//       
//        if let (layout, navigationHeight) = self.controllerNode.validLayout {
//            self.controllerNode.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: mode == .custom ? .animated(duration: 0.2, curve: .easeInOut) : .immediate, additive: false)
//        }
//        self.controllerNode.headerNode.ignoreCollapse = false
//        
//        var videoStartTimestamp: Double? = nil
//        if let adjustments = adjustments, adjustments.videoStartValue > 0.0 {
//            videoStartTimestamp = adjustments.videoStartValue - adjustments.trimStartValue
//        }
//    
//        let account = self.context.account
//        let context = self.context
//        
//        let videoResource: Signal<TelegramMediaResource?, UploadPeerPhotoError>
//        if uploadVideo {
//            videoResource = Signal<TelegramMediaResource?, UploadPeerPhotoError> { [weak self] subscriber in
//                let entityRenderer: LegacyPaintEntityRenderer? = adjustments.flatMap { adjustments in
//                    if let paintingData = adjustments.paintingData, paintingData.hasAnimation {
//                        return LegacyPaintEntityRenderer(postbox: account.postbox, adjustments: adjustments)
//                    } else {
//                        return nil
//                    }
//                }
//                
//                let tempFile = EngineTempBox.shared.tempFile(fileName: "video.mp4")
//                let uploadInterface = LegacyLiveUploadInterface(context: context)
//                let signal: SSignal
//                if let url = asset as? URL, url.absoluteString.hasSuffix(".jpg"), let data = try? Data(contentsOf: url, options: [.mappedRead]), let image = UIImage(data: data), let entityRenderer = entityRenderer {
//                    let durationSignal: SSignal = SSignal(generator: { subscriber in
//                        let disposable = (entityRenderer.duration()).start(next: { duration in
//                            subscriber.putNext(duration)
//                            subscriber.putCompletion()
//                        })
//                        
//                        return SBlockDisposable(block: {
//                            disposable.dispose()
//                        })
//                    })
//                    signal = durationSignal.map(toSignal: { duration -> SSignal in
//                        if let duration = duration as? Double {
//                            return TGMediaVideoConverter.renderUIImage(image, duration: duration, adjustments: adjustments, path: tempFile.path, watcher: nil, entityRenderer: entityRenderer)!
//                        } else {
//                            return SSignal.single(nil)
//                        }
//                    })
//                } else if let asset = asset as? AVAsset {
//                    signal = TGMediaVideoConverter.convert(asset, adjustments: adjustments, path: tempFile.path, watcher: uploadInterface, entityRenderer: entityRenderer)!
//                } else {
//                    signal = SSignal.complete()
//                }
//                
//                let signalDisposable = signal.start(next: { next in
//                    if let result = next as? TGMediaVideoConversionResult {
//                        if let image = result.coverImage, let data = image.jpegData(compressionQuality: 0.7) {
//                            account.postbox.mediaBox.storeResourceData(photoResource.id, data: data)
//                        }
//                        
//                        if let timestamp = videoStartTimestamp {
//                            videoStartTimestamp = max(0.0, min(timestamp, result.duration - 0.05))
//                        }
//                        
//                        var value = stat()
//                        if stat(result.fileURL.path, &value) == 0 {
//                            if let data = try? Data(contentsOf: result.fileURL) {
//                                let resource: TelegramMediaResource
//                                if let liveUploadData = result.liveUploadData as? LegacyLiveUploadInterfaceResult {
//                                    resource = LocalFileMediaResource(fileId: liveUploadData.id)
//                                } else {
//                                    resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
//                                }
//                                account.postbox.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
//                                subscriber.putNext(resource)
//                                
//                                EngineTempBox.shared.dispose(tempFile)
//                            }
//                        }
//                        subscriber.putCompletion()
//                    } else if let strongSelf = self, let progress = next as? NSNumber {
//                        Queue.mainQueue().async {
//                            strongSelf.state = strongSelf.state.withAvatarUploadProgress(.value(CGFloat(progress.floatValue * 0.45)))
//                            if let (layout, navigationHeight) = strongSelf.validLayout {
//                                strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
//                            }
//                        }
//                    }
//                }, error: { _ in
//                }, completed: nil)
//                
//                let disposable = ActionDisposable {
//                    signalDisposable?.dispose()
//                }
//                
//                return ActionDisposable {
//                    disposable.dispose()
//                }
//            }
//        } else {
//            videoResource = .single(nil)
//        }
//        
//        var dismissStatus: (() -> Void)?
//        if [.suggest, .fallback, .accept].contains(mode) {
//            let statusController = OverlayStatusController(theme: self.presentationData.theme, type: .loading(cancelled: { [weak self] in
//                self?.controllerNode.updateAvatarDisposable.set(nil)
//                dismissStatus?()
//            }))
//            dismissStatus = { [weak statusController] in
//                statusController?.dismiss()
//            }
//            if let topController = self.navigationController?.topViewController as? ViewController {
//                topController.presentInGlobalOverlay(statusController)
//            } else if let topController = self.parentController?.topViewController as? ViewController {
//                topController.presentInGlobalOverlay(statusController)
//            } else {
//                self.presentInGlobalOverlay(statusController)
//            }
//        }
//        
//        let peerId = self.peerId
//        let isSettings = self.isSettings
//        let isMyProfile = self.isMyProfile
//        self.controllerNode.updateAvatarDisposable.set((videoResource
//        |> mapToSignal { videoResource -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
//            if isSettings || isMyProfile {
//                if case .fallback = mode {
//                    return context.engine.accountData.updateFallbackPhoto(resource: photoResource, videoResource: videoResource, videoStartTimestamp: videoStartTimestamp, markup: markup, mapResourceToAvatarSizes: { resource, representations in
//                        return mapResourceToAvatarSizes(postbox: account.postbox, resource: resource, representations: representations)
//                    })
//                } else {
//                    return context.engine.accountData.updateAccountPhoto(resource: photoResource, videoResource: videoResource, videoStartTimestamp: videoStartTimestamp, markup: markup, mapResourceToAvatarSizes: { resource, representations in
//                        return mapResourceToAvatarSizes(postbox: account.postbox, resource: resource, representations: representations)
//                    })
//                }
//            } else if case .custom = mode {
//                return context.engine.contacts.updateContactPhoto(peerId: peerId, resource: photoResource, videoResource: videoResource, videoStartTimestamp: videoStartTimestamp, markup: markup, mode: .custom, mapResourceToAvatarSizes: { resource, representations in
//                    return mapResourceToAvatarSizes(postbox: account.postbox, resource: resource, representations: representations)
//                })
//            } else if case .suggest = mode {
//                return context.engine.contacts.updateContactPhoto(peerId: peerId, resource: photoResource, videoResource: videoResource, videoStartTimestamp: videoStartTimestamp, markup: markup, mode: .suggest, mapResourceToAvatarSizes: { resource, representations in
//                    return mapResourceToAvatarSizes(postbox: account.postbox, resource: resource, representations: representations)
//                })
//            } else {
//                return context.engine.peers.updatePeerPhoto(peerId: peerId, photo: context.engine.peers.uploadedPeerPhoto(resource: photoResource), video: videoResource.flatMap { context.engine.peers.uploadedPeerVideo(resource: $0) |> map(Optional.init) }, videoStartTimestamp: videoStartTimestamp, markup: markup, mapResourceToAvatarSizes: { resource, representations in
//                    return mapResourceToAvatarSizes(postbox: account.postbox, resource: resource, representations: representations)
//                })
//            }
//        }
//        |> deliverOnMainQueue).startStrict(next: { [weak self] result in
//            guard let strongSelf = self else {
//                return
//            }
//            switch result {
//                case .complete:
//                    strongSelf.controllerNode.state = strongSelf.controllerNode.state.withUpdatingAvatar(nil).withAvatarUploadProgress(nil)
//                case let .progress(value):
//                    strongSelf.controllerNode.state = strongSelf.controllerNode.state.withAvatarUploadProgress(.value(CGFloat(0.45 + value * 0.55)))
//            }
//            if let (layout, navigationHeight) = strongSelf.controllerNode.validLayout {
//                strongSelf.controllerNode.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
//            }
//            
//            if case .complete = result {
//                dismissStatus?()
//                
//                let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: strongSelf.peerId))
//                |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
//                    if let strongSelf = self, let peer {
//                        switch mode {
//                        case .fallback:
//                            (strongSelf.parentController?.topViewController as? ViewController)?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .image(image: image, title: nil, text: strongSelf.presentationData.strings.Privacy_ProfilePhoto_PublicVideoSuccess, round: true, undoText: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
//                        case .custom:
//                            strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .invitedToVoiceChat(context: strongSelf.context, peer: peer, title: nil, text: strongSelf.presentationData.strings.UserInfo_SetCustomPhoto_SuccessVideoText(peer.compactDisplayTitle).string, action: nil, duration: 5), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
//                            
//                            let _ = (strongSelf.context.peerChannelMemberCategoriesContextsManager.profilePhotos(postbox: strongSelf.context.account.postbox, network: strongSelf.context.account.network, peerId: strongSelf.peerId, fetch: peerInfoProfilePhotos(context: strongSelf.context, peerId: strongSelf.peerId)) |> ignoreValues).startStandalone()
//                        case .suggest:
//                            if let navigationController = (strongSelf.navigationController as? NavigationController) {
//                                strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peer), keepStack: .default, completion: { _ in
//                                }))
//                            }
//                        case .accept:
//                            (strongSelf.parentController?.topViewController as? ViewController)?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .image(image: image, title: strongSelf.presentationData.strings.Conversation_SuggestedVideoSuccess, text: strongSelf.presentationData.strings.Conversation_SuggestedVideoSuccessText, round: true, undoText: nil), elevatedLayout: false, animateInAsReplacement: true, action: { [weak self] action in
//                                if case .info = action {
//                                    self?.parentController?.openSettings()
//                                }
//                                return false
//                            }), in: .current)
//                        default:
//                            break
//                        }
//                    }
//                })
//            }
//        }))
    }
}
