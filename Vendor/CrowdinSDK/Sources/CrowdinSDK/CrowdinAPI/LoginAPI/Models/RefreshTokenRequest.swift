//
//  RefreshTokenRequest.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 8/12/19.
//

import Foundation

struct RefreshTokenRequest: Codable {
	var grantType: String = "refresh_token"
	var clientId: String
	var clientSecret: String
	var redirectURI: String
	var refreshToken: String
	
    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case clientId = "client_id"
        case clientSecret = "client_secret"
        case redirectURI = "redirect_uri"
        case refreshToken = "refresh_token"
    }
    
    init(clientId: String, clientSecret: String, redirectURI: String, refreshToken: String) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.redirectURI = redirectURI
        self.refreshToken = refreshToken
    }
}
