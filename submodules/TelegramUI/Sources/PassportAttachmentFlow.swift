import Foundation
import UIKit
import Photos
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import LegacyComponents
import LegacyMediaPickerUI
import Camera
import CameraScreen
import MediaPickerUI
import ChatMediaSend
import ChatMediaEditorScreen
import DeviceAccess
import PresentationDataUtils

private final class PassportCarouselActionSheetItem: ActionSheetItem {
    let carousel: MediaPickerAttachmentCarouselView

    init(carousel: MediaPickerAttachmentCarouselView) {
        self.carousel = carousel
    }

    func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        return PassportCarouselActionSheetItemNode(theme: theme, carousel: self.carousel)
    }

    func updateNode(_ node: ActionSheetItemNode) {
    }
}

private final class PassportCarouselActionSheetItemNode: ActionSheetItemNode {
    private let carousel: MediaPickerAttachmentCarouselView

    init(theme: ActionSheetControllerTheme, carousel: MediaPickerAttachmentCarouselView) {
        self.carousel = carousel

        super.init(theme: theme)
    }

    override func didLoad() {
        super.didLoad()

        self.view.addSubview(self.carousel)
    }

    override func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let size = CGSize(width: constrainedSize.width, height: self.carousel.preferredHeight)
        if self.isNodeLoaded, self.carousel.superview !== self.view {
            self.view.addSubview(self.carousel)
        }
        transition.updateFrame(view: self.carousel, frame: CGRect(origin: .zero, size: size))
        self.updateInternalLayout(size, constrainedSize: constrainedSize)
        return size
    }
}

private final class PassportAttachmentFlow {
    private let context: AccountContext
    private let intent: PassportCaptureIntent
    private let policy: PassportCarouselPolicy
    private let present: (ViewController) -> Void
    private let completion: ([TelegramMediaResource]) -> Void
    private let actionSheet: ActionSheetController
    private let carousel: MediaPickerAttachmentCarouselView
    private let renderDisposable = MetaDisposable()
    private let iCloudDisposable = MetaDisposable()
    private let sendInProgress = ValuePromise<Bool>(false, ignoreRepeated: true)
    private var isRendering = false
    private var isCompleted = false
    private weak var currentGallery: ViewController?

    init(context: AccountContext, intent: PassportCaptureIntent, present: @escaping (ViewController) -> Void, completion: @escaping ([TelegramMediaResource]) -> Void) {
        self.context = context
        self.intent = intent
        self.policy = passportCarouselPolicy(intent: intent)
        self.present = present
        self.completion = completion

        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.actionSheet = ActionSheetController(presentationData: presentationData)
        self.carousel = MediaPickerAttachmentCarouselView(context: context, policy: self.policy, selfPortrait: intent == .selfie)
    }

    deinit {
        self.renderDisposable.dispose()
        self.iCloudDisposable.dispose()
    }

    func start() {
        self.carousel.openCamera = { [self] holder in
            self.openCamera(holder: holder)
        }
        self.carousel.openAsset = { [self] fetchResult, index, thumbnail in
            self.openGallery(fetchResult: fetchResult, fetchIndex: index, thumbnail: thumbnail)
        }
        self.carousel.zoomUpdated = { [self] isZoomed in
            self.actionSheet.setItemGroups(self.itemGroups(isZoomed: isZoomed))
        }
        self.carousel.cameraAccessDenied = { [self] in
            self.presentCameraAccessAlert()
        }
        self.actionSheet.dismissed = { [self] _ in
            self.carousel.stopCamera()
            self.renderDisposable.set(nil)
            self.carousel.openCamera = nil
            self.carousel.openAsset = nil
            self.carousel.zoomUpdated = nil
            self.carousel.cameraAccessDenied = nil
            self.actionSheet.dismissed = nil
        }
        self.actionSheet.setItemGroups(self.itemGroups(isZoomed: false))
        self.present(self.actionSheet)
    }

    private func itemGroups(isZoomed: Bool) -> [ActionSheetItemGroup] {
        let strings = self.context.sharedContext.currentPresentationData.with { $0 }.strings
        var items: [ActionSheetItem] = [PassportCarouselActionSheetItem(carousel: self.carousel)]
        if isZoomed {
            items.append(ActionSheetButtonItem(title: strings.Common_Done, color: .accent, font: .bold, action: { [weak self] in
                self?.sendCarouselSelection(currentItem: nil, galleryCompletion: nil, gallery: nil)
            }))
        } else {
            items.append(ActionSheetButtonItem(title: strings.Common_ChoosePhoto, color: .accent, action: { [weak self] in
                guard let self else {
                    return
                }
                self.actionSheet.dismissAnimated()
                self.openPicker()
            }))
            if self.policy.hasICloudRow {
                items.append(ActionSheetButtonItem(title: strings.Conversation_FileICloudDrive, color: .accent, action: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.actionSheet.dismissAnimated()
                    self.openICloud()
                }))
            }
        }
        return [
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet = self.actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])
        ]
    }

    private func finish(_ resources: [TelegramMediaResource]) {
        guard !self.isCompleted, !resources.isEmpty else {
            return
        }
        self.isCompleted = true
        self.actionSheet.dismissAnimated()
        self.completion(resources)
    }

    private func presentCameraAccessAlert() {
        let context = self.context
        DeviceAccess.authorizeAccess(to: .camera(.video), presentationData: context.sharedContext.currentPresentationData.with { $0 }, present: { [weak self] c, _ in
            self?.present(c)
        }, openSettings: {
            context.sharedContext.applicationBindings.openSettings()
        })
    }

    private func presentMediaUnavailableAlert(on controller: ViewController?) {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkColorPresentationTheme)
        let alert = textAlertController(
            context: self.context,
            forceTheme: defaultDarkColorPresentationTheme,
            title: nil,
            text: presentationData.strings.Story_Editor_MediaUnavailable,
            actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]
        )
        if let controller {
            controller.present(alert, in: .window(.root))
        } else {
            self.present(alert)
        }
    }

    private func openCamera(holder: CameraHolder) {
        let camera = makePassportCameraScreen(
            context: self.context,
            intent: self.intent,
            holder: holder,
            transitionIn: CameraScreenImpl.TransitionIn(
                sourceView: holder.parentView,
                sourceRect: holder.parentView.bounds,
                sourceCornerRadius: holder.parentView.layer.cornerRadius,
                useFillAnimation: false
            ),
            transitionOut: { [weak holder] _ in
                guard let holder, holder.parentView.window != nil else {
                    return nil
                }
                return CameraScreenImpl.TransitionOut(
                    destinationView: holder.parentView,
                    destinationRect: holder.parentView.bounds,
                    destinationCornerRadius: holder.parentView.layer.cornerRadius
                )
            },
            completion: { [self] resources in
                self.finish(resources)
            }
        )
        camera.transitionedOut = { [weak holder] in
            holder?.restore()
        }
        self.present(camera)
    }

    private func openGallery(fetchResult: PHFetchResult<PHAsset>, fetchIndex: Int, thumbnail: UIImage?) {
        let carousel = self.carousel
        let galleryIndex = max(0, fetchResult.count - fetchIndex - 1)
        let parameters = ChatMediaGalleryParameters(
            source: .fetchResult(fetchResult, index: galleryIndex, reversed: true),
            itemStore: carousel.itemStore,
            selectionContext: self.policy.allowsSelection ? carousel.selectionContext : nil,
            editingContext: carousel.editingContext,
            recipientName: nil,
            isActionButtonDone: true,
            isScheduledMessages: false,
            hasSendMenu: false,
            hasSilentPosting: false,
            hasSchedule: false,
            hasTimer: false,
            hasCoverButton: false,
            hasLivePhotoButton: false,
            reminder: false,
            sendWhenOnlineAvailable: .single(false),
            sendInProgress: self.sendInProgress.get(),
            immediateThumbnail: thumbnail,
            getCaptionPanelView: {
                return nil
            },
            presentSchedulePicker: { _ in
            },
            presentTimerPicker: { _ in
            },
            editCover: nil,
            transitionHostView: { [weak carousel] in
                return carousel
            },
            transitionView: { [weak carousel] identifier in
                return carousel?.transitionView(for: identifier)
            },
            updateHiddenMedia: { [weak carousel] identifier in
                carousel?.updateHiddenAsset(identifier)
            },
            finishedTransitionIn: {
            },
            willTransitionOut: {
            },
            sendSelected: { [self] item, _, _, completion in
                return self.sendCarouselSelection(currentItem: item as? TGMediaAsset, galleryCompletion: completion, gallery: self.currentGallery)
            },
            dismissAll: {
            },
            isCropOnly: true
        )
        guard let gallery = self.context.sharedContext.makeChatMediaGalleryController(context: self.context, parameters: parameters) else {
            return
        }
        self.currentGallery = gallery
        self.present(gallery)
    }

    @discardableResult
    private func sendCarouselSelection(currentItem: TGMediaAsset?, galleryCompletion: (() -> Void)?, gallery: ViewController?) -> Bool {
        guard !self.isRendering, !self.isCompleted else {
            return false
        }
        var assets: [TGMediaAsset] = []
        if self.policy.allowsSelection {
            for case let asset as TGMediaAsset in self.carousel.selectionContext.selectedItems() ?? [] {
                assets.append(asset)
            }
        }
        if assets.isEmpty, let currentItem {
            assets.append(currentItem)
        }
        let store = self.carousel.itemStore
        let items: [PassportImageItem] = assets.compactMap { asset in
            guard !asset.isVideo, let uniqueId = asset.uniqueIdentifier else {
                return nil
            }
            return PassportImageItem(uniqueId: uniqueId, source: .asset(identifier: uniqueId), values: mediaPickerChatMediaSendEditedValues(store: store, uniqueId: uniqueId))
        }
        guard !items.isEmpty else {
            return false
        }
        self.isRendering = true
        self.sendInProgress.set(true)
        self.renderDisposable.set((passportRenderedResources(context: self.context, items: items)
        |> deliverOnMainQueue).startStrict(next: { [self, weak gallery] resources in
            self.isRendering = false
            self.sendInProgress.set(false)
            if resources.isEmpty {
                self.presentMediaUnavailableAlert(on: gallery)
                return
            }
            galleryCompletion?()
            self.finish(resources)
        }))
        return true
    }

    private func openPicker() {
        let picker = passportMediaPickerController(context: self.context, multiple: self.intent == .multiple, completion: { [self] resources in
            self.finish(resources)
        })
        self.present(picker)
    }

    private func openICloud() {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let picker = legacyICloudFilePicker(theme: presentationData.theme, documentTypes: ["public.image"], completion: { [self] urls in
            guard let url = urls.first, let signal = TGPassportICloud.fetchFile(with: url) else {
                return
            }
            self.iCloudDisposable.set((Signal<UIImage?, NoError> { subscriber in
                let disposable = signal.start(next: { next in
                    if let url = next as? URL {
                        subscriber.putNext(UIImage(contentsOfFile: url.path))
                    }
                }, error: { _ in
                    subscriber.putCompletion()
                }, completed: {
                    subscriber.putCompletion()
                })
                return ActionDisposable {
                    disposable?.dispose()
                }
            }
            |> take(1)
            |> mapToSignal { image -> Signal<TelegramMediaResource?, NoError> in
                guard let image else {
                    return .single(nil)
                }
                return passportFittedImageResource(image)
            }
            |> deliverOnMainQueue).startStrict(next: { [self] resource in
                if let resource {
                    self.finish([resource])
                }
            }))
        })
        self.present(picker)
    }
}

func presentPassportAttachmentFlow(context: AccountContext, intent: PassportCaptureIntent, present: @escaping (ViewController) -> Void, completion: @escaping ([TelegramMediaResource]) -> Void) {
    let flow = PassportAttachmentFlow(context: context, intent: intent, present: present, completion: completion)
    flow.start()
}
