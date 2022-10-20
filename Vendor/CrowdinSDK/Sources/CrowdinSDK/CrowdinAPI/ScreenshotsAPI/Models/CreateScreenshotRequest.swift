//
//  CreateScreenshotRequest.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 5/9/19.
//

import Foundation

struct CreateScreenshotRequest: Codable {
    let storageId: Int
    let name: String
    let autoTag: Bool
}
