//
//  LoginAPI.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 29.10.2019.
//

import Foundation
import BaseAPI

class LoginAPI: BaseAPI {
    fileprivate let defaultCrowdinErrorCode = 9999
    var organizationName: String?
    var clientId: String
    var clientSecret: String
    var scope: String
    var redirectURI: String
    
    init(clientId: String, clientSecret: String, scope: String, redirectURI: String, organizationName: String? = nil, session: URLSession = URLSession.shared) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.scope = scope
        self.redirectURI = redirectURI
        self.organizationName = organizationName
        super.init(session: session)
    }
    
    var loginURLString: String {
        if let organizationName = organizationName {
            return "https://accounts.crowdin.com/oauth/authorize?client_id=\(clientId)&response_type=code&scope=\(scope)&redirect_uri=\(redirectURI)&domain=\(organizationName)"
        }
        return "https://accounts.crowdin.com/oauth/authorize?client_id=\(clientId)&response_type=code&scope=\(scope)&redirect_uri=\(redirectURI)"
    }
    
    private var tokenStringURL: String {
        if let organizationName = organizationName {
            return"https://accounts.crowdin.com/oauth/token?domain=\(organizationName)"
        }
        return "https://accounts.crowdin.com/oauth/token"
    }
    
    func hadle(url: URL, completion: @escaping (TokenResponse) -> Void, error: @escaping (Error) -> Void) -> Bool {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        guard let queryItems = components?.queryItems else { return false }
        guard let code = queryItems.first(where: { $0.name == "code" })?.value else { return false }
        self.getAutorizationToken(with: code, success: completion, error: error)
        return true
    }
    
    func getAutorizationToken(with code: String, success: ((TokenResponse) -> Void)?, error: ((Error) -> Void)?) {
        guard let url = URL(string: tokenStringURL) else {
            error?(NSError(domain: "Unable to create url from - \(tokenStringURL)", code: defaultCrowdinErrorCode, userInfo: nil))
            return
        }
        var request = URLRequest(url: url)
        let tokenRequest = TokenRequest(clientId: clientId, clientSecret: clientSecret, code: code, redirectURI: redirectURI)
        request.httpBody = try? JSONEncoder().encode(tokenRequest)
        request.allHTTPHeaderFields = [:]
        request.allHTTPHeaderFields?["Content-Type"] = "application/json"
        request.httpMethod = "POST"
        let errorHandler = error
        
        self.send(request: request) { (data, response, error) in
            if let data = data {
                do {
                    let response = try JSONDecoder().decode(TokenResponse.self, from: data)
                    success?(response)
                } catch {
                    errorHandler?(error)
                }
            } else if let error = error {
                errorHandler?(error)
            } else {
                errorHandler?(NSError(domain: "Unknown error", code: self.defaultCrowdinErrorCode, userInfo: nil))
            }
        }
    }
    
    func refreshToken(refreshToken: String, success: ((TokenResponse) -> Void)?, error: ((Error) -> Void)?) {
        guard let url = URL(string: tokenStringURL) else { return }
        var request = URLRequest(url: url)
        let tokenRequest = RefreshTokenRequest(clientId: clientId, clientSecret: clientSecret, redirectURI: redirectURI, refreshToken: refreshToken)
        request.httpBody = try? JSONEncoder().encode(tokenRequest)
        request.allHTTPHeaderFields = [:]
        request.allHTTPHeaderFields?["Content-Type"] = "application/json"
        request.httpMethod = "POST"
        let errorHandler = error
        self.send(request: request) { (data, response, error) in
            if let data = data {
                do {
                    let response = try JSONDecoder().decode(TokenResponse.self, from: data)
                    success?(response)
                } catch {
                    errorHandler?(error)
                }
            } else if let error = error {
                errorHandler?(error)
            } else {
                errorHandler?(NSError(domain: "Unknown error", code: self.defaultCrowdinErrorCode, userInfo: nil))
            }
        }
    }
    
    func refreshTokenSync(refreshToken: String) -> TokenResponse? {
        var result: TokenResponse? = nil
        let semaphore = DispatchSemaphore(value: 0)
        self.refreshToken (refreshToken: refreshToken, success: { response in
            result = response
            semaphore.signal()
        }) { _ in
            result = nil
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }
}
