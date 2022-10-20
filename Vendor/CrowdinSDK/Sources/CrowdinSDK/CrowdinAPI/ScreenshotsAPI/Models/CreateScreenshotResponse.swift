//
//  CreateScreenshotResponse.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 5/9/19.
//

import Foundation

struct CreateScreenshotResponse: Codable {
    let data: CreateScreenshotData
}

struct CreateScreenshotData: Codable {
    let id, userID: Int
    let url, name: String
    let size: CreateScreenshotSize
    let tagsCount: Int
    let tags: [CreateScreenshotTag]
    let createdAt, updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userID = "userId"
        case url, name, size, tagsCount, tags, createdAt, updatedAt
    }
}

struct CreateScreenshotSize: Codable {
    let width, height: Int
}

struct CreateScreenshotTag: Codable {
    let id, screenshotID, stringID: Int
    let position: CreateScreenshotPosition
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case screenshotID = "screenshotId"
        case stringID = "stringId"
        case position, createdAt
    }
}

struct CreateScreenshotPosition: Codable {
    let x, y, width, height: Int
}
