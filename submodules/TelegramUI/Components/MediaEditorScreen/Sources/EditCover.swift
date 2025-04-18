import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import TextFormat

public extension MediaEditorScreenImpl {
    static func makeEditVideoCoverController(
        context: AccountContext,
        video: MediaEditorScreenImpl.Subject,
        completed: @escaping () -> Void = {},
        willDismiss: @escaping () -> Void = {},
        update: @escaping (Disposable?) -> Void
    ) -> MediaEditorScreenImpl? {
        let controller = MediaEditorScreenImpl(
            context: context,
            mode: .storyEditor,
            subject: .single(video),
            isEditing: true,
            isEditingCover: true,
            forwardSource: nil,
            initialCaption: nil,
            initialPrivacy: nil,
            initialMediaAreas: nil,
            initialVideoPosition: 0.0,
            transitionIn: .noAnimation,
            transitionOut: { finished, isNew in
                return nil
            },
            completion: { result, commit in
                if let _ = result.coverTimestamp {
                    
                }
                commit({})
            }
        )
        controller.willDismiss = willDismiss
        controller.navigationPresentation = .flatModal
                
        return controller
    }
}
