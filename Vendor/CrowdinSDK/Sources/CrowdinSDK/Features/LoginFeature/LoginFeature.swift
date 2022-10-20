//
//  LoginFeature.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 5/20/19.
//

import UIKit
import SafariServices

protocol LoginFeatureProtocol {
	static var shared: Self? { get }
	static var isLogined: Bool { get }
	static func configureWith(with hash: String, loginConfig: CrowdinLoginConfig)
	
	func login(completion: @escaping () -> Void, error: @escaping (Error) -> Void)
	func relogin(completion: @escaping () -> Void, error: @escaping (Error) -> Void)
	func logout()
}

final class LoginFeature: NSObject, LoginFeatureProtocol, CrowdinAuth {
	var config: CrowdinLoginConfig
	static var shared: LoginFeature?
    private var loginAPI: LoginAPI
    
    fileprivate var safariVC: SFSafariViewController?
    
    init(hashString: String, config: CrowdinLoginConfig) {
		self.config = config
        self.loginAPI = LoginAPI(clientId: config.clientId, clientSecret: config.clientSecret, scope: config.scope, redirectURI: config.redirectURI, organizationName: config.organizationName)
        super.init()
        if self.hashString != hashString {
            self.logout()
        }
        self.hashString = hashString
        NotificationCenter.default.addObserver(self, selector: #selector(receiveUnautorizedResponse), name: .CrowdinAPIUnautorizedNotification, object: nil)
	}
	
    static func configureWith(with hashString: String, loginConfig: CrowdinLoginConfig) {
        LoginFeature.shared = LoginFeature(hashString: hashString, config: loginConfig)
	}
    
    var hashString: String {
        set {
            UserDefaults.standard.set(newValue, forKey: "crowdin.hash.key")
            UserDefaults.standard.synchronize()
        }
        get {
            return UserDefaults.standard.string(forKey: "crowdin.hash.key") ?? ""
        }
    }
	
	var tokenExpirationDate: Date? {
		set {
			UserDefaults.standard.set(newValue, forKey: "crowdin.tokenExpirationDate.key")
			UserDefaults.standard.synchronize()
		}
		get {
			return UserDefaults.standard.object(forKey: "crowdin.tokenExpirationDate.key") as? Date
		}
	}
	
	var tokenResponse: TokenResponse? {
		set {
			let data = try? JSONEncoder().encode(newValue)
			UserDefaults.standard.set(data, forKey: "crowdin.tokenResponse.key")
			UserDefaults.standard.synchronize()
		}
		get {
			guard let data = UserDefaults.standard.data(forKey: "crowdin.tokenResponse.key") else { return nil }
			return try? JSONDecoder().decode(TokenResponse.self, from: data)
		}
	}
	
	static var isLogined: Bool {
		return shared?.tokenResponse?.accessToken != nil && shared?.tokenResponse?.refreshToken != nil
	}
	
	var accessToken: String? {
		guard let tokenExpirationDate = tokenExpirationDate else { return nil }
		if tokenExpirationDate < Date() {
            if let refreshToken = tokenResponse?.refreshToken, let response = loginAPI.refreshTokenSync(refreshToken: refreshToken) {
                self.tokenExpirationDate = Date(timeIntervalSinceNow: TimeInterval(response.expiresIn))
                self.tokenResponse = response
            } else {
                logout()
            }
		}
		return tokenResponse?.accessToken
	}

    var loginCompletion: (() -> Void)?  = nil
    var loginError: ((Error) -> Void)?  = nil
    
    func login(completion: @escaping () -> Void, error: @escaping (Error) -> Void) {
        self.loginCompletion = completion
        self.loginError = error
        guard let url = URL(string: loginAPI.loginURLString) else {
            error(NSError(domain: "Unable to create URL for login", code: defaultCrowdinErrorCode, userInfo: nil))
            return
        }
        
        self.showWarningAlert(with: url)
	}
	
	func relogin(completion: @escaping () -> Void, error: @escaping (Error) -> Void) {
		logout()
		login(completion: completion, error: error)
	}
	
	func logout() {
		tokenResponse = nil
		tokenExpirationDate = nil
	}
	
	func hadle(url: URL) -> Bool {
        dismissSafariVC()
        let errorHandler = loginError ?? { _ in }
        let result = loginAPI.hadle(url: url, completion: { (tokenResponse) in
            self.tokenExpirationDate = Date(timeIntervalSinceNow: TimeInterval(tokenResponse.expiresIn))
            self.tokenResponse = tokenResponse
            self.loginCompletion?()
        }, error: errorHandler)
        return result
	}
    
    @objc func receiveUnautorizedResponse() {
        // Try to refresh token.
        if let refreshToken = tokenResponse?.refreshToken, let response = loginAPI.refreshTokenSync(refreshToken: refreshToken) {
            self.tokenExpirationDate = Date(timeIntervalSinceNow: TimeInterval(response.expiresIn))
            self.tokenResponse = response
        } else {
            logout()
        }
    }
    
    fileprivate func showWarningAlert(with url: URL) {
        let alert = UIAlertController(title: "CrowdinSDK", message: "The Real-Time Preview and Screenshots features require Crowdin Authorization. You will now be redirected to the Crowdin login page.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            alert.cw_dismiss()
            self.showSafariVC(with: url)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { _ in
            alert.cw_dismiss()
        }))
        alert.cw_present()
    }
    
    fileprivate func showSafariVC(with url: URL) {
        let safariVC = SFSafariViewController(url: url)
        safariVC.delegate = self
        safariVC.cw_present()
        self.safariVC = safariVC
    }
    
    fileprivate func dismissSafariVC() {
        safariVC?.cw_dismiss()
        safariVC = nil
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension LoginFeature: SFSafariViewControllerDelegate {
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        dismissSafariVC()
    }
}
