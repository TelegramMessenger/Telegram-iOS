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

private var accessibilityCoverCheckInProgress = false

private func normalizedAccessibilityText(_ text: String) -> String {
    return text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
}

/// The words of a text for matching: split at whitespace and punctuation, lowercased.
private func accessibilityWords(_ text: String) -> [String] {
    return text.lowercased().split(whereSeparator: { $0.isWhitespace || $0.isNewline || ($0.isPunctuation && $0 != "#") }).map(String.init)
}

/// Whether `label` speaks `text`: the text's words appear in the label as a run of whole words ("1" is not spoken by
/// "last seen 10 minutes ago", "On" not by "Mention").
func accessibilityLabel(_ label: String, speaks text: String) -> Bool {
    let textWords = accessibilityWords(text)
    let labelWords = accessibilityWords(label)
    if textWords.isEmpty || textWords.count > labelWords.count {
        return false
    }
    for start in 0 ... (labelWords.count - textWords.count) {
        if Array(labelWords[start ..< start + textWords.count]) == textWords {
            return true
        }
    }
    return false
}

/// Whether a text view's words are already spoken by another element: an ancestor that is itself an element, one of the
/// view's nearest `maxDepth` ancestors
/// whose label contains the text (a labelled container), or an element among those ancestors' direct subviews (outside
/// the view's own branch) that covers the text's centre and whose label contains the text. Text components use it to stay silent next to a hand-labelled area (an
/// `AccessibilityAreaNode` or a labelled container drawn over them), so the words are not read twice. Main thread;
/// runs only when an accessibility client asks.
public func accessibilityTextIsSpokenByCoveringElement(_ view: UIView, text: String, maxDepth: Int = 4) -> Bool {
    if accessibilityCoverCheckInProgress {
        // A text queried as a candidate by another text's check: it does not count as speaking (two overlapping copies
        // of one text, as in a cross-fade, must not silence each other).
        return true
    }
    let normalizedText = normalizedAccessibilityText(text)
    if normalizedText.isEmpty {
        return false
    }
    accessibilityCoverCheckInProgress = true
    defer {
        accessibilityCoverCheckInProgress = false
    }
    // Inside an element (a title view, a button) the text is never reached on its own: stay out of the tree.
    var ancestorView = view.superview
    while let current = ancestorView {
        if current.isAccessibilityElement {
            return true
        }
        ancestorView = current.superview
    }
    let center = view.convert(CGPoint(x: view.bounds.midX, y: view.bounds.midY), to: nil)
    var branch: UIView = view
    var depth = 0
    while depth < maxDepth, let ancestor = branch.superview {
        // A labelled container around the text (a title view that names itself) already says these words.
        if let label = ancestor.accessibilityLabel, !label.isEmpty, accessibilityLabel(label, speaks: normalizedText) {
            return true
        }
        for candidate in ancestor.subviews where candidate !== branch {
            if candidate.isHidden || candidate.alpha < 0.01 || candidate.accessibilityElementsHidden || !candidate.isAccessibilityElement {
                continue
            }
            // The frame test first: a button's label getter can walk its whole content tree.
            if !candidate.convert(candidate.bounds, to: nil).contains(center) {
                continue
            }
            guard let label = candidate.accessibilityLabel, !label.isEmpty else {
                continue
            }
            if accessibilityLabel(label, speaks: normalizedText) {
                return true
            }
        }
        branch = ancestor
        depth += 1
    }
    return false
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
    /// Called from layout: the element is rebuilt only when the text changes; the handler is always the latest one.
    func applyAccessibilityText(_ text: NSAttributedString, linkAttribute: NSAttributedString.Key, open: ((Any) -> Void)?) {
        self.accessibilityTextOpen = open
        if let applied = self.appliedAccessibilityText, applied.hasOpen == (open != nil), applied.text.isEqual(to: text) {
            return
        }
        self.appliedAccessibilityText = (text, open != nil)
        
        self.accessibilityLabel = accessibilityDisplayedText(text)
        let links = open == nil ? [] : accessibilityTextLinks(in: text, attribute: linkAttribute)
        if let first = links.first {
            self.accessibilityTraits = [.staticText, .link]
            self.activate = { [weak self] in
                guard let open = self?.accessibilityTextOpen else {
                    return false
                }
                open(first.value)
                return true
            }
            if links.count > 1 {
                self.view.accessibilityCustomActions = links.map { link in
                    return UIAccessibilityCustomAction(name: link.text, actionHandler: { [weak self] _ in
                        guard let open = self?.accessibilityTextOpen else {
                            return false
                        }
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

/// Whether `view` is inside a subtree that keeps UIKit's own accessibility (`accessibilityUsesViewElements`). Defaults
/// added to shared components for the screen sweeps (a button reading its shown text, links as custom actions) keep their
/// old result there.
///
/// Boundary: today only `ChatControllerNode.contentContainerNode` sets the flag, so this covers the chat's history, its
/// navigation bar with the title accessory panels (business link, managing bot), the navigate buttons and the overlay
/// context panels. The input-panel area (`inputPanelContainerNode`, `inputContextPanelContainer`, the panels that replace
/// the input such as tag search or "Premium required") lies outside it, on the new collector like the rest of the app:
/// there these defaults apply (an unlabelled button there now reads its text). Sheets presented over the chat are
/// outside it too. Mostly called from accessibility getters, so it runs only when an accessibility client asks.
public func accessibilityIsInsideViewElementsSubtree(_ view: UIView) -> Bool {
    var current: UIView? = view
    while let value = current {
        if let node = value.asyncdisplaykit_node, node.accessibilityUsesViewElements {
            return true
        }
        current = value.superview
    }
    return false
}
