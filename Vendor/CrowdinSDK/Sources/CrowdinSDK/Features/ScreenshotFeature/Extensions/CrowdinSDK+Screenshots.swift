//
//  CrowdinSDK+ScreenshotFeature.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 6/1/19.
//

import UIKit

extension CrowdinSDK {
    @objc class func initializeScreenshotFeature() {
        guard let config = CrowdinSDK.config else { return }
        if config.screenshotsEnabled {
            let crowdinProviderConfig = config.crowdinProviderConfig ?? CrowdinProviderConfig()
            let screenshotUploader = CrowdinScreenshotUploader(organizationName: config.loginConfig?.organizationName, hash: crowdinProviderConfig.hashString, sourceLanguage: crowdinProviderConfig.sourceLanguage)
            ScreenshotFeature.shared = ScreenshotFeature(screenshotUploader: screenshotUploader, screenshotProcessor: CrowdinScreenshotProcessor())
            swizzleControlMethods()
        }
    }
    
    public class func captureScreenshot(name: String, success: @escaping (() -> Void), errorHandler: @escaping ((Error?) -> Void)) {
        guard let screenshotFeature = ScreenshotFeature.shared else {
            errorHandler(NSError(domain: "Screenshots feature disabled", code: defaultCrowdinErrorCode, userInfo: nil))
            return
        }
        screenshotFeature.captureScreenshot(name: name, success: success, errorHandler: errorHandler)
    }
    
    public class func captureScreenshot(view: UIView, name: String, success: @escaping (() -> Void), errorHandler: @escaping ((Error?) -> Void)) {
        guard let screenshotFeature = ScreenshotFeature.shared else {
            errorHandler(NSError(domain: "Screenshots feature disabled", code: defaultCrowdinErrorCode, userInfo: nil))
            return
        }
        screenshotFeature.captureScreenshot(view: view, name: name, success: success, errorHandler: errorHandler)
    }
}
