//
//  LanguagesAPI.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 3/26/19.
//

import Foundation

class LanguagesAPI: CrowdinAPI {
    enum Strings: String {
        case languages
        case limit
        case offset
    }
    
    override var apiPath: String { return Strings.languages.rawValue }
    
    func getLanguages(limit: Int, offset: Int, completion: @escaping (LanguagesResponse?, Error?) -> Void) {
        let parameters = [Strings.limit.rawValue: String(limit), Strings.offset.rawValue: String(offset)]
        self.cw_get(url: fullPath, parameters: parameters, completion: completion)
    }
    
    func getLanguagesSync(limit: Int, offset: Int) -> (LanguagesResponse?, Error?) {
        let parameters = [Strings.limit.rawValue: String(limit), Strings.offset.rawValue: String(offset)]
        return self.cw_getSync(url: fullPath, parameters: parameters)
    }
}
