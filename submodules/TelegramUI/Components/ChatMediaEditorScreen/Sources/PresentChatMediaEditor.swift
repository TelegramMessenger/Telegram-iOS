import Foundation
import UIKit
import AVFoundation
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import LocalizedPeerData
import LegacyComponents
import LegacyMediaPickerUI
import SaveToCameraRoll
import ChatMediaSend

public func chatMediaEditorInitialTool(_ mode: LegacyMediaEditorMode) -> ChatMediaEditorInitialTool? {
    switch mode {
    case .plain:
        return ChatMediaEditorInitialTool.none
    case .draw:
        return .paint
    case .adjustments:
        return .tools
    case .caption:
        return .caption
    case .default:
        return ChatMediaEditorInitialTool.none
    }
}

public func chatMediaEditorIsAnimation(mode: LegacyMediaEditorMode, mediaIsAnimated: Bool) -> Bool {
    return mediaIsAnimated && (mode == .default || mode == .caption)
}

public func chatMediaEditorRecipientName(context: AccountContext, peer: EnginePeer, threadTitle: String?) -> String {
    if let threadTitle {
        return threadTitle
    }
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    if peer.id == context.account.peerId {
        return presentationData.strings.DialogList_SavedMessages
    }
    return peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
}

public func presentChatMediaEditor(
    context: AccountContext,
    media: AnyMediaReference,
    initialTool: ChatMediaEditorInitialTool,
    initialCaption: NSAttributedString,
    recipientName: String?,
    getCaptionPanelView: @escaping () -> TGCaptionPanelView?,
    hasSilentPosting: Bool,
    hasSchedule: Bool,
    reminder: Bool,
    presentSchedulePicker: @escaping (@escaping (Int32, Bool) -> Void) -> Void,
    isAnimation: Bool,
    originalMediaReference: (() -> AnyMediaReference?)?,
    sendMessages: @escaping (Signal<[LegacyAssetPickerEnqueueMessage], Void>, _ silentPosting: Bool, _ scheduleTime: Int32, _ isCaptionAbove: Bool) -> Void,
    present: @escaping (ViewController, Any?) -> Void
) {
    let _ = (fetchMediaData(context: context, userLocation: .other, mediaReference: media)
    |> deliverOnMainQueue).start(next: { value, _ in
        guard case let .data(data) = value, data.isComplete else {
            return
        }

        let subject: ChatMediaEditorSubject
        if let image = UIImage(contentsOfFile: data.path) {
            subject = .image(image)
        } else {
            guard let file = media.media as? TelegramMediaFile else {
                return
            }
            var path = data.path
            if (path as NSString).pathExtension.isEmpty, let mp4Path = context.engine.resources.completedResourcePath(id: EngineMediaResource.Id(file.resource.id), pathExtension: "mp4") {
                path = mp4Path
            }
            guard let parameters = chatMediaEditorVideoParameters(file: file, path: path) else {
                return
            }
            subject = .video(path: path, dimensions: parameters.dimensions, duration: parameters.duration)
        }

        let controller = ChatMediaEditorScreen(
            context: context,
            subject: subject,
            initialTool: initialTool,
            initialCaption: initialCaption,
            recipientName: recipientName,
            getCaptionPanelView: getCaptionPanelView,
            hasSilentPosting: hasSilentPosting,
            hasSchedule: hasSchedule,
            reminder: reminder,
            presentSchedulePicker: presentSchedulePicker,
            isAnimation: isAnimation,
            completion: { result, silentPosting, scheduleTime, isCaptionAbove in
                sendMessages(chatMediaEditorEnqueueMessages(context: context, result: result, forceHd: chatMediaEditorSendsForceHd, originalMediaReference: originalMediaReference?()), silentPosting, scheduleTime, isCaptionAbove)
            }
        )
        present(controller, nil)
    })
}

private func chatMediaEditorVideoParameters(file: TelegramMediaFile, path: String) -> (dimensions: PixelDimensions, duration: Double)? {
    var attributeParameters: (dimensions: PixelDimensions, duration: Double)?
    for attribute in file.attributes {
        if case let .Video(duration, size, _, _, _, _) = attribute {
            attributeParameters = (size, duration)
            break
        }
    }
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    let trackSize = asset.tracks(withMediaType: .video).first.flatMap { track in
        return track.naturalSize.applying(track.preferredTransform)
    }
    return chatMediaEditorResolveVideoParameters(trackSize: trackSize, assetDuration: asset.duration.seconds, attribute: attributeParameters)
}

public func chatMediaEditorResolveVideoParameters(trackSize: CGSize?, assetDuration: Double, attribute: (dimensions: PixelDimensions, duration: Double)?) -> (dimensions: PixelDimensions, duration: Double)? {
    var dimensions: PixelDimensions?
    if let trackSize {
        let width = Int32(abs(trackSize.width).rounded())
        let height = Int32(abs(trackSize.height).rounded())
        if width > 0, height > 0 {
            dimensions = PixelDimensions(width: width, height: height)
        }
    }
    var duration: Double?
    if assetDuration.isFinite, assetDuration > 0.0 {
        duration = assetDuration
    }
    if dimensions == nil, let attribute, attribute.dimensions.width > 0, attribute.dimensions.height > 0 {
        dimensions = attribute.dimensions
    }
    if duration == nil, let attribute, attribute.duration.isFinite, attribute.duration > 0.0 {
        duration = attribute.duration
    }
    guard let dimensions, let duration else {
        return nil
    }
    return (dimensions, duration)
}
