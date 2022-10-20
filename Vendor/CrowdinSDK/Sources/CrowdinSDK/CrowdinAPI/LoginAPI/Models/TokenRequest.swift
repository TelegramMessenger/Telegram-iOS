//
//  TokenRequest.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 8/6/19.
//

import Foundation

struct TokenRequest: Codable {
	var grantType: String = "authorization_code"
	var clientId: String
	var clientSecret: String
	var code: String
	var redirectURI: String
    
    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case clientId = "client_id"
        case clientSecret = "client_secret"
        case code
        case redirectURI = "redirect_uri"
    }
    
    init(clientId: String, clientSecret: String, code: String, redirectURI: String) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.code = code
        self.redirectURI = redirectURI
    }
}
