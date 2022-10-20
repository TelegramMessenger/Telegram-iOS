//
//  DistributionsResponse.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 5/19/19.
//

import Foundation

// MARK: - DistributionsResponse
public struct DistributionsResponse: Codable {
    public let data: DistributionsResponseData
    
    enum CodingKeys: String, CodingKey {
        case data
    }
    
    public init(data: DistributionsResponseData) {
        self.data = data
    }
}

// MARK: - DistributionsResponseData
public struct DistributionsResponseData: Codable {
    public let project: DistributionsResponseProject
    public let user: DistributionsResponseUser
	public let wsUrl: String
	
    enum CodingKeys: String, CodingKey {
        case project
        case user
		case wsUrl
    }
    
    public init(project: DistributionsResponseProject, user: DistributionsResponseUser, wsUrl: String) {
        self.project = project
        self.user = user
		self.wsUrl = wsUrl
    }
}

// MARK: - DistributionsResponseProject
public struct DistributionsResponseProject: Codable {
    public let id: String
    public let wsHash: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case wsHash
    }
    
    public init(id: String, wsHash: String) {
        self.id = id
        self.wsHash = wsHash
    }
}

// MARK: - DistributionsResponseUser
public struct DistributionsResponseUser: Codable {
    public let id: String
    
    enum CodingKeys: String, CodingKey {
        case id
    }
    
    public init(id: String) {
        self.id = id
    }
}
