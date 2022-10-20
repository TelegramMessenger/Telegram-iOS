//
//  CrowdinLanguage.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 09.11.2021.
//

import Foundation

protocol CrowdinLanguage {
    var id: String { get }
    var name: String { get }
    var twoLettersCode: String { get }
    var threeLettersCode: String { get }
    var locale: String { get }
    var osxCode: String { get }
    var osxLocale: String { get }
}

extension CrowdinLanguage {
    var iOSLanguageCode: String {
        return self.osxLocale.replacingOccurrences(of: "_", with: "-")
    }
}
