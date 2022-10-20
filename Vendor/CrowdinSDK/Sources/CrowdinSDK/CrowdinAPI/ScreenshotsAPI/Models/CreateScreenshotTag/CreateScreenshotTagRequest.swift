//
//  CreateScreenshotTagRequest.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 5/9/19.
//

import Foundation

typealias CreateScreenshotTagRequest = [CreateScreenshotTagRequestElement]

struct CreateScreenshotTagRequestElement: Codable {
    let stringId: Int
    let position: CreateScreenshotTagPosition
    
    enum CodingKeys: String, CodingKey {
        case stringId
        case position
    }
}

struct CreateScreenshotTagPosition: Codable {
    let x, y, width, height: Int
}
