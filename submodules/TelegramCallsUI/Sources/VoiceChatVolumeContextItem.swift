import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import AppBundle
import ContextUI

final class VoiceChatVolumeContextItem: ContextMenuCustomItem {
    private let minValue: CGFloat
    private let value: CGFloat
    private let valueChanged: (CGFloat, Bool) -> Void
    
    init(minValue: CGFloat, value: CGFloat, valueChanged: @escaping (CGFloat, Bool) -> Void) {
        self.minValue = minValue
        self.value = value
        self.valueChanged = valueChanged
    }
    
    func node(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode {
        return VoiceChatVolumeContextItemNode(presentationData: presentationData, getController: getController, minValue: self.minValue, value: self.value, valueChanged: self.valueChanged)
    }
}

private let textFont = Font.regular(17.0)

private final class VoiceChatVolumeContextItemNode: ASDisplayNode, ContextMenuCustomNode {
    private var presentationData: PresentationData
    
    private let backgroundIconNode: VoiceChatSpeakerNode
    private let backgroundTextNode: ImmediateTextNode
    
    private let foregroundNode: ASDisplayNode
    private let foregroundIconNode: VoiceChatSpeakerNode
    private let foregroundTextNode: ImmediateTextNode
    
    let minValue: CGFloat
    var value: CGFloat = 1.0 {
        didSet {
            self.updateValue()
        }
    }
    
    private let valueChanged: (CGFloat, Bool) -> Void
    
    private let hapticFeedback = HapticFeedback()

    init(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, minValue: CGFloat, value: CGFloat, valueChanged: @escaping (CGFloat, Bool) -> Void) {
        self.presentationData = presentationData
        self.minValue = minValue
        self.value = value
        self.valueChanged = valueChanged
        
        self.backgroundIconNode = VoiceChatSpeakerNode()
        
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
        
        self.foregroundIconNode = VoiceChatSpeakerNode()
        
        self.foregroundTextNode = ImmediateTextNode()
        self.foregroundTextNode.isAccessibilityElement = false
        self.foregroundTextNode.isUserInteractionEnabled = false
        self.foregroundTextNode.displaysAsynchronously = false
        self.foregroundTextNode.textAlignment = .left
        
        super.init()
        
        self.isUserInteractionEnabled = true
        
        self.addSubnode(self.backgroundIconNode)
        self.addSubnode(self.backgroundTextNode)
        self.addSubnode(self.foregroundNode)
        self.foregroundNode.addSubnode(self.foregroundIconNode)
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
        
        let value = self.value / 2.0
        transition.updateFrameAdditive(node: self.foregroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: value * width, height: self.frame.height)))
        
        self.backgroundTextNode.attributedText = NSAttributedString(string: "\(Int(self.value * 100.0))%", font: textFont, textColor: UIColor(rgb: 0xffffff))
        self.foregroundTextNode.attributedText = NSAttributedString(string: "\(Int(self.value * 100.0))%", font: textFont, textColor: UIColor(rgb: 0x000000))
        
        let iconValue: VoiceChatSpeakerNode.State.Value
        if value == 0.0 {
            iconValue = .muted
        } else if value < 0.33 {
            iconValue = .low
        } else if value < 0.66 {
            iconValue = .medium
        } else {
            iconValue = .high
        }
        
        self.backgroundIconNode.update(state: VoiceChatSpeakerNode.State(value: iconValue, color: UIColor(rgb: 0xffffff)), animated: true)
        self.foregroundIconNode.update(state: VoiceChatSpeakerNode.State(value: iconValue, color: UIColor(rgb: 0x000000)), animated: true)
        
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
            
            let iconSize = CGSize(width: 36.0, height: 36.0)
            let iconFrame = CGRect(origin: CGPoint(x: size.width - iconSize.width - 10.0, y: floor((size.height - iconSize.height) / 2.0)), size: iconSize)
            self.backgroundIconNode.frame = iconFrame
            self.foregroundIconNode.frame = iconFrame
            
            self.updateValue(transition: transition)
        })
    }
    
    @objc private func panGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        switch gestureRecognizer.state {
            case .began:
                break
            case .changed:
                let previousValue = self.value
                
                let translation: CGFloat = gestureRecognizer.translation(in: gestureRecognizer.view).x
                let delta = translation / self.bounds.width * 2.0
                self.value = max(self.minValue, min(2.0, self.value + delta))
                gestureRecognizer.setTranslation(CGPoint(), in: gestureRecognizer.view)
                
                if self.value == 2.0 && previousValue != 2.0 {
                    self.backgroundIconNode.layer.animateScale(from: 1.0, to: 1.1, duration: 0.16, removeOnCompletion: false, completion: { [weak self] _ in
                        if let strongSelf = self {
                            strongSelf.backgroundIconNode.layer.animateScale(from: 1.1, to: 1.0, duration: 0.16)
                        }
                    })
                    self.foregroundIconNode.layer.animateScale(from: 1.0, to: 1.1, duration: 0.16, removeOnCompletion: false, completion: { [weak self] _ in
                        if let strongSelf = self {
                            strongSelf.foregroundIconNode.layer.animateScale(from: 1.1, to: 1.0, duration: 0.16)
                        }
                    })
                    self.hapticFeedback.impact(.soft)
                } else if self.value == 0.0 && previousValue != 0.0 {
                    self.hapticFeedback.impact(.soft)
                }
                if abs(previousValue - self.value) >= 0.01 {
                    self.valueChanged(self.value, false)
                }
            case .ended:
                let translation: CGFloat = gestureRecognizer.translation(in: gestureRecognizer.view).x
                let delta = translation / self.bounds.width * 2.0
                self.value = max(self.minValue, min(2.0, self.value + delta))
                self.valueChanged(self.value, true)
            default:
                break
        }
    }
    
    @objc private func tapGesture(_ gestureRecognizer: UITapGestureRecognizer) {
        let location = gestureRecognizer.location(in: gestureRecognizer.view)
        self.value = max(self.minValue, min(2.0, location.x / self.bounds.width * 2.0))
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
