//
//  File.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 02.11.2021.
//

import Foundation

struct CustomLangugage {
    let id: String
    let locale: String
    let twoLettersCode: String
    let threeLettersCode: String
    let localeWithUnderscore: String
    let androidCode: String
    let osxCode: String
    let osxLocale: String
    
    init(id: String, customLanguage: ManifestResponse.ManifestResponseCustomLangugage) {
        self.id = id
        self.locale = customLanguage.locale
        self.twoLettersCode = customLanguage.twoLettersCode
        self.threeLettersCode = customLanguage.threeLettersCode
        self.localeWithUnderscore = customLanguage.localeWithUnderscore
        self.androidCode = customLanguage.androidCode
        self.osxCode = customLanguage.osxCode
        self.osxLocale = customLanguage.osxLocale
    }
}

extension ManifestResponse {
    var customLanguages: [CustomLangugage] {
        return responseCustomLanguages?.compactMap({ (key: String, value: ManifestResponseCustomLangugage) in
            CustomLangugage(id: key, customLanguage: value)
        }) ?? []
    }
}

extension CustomLangugage: CrowdinLanguage {
    var name: String {
        return id
    }
}
