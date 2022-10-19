//
//  ScreenshotFeature.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 1/26/19.
//

import UIKit

class ScreenshotFeature {
    static var shared: ScreenshotFeature?
	var screenshotUploader: ScreenshotUploader
	var screenshotProcessor: ScreenshotProcessor
	
	init(screenshotUploader: ScreenshotUploader, screenshotProcessor: ScreenshotProcessor) {
		self.screenshotUploader = screenshotUploader
		self.screenshotProcessor = screenshotProcessor
	}
	
    func captureScreenshot(name: String, success: @escaping (() -> Void), errorHandler: @escaping ((Error?) -> Void)) {
        guard let window = UIApplication.shared.cw_KeyWindow, let vc = window.topViewController() else {
			errorHandler(NSError(domain: "Unable to create screenshot.", code: defaultCrowdinErrorCode, userInfo: nil))
			return
		}
        self.captureScreenshot(view: vc.view, name: name, success: success, errorHandler: errorHandler)
    }
    
    func captureScreenshot(view: UIView, name: String, success: @escaping (() -> Void), errorHandler: @escaping ((Error?) -> Void)) {
        guard let screenshot = view.screenshot else {
            errorHandler(NSError(domain: "Unable to create screenshot.", code: defaultCrowdinErrorCode, userInfo: nil))
            return
        }
        let controlsInformation = ScreenshotInformationCollector.getControlsInformation(from: view, rootView: view)
        screenshotUploader.uploadScreenshot(screenshot: screenshot, controlsInformation: controlsInformation, name: name, success: success, errorHandler: errorHandler)
    }
}
