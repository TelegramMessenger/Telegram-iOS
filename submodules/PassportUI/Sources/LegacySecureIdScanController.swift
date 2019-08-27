import Foundation
import UIKit
import Display
import LegacyComponents
import TelegramPresentationData
import LegacyUI

func legacySecureIdScanController(theme: PresentationTheme, strings: PresentationStrings, finished: @escaping (SecureIdRecognizedDocumentData?) -> Void) -> ViewController {
    let legacyController = LegacyController(presentation: .modal(animateIn: true), theme: theme, strings: strings)
    let theme = TGPassportScanControllerTheme(backgroundColor: theme.list.plainBackgroundColor, textColor: theme.list.itemPrimaryTextColor)
    let controller = TGPassportScanController(context: legacyController.context, theme: theme)!
    controller.finishedWithMRZ = { value in
        if let value = value {
            var issuingCountry: String? = nil
            if let issuingCountryValue = value.issuingCountry {
                issuingCountry = countryCodeAlpha3ToAlpha2(issuingCountryValue)
            }
            var nationality: String? = nil
            if let nationalityValue = value.nationality {
                nationality = countryCodeAlpha3ToAlpha2(nationalityValue)
            }
            finished(SecureIdRecognizedDocumentData(documentType: value.documentType, documentSubtype: value.documentSubtype, issuingCountry: issuingCountry, nationality: nationality, lastName: value.lastName.capitalized, firstName: value.firstName.capitalized, documentNumber: value.documentNumber, birthDate: value.birthDate, gender: value.gender, expiryDate: value.expiryDate))
        } else {
            finished(nil)
        }
    }
    
    let navigationController = TGNavigationController(controllers: [controller])!
    controller.navigation_setDismiss({ [weak legacyController] in
        legacyController?.dismiss()
        }, rootController: nil)
    
    legacyController.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    legacyController.bind(controller: navigationController)
    
    return legacyController
}
