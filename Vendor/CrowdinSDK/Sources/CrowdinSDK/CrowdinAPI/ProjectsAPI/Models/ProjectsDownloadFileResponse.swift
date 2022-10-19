//
//  ProjectsDownloadFileResponse.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 09.02.2020.
//

import Foundation

struct ProjectsDownloadFileResponse: Codable {
    var data: ProjectsDownloadFileResponseData
    
    enum CodingKeys: String, CodingKey {
        case data
    }
}

struct ProjectsDownloadFileResponseData: Codable {
    var url: String
    var expireIn: String
    
    enum CodingKeys: String, CodingKey {
        case url
        case expireIn
    }
}
