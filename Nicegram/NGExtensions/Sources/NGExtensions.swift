import UIKit
import SnapKit

@objc public protocol KeyboardPresentable: AnyObject {
    @objc func dismissKeyboard(_ recognizer: UITapGestureRecognizer)
    @objc func keyboardWillShow(_ notification: Notification)
    @objc func keyboardWillHide(_ notification: Notification)
}

extension KeyboardPresentable where Self: UIViewController {
    @discardableResult
    public func registerKeyboardObservers() -> UITapGestureRecognizer {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        return tap
    }

    public func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
}

extension UIView {
    public var safeArea: ConstraintBasicAttributesDSL {
        if #available(iOS 11.0, *) {
            return self.safeAreaLayoutGuide.snp
        } else {
            return self.snp
        }
    }

    public func hasSuperview(_ superview: UIView) -> Bool{
        return viewHasSuperview(self, superview: superview)
    }

    public func viewHasSuperview(_ view: UIView, superview: UIView) -> Bool {
        if let sview = view.superview {
            if sview === superview {
                return true
            } else {
                return viewHasSuperview(sview, superview: superview)
            }
        } else {
            return false
        }
    }
}

extension UIView {
    public func padding(_ insets: UIEdgeInsets) -> UIView {
        let stack = UIStackView(arrangedSubviews: [self])
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = insets
        return stack
    }
    
    public func padding(top: CGFloat = .zero, left: CGFloat = .zero, bottom: CGFloat = .zero, right: CGFloat = .zero) -> UIView {
        return padding(.init(top: top, left: left, bottom: bottom, right: right))
    }
}

extension UIStackView {
    public func removeAllArrangedSubviews() {
        
        let removedSubviews = arrangedSubviews.reduce([]) { (allSubviews, subview) -> [UIView] in
            self.removeArrangedSubview(subview)
            return allSubviews + [subview]
        }
        
        // Remove the views from self
        removedSubviews.forEach({ $0.removeFromSuperview() })
    }
}

extension UIScrollView {
    public func adjustBottomInsetToNotBeCovered(by coveringView: UIView, additionalInset: CGFloat = 0) {
        if #available(iOS 11.0, *) {
            self.contentInsetAdjustmentBehavior = .never
        }
        
        let coveringFrame = coveringView.convert(coveringView.bounds, to: self)
        let inset = bounds.maxY - (coveringFrame.minY - additionalInset)
        if inset > 0 {
            contentInset.bottom = inset
        }
    }
}

public struct KeyboardChange {
    public let duration: TimeInterval
    public let height: CGFloat
    public let animationCurve: UIView.AnimationCurve?
    public let animationOptions: UIView.AnimationOptions?
}

extension Notification {
    public func willShowKeyboard(in view: UIView) -> KeyboardChange {
        let info = self.userInfo!
        var duration: TimeInterval = 0
        (info[UIResponder.keyboardAnimationDurationUserInfoKey] as! NSValue).getValue(&duration)
        let value: NSValue? = info[UIResponder.keyboardFrameEndUserInfoKey]! as? NSValue
        let rawFrame = value?.cgRectValue
        let keyboardFrame = view.convert(rawFrame!, from: nil)
        let curve = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        let animationCurve = curve.flatMap { UIView.AnimationCurve(rawValue: Int($0)) }
        let animationOptions = curve.flatMap { UIView.AnimationOptions(rawValue: $0 << 16) }

        return KeyboardChange(
            duration: duration,
            height: keyboardFrame.height,
            animationCurve: animationCurve,
            animationOptions: animationOptions
        )
    }
}

public protocol ReuseIdentifiable {
    static var reuseIdentifier: String { get }
}

public extension ReuseIdentifiable where Self: UIView {
    static var reuseIdentifier: String {
        return String(describing: self)
    }
}

public extension UIBarItem {
    var view: UIView? {
        if let item = self as? UIBarButtonItem, let customView = item.customView {
            return customView
        }
        return self.value(forKey: "view") as? UIView
    }
}

public protocol ClosureBindable: AnyObject { }

public extension ClosureBindable {
    typealias Function = Self

    func weak<Args>(_ method: @escaping ((Self) -> ((Args) -> Void))) -> ((Args) -> Void) {
        return { [weak self] arg in
            guard let strongSelf = self else { return }
            method(strongSelf)(arg)
        }
    }

    func weak<Arg1, Arg2>(_ method: @escaping ((Self) -> ((Arg1, Arg2) -> Void))) -> ((Arg1, Arg2) -> Void) {
        return { [weak self] arg1, arg2 in
            guard let strongSelf = self else { return }
            method(strongSelf)(arg1, arg2)
        }
    }

    func weak(_ method: @escaping ((Self) -> (() -> Void))) -> (() -> Void) {
        return { [weak self] in
            guard let strongSelf = self else { return }
            method(strongSelf)()
        }
    }
}
