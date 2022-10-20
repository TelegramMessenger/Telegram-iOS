//
//  UIButton+Swizzle.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 1/27/19.
//

import UIKit

// MARK: - Extension with all control states property.
extension UIControl.State {
    static let all: [UIControl.State] = [.normal, .selected, .disabled, .highlighted]
}

// MARK: - UIButton extension with core functionality for language substitution.
extension UIButton {
    /// Association object for storing localization keys for different states.
    private static let localizationKeyAssociation = ObjectAssociation<[UInt: String]>()
    
    /// Dictionary with localization keys for different states.
    var localizationKeys: [UInt: String]? {
        get { return UIButton.localizationKeyAssociation[self] }
        set { UIButton.localizationKeyAssociation[self] = newValue }
    }
    
    /// Method for getting localization key for given state.
    ///
    /// - Parameter state: Button state.
    /// - Returns: Localization key for passed state.
    func localizationKey(for state: UIControl.State) -> String? {
        return localizationKeys?[state.rawValue]
    }
    
    /// Association object for storing localization format string values if such exists.
    private static let localizationValuesAssociation = ObjectAssociation<[UInt: [Any]]>()
    
    /// Dictionary with localization format string values for different state.
    var localizationValues: [UInt: [Any]]? {
        get { return UIButton.localizationValuesAssociation[self] }
        set { UIButton.localizationValuesAssociation[self] = newValue }
    }
    
    /// Method for getting localization format string values for given state.
    ///
    /// - Parameter state: Button state.
    /// - Returns: Localization format string values for given state.
    func localizationValues(for state: UIControl.State) -> [Any]? {
        return localizationValues?[state.rawValue]
    }
    
    /// Association object for storing localization format string values if such exists.
    private static let usingAttributedTitleAssociation = ObjectAssociation<Bool>()
    
    /// Store boolean value which indicates whether title was set as attributed string.
    var usingAttributedTitle: Bool {
        get { return UIButton.usingAttributedTitleAssociation[self] ?? false }
        set { UIButton.usingAttributedTitleAssociation[self] = newValue }
    }
    
    // swiftlint:disable implicitly_unwrapped_optional
    /// Original setTitle(_:for:) method.
    static var originalSetTitle: Method!
    /// Swizzled setTitle(_:for:) method.
    static var swizzledSetTitle: Method!
    /// Original setAttributedTitle(_:for:) method.
    static var originalSetAttributedTitle: Method!
    /// Swizzled setAttributedTitle(_:for:) method.
    static var swizzledSetAttributedTitle: Method!
    
    static var isSwizzled: Bool {
        return originalSetTitle != nil && swizzledSetTitle != nil && originalSetAttributedTitle != nil && swizzledSetAttributedTitle != nil
    }
    
    /// Swizzled implementation for setTitle(_:for:) method.
    ///
    /// - Parameters:
    ///   - title: Title string.
    ///   - state: The state that uses the specified title.
    @objc func swizzled_setTitle(_ title: String?, for state: UIControl.State) {
        proceed(title: title, for: state)
        swizzled_setTitle(title, for: state)
        usingAttributedTitle = false
    }
    
    /// Swizzled implementation for setAttributedTitle(_:for:) method.
    ///
    /// - Parameters:
    ///   - title: Title attributed string.
    ///   - state: The state that uses the specified title.
    @objc func swizzled_setAttributedTitle(_ title: NSAttributedString?, for state: UIControl.State) {
        // TODO: Add saving attributes.
        let titleString = title?.string
        proceed(title: titleString, for: state)
        swizzled_setAttributedTitle(title, for: state)
        usingAttributedTitle = true
    }
    
    /// Method for title string processing. Detect localization key for this string and store all needed values for this string.
    ///
    /// - Parameters:
    ///   - title: Title string to proceed.
    ///   - state: The state that uses the specified title.
    func proceed(title: String?, for state: UIControl.State) {
        if let title = title {
            if let key = Localization.current.keyForString(title) {
                // Try to find values for key (formated strings, plurals)
                if let string = Localization.current.localizedString(for: key), string.isFormated {
                    if let values = Localization.current.findValues(for: title, with: string) {
                        // Store values in localizationValues
                        if var localizationValues = self.localizationValues {
                            localizationValues.merge(with: [state.rawValue: values])
                            self.localizationValues = localizationValues
                        } else {
                            self.localizationValues = [state.rawValue: values]
                        }
                    }
                }
                // Store key in localizationKeys
                if var localizationKeys = self.localizationKeys {
                    localizationKeys.merge(with: [state.rawValue: key])
                    self.localizationKeys = localizationKeys
                } else {
                    self.localizationKeys = [state.rawValue: key]
                }
            }
            self.subscribeForRealtimeUpdatesIfNeeded()
        } else {
            self.localizationKeys?[state.rawValue] = nil
            self.localizationValues?[state.rawValue] = nil
            self.unsubscribeFromRealtimeUpdatesIfNeeded()
        }
    }
    
    func cw_setTitle(_ title: String?, for state: UIControl.State) {
        if usingAttributedTitle {
            // TODO: Apply attributes.
            original_setAttributedTitle(NSAttributedString(string: title ?? ""), for: state)
        } else {
            original_setTitle(title, for: state)
        }
    }
    
    /// Original method for setting title string for button after swizzling.
    ///
    /// - Parameters:
    ///   - title: Title string.
    ///   - state: The state that uses the specified title.
    private func original_setTitle(_ title: String?, for state: UIControl.State) {
        guard UIButton.swizzledSetTitle != nil else { return }
        swizzled_setTitle(title, for: state)
    }
    
    /// Original method for setting attributed title string for button after swizzling.
    ///
    /// - Parameters:
    ///   - title: Title attributed string.
    ///   - state: The state that uses the specified title.
    private func original_setAttributedTitle(_ title: NSAttributedString?, for state: UIControl.State) {
        // TODO: Add saving attributes.
        guard UIButton.swizzledSetAttributedTitle != nil else { return }
        swizzled_setAttributedTitle(title, for: state)
    }

    /// Method for swizzling implementations for setTitle(_:for:) and setAttributedTitle(_:for:) methods.
    /// Note: This method should be called only when we need to get localization key from string, currently it is needed for screenshots and realtime preview features.
    class func swizzle() {
        // swiftlint:disable force_unwrapping
        originalSetTitle = class_getInstanceMethod(self, #selector(UIButton.setTitle(_:for:)))!
        swizzledSetTitle = class_getInstanceMethod(self, #selector(UIButton.swizzled_setTitle(_:for:)))!
        method_exchangeImplementations(originalSetTitle, swizzledSetTitle)
        
        originalSetAttributedTitle = class_getInstanceMethod(self, #selector(UIButton.setAttributedTitle(_:for:)))!
        swizzledSetAttributedTitle = class_getInstanceMethod(self, #selector(UIButton.swizzled_setAttributedTitle(_:for:)))!
        method_exchangeImplementations(originalSetAttributedTitle, swizzledSetAttributedTitle)
    }
    
    /// Method for swizzling implementations back for setTitle(_:for:) and setAttributedTitle(_:for:) methods.
    class func unswizzle() {
        if originalSetTitle != nil && swizzledSetTitle != nil {
            method_exchangeImplementations(swizzledSetTitle, originalSetTitle)
            swizzledSetTitle = nil
            originalSetTitle = nil
        }
        if originalSetAttributedTitle != nil && swizzledSetAttributedTitle != nil {
            method_exchangeImplementations(swizzledSetAttributedTitle, originalSetAttributedTitle)
            swizzledSetAttributedTitle = nil
            originalSetAttributedTitle = nil
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
