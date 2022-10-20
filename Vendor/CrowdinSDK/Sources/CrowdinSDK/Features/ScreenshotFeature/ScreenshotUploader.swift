//
//  ScreenshotUploader.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 7/18/19.
//

import UIKit
import CoreGraphics

public protocol ScreenshotUploader {
	func uploadScreenshot(screenshot: UIImage, controlsInformation: [ControlInformation], name: String, success: (() -> Void)?, errorHandler: ((Error) -> Void)?)
}

class CrowdinScreenshotUploader: ScreenshotUploader {
    var organizationName: String? = nil
	var hash: String
	var sourceLanguage: String
	
	var mappingManager: CrowdinMappingManagerProtocol
	var projectId: Int? = nil
	
	enum Errors: String {
		case storageIdIsMissing = "Storage id is missing."
		case screenshotIdIsMissing = "Screenshot id is missing."
		case unknownError = "Unknown error."
        case noLocalizedStringsDetected = "There are no localized strings detected on current screen."
	}
	
	init(organizationName: String? = nil, hash: String, sourceLanguage: String) {
        self.organizationName = organizationName
		self.hash = hash
		self.sourceLanguage = sourceLanguage
        self.mappingManager = CrowdinMappingManager(hash: hash, sourceLanguage: sourceLanguage)
	}
	
	func loginAndGetProjectId(success: (() -> Void)? = nil, errorHandler: ((Error) -> Void)? = nil) {
        if LoginFeature.isLogined {
            self.getProjectId(success: success, errorHandler: errorHandler)
        } else if let loginFeature = LoginFeature.shared {
            loginFeature.login(completion: {
                self.getProjectId(success: success, errorHandler: errorHandler)
            }) { err in
                errorHandler?(err)
            }
        } else {
            errorHandler?(NSError(domain: "Login feature is not configured properly", code: defaultCrowdinErrorCode, userInfo: nil))
        }
	}
	
	func getProjectId(success: (() -> Void)? = nil, errorHandler: ((Error) -> Void)? = nil) {
        let distrinbutionsAPI = DistributionsAPI(hashString: hash, organizationName: organizationName, auth: LoginFeature.shared)
		distrinbutionsAPI.getDistribution { (response, error) in
			if let error = error {
				errorHandler?(error)
			} else if let id = response?.data.project.id, let projectId = Int(id) {
				self.projectId = projectId
				success?()
                CrowdinLogsCollector.shared.add(log: CrowdinLog(type: .info, message: "Get distribution success"))
			} else {
				errorHandler?(NSError(domain: Errors.unknownError.rawValue, code: defaultCrowdinErrorCode, userInfo: nil))
                CrowdinLogsCollector.shared.add(log: CrowdinLog(type: .info, message: "Get distribution failed - \(Errors.unknownError.rawValue)"))
			}
		}
	}
	
	func uploadScreenshot(screenshot: UIImage, controlsInformation: [ControlInformation], name: String, success: (() -> Void)?, errorHandler: ((Error) -> Void)?) {
		guard let projectId = self.projectId else {
			self.loginAndGetProjectId(success: {
				DispatchQueue.main.async {
					self.uploadScreenshot(screenshot: screenshot, controlsInformation: controlsInformation, name: name, success: success, errorHandler: errorHandler)
				}
			}, errorHandler: errorHandler)
			return
		}
        let values = self.proceed(controlsInformation: controlsInformation)
        guard values.count > 0 else {
            errorHandler?(NSError(domain: Errors.noLocalizedStringsDetected.rawValue, code: defaultCrowdinErrorCode, userInfo: nil))
            return
        }
        
		guard let data = screenshot.pngData() else { return }
		let screenshotsAPI = ScreenshotsAPI(organizationName: organizationName, auth: LoginFeature.shared)
        let storageAPI = StorageAPI(organizationName: organizationName, auth: LoginFeature.shared)
		storageAPI.uploadNewFile(data: data, completion: { response, error in
			if let error = error {
				errorHandler?(error)
				return
			}
			guard let storageId = response?.data.id else {
				errorHandler?(NSError(domain: Errors.storageIdIsMissing.rawValue, code: defaultCrowdinErrorCode, userInfo: nil))
				return
			}
			screenshotsAPI.createScreenshot(projectId: projectId, storageId: storageId, name: name, completion: { response, error in
				if let error = error {
					errorHandler?(error)
					return
				}
				guard let screenshotId = response?.data.id else {
					errorHandler?(NSError(domain: Errors.screenshotIdIsMissing.rawValue, code: defaultCrowdinErrorCode, userInfo: nil))
					return
				}
				screenshotsAPI.createScreenshotTags(projectId: projectId, screenshotId: screenshotId, frames: values, completion: { (_, error) in
					if let error = error {
						errorHandler?(error)
					} else {
						success?()
					}
				})
			})
		})
	}
	
	func proceed(controlsInformation: [ControlInformation]) -> [(id: Int, rect: CGRect)] {
		var results = [(id: Int, rect: CGRect)]()
		controlsInformation.forEach { (controlInformation) in
			if let id = mappingManager.id(for: controlInformation.key) {
				results.append((id: id, rect: controlInformation.rect))
			}
		}
		return results
	}
}
