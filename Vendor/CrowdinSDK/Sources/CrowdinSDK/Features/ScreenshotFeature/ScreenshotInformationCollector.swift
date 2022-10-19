//
//  ScreenshotInformationCollector.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 7/18/19.
//

import UIKit
import CoreGraphics

public struct ControlInformation {
	var key: String
	var rect: CGRect
}

class ScreenshotInformationCollector {
    static let scale = UIScreen.main.scale
    
	class func captureControlsInformation() -> [ControlInformation] {
        guard let window = UIApplication.shared.cw_KeyWindow, let topViewController = window.topViewController() else { return [] }
        return self.getControlsInformation(from: topViewController.view, rootView: topViewController.view)
	}
	
    class func getControlsInformation(from view: UIView, rootView: UIView) -> [ControlInformation] {
		var description = [ControlInformation]()
		view.subviews.forEach { subview in
            guard !subview.isHidden && subview.alpha != 0.0 else { return }
			if let label = subview as? UILabel, let localizationKey = label.localizationKey {
				if let frame = label.superview?.convert(label.frame, to: rootView), rootView.bounds.contains(frame), frame.isValid { // Check wheather control frame is visible on screen.
                    let newRect = CGRect(x: frame.origin.x * scale, y: frame.origin.y * scale, width: frame.size.width * scale, height: frame.size.height * scale)
                    description.append(ControlInformation(key: localizationKey, rect: newRect))
				}
			}
            description.append(contentsOf: getControlsInformation(from: subview, rootView: rootView))
		}
        return description
	}
}
