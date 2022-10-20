//
//  CGRect.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 7/18/19.
//

import CoreGraphics

extension CGRect {
	var isOriginInfinite: Bool {
		return origin.x == CGFloat.infinity || origin.y == CGFloat.infinity
	}
	
	var hasValidSize: Bool {
		return size.width != 0.0 && size.height != 0.0
	}
	
	var isValid: Bool {
		return !isInfinite && !isOriginInfinite && hasValidSize
	}
}
