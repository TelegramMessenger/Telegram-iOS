//
//  UpdateDraftResponse.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 5/19/19.
//

import Foundation

struct UpdateDraftResponse: Codable {
    let event: String?
    let data: UpdateDraftResponseData?
}

struct UpdateDraftResponseData: Codable {
    let text, pluralForm: String?
}
