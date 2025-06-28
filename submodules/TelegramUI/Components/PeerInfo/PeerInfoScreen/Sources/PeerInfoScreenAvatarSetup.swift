import Foundation
import UIKit
import Display
import SSignalKit
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
import LegacyMediaPickerUI

extension PeerInfoScreenImpl {
    func openAvatarForEditing(mode: PeerInfoAvatarEditingMode = .generic, fromGallery: Bool = false, completion: @escaping (UIImage?) -> Void = { _ in }, completedWithUploadingImage: @escaping (UIImage, Signal<PeerInfoAvatarUploadStatus, NoError>) -> UIView? = { _, _ in nil }) {
        guard !self.presentAccountFrozenInfoIfNeeded() else {
            return
        }
        guard let data = self.controllerNode.data, let peer = data.peer, mode != .generic || canEditPeerInfo(context: self.context, peer: peer, chatLocation: self.chatLocation, threadData: data.threadData) else {
            return
        }
        self.view.endEditing(true)
        
        let peerId = self.peerId
        var isForum = false
        if let peer = peer as? TelegramChannel, peer.isForumOrMonoForum {
            isForum = true
        }
        
        var currentIsVideo = false
        var emojiMarkup: TelegramMediaImage.EmojiMarkup?
        let item = self.controllerNode.headerNode.avatarListNode.listContainerNode.currentItemNode?.item
        if let item = item, case let .image(_, _, videoRepresentations, _, _, emojiMarkupValue) = item {
            currentIsVideo = !videoRepresentations.isEmpty
            emojiMarkup = emojiMarkupValue
        }
        
        let _ = isForum
        let _ = currentIsVideo
        
        let _ = (self.context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
        )
        |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
            guard let self, let peer else {
                return
            }
            
            let keyboardInputData = Promise<AvatarKeyboardInputData>()
            keyboardInputData.set(AvatarEditorScreen.inputData(context: self.context, isGroup: peer.id.namespace != Namespaces.Peer.CloudUser))
            
            var hasPhotos = false
            if !peer.profileImageRepresentations.isEmpty {
                hasPhotos = true
            }

            var hasDeleteButton = false
            if case .generic = mode {
                hasDeleteButton = hasPhotos && !fromGallery
            } else if case .custom = mode {
                hasDeleteButton = peer.profileImageRepresentations.first?.isPersonal == true
            } else if case .fallback = mode {
                if let cachedData = data.cachedData as? CachedUserData, case let .known(photo) = cachedData.fallbackPhoto {
                    hasDeleteButton = photo != nil
                }
            }
            
            struct ConfirmationAlert {
                let title: String
                let photoText: String
                let videoText: String
                let action: String
            }
            
            let confirmationAlert: ConfirmationAlert?
            switch mode {
            case .suggest:
                confirmationAlert = ConfirmationAlert(
                    title: self.presentationData.strings.UserInfo_SuggestPhotoTitle(peer.compactDisplayTitle).string,
                    photoText: self.presentationData.strings.UserInfo_SuggestPhoto_AlertPhotoText(peer.compactDisplayTitle).string,
                    videoText: self.presentationData.strings.UserInfo_SuggestPhoto_AlertVideoText(peer.compactDisplayTitle).string,
                    action: self.presentationData.strings.UserInfo_SuggestPhoto_AlertSuggest
                )
            case .custom:
                confirmationAlert = ConfirmationAlert(
                    title: self.presentationData.strings.UserInfo_SetCustomPhotoTitle(peer.compactDisplayTitle).string,
                    photoText: self.presentationData.strings.UserInfo_SetCustomPhoto_AlertPhotoText(peer.compactDisplayTitle, peer.compactDisplayTitle).string,
                    videoText: self.presentationData.strings.UserInfo_SetCustomPhoto_AlertVideoText(peer.compactDisplayTitle, peer.compactDisplayTitle).string,
                    action: self.presentationData.strings.UserInfo_SetCustomPhoto_AlertSet
                )
            default:
                confirmationAlert = nil
            }
            
            let parentController = (self.context.sharedContext.mainWindow?.viewController as? NavigationController)?.topViewController as? ViewController
            
            var dismissImpl: (() -> Void)?
            let mainController = self.context.sharedContext.makeAvatarMediaPickerScreen(context: self.context, getSourceRect: { return nil }, canDelete: hasDeleteButton, performDelete: { [weak self] in
                self?.openAvatarRemoval(mode: mode, peer: peer, item: item)
            }, completion: { result, transitionView, transitionRect, transitionImage, fromCamera, transitionOut, cancelled in
                var resultImage: UIImage?
                let uploadStatusPromise = Promise<PeerInfoAvatarUploadStatus>(.progress(0.0))
                
                let subject: Signal<MediaEditorScreenImpl.Subject?, NoError>
                if let asset = result as? PHAsset {
                    subject = .single(.asset(asset))
                } else if let image = result as? UIImage {
                    subject = .single(.image(image: image, dimensions: PixelDimensions(image.size), additionalImage: nil, additionalImagePosition: .bottomRight, fromCamera: false))
                } else if let result = result as? Signal<CameraScreenImpl.Result, NoError> {
                    subject = result
                    |> map { value -> MediaEditorScreenImpl.Subject? in
                        switch value {
                        case .pendingImage:
                            return nil
                        case let .image(image):
                            return .image(image: image.image, dimensions: PixelDimensions(image.image.size), additionalImage: nil, additionalImagePosition: .topLeft, fromCamera: false)
                        case let .video(video):
                            return .video(videoPath: video.videoPath, thumbnail: video.coverImage, mirror: video.mirror, additionalVideoPath: nil, additionalThumbnail: nil, dimensions: video.dimensions, duration: video.duration, videoPositionChanges: [], additionalVideoPosition: .topLeft, fromCamera: false)
                        default:
                            return nil
                        }
                    }
                } else {
                    let peerType: AvatarEditorScreen.PeerType
                    if mode == .suggest {
                        peerType = .suggest
                    } else if case .legacyGroup = peer {
                        peerType = .group
                    } else if case let .channel(channel) = peer {
                        if case .group = channel.info {
                            peerType = channel.isForumOrMonoForum ? .forum : .group
                        } else {
                            peerType = .channel
                        }
                    } else {
                        peerType = .user
                    }
                    let controller = AvatarEditorScreen(context: self.context, inputData: keyboardInputData.get(), peerType: peerType, markup: emojiMarkup)
                    controller.imageCompletion = { [weak self] image, commit in
                        resultImage = image
                        self?.updateProfilePhoto(image, mode: mode, uploadStatus: uploadStatusPromise)
                        commit()
                    }
                    controller.videoCompletion = { [weak self] image, url, values, markup, commit in
                        resultImage = image
                        self?.updateProfileVideo(image, video: nil, values: nil, markup: markup, mode: mode, uploadStatus: uploadStatusPromise)
                        commit()
                    }
                    parentController?.push(controller)
                    //isFromEditor = true
                    return
                }
                
                let editorController = MediaEditorScreenImpl(
                    context: self.context,
                    mode: .avatarEditor,
                    subject: subject,
                    transitionIn: fromCamera ? .camera : transitionView.flatMap({ .gallery(
                        MediaEditorScreenImpl.TransitionIn.GalleryTransitionIn(
                            sourceView: $0,
                            sourceRect: transitionRect,
                            sourceImage: transitionImage
                        )
                    ) }),
                    transitionOut: { finished, isNew in
                        if !finished {
                            if let transitionView {
                                return MediaEditorScreenImpl.TransitionOut(
                                    destinationView: transitionView,
                                    destinationRect: transitionView.bounds,
                                    destinationCornerRadius: 0.0
                                )
                            }
                        } else if let resultImage, let transitionOutView = completedWithUploadingImage(resultImage, uploadStatusPromise.get()) {
                            transitionOutView.isHidden = true
                            return MediaEditorScreenImpl.TransitionOut(
                                destinationView: transitionOutView,
                                destinationRect: transitionOutView.bounds,
                                destinationCornerRadius: transitionOutView.bounds.height * 0.5,
                                completion: { [weak transitionOutView] in
                                    transitionOutView?.isHidden = false
                                }
                            )
                        }
                        return nil
                    },
                    willComplete: { [weak self, weak parentController] image, isVideo, commit in
                        if let self, let confirmationAlert, let image {
                            let controller = photoUpdateConfirmationController(context: self.context, peer: peer, image: image, text: isVideo ? confirmationAlert.videoText : confirmationAlert.photoText, doneTitle: confirmationAlert.action, commit: {
                                commit()
                            })
                            parentController?.presentInGlobalOverlay(controller)
                        } else {
                            commit()
                        }
                    },
                    completion: { [weak self] results, commit in
                        guard let result = results.first else {
                            return
                        }
                        switch result.media {
                        case let .image(image, _):
                            resultImage = image
                            self?.updateProfilePhoto(image, mode: mode, uploadStatus: uploadStatusPromise)
                            commit({})
                        case let .video(video, coverImage, values, _, _):
                            if let coverImage {
                                resultImage = coverImage
                                self?.updateProfileVideo(coverImage, video: video, values: values, markup: nil, mode: mode, uploadStatus: uploadStatusPromise)
                            }
                            commit({})
                        default:
                            break
                        }
                        dismissImpl?()
                    } as ([MediaEditorScreenImpl.Result], @escaping (@escaping () -> Void) -> Void) -> Void
                )
                editorController.cancelled = { _ in
                    cancelled()
                }
                if self.navigationController != nil {
                    self.push(editorController)
                } else {
                    self.parentController?.pushViewController(editorController)
                }
            }, dismissed: {
                
            })
            dismissImpl = { [weak self, weak mainController] in
                if let mainController, let navigationController = mainController.navigationController {
                    var viewControllers = navigationController.viewControllers
                    viewControllers = viewControllers.filter { c in
                        return !(c is CameraScreen) && c !== mainController
                    }
                    navigationController.setViewControllers(viewControllers, animated: false)
                }
                if let self, let navigationController = self.parentController, let mainController {
                    var viewControllers = navigationController.viewControllers
                    viewControllers = viewControllers.filter { c in
                        return !(c is CameraScreen) && c !== mainController
                    }
                    navigationController.setViewControllers(viewControllers, animated: false)
                }

            }
            mainController.navigationPresentation = .flatModal
            mainController.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
            if self.navigationController != nil {
                self.push(mainController)
            } else {
                self.parentController?.pushViewController(mainController)
            }
        })
    }
    
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
    
    private func setupProfilePhotoUpload(image: UIImage, mode: PeerInfoAvatarEditingMode, indefiniteProgress: Bool) -> LocalFileMediaResource? {
        guard let data = image.jpegData(compressionQuality: 0.6) else {
            return nil
        }
        
        if self.controllerNode.headerNode.isAvatarExpanded {
            self.controllerNode.headerNode.ignoreCollapse = true
            self.controllerNode.headerNode.updateIsAvatarExpanded(false, transition: .immediate)
            self.controllerNode.updateNavigationExpansionPresentation(isExpanded: false, animated: true)
        }
        self.controllerNode.scrollNode.view.setContentOffset(CGPoint(), animated: false)
        
        let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
        self.context.account.postbox.mediaBox.storeResourceData(resource.id, data: data)
        let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 640, height: 640), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: mode == .custom)
        
        if [.suggest, .fallback].contains(mode) {
        } else {
            if indefiniteProgress {
                self.controllerNode.state = self.controllerNode.state.withAvatarUploadProgress(.indefinite)
            }
            self.controllerNode.state = self.controllerNode.state.withUpdatingAvatar(.image(representation))
        }
        if let (layout, navigationHeight) = self.controllerNode.validLayout {
            self.controllerNode.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: mode == .custom ? .animated(duration: 0.2, curve: .easeInOut) : .immediate, additive: false)
        }
        self.controllerNode.headerNode.ignoreCollapse = false
        
        return resource
    }
    
    public func updateProfilePhoto(_ image: UIImage, mode: PeerInfoAvatarEditingMode, uploadStatus: Promise<PeerInfoAvatarUploadStatus>?) {
        guard let resource = setupProfilePhotoUpload(image: image, mode: mode, indefiniteProgress: false) else {
            uploadStatus?.set(.single(.done))
            return
        }
        
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
                uploadStatus?.set(.single(.done))
                strongSelf.controllerNode.state = strongSelf.controllerNode.state.withUpdatingAvatar(nil).withAvatarUploadProgress(nil)
            case let .progress(value):
                uploadStatus?.set(.single(.progress(value)))
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
        
    public func updateProfileVideo(_ image: UIImage, video: MediaEditorScreenImpl.MediaResult.VideoResult?, values: MediaEditorValues?, markup: UploadPeerPhotoMarkup?, mode: PeerInfoAvatarEditingMode, uploadStatus: Promise<PeerInfoAvatarUploadStatus>?) {
        var uploadVideo = true
        if let _ = markup {
            if let data = self.context.currentAppConfiguration.with({ $0 }).data, let uploadVideoValue = data["upload_markup_video"] as? Bool, uploadVideoValue {
                uploadVideo = true
            } else {
                uploadVideo = false
            }
        }
        guard let photoResource = self.setupProfilePhotoUpload(image: image, mode: mode, indefiniteProgress: !uploadVideo) else {
            uploadStatus?.set(.single(.done))
            return
        }
        
        var videoStartTimestamp: Double? = nil
        if let values, let coverImageTimestamp =  values.coverImageTimestamp, coverImageTimestamp > 0.0 {
            videoStartTimestamp = coverImageTimestamp - (values.videoTrimRange?.lowerBound ?? 0.0)
        }
    
        let account = self.context.account
        let context = self.context
        
        let videoResource: Signal<TelegramMediaResource?, UploadPeerPhotoError>
        if uploadVideo, let video, let values {
            var exportSubject: Signal<(MediaEditorVideoExport.Subject, Double), NoError>?
            switch video {
            case let .imageFile(path):
                if let image = UIImage(contentsOfFile: path) {
                    exportSubject = .single((.image(image: image), 3.0))
                }
            case let .videoFile(path):
                let asset = AVURLAsset(url: NSURL(fileURLWithPath: path) as URL)
                exportSubject = .single((.video(asset: asset, isStory: false), asset.duration.seconds))
            case let .asset(localIdentifier):
                exportSubject = Signal { subscriber in
                    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
                    if fetchResult.count != 0 {
                        let asset = fetchResult.object(at: 0)
                        if asset.mediaType == .video {
                            PHImageManager.default().requestAVAsset(forVideo: asset, options: nil) { avAsset, _, _ in
                                if let avAsset {
                                    subscriber.putNext((.video(asset: avAsset, isStory: true), avAsset.duration.seconds))
                                    subscriber.putCompletion()
                                }
                            }
                        } else {
                            let options = PHImageRequestOptions()
                            options.deliveryMode = .highQualityFormat
                            PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: options) { image, _ in
                                if let image {
                                    subscriber.putNext((.image(image: image), 3.0))
                                    subscriber.putCompletion()
                                }
                            }
                        }
                    }
                    return EmptyDisposable
                }
            }
            
            if let exportSubject {
                videoResource = exportSubject
                |> castError(UploadPeerPhotoError.self)
                |> mapToSignal { exportSubject, duration in
                    return Signal<TelegramMediaResource?, UploadPeerPhotoError> { subscriber in
                        let configuration = recommendedVideoExportConfiguration(values: values, duration: duration, forceFullHd: true, frameRate: 60.0, isAvatar: true)
                        let tempFile = EngineTempBox.shared.tempFile(fileName: "video.mp4")
                        let videoExport = MediaEditorVideoExport(postbox: context.account.postbox, subject: exportSubject, configuration: configuration, outputPath: tempFile.path, textScale: 2.0)
                        let _ = (videoExport.status
                        |> deliverOnMainQueue).startStandalone(next: { [weak self] status in
                            guard let self else {
                                return
                            }
                            switch status {
                            case .completed:
                                if let data = try? Data(contentsOf: URL(fileURLWithPath: tempFile.path), options: .mappedIfSafe) {
                                    let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                                    account.postbox.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
                                    subscriber.putNext(resource)
                                    subscriber.putCompletion()
                                }
                                EngineTempBox.shared.dispose(tempFile)
                            case let .progress(progress):
                                Queue.mainQueue().async {
                                    self.controllerNode.state = self.controllerNode.state.withAvatarUploadProgress(.value(CGFloat(progress * 0.45)))
                                    self.requestLayout(transition: .immediate)
                                }
                            default:
                                break
                            }
                        })
                        
                        return EmptyDisposable
                    }
                }
            } else {
                videoResource = .single(nil)
            }
        } else {
            videoResource = .single(nil)
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
        
        let peerId = self.peerId
        let isSettings = self.isSettings
        let isMyProfile = self.isMyProfile
        self.controllerNode.updateAvatarDisposable.set((videoResource
        |> mapToSignal { videoResource -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
            if isSettings || isMyProfile {
                if case .fallback = mode {
                    return context.engine.accountData.updateFallbackPhoto(resource: photoResource, videoResource: videoResource, videoStartTimestamp: videoStartTimestamp, markup: markup, mapResourceToAvatarSizes: { resource, representations in
                        return mapResourceToAvatarSizes(postbox: account.postbox, resource: resource, representations: representations)
                    })
                } else {
                    return context.engine.accountData.updateAccountPhoto(resource: photoResource, videoResource: videoResource, videoStartTimestamp: videoStartTimestamp, markup: markup, mapResourceToAvatarSizes: { resource, representations in
                        return mapResourceToAvatarSizes(postbox: account.postbox, resource: resource, representations: representations)
                    })
                }
            } else if case .custom = mode {
                return context.engine.contacts.updateContactPhoto(peerId: peerId, resource: photoResource, videoResource: videoResource, videoStartTimestamp: videoStartTimestamp, markup: markup, mode: .custom, mapResourceToAvatarSizes: { resource, representations in
                    return mapResourceToAvatarSizes(postbox: account.postbox, resource: resource, representations: representations)
                })
            } else if case .suggest = mode {
                return context.engine.contacts.updateContactPhoto(peerId: peerId, resource: photoResource, videoResource: videoResource, videoStartTimestamp: videoStartTimestamp, markup: markup, mode: .suggest, mapResourceToAvatarSizes: { resource, representations in
                    return mapResourceToAvatarSizes(postbox: account.postbox, resource: resource, representations: representations)
                })
            } else {
                return context.engine.peers.updatePeerPhoto(peerId: peerId, photo: context.engine.peers.uploadedPeerPhoto(resource: photoResource), video: videoResource.flatMap { context.engine.peers.uploadedPeerVideo(resource: $0) |> map(Optional.init) }, videoStartTimestamp: videoStartTimestamp, markup: markup, mapResourceToAvatarSizes: { resource, representations in
                    return mapResourceToAvatarSizes(postbox: account.postbox, resource: resource, representations: representations)
                })
            }
        }
        |> deliverOnMainQueue).startStrict(next: { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            switch result {
            case .complete:
                uploadStatus?.set(.single(.done))
                strongSelf.controllerNode.state = strongSelf.controllerNode.state.withUpdatingAvatar(nil).withAvatarUploadProgress(nil)
            case let .progress(value):
                uploadStatus?.set(.single(.progress(value)))
                strongSelf.controllerNode.state = strongSelf.controllerNode.state.withAvatarUploadProgress(.value(CGFloat(0.45 + value * 0.55)))
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
                            (strongSelf.parentController?.topViewController as? ViewController)?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .image(image: image, title: nil, text: strongSelf.presentationData.strings.Privacy_ProfilePhoto_PublicVideoSuccess, round: true, undoText: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                        case .custom:
                            strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .invitedToVoiceChat(context: strongSelf.context, peer: peer, title: nil, text: strongSelf.presentationData.strings.UserInfo_SetCustomPhoto_SuccessVideoText(peer.compactDisplayTitle).string, action: nil, duration: 5), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                            
                            let _ = (strongSelf.context.peerChannelMemberCategoriesContextsManager.profilePhotos(postbox: strongSelf.context.account.postbox, network: strongSelf.context.account.network, peerId: strongSelf.peerId, fetch: peerInfoProfilePhotos(context: strongSelf.context, peerId: strongSelf.peerId)) |> ignoreValues).startStandalone()
                        case .suggest:
                            if let navigationController = (strongSelf.navigationController as? NavigationController) {
                                strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peer), keepStack: .default, completion: { _ in
                                }))
                            }
                        case .accept:
                            (strongSelf.parentController?.topViewController as? ViewController)?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .image(image: image, title: strongSelf.presentationData.strings.Conversation_SuggestedVideoSuccess, text: strongSelf.presentationData.strings.Conversation_SuggestedVideoSuccessText, round: true, undoText: nil), elevatedLayout: false, animateInAsReplacement: true, action: { [weak self] action in
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
    
    public func oldUpdateProfileVideo(_ image: UIImage, asset: Any?, adjustments: TGVideoEditAdjustments?, mode: PeerInfoAvatarEditingMode) {
        var markup: UploadPeerPhotoMarkup? = nil
        if let fileId = adjustments?.documentId, let backgroundColors = adjustments?.colors as? [Int32], fileId != 0 {
            if let packId = adjustments?.stickerPackId, let accessHash = adjustments?.stickerPackAccessHash, packId != 0 {
                markup = .sticker(packReference: .id(id: packId, accessHash: accessHash), fileId: fileId, backgroundColors: backgroundColors)
            } else {
                markup = .emoji(fileId: fileId, backgroundColors: backgroundColors)
            }
        }
        
        var uploadVideo = true
        if let _ = markup {
            if let data = self.context.currentAppConfiguration.with({ $0 }).data, let uploadVideoValue = data["upload_markup_video"] as? Bool, uploadVideoValue {
                uploadVideo = true
            } else {
                uploadVideo = false
            }
        }
        guard let photoResource = self.setupProfilePhotoUpload(image: image, mode: mode, indefiniteProgress: !uploadVideo) else {
            return
        }
        
        var videoStartTimestamp: Double? = nil
        if let adjustments = adjustments, adjustments.videoStartValue > 0.0 {
            videoStartTimestamp = adjustments.videoStartValue - adjustments.trimStartValue
        }
    
        let account = self.context.account
        let context = self.context
        
        let videoResource: Signal<TelegramMediaResource?, UploadPeerPhotoError>
        if uploadVideo {
            videoResource = Signal<TelegramMediaResource?, UploadPeerPhotoError> { [weak self] subscriber in
                let entityRenderer: LegacyPaintEntityRenderer? = adjustments.flatMap { adjustments in
                    if let paintingData = adjustments.paintingData, paintingData.hasAnimation {
                        return LegacyPaintEntityRenderer(postbox: account.postbox, adjustments: adjustments)
                    } else {
                        return nil
                    }
                }
                
                let tempFile = EngineTempBox.shared.tempFile(fileName: "video.mp4")
                let uploadInterface = LegacyLiveUploadInterface(context: context)
                let signal: SSignal
                if let url = asset as? URL, url.absoluteString.hasSuffix(".jpg"), let data = try? Data(contentsOf: url, options: [.mappedRead]), let image = UIImage(data: data), let entityRenderer = entityRenderer {
                    let durationSignal: SSignal = SSignal(generator: { subscriber in
                        let disposable = (entityRenderer.duration()).start(next: { duration in
                            subscriber.putNext(duration)
                            subscriber.putCompletion()
                        })
                        
                        return SBlockDisposable(block: {
                            disposable.dispose()
                        })
                    })
                    signal = durationSignal.map(toSignal: { duration -> SSignal in
                        if let duration = duration as? Double {
                            return TGMediaVideoConverter.renderUIImage(image, duration: duration, adjustments: adjustments, path: tempFile.path, watcher: nil, entityRenderer: entityRenderer)!
                        } else {
                            return SSignal.single(nil)
                        }
                    })
                } else if let asset = asset as? AVAsset {
                    signal = TGMediaVideoConverter.convert(asset, adjustments: adjustments, path: tempFile.path, watcher: uploadInterface, entityRenderer: entityRenderer)!
                } else {
                    signal = SSignal.complete()
                }
                
                let signalDisposable = signal.start(next: { next in
                    if let result = next as? TGMediaVideoConversionResult {
                        if let image = result.coverImage, let data = image.jpegData(compressionQuality: 0.7) {
                            account.postbox.mediaBox.storeResourceData(photoResource.id, data: data)
                        }
                        
                        if let timestamp = videoStartTimestamp {
                            videoStartTimestamp = max(0.0, min(timestamp, result.duration - 0.05))
                        }
                        
                        var value = stat()
                        if stat(result.fileURL.path, &value) == 0 {
                            if let data = try? Data(contentsOf: result.fileURL) {
                                let resource: TelegramMediaResource
                                if let liveUploadData = result.liveUploadData as? LegacyLiveUploadInterfaceResult {
                                    resource = LocalFileMediaResource(fileId: liveUploadData.id)
                                } else {
                                    resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                                }
                                account.postbox.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
                                subscriber.putNext(resource)
                                
                                EngineTempBox.shared.dispose(tempFile)
                            }
                        }
                        subscriber.putCompletion()
                    } else if let strongSelf = self, let progress = next as? NSNumber {
                        Queue.mainQueue().async {
                            strongSelf.controllerNode.state = strongSelf.controllerNode.state.withAvatarUploadProgress(.value(CGFloat(progress.floatValue * 0.45)))
                            if let (layout, navigationHeight) = strongSelf.controllerNode.validLayout {
                                strongSelf.controllerNode.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                            }
                        }
                    }
                }, error: { _ in
                }, completed: nil)
                
                let disposable = ActionDisposable {
                    signalDisposable?.dispose()
                }
                
                return ActionDisposable {
                    disposable.dispose()
                }
            }
        } else {
            videoResource = .single(nil)
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
        
        let peerId = self.peerId
        let isSettings = self.isSettings
        let isMyProfile = self.isMyProfile
        self.controllerNode.updateAvatarDisposable.set((videoResource
        |> mapToSignal { videoResource -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
            if isSettings || isMyProfile {
                if case .fallback = mode {
                    return context.engine.accountData.updateFallbackPhoto(resource: photoResource, videoResource: videoResource, videoStartTimestamp: videoStartTimestamp, markup: markup, mapResourceToAvatarSizes: { resource, representations in
                        return mapResourceToAvatarSizes(postbox: account.postbox, resource: resource, representations: representations)
                    })
                } else {
                    return context.engine.accountData.updateAccountPhoto(resource: photoResource, videoResource: videoResource, videoStartTimestamp: videoStartTimestamp, markup: markup, mapResourceToAvatarSizes: { resource, representations in
                        return mapResourceToAvatarSizes(postbox: account.postbox, resource: resource, representations: representations)
                    })
                }
            } else if case .custom = mode {
                return context.engine.contacts.updateContactPhoto(peerId: peerId, resource: photoResource, videoResource: videoResource, videoStartTimestamp: videoStartTimestamp, markup: markup, mode: .custom, mapResourceToAvatarSizes: { resource, representations in
                    return mapResourceToAvatarSizes(postbox: account.postbox, resource: resource, representations: representations)
                })
            } else if case .suggest = mode {
                return context.engine.contacts.updateContactPhoto(peerId: peerId, resource: photoResource, videoResource: videoResource, videoStartTimestamp: videoStartTimestamp, markup: markup, mode: .suggest, mapResourceToAvatarSizes: { resource, representations in
                    return mapResourceToAvatarSizes(postbox: account.postbox, resource: resource, representations: representations)
                })
            } else {
                return context.engine.peers.updatePeerPhoto(peerId: peerId, photo: context.engine.peers.uploadedPeerPhoto(resource: photoResource), video: videoResource.flatMap { context.engine.peers.uploadedPeerVideo(resource: $0) |> map(Optional.init) }, videoStartTimestamp: videoStartTimestamp, markup: markup, mapResourceToAvatarSizes: { resource, representations in
                    return mapResourceToAvatarSizes(postbox: account.postbox, resource: resource, representations: representations)
                })
            }
        }
        |> deliverOnMainQueue).startStrict(next: { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            switch result {
                case .complete:
                    strongSelf.controllerNode.state = strongSelf.controllerNode.state.withUpdatingAvatar(nil).withAvatarUploadProgress(nil)
                case let .progress(value):
                    strongSelf.controllerNode.state = strongSelf.controllerNode.state.withAvatarUploadProgress(.value(CGFloat(0.45 + value * 0.55)))
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
                            (strongSelf.parentController?.topViewController as? ViewController)?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .image(image: image, title: nil, text: strongSelf.presentationData.strings.Privacy_ProfilePhoto_PublicVideoSuccess, round: true, undoText: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                        case .custom:
                            strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .invitedToVoiceChat(context: strongSelf.context, peer: peer, title: nil, text: strongSelf.presentationData.strings.UserInfo_SetCustomPhoto_SuccessVideoText(peer.compactDisplayTitle).string, action: nil, duration: 5), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                            
                            let _ = (strongSelf.context.peerChannelMemberCategoriesContextsManager.profilePhotos(postbox: strongSelf.context.account.postbox, network: strongSelf.context.account.network, peerId: strongSelf.peerId, fetch: peerInfoProfilePhotos(context: strongSelf.context, peerId: strongSelf.peerId)) |> ignoreValues).startStandalone()
                        case .suggest:
                            if let navigationController = (strongSelf.navigationController as? NavigationController) {
                                strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peer), keepStack: .default, completion: { _ in
                                }))
                            }
                        case .accept:
                            (strongSelf.parentController?.topViewController as? ViewController)?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .image(image: image, title: strongSelf.presentationData.strings.Conversation_SuggestedVideoSuccess, text: strongSelf.presentationData.strings.Conversation_SuggestedVideoSuccessText, round: true, undoText: nil), elevatedLayout: false, animateInAsReplacement: true, action: { [weak self] action in
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
}
