import SwiftSignalKit
import UIKit

func smartInvertColorsEnabled() -> Bool {
    if #available(iOSApplicationExtension 11.0, iOS 11.0, *), UIAccessibility.isInvertColorsEnabled {
        return true
    } else {
        return false
    }
}

func reduceMotionEnabled() -> Signal<Bool, NoError> {
    return Signal { subscriber in
        subscriber.putNext(UIAccessibility.isReduceMotionEnabled)
        
        let observer = NotificationCenter.default.addObserver(forName: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil, queue: .main, using: { _ in
            subscriber.putNext(UIAccessibility.isReduceMotionEnabled)
        })
        
        return ActionDisposable {
            Queue.mainQueue().async {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    } |> runOn(Queue.mainQueue())
}

func boldTextEnabled() -> Signal<Bool, NoError> {
    return Signal { subscriber in
        subscriber.putNext(UIAccessibility.isBoldTextEnabled)
        
        let observer = NotificationCenter.default.addObserver(forName: UIAccessibility.boldTextStatusDidChangeNotification, object: nil, queue: .main, using: { _ in
            subscriber.putNext(UIAccessibility.isBoldTextEnabled)
        })
        
        return ActionDisposable {
            Queue.mainQueue().async {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    } |> runOn(Queue.mainQueue())
}

private func checkButtonShapes() -> Bool {
    let button = UIButton()
    button.setTitle("title", for: .normal)
    
    if let attributes = button.titleLabel?.attributedText?.attributes(at: 0, effectiveRange: nil), let _ = attributes[NSAttributedString.Key.underlineStyle] {
        return true
    } else {
        return false
    }
}
