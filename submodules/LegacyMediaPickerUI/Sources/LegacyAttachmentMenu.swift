import Foundation
import UIKit
import LegacyComponents
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import DeviceAccess
import AccountContext
import LegacyUI
import SaveToCameraRoll
import Photos

public func defaultVideoPresetForContext(_ context: AccountContext) -> TGMediaVideoConversionPreset {
    var networkType: NetworkType = .wifi
    let _ = (context.account.networkType
    |> take(1)).start(next: { value in
        networkType = value
    })
    
    let autodownloadSettings = context.sharedContext.currentAutodownloadSettings.with { $0 }
    let presetSettings: AutodownloadPresetSettings
    switch networkType {
    case .wifi:
        presetSettings = autodownloadSettings.highPreset
    default:
        presetSettings = autodownloadSettings.mediumPreset
    }
    
    let effectiveValue: Int
    if presetSettings.videoUploadMaxbitrate == 0 {
        effectiveValue = 0
    } else {
        effectiveValue = Int(presetSettings.videoUploadMaxbitrate) * 5 / 100
    }
    
    switch effectiveValue {
    case 0:
        return TGMediaVideoConversionPresetCompressedMedium
    case 1:
        return TGMediaVideoConversionPresetCompressedVeryLow
    case 2:
        return TGMediaVideoConversionPresetCompressedLow
    case 3:
        return TGMediaVideoConversionPresetCompressedMedium
    case 4:
        return TGMediaVideoConversionPresetCompressedHigh
    case 5:
        return TGMediaVideoConversionPresetCompressedVeryHigh
    default:
        return TGMediaVideoConversionPresetCompressedMedium
    }
}

public enum LegacyMediaEditorMode {
    /// The animated-media (GIF) editor.
    case `default`
    case caption
    case draw
    case adjustments
    /// The editor for a photo or a regular video with no tool preselected.
    case plain
}

public func legacyWallpaperEditor(context: AccountContext, item: TGMediaEditableItem, cropRect: CGRect, adjustments: TGMediaEditAdjustments?, referenceView: UIView, beginTransitionOut: ((Bool) -> Void)?, finishTransitionOut: (() -> Void)?, completion: @escaping (UIImage?, TGMediaEditAdjustments?) -> Void, fullSizeCompletion: @escaping (UIImage?) -> Void, present: @escaping (ViewController, Any?) -> Void) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let legacyController = LegacyController(presentation: .custom, theme: presentationData.theme, initialLayout: nil)
    legacyController.blocksBackgroundWhenInOverlay = true
    legacyController.acceptsFocusWhenInOverlay = true
    legacyController.statusBar.statusBarStyle = .Ignore
    legacyController.controllerLoaded = { [weak legacyController] in
        legacyController?.view.disablesInteractiveTransitionGestureRecognizer = true
    }

    let emptyController = LegacyEmptyController(context: legacyController.context)!
    emptyController.navigationBarShouldBeHidden = true
    let navigationController = makeLegacyNavigationController(rootController: emptyController)
    navigationController.setNavigationBarHidden(true, animated: false)
    legacyController.bind(controller: navigationController)

    legacyController.enableSizeClassSignal = true
    
    present(legacyController, nil)
    
    TGPhotoVideoEditor.present(with: legacyController.context, controller: emptyController, with: item, cropRect: cropRect, adjustments: adjustments, referenceView: referenceView, completion: { image, adjustments in
        completion(image, adjustments)
    }, fullSizeCompletion: { image in
        Queue.mainQueue().async {
            fullSizeCompletion(image)
        }
    }, beginTransitionOut: { saving in
        beginTransitionOut?(saving)
    }, finishTransitionOut: { [weak legacyController] in
        legacyController?.dismiss()
        finishTransitionOut?()
    })
}

public enum StoryMediaEditorResult {
    case image(UIImage)
    case video(String)
    case asset(PHAsset)
}

public func legacyStoryMediaEditor(context: AccountContext, item: TGMediaEditableItem & TGMediaSelectableItem, getCaptionPanelView: @escaping () -> TGCaptionPanelView?, completion: @escaping (StoryMediaEditorResult) -> Void, present: @escaping (ViewController, Any?) -> Void) {
    let paintStickersContext = LegacyPaintStickersContext(context: context)
    paintStickersContext.captionPanelView = {
        return getCaptionPanelView()
    }
    
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let legacyController = LegacyController(presentation: .custom, theme: presentationData.theme, initialLayout: nil)
    legacyController.blocksBackgroundWhenInOverlay = true
    legacyController.acceptsFocusWhenInOverlay = true
    legacyController.statusBar.statusBarStyle = .Ignore
    legacyController.controllerLoaded = { [weak legacyController] in
        legacyController?.view.disablesInteractiveTransitionGestureRecognizer = true
    }

    let emptyController = LegacyEmptyController(context: legacyController.context)!
    emptyController.navigationBarShouldBeHidden = true
    let navigationController = makeLegacyNavigationController(rootController: emptyController)
    navigationController.setNavigationBarHidden(true, animated: false)
    legacyController.bind(controller: navigationController)

    legacyController.enableSizeClassSignal = true
    
    present(legacyController, nil)
    
    TGPhotoVideoEditor.present(with: legacyController.context, controller: emptyController, caption: NSAttributedString(), withItem: item, paint: false, adjustments: false, recipientName: "", stickersContext: paintStickersContext, from: .zero, mainSnapshot: nil, snapshots: [] as [Any], immediate: true, activateInput: false, isGif: false, hasSilentPosting: false, hasSchedule: false, reminder: false, presentSchedulePicker: { _, _ in }, appeared: {
        
    }, completion: { result, editingContext, _, _ in
        var completionResult: Signal<StoryMediaEditorResult, NoError>
        if let photo = result as? TGCameraCapturedPhoto {
            if let _ = editingContext.adjustments(for: result) {
                completionResult = .single(.image(photo.existingImage))
            } else {
                completionResult = .single(.image(photo.existingImage))
            }
        } else if let video = result as? TGCameraCapturedVideo {
            completionResult = .single(.video(video.immediateAVAsset.url.absoluteString))
        } else if let asset = result as? TGMediaAsset {
            completionResult = .single(.asset(asset.backingAsset))
        } else {
            completionResult = .complete()
        }
        let _ = (completionResult
        |> deliverOnMainQueue).start(next: { value in
            completion(value)
        })
    }, dismissed: { [weak legacyController] in
        legacyController?.dismiss()
    })
}

public func legacyMediaEditor(
    context: AccountContext,
    peer: EnginePeer,
    threadTitle: String?,
    media: AnyMediaReference,
    mode: LegacyMediaEditorMode,
    initialCaption: NSAttributedString,
    snapshots: [UIView],
    transitionCompletion: (() -> Void)?,
    getCaptionPanelView: @escaping () -> TGCaptionPanelView?,
    photoToolbarView: ((TGPhotoEditorBackButton, TGPhotoEditorDoneButton, Bool, Bool) -> (UIView & TGPhotoToolbarViewProtocol)?)? = nil,
    hasSilentPosting: Bool = false,
    hasSchedule: Bool = false,
    reminder: Bool = false,
    presentSchedulePicker: @escaping (Bool, @escaping (Int32, Bool) -> Void) -> Void = { _, _ in },
    sendMessagesWithSignals: @escaping ([Any]?, Bool, Int32, Bool) -> Void,
    present: @escaping (ViewController, Any?) -> Void
) {
    let _ = (fetchMediaData(context: context, userLocation: .other, mediaReference: media)
    |> deliverOnMainQueue).start(next: { (value, isImage) in
        guard case let .data(data) = value, data.isComplete else {
            return
        }
        
        let isGif = [.default, .caption].contains(mode)
        let item: TGMediaEditableItem & TGMediaSelectableItem
        if let image = UIImage(contentsOfFile: data.path) {
            item = TGCameraCapturedPhoto(existing: image)
        } else {
            item = TGCameraCapturedVideo(url: URL(fileURLWithPath: data.path), isAnimation: isGif)
        }
        
        let paintStickersContext = LegacyPaintStickersContext(context: context)
        paintStickersContext.captionPanelView = {
            return getCaptionPanelView()
        }
        paintStickersContext.photoToolbarView = photoToolbarView
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let recipientName: String
        if let threadTitle {
            recipientName = threadTitle
        } else {
            if peer.id == context.account.peerId {
                recipientName = presentationData.strings.DialogList_SavedMessages
            } else {
                recipientName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
            }
        }
        
        let legacyController = LegacyController(presentation: .custom, theme: presentationData.theme, initialLayout: nil)
        legacyController.blocksBackgroundWhenInOverlay = true
        legacyController.acceptsFocusWhenInOverlay = true
        legacyController.statusBar.statusBarStyle = .Ignore
        paintStickersContext.presentMediaPickerSendActionMenu = makeLegacyMediaPickerSendActionMenuPresenter(context: context, presentationData: presentationData, presentInGlobalOverlay: { [weak legacyController] controller in
            if let legacyController {
                legacyController.presentInGlobalOverlay(controller)
            } else if let mainWindow = context.sharedContext.mainWindow {
                mainWindow.presentInGlobalOverlay(controller)
            } else {
                context.sharedContext.presentGlobalController(controller, nil)
            }
        })
        legacyController.controllerLoaded = { [weak legacyController] in
            legacyController?.view.disablesInteractiveTransitionGestureRecognizer = true
        }
        legacyController.presentationCompleted = {
            Queue.mainQueue().after(0.1) {
                transitionCompletion?()
            }
        }
        
        let schedulePicker: (Bool, @escaping (Int32, Bool) -> Void) -> Void = { media, done in
            presentSchedulePicker(media, done)
        }
        let appeared: () -> Void = {
        }
        let completion: (TGMediaEditableItem, TGMediaEditingContext, Bool, Int32) -> Void = { result, editingContext, silentPosting, scheduleTime in
            let nativeGenerator = legacyAssetPickerItemGenerator()
            var selectableResult: TGMediaSelectableItem?
            selectableResult = unsafeDowncast(result, to: TGMediaSelectableItem.self)
            
            let signals = TGCameraController.resultSignals(for: nil, editingContext: editingContext, currentItem: selectableResult, storeAssets: false, saveEditedPhotos: false, descriptionGenerator: { _1, _2, _3 in
                nativeGenerator(_1, _2, _3, nil)
            })
            let isCaptionAbove = editingContext.isCaptionAbove()
            sendMessagesWithSignals(signals, silentPosting, scheduleTime, isCaptionAbove)
        }
        let dismissed: () -> Void = { [weak legacyController] in
            legacyController?.dismiss()
        }
        
        legacyController.enableSizeClassSignal = true
        
        let galleryController = TGPhotoVideoEditor.controller(
            with: legacyController.context,
            caption: initialCaption,
            withItem: item,
            paint: mode == .draw,
            adjustments: mode == .adjustments,
            recipientName: recipientName,
            stickersContext: paintStickersContext,
            from: .zero,
            mainSnapshot: nil,
            snapshots: snapshots as [Any],
            immediate: transitionCompletion != nil,
            activateInput: mode == .caption,
            isGif: isGif,
            hasSilentPosting: hasSilentPosting,
            hasSchedule: hasSchedule,
            reminder: reminder,
            presentSchedulePicker: schedulePicker,
            appeared: appeared,
            completion: completion,
            dismissed: dismissed
        )
        legacyController.bind(controller: galleryController)
        present(legacyController, nil)
    })
}
    
public func legacyMenuPaletteFromTheme(_ theme: PresentationTheme, forceDark: Bool) -> TGMenuSheetPallete {
    let sheetTheme: PresentationThemeActionSheet
    if forceDark && !theme.overallDarkAppearance {
        sheetTheme = defaultDarkColorPresentationTheme.actionSheet
    } else {
        sheetTheme = theme.actionSheet
    }
    return TGMenuSheetPallete(dark: forceDark || theme.overallDarkAppearance, backgroundColor: sheetTheme.opaqueItemBackgroundColor, selectionColor: sheetTheme.opaqueItemHighlightedBackgroundColor, separatorColor: sheetTheme.opaqueItemSeparatorColor, accentColor: sheetTheme.controlAccentColor, destructiveColor: sheetTheme.destructiveActionTextColor, textColor: sheetTheme.primaryTextColor, secondaryTextColor: sheetTheme.secondaryTextColor, spinnerColor: sheetTheme.secondaryTextColor, badgeTextColor: sheetTheme.controlAccentColor, badgeImage: nil, cornersImage: generateStretchableFilledCircleImage(diameter: 11.0, color: nil, strokeColor: nil, strokeWidth: nil, backgroundColor: sheetTheme.opaqueItemBackgroundColor))
}
