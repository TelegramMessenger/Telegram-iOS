import Foundation
import Postbox
import TelegramApi


extension UnauthorizedAccountTermsOfService {
    init?(apiTermsOfService: Api.help.TermsOfService) {
        switch apiTermsOfService {
            case let .termsOfService(termsOfServiceData):
                let (_, id, text, entities, minAgeConfirm) = (termsOfServiceData.flags, termsOfServiceData.id, termsOfServiceData.text, termsOfServiceData.entities, termsOfServiceData.minAgeConfirm)
                let idData: String
                switch id {
                    case let .dataJSON(dataJSONData):
                        let data = dataJSONData.data
                        idData = data
                }
                self.init(id: idData, text: text, entities: messageTextEntitiesFromApiEntities(entities), ageConfirmation: minAgeConfirm)
        }
    }
}

extension SentAuthorizationCodeType {
    init(apiType: Api.auth.SentCodeType) {
        switch apiType {
            case let .sentCodeTypeApp(sentCodeTypeAppData):
                let length = sentCodeTypeAppData.length
                self = .otherSession(length: length)
            case let .sentCodeTypeSms(sentCodeTypeSmsData):
                let length = sentCodeTypeSmsData.length
                self = .sms(length: length)
            case let .sentCodeTypeCall(sentCodeTypeCallData):
                let length = sentCodeTypeCallData.length
                self = .call(length: length)
            case let .sentCodeTypeFlashCall(sentCodeTypeFlashCallData):
                let pattern = sentCodeTypeFlashCallData.pattern
                self = .flashCall(pattern: pattern)
            case let .sentCodeTypeMissedCall(sentCodeTypeMissedCallData):
                let (prefix, length) = (sentCodeTypeMissedCallData.prefix, sentCodeTypeMissedCallData.length)
                self = .missedCall(numberPrefix: prefix, length: length)
            case let .sentCodeTypeEmailCode(sentCodeTypeEmailCodeData):
                let (flags, emailPattern, length, resetAvailablePeriod, resetPendingDate) = (sentCodeTypeEmailCodeData.flags, sentCodeTypeEmailCodeData.emailPattern, sentCodeTypeEmailCodeData.length, sentCodeTypeEmailCodeData.resetAvailablePeriod, sentCodeTypeEmailCodeData.resetPendingDate)
                self = .email(emailPattern: emailPattern, length: length, resetAvailablePeriod: resetAvailablePeriod, resetPendingDate: resetPendingDate, appleSignInAllowed: (flags & (1 << 0)) != 0, setup: false)
            case let .sentCodeTypeSetUpEmailRequired(sentCodeTypeSetUpEmailRequiredData):
                let flags = sentCodeTypeSetUpEmailRequiredData.flags
                self = .emailSetupRequired(appleSignInAllowed: (flags & (1 << 0)) != 0)
            case let .sentCodeTypeFragmentSms(sentCodeTypeFragmentSmsData):
                let (url, length) = (sentCodeTypeFragmentSmsData.url, sentCodeTypeFragmentSmsData.length)
                self = .fragment(url: url, length: length)
            case let .sentCodeTypeFirebaseSms(sentCodeTypeFirebaseSmsData):
                let (pushTimeout, length) = (sentCodeTypeFirebaseSmsData.pushTimeout, sentCodeTypeFirebaseSmsData.length)
                self = .firebase(pushTimeout: pushTimeout, length: length)
            case let .sentCodeTypeSmsWord(sentCodeTypeSmsWordData):
                let beginning = sentCodeTypeSmsWordData.beginning
                self = .word(startsWith: beginning)
            case let .sentCodeTypeSmsPhrase(sentCodeTypeSmsPhraseData):
                let beginning = sentCodeTypeSmsPhraseData.beginning
                self = .phrase(startsWith: beginning)
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
            case .codeTypeMissedCall:
                self = .missedCall
            case .codeTypeFragmentSms:
                self = .fragment
        }
    }
}
