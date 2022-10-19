
//
//  ScreenshotProcessor.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 7/18/19.
//

import UIKit

public protocol ScreenshotProcessor {
	func process(screenshot: UIImage, with controlsInfo: [ControlInformation]) -> UIImage
}

class CrowdinScreenshotProcessor: ScreenshotProcessor {
	func process(screenshot: UIImage, with controlsInfo: [ControlInformation]) -> UIImage {
		return screenshot
	}
}
