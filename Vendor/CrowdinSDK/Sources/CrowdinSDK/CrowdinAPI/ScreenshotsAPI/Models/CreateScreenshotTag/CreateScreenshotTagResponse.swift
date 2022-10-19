//
//  CreateScreenshotTagResponse.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 5/9/19.
//

import Foundation

struct CreateScreenshotTagResponse: Codable {
    let data: [CreateScreenshotTagDatum]
    let pagination: CreateScreenshotTagPagination
}

struct CreateScreenshotTagDatum: Codable {
    let data: CreateScreenshotTagData
}

struct CreateScreenshotTagData: Codable {
    let id, screenshotId, stringId: Int
    let position: CreateScreenshotTagPosition
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case screenshotId
        case stringId
        case position, createdAt
    }
}

struct CreateScreenshotTagPagination: Codable {
    let offset, limit: Int
}
