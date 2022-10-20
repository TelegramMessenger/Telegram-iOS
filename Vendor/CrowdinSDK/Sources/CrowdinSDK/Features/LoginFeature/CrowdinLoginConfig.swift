//
//  CrowdinLoginConfig.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 8/16/19.
//

import Foundation

private let URLSchemeDocumentationLink = "https://developer.apple.com/documentation/uikit/inter-process_communication/allowing_apps_and_websites_to_link_to_your_content/defining_a_custom_url_scheme_for_your_app"

@objcMembers public class CrowdinLoginConfig: NSObject {
	var clientId: String
	var clientSecret: String
	var scope: String
	var redirectURI: String
	var organizationName: String? = nil
    
    public convenience init(clientId: String, clientSecret: String, scope: String) throws {
        guard let redirectURI = Bundle.main.urlSchemes?.first else { throw NSError(domain: "Application do not support any URL Scheme. To setup it, please check - \(URLSchemeDocumentationLink)", code: defaultCrowdinErrorCode, userInfo: nil) }
        try self.init(with: clientId, clientSecret: clientSecret, scope: scope, redirectURI: redirectURI, organizationName: nil)
    }
    
    public convenience init(clientId: String, clientSecret: String, scope: String, redirectURI: String) throws {
        try self.init(with: clientId, clientSecret: clientSecret, scope: scope, redirectURI: redirectURI, organizationName: nil)
    }
    
    public convenience init(clientId: String, clientSecret: String, scope: String, organizationName: String) throws {
        guard let redirectURI = Bundle.main.urlSchemes?.first else { throw NSError(domain: "Application do not support any URL Scheme. To setup it, please check - \(URLSchemeDocumentationLink)", code: defaultCrowdinErrorCode, userInfo: nil) }
        try self.init(with: clientId, clientSecret: clientSecret, scope: scope, redirectURI: redirectURI, organizationName: organizationName)
    }
    
    public convenience init(clientId: String, clientSecret: String, scope: String, redirectURI: String, organizationName: String) throws {
        try self.init(with: clientId, clientSecret: clientSecret, scope: scope, redirectURI: redirectURI, organizationName: organizationName)
    }
    
    private init(with clientId: String, clientSecret: String, scope: String, redirectURI: String, organizationName: String? = nil) throws {
        guard !clientId.isEmpty else { throw NSError(domain: "clientId could not be empty.", code: defaultCrowdinErrorCode, userInfo: nil) }
        self.clientId = clientId
        guard !clientSecret.isEmpty else { throw NSError(domain: "clientSecret could not be empty.", code: defaultCrowdinErrorCode, userInfo: nil) }
        self.clientSecret = clientSecret
        guard !scope.isEmpty else { throw NSError(domain: "scope could not be empty.", code: defaultCrowdinErrorCode, userInfo: nil) }
        self.scope = scope
        guard !redirectURI.isEmpty else { throw NSError(domain: "redirectURI could not be empty.", code: defaultCrowdinErrorCode, userInfo: nil) }
        guard let urlSchemes = Bundle.main.urlSchemes, urlSchemes.contains(redirectURI) else { throw NSError(domain: "Application supported url schemes should contain \(redirectURI)", code: defaultCrowdinErrorCode, userInfo: nil) }
        self.redirectURI = redirectURI
        self.organizationName = organizationName
	}
}
