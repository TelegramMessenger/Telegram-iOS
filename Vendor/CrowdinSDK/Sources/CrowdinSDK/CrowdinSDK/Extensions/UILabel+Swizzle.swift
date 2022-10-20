//
//  UILabel.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 1/23/19.
//

import Foundation
import UIKit

// MARK: -  extension with core functionality for language substitution.
extension UILabel {
    /// Association object for storing localization key.
    private static let localizationKeyAssociation = ObjectAssociation<String>()
    
    /// Localization key.
    var localizationKey: String? {
        get { return UILabel.localizationKeyAssociation[self] }
        set { UILabel.localizationKeyAssociation[self] = newValue }
    }
	
    ///  Association object for storing localization format string values if such exists.
	private static let localizationValuesAssociation = ObjectAssociation<[Any]>()
	
    /// Array with localization format string values.
	var localizationValues: [Any]? {
		get { return UILabel.localizationValuesAssociation[self] }
		set { UILabel.localizationValuesAssociation[self] = newValue }
	}
    
    // swiftlint:disable implicitly_unwrapped_optional
    /// Original text method.
    static var originalText: Method!
    
    /// Swizzled text method.
    static var swizzledText: Method!
    
    /// Original attributedText method.
    static var originalAttributedText: Method!
    
    /// Swizzled attributedText method.
    static var swizzledAttributedText: Method!
    
    static var isSwizzled: Bool {
        return originalText != nil && swizzledText != nil && originalAttributedText != nil && swizzledAttributedText != nil
    }
    
    /// Swizzled implementation for set text method.
    ///
    /// - Parameter text: Title string.
    @objc func swizzled_setText(_ text: String?) {
		proceed(text: text)
        swizzled_setText(text)
    }
    
    /// Swizzled implementation for set attributed text method.
    ///
    /// - Parameter attributedText: Attributed title string.
    @objc func swizzled_setAttributedText(_ attributedText: NSAttributedString?) {
        // TODO: Add saving attributes.
        proceed(text: attributedText?.string)
        swizzled_setAttributedText(attributedText)
    }
    
    /// Method for string processing. Include localization key detection and storing.
    ///
    /// - Parameter text: Title text.
    func proceed(text: String?) {
        if let text = text {
            self.localizationKey = Localization.current.keyForString(text)
            
            if self.localizationKey != nil {
                self.subscribeForRealtimeUpdatesIfNeeded()
            }
            
            if let key = localizationKey, let string = Localization.current.localizedString(for: key), string.isFormated {
                self.localizationValues = Localization.current.findValues(for: text, with: string)
            }
        } else {
            self.localizationKey = nil
            self.localizationValues = nil
            self.unsubscribeFromRealtimeUpdatesIfNeeded()
        }
    }
    
    /// Original method for setting title string after swizzling.
    ///
    /// - Parameter text: Title text.
    func original_setText(_ text: String) {
        guard UILabel.swizzledText != nil else { return }
        swizzled_setText(text)
    }
    
    /// Original method for setting attributed title string after swizzling.
    ///
    /// - Parameter attributedText: Attributed title text.
    func original_setAttributedText(_ attributedText: NSAttributedString?) {
        // TODO: Add saving attributes.
        guard UILabel.swizzledAttributedText != nil else { return }
        swizzled_setAttributedText(attributedText)
    }

    /// Method for swizzling implementations for text and attributedText methods.
    /// Note: This method should be called only when we need to get localization key from localization string, currently it is needed for screenshots and realtime preview features.
    class func swizzle() {
        // swiftlint:disable force_unwrapping
        originalText = class_getInstanceMethod(self, #selector(setter: UILabel.text))!
        swizzledText = class_getInstanceMethod(self, #selector(UILabel.swizzled_setText(_:)))!
        method_exchangeImplementations(originalText, swizzledText)
        
        originalAttributedText = class_getInstanceMethod(self, #selector(setter: UILabel.attributedText))!
        swizzledAttributedText = class_getInstanceMethod(self, #selector(UILabel.swizzled_setAttributedText(_:)))!
        method_exchangeImplementations(originalAttributedText, swizzledAttributedText)
    }
    
    /// Method for swizzling implementations back for text and attributedText methods.
    class func unswizzle() {
        if originalText != nil && swizzledText != nil {
            method_exchangeImplementations(swizzledText, originalText)
            originalText = nil
            swizzledText = nil
        }
        if originalAttributedText != nil && swizzledAttributedText != nil {
            method_exchangeImplementations(originalAttributedText, swizzledAttributedText)
            originalAttributedText = nil
            swizzledAttributedText = nil
        }
    }
    
    /// Selectors for working with real-time updates.
    ///
    /// - subscribeForRealtimeUpdates: Method for subscribing to real-time updates.
    /// - unsubscribeForRealtimeUpdates: Method for unsubscribing from real-time updates.
    enum Selectors: Selector {
        case subscribeForRealtimeUpdates
        case unsubscribeFromRealtimeUpdates
    }
    
    /// Method for subscription to real-time updates if real-time feature enabled.
    func subscribeForRealtimeUpdatesIfNeeded() {
        if self.responds(to: Selectors.subscribeForRealtimeUpdates.rawValue) {
            self.perform(Selectors.subscribeForRealtimeUpdates.rawValue)
        }
    }
    
    /// Method for unsubscribing from real-time updates if real-time feature enabled.
    func unsubscribeFromRealtimeUpdatesIfNeeded() {
        if self.responds(to: Selectors.unsubscribeFromRealtimeUpdates.rawValue) {
            self.perform(Selectors.unsubscribeFromRealtimeUpdates.rawValue)
        }
    }
}
