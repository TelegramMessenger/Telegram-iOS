import Foundation
#if os(macOS)
    import PostboxMac
    import TelegramApiMac
#else
    import Postbox
    import TelegramApi
#endif

import SyncCore

extension UnauthorizedAccountTermsOfService {
    init?(apiTermsOfService: Api.help.TermsOfService) {
        switch apiTermsOfService {
            case let .termsOfService(_, id, text, entities, minAgeConfirm):
                let idData: String
                switch id {
                    case let .dataJSON(data):
                        idData = data
                }
                self.init(id: idData, text: text, entities: messageTextEntitiesFromApiEntities(entities), ageConfirmation: minAgeConfirm)
        }
    }
}

extension SentAuthorizationCodeType {
    init(apiType: Api.auth.SentCodeType) {
        switch apiType {
            case let .sentCodeTypeApp(length):
                self = .otherSession(length: length)
            case let .sentCodeTypeSms(length):
                self = .sms(length: length)
            case let .sentCodeTypeCall(length):
                self = .call(length: length)
            case let .sentCodeTypeFlashCall(pattern):
                self = .flashCall(pattern: pattern)
        }
    }
}

extension AuthorizationCodeNextType {
    init(apiType: Api.auth.CodeType) {
        switch apiType {
            case .codeTypeSms:
                self = .sms
            case .codeTypeCall:
                self = .call
            case .codeTypeFlashCall:
                self = .flashCall
        }
    }
}
