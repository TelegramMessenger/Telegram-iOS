import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext

func secureIdPassportCaptureIntent(_ type: SecureIdAttachmentMenuType) -> PassportCaptureIntent {
    switch type {
    case .generic:
        return .document
    case .idCard:
        return .idCard
    case .multiple:
        return .multiple
    case .selfie:
        return .selfie
    }
}

func presentSecureIdAttachmentMenu(context: AccountContext, present: @escaping (ViewController) -> Void, validLayout: ContainerViewLayout, type: SecureIdAttachmentMenuType, recognizeDocumentData: Bool, completion: @escaping ([TelegramMediaResource], SecureIdRecognizedDocumentData?) -> Void) {
    guard context.routesToChatMediaEditorV2(.passport) else {
        presentLegacySecureIdAttachmentMenu(context: context, present: present, validLayout: validLayout, type: type, recognizeDocumentData: recognizeDocumentData, completion: completion)
        return
    }
    var uploadStarted = false
    context.sharedContext.makePassportAttachmentFlow(context: context, intent: secureIdPassportCaptureIntent(type), present: present, completion: { resources in
        if uploadStarted || resources.isEmpty {
            return
        }
        uploadStarted = true
        performSecureIdAttachmentUpload(context: context, present: present, type: type, recognizeDocumentData: recognizeDocumentData, resources: .single(resources), completion: completion, completed: {
        })
    })
}
