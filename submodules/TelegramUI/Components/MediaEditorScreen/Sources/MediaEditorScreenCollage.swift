import Foundation
import UIKit
import Photos
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import MediaEditor
import ComponentFlow
import AlertComponent

func mediaEditorCollageSubject(_ collage: MediaEditorCollage) -> MediaEditorScreenImpl.Subject? {
    if !collage.isVideo {
        guard let image = collage.image() else {
            return nil
        }
        return .image(image: image, dimensions: PixelDimensions(collage.size), additionalImage: nil, additionalImagePosition: .topLeft, fromCamera: false)
    }
    var items: [MediaEditorScreenImpl.Subject.VideoCollageItem] = []
    for item in collage.items {
        let content: MediaEditorScreenImpl.Subject.VideoCollageItem.Content
        switch item.source {
        case let .image(image, _):
            content = .image(image)
        case let .imageFile(path):
            guard let image = mediaEditorCollageImage(path: path) else {
                return nil
            }
            content = .image(image)
        case let .videoFile(path):
            content = .video(path, item.duration)
        case let .videoAsset(asset):
            content = .asset(asset)
        }
        items.append(MediaEditorScreenImpl.Subject.VideoCollageItem(content: content, frame: item.frame, contentScale: item.contentScale, contentOffset: item.contentOffset, id: item.id, isMain: item.id == collage.mainItemId))
    }
    return .videoCollage(items: items)
}

extension MediaEditorScreenImpl {
    func resolveCollageDraft(_ draft: MediaEditorDraft) {
        guard let manifest = draft.collage else {
            return
        }
        let resolutionId = UUID()
        self.collageResolutionId = resolutionId
        let engine = self.context.engine
        Queue.concurrentDefaultQueue().async { [weak self] in
            let result = Swift.Result { try manifest.resolve(engine: engine) }
            Queue.mainQueue().async {
                guard let self, self.collageResolutionId == resolutionId else {
                    return
                }
                switch result {
                case let .success(resolved):
                    if let collage = resolved.collage {
                        self.openCollage(collage, draft: draft)
                    } else {
                        self.node.readyForCollage()
                        self.presentCollageAlert(text: self.context.sharedContext.currentPresentationData.with { $0 }.strings.Story_Editor_CollageDraftAllMediaMissing, completion: { [weak self] in
                            guard let self else {
                                return
                            }
                            if case let .draft(_, id) = self.node.actualSubject, id == nil {
                                removeStoryDraft(engine: self.context.engine, path: draft.path, delete: true)
                            }
                            self.requestDismiss(saveDraft: false, animated: true, discardDraft: false)
                        })
                    }
                case .failure:
                    self.node.readyForCollage()
                    self.presentCollageAlert(text: self.context.sharedContext.currentPresentationData.with { $0 }.strings.Login_UnknownError, completion: { [weak self] in
                        self?.requestDismiss(saveDraft: false, animated: true, discardDraft: false)
                    })
                }
            }
        }
    }

    func openCollage(_ collage: MediaEditorCollage, draft: MediaEditorDraft?, mediaPrepared: Bool = false) {
        if draft != nil, collage.isVideo, !mediaPrepared {
            self.node.readyForCollage()
            self.prepareCollageMedia(collage) { [weak self] success in
                guard let self else {
                    return
                }
                if success {
                    self.openCollage(collage, draft: draft, mediaPrepared: true)
                } else {
                    self.requestDismiss(saveDraft: false, animated: true, discardDraft: false)
                }
            }
            return
        }
        let resolutionId = self.collageResolutionId
        Queue.concurrentDefaultQueue().async { [weak self] in
            // Decoding and composing full-size photos must not block the picker transition.
            let subject = mediaEditorCollageSubject(collage)
            Queue.mainQueue().async {
                guard let self, self.collageResolutionId == resolutionId else {
                    return
                }
                guard let subject else {
                    self.node.readyForCollage()
                    self.presentCollageAlert(text: self.context.sharedContext.currentPresentationData.with { $0 }.strings.Login_UnknownError, completion: { [weak self] in
                        self?.requestDismiss(saveDraft: false, animated: true, discardDraft: false)
                    })
                    return
                }
                self.collage = collage
                self.node.setup(subject: subject, privacy: draft?.privacy, values: draft.map { collage.valuesForEditor($0.values, resetVideoTimeline: $0.collage?.mainItemId != collage.mainItemId) }, caption: draft?.caption, isDraft: draft != nil)
            }
        }
    }

    func presentCollageAlert(text: String, completion: @escaping () -> Void = {}) {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkPresentationTheme)
        Queue.mainQueue().justDispatch { [weak self] in
            guard let self else {
                return
            }
            weak var weakAlert: MediaEditorDraftSaveAlert?
            var finished = false
            let close = {
                guard !finished else {
                    return
                }
                finished = true
                weakAlert?.close(completion: completion)
            }
            let alert = MediaEditorDraftSaveAlert(
                configuration: AlertScreen.Configuration(dismissOnOutsideTap: false),
                contentSignal: .single([AnyComponentWithIdentity(id: "text", component: AnyComponent(AlertTextComponent(content: .plain(text))))]),
                actionsSignal: .single([AlertScreen.Action(title: presentationData.strings.Common_OK, type: .default, action: close, autoDismiss: false)]),
                updatedPresentationData: (initial: presentationData, signal: self.context.sharedContext.presentationData |> map { $0.withUpdated(theme: defaultDarkPresentationTheme) })
            )
            weakAlert = alert
            alert.requestClose = {
                close()
                return false
            }
            self.present(alert, in: .window(.root))
        }
    }
}
