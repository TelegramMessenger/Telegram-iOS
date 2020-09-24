//
//  PremiumIntroControllerGet.swift
//  SettingsUI
//
//  Created by Sergey on 27.10.2019.
//  Copyright © 2019 Nicegram. All rights reserved.
//

import Foundation
import TelegramPermissionsUI
import TelegramPermissions
import TelegramPresentationData
import AccountContext
import Display
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import AlertUI
import NGData
import NGStrings
import StoreKit

extension SKProduct {
    
    var localizedPrice: String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = priceLocale
        return formatter.string(from: price)
    }
    
}

public func getPremiumIntroController(context: AccountContext, presentationData: PresentationData, product: SKProduct) -> PremiumIntroController {
    
    
    let locale = presentationData.strings.baseLanguageCode
    
    let title = l("IAP.Premium.Title", locale)
    let subtitle = l("IAP.Premium.Subtitle", locale)
    let text = l("IAP.Premium.Features", locale)
    
    let buttonTitle = product.localizedPrice ?? "Free"
    
    
    let controller = PremiumIntroController(context: context, splashScreen: true)
    controller.setState(.custom(icon: PremiumIntroControllerCustomIcon(light: UIImage(bundleImageName: "PremiumIntro"), dark: nil), title: title, subtitle: subtitle, text: text, buttonTitle: buttonTitle, footerText: nil), animated: true)
    controller.navigationPresentation = .master
    
    
    
    return controller
}


public func getIAPErrorController(context: AccountContext, _ text: String, _ presentationData: PresentationData) -> AlertController {
    
    let errorController =
        standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: l(text, presentationData.strings.baseLanguageCode), actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})])
    return errorController
}


public func getPremiumActivatedAlert(context: AccountContext, _ title: String, _ text: String, _ presentationData: PresentationData, action: @escaping () -> Void ) -> AlertController {

    let Controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: title, text: l(text, presentationData.strings.baseLanguageCode), actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {action()})])
    return Controller
    
}
