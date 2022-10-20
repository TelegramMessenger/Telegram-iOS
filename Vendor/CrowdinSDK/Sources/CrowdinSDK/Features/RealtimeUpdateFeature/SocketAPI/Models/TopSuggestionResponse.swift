//
//  TopSuggestionResponse.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 5/19/19.
//

import Foundation

struct TopSuggestionResponse: Codable {
    let event: String?
    let data: TopSuggestionResponseData?
}

struct TopSuggestionResponseData: Codable {
    let id, userID, time, text: String?
    let wordsCount: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case time, text
        case wordsCount = "words_count"
    }
}
