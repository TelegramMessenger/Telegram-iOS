import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ContextUI
import TelegramPresentationData

public final class SliderContextItem: ContextMenuCustomItem {
    private let minValue: CGFloat
    private let maxValue: CGFloat
    private let value: CGFloat
    private let valueChanged: (CGFloat, Bool) -> Void
    
    public init(minValue: CGFloat, maxValue: CGFloat, value: CGFloat, valueChanged: @escaping (CGFloat, Bool) -> Void) {
        self.minValue = minValue
        self.maxValue = maxValue
        self.value = value
        self.valueChanged = valueChanged
    }
    
    public func node(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode {
        return SliderContextItemNode(presentationData: presentationData, getController: getController, minValue: self.minValue, maxValue: self.maxValue, value: self.value, valueChanged: self.valueChanged)
    }
}

private let textFont = Font.regular(17.0)

private final class SliderContextItemNode: ASDisplayNode, ContextMenuCustomNode {
    private var presentationData: PresentationData
    
    private let backgroundTextNode: ImmediateTextNode
    
    private let foregroundNode: ASDisplayNode
    private let foregroundTextNode: ImmediateTextNode
    
    let minValue: CGFloat
    let maxValue: CGFloat
    var value: CGFloat = 1.0 {
        didSet {
            self.updateValue()
        }
    }
    
    private let valueChanged: (CGFloat, Bool) -> Void
    
    private let hapticFeedback = HapticFeedback()

    init(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, minValue: CGFloat, maxValue: CGFloat, value: CGFloat, valueChanged: @escaping (CGFloat, Bool) -> Void) {
        self.presentationData = presentationData
        self.minValue = minValue
        self.maxValue = maxValue
        self.value = value
        self.valueChanged = valueChanged
                
        self.backgroundTextNode = ImmediateTextNode()
        self.backgroundTextNode.isAccessibilityElement = false
        self.backgroundTextNode.isUserInteractionEnabled = false
        self.backgroundTextNode.displaysAsynchronously = false
        self.backgroundTextNode.textAlignment = .left
        
        self.foregroundNode = ASDisplayNode()
        self.foregroundNode.clipsToBounds = true
        self.foregroundNode.isAccessibilityElement = false
        self.foregroundNode.backgroundColor = UIColor(rgb: 0xffffff)
        self.foregroundNode.isUserInteractionEnabled = false
        
        self.foregroundTextNode = ImmediateTextNode()
        self.foregroundTextNode.isAccessibilityElement = false
        self.foregroundTextNode.isUserInteractionEnabled = false
        self.foregroundTextNode.displaysAsynchronously = false
        self.foregroundTextNode.textAlignment = .left
        
        super.init()
        
        self.isUserInteractionEnabled = true
        
        self.addSubnode(self.backgroundTextNode)
        self.addSubnode(self.foregroundNode)
        self.foregroundNode.addSubnode(self.foregroundTextNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
        self.view.addGestureRecognizer(panGestureRecognizer)
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
        self.view.addGestureRecognizer(tapGestureRecognizer)
    }
    
    func updateTheme(presentationData: PresentationData) {
        self.presentationData = presentationData
        self.updateValue()
    }
    
    private func updateValue(transition: ContainedViewLayoutTransition = .immediate) {
        let width = self.frame.width
        
        let range = self.maxValue - self.minValue
        let value = (self.value - self.minValue) / range
        transition.updateFrameAdditive(node: self.foregroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: value * width, height: self.frame.height)))
        
        var stringValue = String(format: "%.1fx", self.value)
        if stringValue.hasSuffix(".0x") {
            stringValue = stringValue.replacingOccurrences(of: ".0x", with: "x")
        }
        self.backgroundTextNode.attributedText = NSAttributedString(string: stringValue, font: textFont, textColor: UIColor(rgb: 0xffffff))
        self.foregroundTextNode.attributedText = NSAttributedString(string: stringValue, font: textFont, textColor: UIColor(rgb: 0x000000))
        
        let _ = self.backgroundTextNode.updateLayout(CGSize(width: 70.0, height: .greatestFiniteMagnitude))
        let _ = self.foregroundTextNode.updateLayout(CGSize(width: 70.0, height: .greatestFiniteMagnitude))
    }
    
    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let valueWidth: CGFloat = 70.0
        let height: CGFloat = 45.0
        
        var textSize = self.backgroundTextNode.updateLayout(CGSize(width: valueWidth, height: .greatestFiniteMagnitude))
        textSize.width = valueWidth
        
        return (CGSize(width: height * 3.0, height: height), { size, transition in
            let leftInset: CGFloat = 17.0
            
            let textFrame = CGRect(origin: CGPoint(x: leftInset, y: floor((size.height - textSize.height) / 2.0)), size: textSize)
            transition.updateFrameAdditive(node: self.backgroundTextNode, frame: textFrame)
            transition.updateFrameAdditive(node: self.foregroundTextNode, frame: textFrame)
                        
            self.updateValue(transition: transition)
        })
    }
    
    @objc private func panGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        let range = self.maxValue - self.minValue
        switch gestureRecognizer.state {
            case .began:
                break
            case .changed:
                let previousValue = self.value
                
                let translation: CGFloat = gestureRecognizer.translation(in: gestureRecognizer.view).x
                let delta = translation / self.bounds.width * range
                self.value = max(self.minValue, min(self.maxValue, self.value + delta))
                gestureRecognizer.setTranslation(CGPoint(), in: gestureRecognizer.view)
                
                if self.value == 2.0 && previousValue != 2.0 {
                    self.hapticFeedback.impact(.soft)
                } else if self.value == 1.0 && previousValue != 1.0 {
                    self.hapticFeedback.impact(.soft)
                } else if self.value == 2.5 && previousValue != 2.5 {
                    self.hapticFeedback.impact(.soft)
                } else if self.value == 0.05 && previousValue != 0.05 {
                    self.hapticFeedback.impact(.soft)
                }
                if abs(previousValue - self.value) >= 0.001 {
                    self.valueChanged(self.value, false)
                }
            case .ended:
                let translation: CGFloat = gestureRecognizer.translation(in: gestureRecognizer.view).x
                let delta = translation / self.bounds.width * range
                self.value = max(self.minValue, min(self.maxValue, self.value + delta))
                self.valueChanged(self.value, true)
            default:
                break
        }
    }
    
    @objc private func tapGesture(_ gestureRecognizer: UITapGestureRecognizer) {
        let range = self.maxValue - self.minValue
        let location = gestureRecognizer.location(in: gestureRecognizer.view)
        self.value = max(self.minValue, min(self.maxValue, location.x / range))
        self.valueChanged(self.value, true)
    }
    
    func canBeHighlighted() -> Bool {
        return false
    }
    
    func updateIsHighlighted(isHighlighted: Bool) {
    }
    
    func performAction() {
    }
}
