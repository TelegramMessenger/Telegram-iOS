import Foundation
import Contacts
import AddressBook

func localizedPhoneNumberLabel(label: String, strings: PresentationStrings) -> String {
    if #available(iOSApplicationExtension 9.0, *) {
        return CNLabeledValue<CNPhoneNumber>.localizedString(forLabel: label)
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

func localizedGenericContactFieldLabel(label: String, strings: PresentationStrings) -> String {
    if #available(iOSApplicationExtension 9.0, *) {
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
