//
//  CrowdinSDK+Login.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 8/16/19.
//

import Foundation

extension CrowdinSDK {
	class func setupLogin() {
		// TODO: Add error log if feature isn't configured.
		guard let config = CrowdinSDK.config else { return }
		guard let loginConfig = config.loginConfig else { return }
        guard let hash = config.crowdinProviderConfig?.hashString else { return }
        LoginFeature.configureWith(with: hash, loginConfig: loginConfig)
	}
    
    @discardableResult
    public class func handle(url: URL) -> Bool {
        return LoginFeature.shared?.hadle(url: url) ?? false
    }
}
