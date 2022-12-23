//
//  KeyboardTracker.swift
//  Sugar
//
//  Created by Vadim Suhodolskiy on 1/8/21.
//

import Foundation
import UIKit

public enum KeyboardStatus {
    case hiding
    case hidden
    case showing
    case shown
}

infix operator >=~
func >=~ (lhs: CGFloat, rhs: CGFloat) -> Bool {
    return round(lhs * UIScreen.main.scale) >= round(rhs * UIScreen.main.scale)
}

public typealias KeyboardHeightBlock = (_ height: CGFloat, _ status: KeyboardStatus) -> Void

public class KeyboardTracker {
    private(set) var keyboardStatus: KeyboardStatus = .hidden
    private weak var view: UIView?
    
    var isTracking = false
    private var notificationCenter: NotificationCenter
    
    private var heightBlock: KeyboardHeightBlock
    
    public init(view: UIView, heightBlock: @escaping KeyboardHeightBlock, notificationCenter: NotificationCenter) {
        self.view = view
        self.heightBlock = heightBlock
        self.notificationCenter = notificationCenter
        self.notificationCenter.addObserver(
            self,
            selector: #selector(KeyboardTracker.keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        self.notificationCenter.addObserver(
            self,
            selector: #selector(KeyboardTracker.keyboardDidShow(_:)),
            name: UIResponder.keyboardDidShowNotification,
            object: nil
        )
        self.notificationCenter.addObserver(
            self,
            selector: #selector(KeyboardTracker.keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        self.notificationCenter.addObserver(
            self,
            selector: #selector(KeyboardTracker.keyboardDidHide(_:)),
            name: UIResponder.keyboardDidHideNotification,
            object: nil
        )
        self.notificationCenter.addObserver(
            self,
            selector: #selector(KeyboardTracker.keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }
    
    deinit {
        self.notificationCenter.removeObserver(self)
    }
    
    public func startTracking() {
        self.isTracking = true
    }
    
    public func stopTracking() {
        self.isTracking = false
    }
    
    @objc
    private func keyboardWillShow(_ notification: Notification) {
        guard self.isTracking else { return }
        let bottomConstraint = self.bottomConstraintFromNotification(notification)
        guard bottomConstraint > 0 else { return } // Some keyboards may report initial willShow/DidShow notifications with invalid positions
        self.keyboardStatus = .showing
        heightBlock(bottomConstraint,.showing)
    }
    
    @objc
    private func keyboardDidShow(_ notification: Notification) {
        guard self.isTracking else { return }
        
        let bottomConstraint = self.bottomConstraintFromNotification(notification)
        guard bottomConstraint > 0 else { return } // Some keyboards may report initial willShow/DidShow notifications with invalid positions
        self.keyboardStatus = .shown
        heightBlock(bottomConstraint,.shown)
    }
    
    @objc
    private func keyboardWillChangeFrame(_ notification: Notification) {
        guard self.isTracking else { return }
        let bottomConstraint = self.bottomConstraintFromNotification(notification)
        if bottomConstraint == 0 {
            self.keyboardStatus = .hiding
            heightBlock(0,.hiding)
        }
    }
    
    @objc
    private func keyboardWillHide(_ notification: Notification) {
        guard self.isTracking else { return }
        self.keyboardStatus = .hiding
        heightBlock(0,.hidden)
    }
    
    @objc
    private func keyboardDidHide(_ notification: Notification) {
        guard self.isTracking else { return }
        self.keyboardStatus = .hidden
        heightBlock(0,.hidden)
    }
    
    private func bottomConstraintFromNotification(_ notification: Notification) -> CGFloat {
        guard let rect = ((notification as NSNotification).userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return 0 }
        guard rect.height > 0 else { return 0 }
        guard let view else { return 0 }
        let rectInView = view.convert(rect, from: nil)
        guard rectInView.maxY >=~ view.bounds.height else { return 0 } // Undocked keyboard
        return rect.height
    }
}
