import Foundation
import Contacts
import AddressBook
import TelegramPresentationData

public func localizedPhoneNumberLabel(label: String, strings: PresentationStrings) -> String {
    if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
        if label.isEmpty {
            return strings.ContactInfo_PhoneLabelMain
        } else if label == "X-iPhone" {
            return "iPhone"
        } else {
            return CNLabeledValue<CNPhoneNumber>.localizedString(forLabel: label)
        }
    } else {
        
    }
    if label == "_$!<Mobile>!$_" {
        return "mobile"
    } else if label == "_$!<Home>!$_" {
        return "home"
    } else {
        return label
    }
}

public func localizedGenericContactFieldLabel(label: String, strings: PresentationStrings) -> String {
    if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
        if label.isEmpty {
            return strings.ContactInfo_PhoneLabelMain
        }
        return CNLabeledValue<NSString>.localizedString(forLabel: label)
    } else {
        
    }
    if label == "_$!<Mobile>!$_" {
        return "mobile"
    } else if label == "_$!<Home>!$_" {
        return "home"
    } else {
        return label
    }
}
