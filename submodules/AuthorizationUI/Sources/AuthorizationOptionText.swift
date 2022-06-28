import Foundation
import UIKit
import TelegramCore
import Display
import TelegramPresentationData
import TextFormat
import Markdown

public func authorizationCurrentOptionText(_ type: SentAuthorizationCodeType, strings: PresentationStrings, primaryColor: UIColor, accentColor: UIColor) -> NSAttributedString {
    switch type {
    case .sms:
        return NSAttributedString(string: strings.Login_CodeSentSms, font: Font.regular(16.0), textColor: primaryColor, paragraphAlignment: .center)
    case .otherSession:
        let body = MarkdownAttributeSet(font: Font.regular(16.0), textColor: primaryColor)
        let bold = MarkdownAttributeSet(font: Font.semibold(16.0), textColor: primaryColor)
        return parseMarkdownIntoAttributedString(strings.Login_CodeSentInternal, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in nil }), textAlignment: .center)
    case .missedCall:
        let body = MarkdownAttributeSet(font: Font.regular(16.0), textColor: primaryColor)
        let bold = MarkdownAttributeSet(font: Font.semibold(16.0), textColor: primaryColor)
        return parseMarkdownIntoAttributedString(strings.Login_ShortCallTitle, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in nil }), textAlignment: .center)
    case .call:
        return NSAttributedString(string: strings.Login_CodeSentCall, font: Font.regular(16.0), textColor: primaryColor, paragraphAlignment: .center)
    case .flashCall:
        return NSAttributedString(string: strings.ChangePhoneNumberCode_Called, font: Font.regular(16.0), textColor: primaryColor, paragraphAlignment: .center)
    }
}

public func authorizationNextOptionText(currentType: SentAuthorizationCodeType, nextType: AuthorizationCodeNextType?, timeout: Int32?, strings: PresentationStrings, primaryColor: UIColor, accentColor: UIColor) -> (NSAttributedString, Bool) {
    if let nextType = nextType, let timeout = timeout, timeout > 0 {
        let minutes = timeout / 60
        let seconds = timeout % 60
        switch nextType {
        case .sms:
            if timeout <= 0 {
                return (NSAttributedString(string: strings.Login_CodeSentSms, font: Font.regular(16.0), textColor: primaryColor, paragraphAlignment: .center), false)
            } else {
                let timeString = NSString(format: "%d:%.02d", Int(minutes), Int(seconds))
                return (NSAttributedString(string: strings.Login_WillSendSms(timeString as String).string, font: Font.regular(16.0), textColor: primaryColor, paragraphAlignment: .center), false)
            }
        case .call:
            if timeout <= 0 {
                return (NSAttributedString(string: strings.Login_CodeSentCall, font: Font.regular(16.0), textColor: primaryColor, paragraphAlignment: .center), false)
            } else {
                return (NSAttributedString(string: String(format: strings.ChangePhoneNumberCode_CallTimer(String(format: "%d:%.2d", minutes, seconds)).string, minutes, seconds), font: Font.regular(16.0), textColor: primaryColor, paragraphAlignment: .center), false)
            }
        case .flashCall, .missedCall:
            if timeout <= 0 {
                return (NSAttributedString(string: strings.ChangePhoneNumberCode_Called, font: Font.regular(16.0), textColor: primaryColor, paragraphAlignment: .center), false)
            } else {
                return (NSAttributedString(string: String(format: strings.ChangePhoneNumberCode_CallTimer(String(format: "%d:%.2d", minutes, seconds)).string, minutes, seconds), font: Font.regular(16.0), textColor: primaryColor, paragraphAlignment: .center), false)
            }
        }
    } else {
        switch currentType {
        case .otherSession:
            switch nextType {
            case .sms:
                return (NSAttributedString(string: strings.Login_SendCodeViaSms, font: Font.regular(16.0), textColor: accentColor, paragraphAlignment: .center), true)
            case .call:
                return (NSAttributedString(string: strings.Login_SendCodeViaCall, font: Font.regular(16.0), textColor: accentColor, paragraphAlignment: .center), true)
            case .flashCall, .missedCall:
                return (NSAttributedString(string: strings.Login_SendCodeViaFlashCall, font: Font.regular(16.0), textColor: accentColor, paragraphAlignment: .center), true)
            case .none:
                return (NSAttributedString(string: strings.Login_HaveNotReceivedCodeInternal, font: Font.regular(16.0), textColor: accentColor, paragraphAlignment: .center), true)
            }
        default:
            switch nextType {
            case .sms:
                return (NSAttributedString(string: strings.Login_SendCodeViaSms, font: Font.regular(16.0), textColor: accentColor, paragraphAlignment: .center), true)
            case .call:
                return (NSAttributedString(string: strings.Login_SendCodeViaCall, font: Font.regular(16.0), textColor: accentColor, paragraphAlignment: .center), true)
            case .flashCall, .missedCall:
                return (NSAttributedString(string: strings.Login_SendCodeViaFlashCall, font: Font.regular(16.0), textColor: accentColor, paragraphAlignment: .center), true)
            case .none:
                return (NSAttributedString(string: strings.Login_HaveNotReceivedCodeInternal, font: Font.regular(16.0), textColor: accentColor, paragraphAlignment: .center), true)
            }
        }
    }
}
