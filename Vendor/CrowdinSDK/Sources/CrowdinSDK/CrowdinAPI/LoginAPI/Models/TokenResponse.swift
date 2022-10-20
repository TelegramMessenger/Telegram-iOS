//
//  TokenResponse.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 8/11/19.
//

import Foundation

public struct TokenResponse: Codable {
	public let tokenType: String
	public let expiresIn: Int
	public let accessToken: String
	public let refreshToken: String
	
	enum CodingKeys: String, CodingKey {
		case tokenType = "token_type"
		case expiresIn = "expires_in"
		case accessToken = "access_token"
		case refreshToken = "refresh_token"
	}
}
