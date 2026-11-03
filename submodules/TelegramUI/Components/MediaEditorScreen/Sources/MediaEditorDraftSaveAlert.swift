import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramPresentationData
import AlertComponent
import MediaEditor

final class MediaEditorDraftSaveAlert: AlertScreen {
    var requestClose: (() -> Bool)?
    private var allowDismiss = false

    override func dismiss(completion: (() -> Void)? = nil) {
        guard self.allowDismiss || (self.requestClose?() ?? true) else {
            return
        }
        super.dismiss(completion: completion)
    }

    func close(completion: (() -> Void)? = nil) {
        self.allowDismiss = true
        self.dismiss(completion: completion)
    }
}

extension MediaEditorScreenImpl {
    func prepareCollageMedia(_ collage: MediaEditorCollage, completion: @escaping (Bool) -> Void) {
        guard collage.isVideo else {
            completion(true)
            return
        }
        guard self.collageMediaAlert == nil else {
            completion(false)
            return
        }
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkPresentationTheme)
        var finished = false
        weak var weakAlert: MediaEditorDraftSaveAlert?
        let finish: (Bool, Bool) -> Void = { [weak self] success, cancelled in
            guard let self, !finished else {
                return
            }
            finished = true
            self.collageMediaDisposable.set(nil)
            self.collageMediaAlert = nil
            weakAlert?.close(completion: { [weak self] in
                if !success && !cancelled {
                    self?.presentCollageAlert(text: presentationData.strings.Login_UnknownError, completion: { completion(false) })
                } else {
                    completion(success)
                }
            })
        }
        let alert = MediaEditorDraftSaveAlert(
            configuration: AlertScreen.Configuration(actionAlignment: .vertical, dismissOnOutsideTap: false),
            contentSignal: .single([]),
            actionsSignal: .single([
                AlertScreen.Action(title: presentationData.strings.Channel_NotificationLoading, action: {}, autoDismiss: false, isEnabled: .single(false), progress: .single(true)),
                AlertScreen.Action(title: presentationData.strings.Common_Cancel, action: { finish(false, true) }, autoDismiss: false)
            ]),
            updatedPresentationData: (initial: presentationData, signal: self.context.sharedContext.presentationData |> map { $0.withUpdated(theme: defaultDarkPresentationTheme) })
        )
        weakAlert = alert
        alert.requestClose = {
            finish(false, true)
            return false
        }
        self.collageMediaAlert = alert
        self.present(alert, in: .window(.root))
        self.collageMediaDisposable.set((collage.prepareVideoSources() |> take(1) |> deliverOnMainQueue).start(next: { success in
            finish(success, false)
        }))
    }

    func presentCollageDraftSaveAlert(title: String, text: String, saveTitle: String) {
        guard self.collageSaveAlert == nil else {
            return
        }
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkPresentationTheme)
        let progress = ValuePromise<Bool>(false, ignoreRepeated: true)
        let enabled = progress.get() |> map { !$0 }
        let message = ValuePromise<String>(text, ignoreRepeated: true)
        var isSaving = false
        weak var weakAlert: MediaEditorDraftSaveAlert?
        let close: () -> Bool = { [weak self] in
            guard let self else {
                return true
            }
            if isSaving && !self.cancelCollageDraftSave() {
                return false
            }
            isSaving = false
            self.collageSaveAlert = nil
            return true
        }
        let alert = MediaEditorDraftSaveAlert(
            configuration: AlertScreen.Configuration(actionAlignment: .vertical, dismissOnOutsideTap: false),
            contentSignal: message.get() |> map { message in
                return [
                    AnyComponentWithIdentity(id: "title", component: AnyComponent(AlertTitleComponent(title: title))),
                    AnyComponentWithIdentity(id: "text", component: AnyComponent(AlertTextComponent(content: .plain(message))))
                ]
            },
            actionsSignal: .single([
                AlertScreen.Action(title: presentationData.strings.Story_Editor_DraftDiscard, type: .destructive, action: { [weak self] in
                    guard let self, !isSaving else {
                        return
                    }
                    self.collageSaveAlert = nil
                    weakAlert?.close(completion: { [weak self] in
                        self?.requestDismiss(saveDraft: false, animated: true)
                    })
                }, autoDismiss: false, isEnabled: enabled),
                AlertScreen.Action(title: saveTitle, action: { [weak self] in
                    guard let self, !isSaving else {
                        return
                    }
                    isSaving = true
                    progress.set(true)
                    message.set(text)
                    self.saveCollageDraft(id: nil, completion: { [weak self] result in
                        guard let self else {
                            return
                        }
                        isSaving = false
                        progress.set(false)
                        switch result {
                        case .success:
                            self.collageSaveAlert = nil
                            weakAlert?.close(completion: { [weak self] in
                                self?.requestDismiss(saveDraft: true, animated: true, draftSaved: true)
                            })
                        case let .failure(error):
                            switch error {
                            case .cancelled:
                                self.collageSaveAlert = nil
                                weakAlert?.close()
                            case .mediaUnavailable, .storage:
                                message.set(presentationData.strings.Login_UnknownError)
                            }
                        }
                    })
                }, autoDismiss: false, isEnabled: enabled, progress: progress.get()),
                AlertScreen.Action(title: presentationData.strings.Common_Cancel, action: {
                    if close() {
                        weakAlert?.close()
                    }
                }, autoDismiss: false)
            ]),
            updatedPresentationData: (initial: presentationData, signal: self.context.sharedContext.presentationData |> map { $0.withUpdated(theme: defaultDarkPresentationTheme) })
        )
        weakAlert = alert
        alert.requestClose = close
        self.collageSaveAlert = alert
        self.present(alert, in: .window(.root))
    }
}
