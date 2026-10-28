import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

public func addAccessibilityChildren(of node: ASDisplayNode, container: Any, to list: inout [Any]) {
    if node.isAccessibilityElement {
        let element = UIAccessibilityElement(accessibilityContainer: container)
        element.accessibilityFrame = UIAccessibility.convertToScreenCoordinates(node.bounds, in: node.view)
        element.accessibilityLabel = node.accessibilityLabel
        element.accessibilityValue = node.accessibilityValue
        element.accessibilityTraits = node.accessibilityTraits
        element.accessibilityHint = node.accessibilityHint
        element.accessibilityIdentifier = node.accessibilityIdentifier
        
        //node.accessibilityFrame = UIAccessibilityConvertFrameToScreenCoordinates(node.bounds, node.view)
        list.append(element)
    } else if let accessibilityElements = node.accessibilityElements {
        list.append(contentsOf: accessibilityElements)
    }
}

/// Whether layout should behave as under VoiceOver. Debug builds can force it with the
/// `--force-voiceover-layout` launch argument (the simulator never runs VoiceOver); compiled out of release builds.
public var isVoiceOverRunningForLayout: Bool {
    #if DEBUG
    if CommandLine.arguments.contains("--force-voiceover-layout") {
        return true
    }
    #endif
    return UIAccessibility.isVoiceOverRunning
}

public func smartInvertColorsEnabled() -> Bool {
    if #available(iOSApplicationExtension 11.0, iOS 11.0, *), UIAccessibility.isInvertColorsEnabled {
        return true
    } else {
        return false
    }
}

public func isReduceMotionEnabled() -> Signal<Bool, NoError> {
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

public func isSpeakSelectionEnabled() -> Bool {
    return UIAccessibility.isSpeakSelectionEnabled
}

public func isSpeakSelectionEnabledSignal() -> Signal<Bool, NoError> {
    return Signal { subscriber in
        subscriber.putNext(UIAccessibility.isSpeakSelectionEnabled)
        
        let observer = NotificationCenter.default.addObserver(forName: UIAccessibility.speakSelectionStatusDidChangeNotification, object: nil, queue: .main, using: { _ in
            subscriber.putNext(UIAccessibility.isSpeakSelectionEnabled)
        })
        
        return ActionDisposable {
            Queue.mainQueue().async {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    } |> runOn(Queue.mainQueue())
}

public func isBoldTextEnabled() -> Signal<Bool, NoError> {
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
    }
    |> runOn(Queue.mainQueue())
}

public func isReduceTransparencyEnabled() -> Bool {
    UIAccessibility.isReduceTransparencyEnabled
}

/// VoiceOver: a tappable range of a text, with the value of its link attribute.
public struct AccessibilityTextLink {
    public let text: String
    public let value: Any
    
    public init(text: String, value: Any) {
        self.text = text
        self.value = value
    }
}

/// VoiceOver: the links of `text` (ranges carrying `attribute`), in text order. Adjacent runs with the same value are one
/// link; image attachments (an arrow glyph) are not words.
public func accessibilityTextLinks(in text: NSAttributedString, attribute: NSAttributedString.Key) -> [AccessibilityTextLink] {
    var result: [(text: String, value: Any)] = []
    let string = text.string as NSString
    text.enumerateAttributes(in: NSRange(location: 0, length: text.length), options: []) { attributes, range, _ in
        guard let value = attributes[attribute], attributes[.attachment] == nil else {
            return
        }
        let runText = string.substring(with: range)
        if let last = result.last, (last.value as? NSObject)?.isEqual(value) == true {
            result[result.count - 1] = (last.text + runText, last.value)
        } else {
            result.append((runText, value))
        }
    }
    return result.compactMap { item in
        let trimmed = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }
        return AccessibilityTextLink(text: trimmed, value: item.value)
    }
}

/// VoiceOver: the text as read, without image attachments (an arrow glyph drawn over a ">").
public func accessibilityDisplayedText(_ text: NSAttributedString) -> String {
    let mutable = NSMutableAttributedString(attributedString: text)
    text.enumerateAttribute(.attachment, in: NSRange(location: 0, length: text.length), options: [.reverse]) { value, range, _ in
        if value != nil {
            mutable.deleteCharacters(in: range)
        }
    }
    return mutable.string.trimmingCharacters(in: .whitespacesAndNewlines)
}

public extension AccessibilityAreaNode {
    /// A text with links as one element: the text without attachments as its label, `.link` when it has links,
    /// activation following the first link (as a tap on it does), and a custom action per link when there are several.
    func applyAccessibilityText(_ text: NSAttributedString, linkAttribute: NSAttributedString.Key, open: ((Any) -> Void)?) {
        self.accessibilityLabel = accessibilityDisplayedText(text)
        let links = open == nil ? [] : accessibilityTextLinks(in: text, attribute: linkAttribute)
        if let open, let first = links.first {
            self.accessibilityTraits = [.staticText, .link]
            self.activate = {
                open(first.value)
                return true
            }
            if links.count > 1 {
                self.view.accessibilityCustomActions = links.map { link in
                    return UIAccessibilityCustomAction(name: link.text, actionHandler: { _ in
                        open(link.value)
                        return true
                    })
                }
            } else {
                self.view.accessibilityCustomActions = nil
            }
        } else {
            self.accessibilityTraits = .staticText
            self.activate = nil
            self.view.accessibilityCustomActions = nil
        }
    }
}
