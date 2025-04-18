import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import AppBundle
import ContextUI
import AnimatedCountLabelNode

public final class VolumeSliderContextItem: ContextMenuCustomItem {
    private let minValue: CGFloat
    private let maxValue: CGFloat
    private let value: CGFloat
    private let valueChanged: (CGFloat, Bool) -> Void
    
    public init(minValue: CGFloat, maxValue: CGFloat = 1.0, value: CGFloat, valueChanged: @escaping (CGFloat, Bool) -> Void) {
        self.minValue = minValue
        self.maxValue = maxValue
        self.value = value
        self.valueChanged = valueChanged
    }
    
    public func node(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode {
        return VolumeSliderContextItemNode(presentationData: presentationData, getController: getController, minValue: self.minValue, maxValue: self.maxValue, value: self.value, valueChanged: self.valueChanged)
    }
}

private let textFont = Font.with(size: 17.0, design: .regular, traits: .monospacedNumbers)

private final class VolumeSliderContextItemNode: ASDisplayNode, ContextMenuCustomNode {
    private var presentationData: PresentationData
    
    private(set) var vibrancyEffectView: UIVisualEffectView?
    
    private let backgroundIconNode: VoiceChatSpeakerNode
    private let backgroundTextNode: ImmediateAnimatedCountLabelNode
    private let dimBackgroundTextNode: ImmediateAnimatedCountLabelNode
    
    private let foregroundNode: ASDisplayNode
    private let foregroundIconNode: VoiceChatSpeakerNode
    private let foregroundTextNode: ImmediateAnimatedCountLabelNode
    
    let minValue: CGFloat
    let maxValue: CGFloat
    var value: CGFloat = 1.0 {
        didSet {
            self.updateValue(transition: .animated(duration: 0.2, curve: .spring))
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
        
        self.backgroundIconNode = VoiceChatSpeakerNode()
        
        self.backgroundTextNode = ImmediateAnimatedCountLabelNode()
        self.backgroundTextNode.alwaysOneDirection = true
        
        self.dimBackgroundTextNode = ImmediateAnimatedCountLabelNode()
        self.dimBackgroundTextNode.alwaysOneDirection = true
        
        self.foregroundNode = ASDisplayNode()
        self.foregroundNode.clipsToBounds = true
        self.foregroundNode.isAccessibilityElement = false
        self.foregroundNode.backgroundColor = UIColor(rgb: 0xffffff)
        self.foregroundNode.isUserInteractionEnabled = false
        
        self.foregroundIconNode = VoiceChatSpeakerNode()
        
        self.foregroundTextNode = ImmediateAnimatedCountLabelNode()
        self.foregroundTextNode.alwaysOneDirection = true
        
        super.init()
        
        self.isUserInteractionEnabled = true
        
        if presentationData.theme.overallDarkAppearance {
            
        } else {
            let style: UIBlurEffect.Style
            style = .extraLight
            let blurEffect = UIBlurEffect(style: style)
            let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect)
            let vibrancyEffectView = UIVisualEffectView(effect: vibrancyEffect)
            
            self.vibrancyEffectView = vibrancyEffectView
        }
        
        self.addSubnode(self.backgroundIconNode)
        self.addSubnode(self.backgroundTextNode)
        self.addSubnode(self.dimBackgroundTextNode)
        
        self.addSubnode(self.foregroundNode)
        self.foregroundNode.addSubnode(self.foregroundIconNode)
        self.foregroundNode.addSubnode(self.foregroundTextNode)
        
        let stringValue = "100%"
        
        let dimBackgroundTextColor = self.vibrancyEffectView != nil ? UIColor(white: 0.0, alpha: 0.15) : .clear
        let backgroundTextColor = self.vibrancyEffectView != nil ? UIColor(white: 1.0, alpha: 0.7) : self.presentationData.theme.contextMenu.secondaryColor
        let foregroundTextColor = UIColor.black
        
        var dimBackgroundSegments: [AnimatedCountLabelNode.Segment] = []
        var backgroundSegments: [AnimatedCountLabelNode.Segment] = []
        var foregroundSegments: [AnimatedCountLabelNode.Segment] = []
        var textCount = 0
        for char in stringValue {
            if let intValue = Int(String(char)) {
                dimBackgroundSegments.append(.number(intValue, NSAttributedString(string: String(char), font: textFont, textColor: dimBackgroundTextColor)))
                backgroundSegments.append(.number(intValue, NSAttributedString(string: String(char), font: textFont, textColor: backgroundTextColor)))
                foregroundSegments.append(.number(intValue, NSAttributedString(string: String(char), font: textFont, textColor: foregroundTextColor)))
            } else {
                dimBackgroundSegments.append(.text(textCount, NSAttributedString(string: String(char), font: textFont, textColor: dimBackgroundTextColor)))
                backgroundSegments.append(.text(textCount, NSAttributedString(string: String(char), font: textFont, textColor: backgroundTextColor)))
                foregroundSegments.append(.text(textCount, NSAttributedString(string: String(char), font: textFont, textColor: foregroundTextColor)))
                textCount += 1
            }
        }
        self.dimBackgroundTextNode.segments = dimBackgroundSegments
        self.backgroundTextNode.segments = backgroundSegments
        self.foregroundTextNode.segments = foregroundSegments
    }
    
    override func didLoad() {
        super.didLoad()
        
        if let vibrancyEffectView = self.vibrancyEffectView {
            Queue.mainQueue().after(0.05) {
                if let effectNode = findEffectNode(node: self.supernode) {
                    effectNode.effectView?.contentView.insertSubview(vibrancyEffectView, at: 0)
                    vibrancyEffectView.contentView.addSubnode(self.backgroundTextNode)
                }
            }
        }
        
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
        let value = self.value
        transition.updateFrameAdditive(node: self.foregroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: value / range * width, height: self.frame.height)))
        
        let stringValue = "\(Int(self.value * 100.0))%"
        
        let dimBackgroundTextColor = self.vibrancyEffectView != nil ? UIColor(white: 0.0, alpha: 0.15) : .clear
        let backgroundTextColor = self.vibrancyEffectView != nil ? UIColor(white: 1.0, alpha: 0.7) : self.presentationData.theme.contextMenu.secondaryColor
        let foregroundTextColor = UIColor.black
        
        var dimBackgroundSegments: [AnimatedCountLabelNode.Segment] = []
        var backgroundSegments: [AnimatedCountLabelNode.Segment] = []
        var foregroundSegments: [AnimatedCountLabelNode.Segment] = []
        var textCount = 0
        for char in stringValue {
            if let intValue = Int(String(char)) {
                dimBackgroundSegments.append(.number(intValue, NSAttributedString(string: String(char), font: textFont, textColor: dimBackgroundTextColor)))
                backgroundSegments.append(.number(intValue, NSAttributedString(string: String(char), font: textFont, textColor: backgroundTextColor)))
                foregroundSegments.append(.number(intValue, NSAttributedString(string: String(char), font: textFont, textColor: foregroundTextColor)))
            } else {
                dimBackgroundSegments.append(.text(textCount, NSAttributedString(string: String(char), font: textFont, textColor: dimBackgroundTextColor)))
                backgroundSegments.append(.text(textCount, NSAttributedString(string: String(char), font: textFont, textColor: backgroundTextColor)))
                foregroundSegments.append(.text(textCount, NSAttributedString(string: String(char), font: textFont, textColor: foregroundTextColor)))
                textCount += 1
            }
        }
        self.dimBackgroundTextNode.segments = dimBackgroundSegments
        self.backgroundTextNode.segments = backgroundSegments
        self.foregroundTextNode.segments = foregroundSegments
        
        let _ = self.dimBackgroundTextNode.updateLayout(size: CGSize(width: 70.0, height: .greatestFiniteMagnitude), animated: transition.isAnimated)
        let _ = self.backgroundTextNode.updateLayout(size: CGSize(width: 70.0, height: .greatestFiniteMagnitude), animated: transition.isAnimated)
        let _ = self.foregroundTextNode.updateLayout(size: CGSize(width: 70.0, height: .greatestFiniteMagnitude), animated: transition.isAnimated)
        
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
    }
    
    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let valueWidth: CGFloat = 70.0
        let height: CGFloat = 45.0
        
        var backgroundTextSize = self.backgroundTextNode.updateLayout(size: CGSize(width: 70.0, height: .greatestFiniteMagnitude), animated: true)
        backgroundTextSize.width = valueWidth
        
        return (CGSize(width: height * 3.0, height: height), { size, transition in
            let leftInset: CGFloat = 17.0
            
            self.vibrancyEffectView?.frame = CGRect(origin: .zero, size: size)
            
            let textFrame = CGRect(origin: CGPoint(x: leftInset, y: floor((height - backgroundTextSize.height) / 2.0)), size: backgroundTextSize)
            transition.updateFrameAdditive(node: self.dimBackgroundTextNode, frame: textFrame)
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
                let delta = translation / self.bounds.width
                self.value = max(self.minValue, min(self.maxValue, self.value + delta))
                gestureRecognizer.setTranslation(CGPoint(), in: gestureRecognizer.view)
                
                if self.value == self.maxValue && previousValue != self.maxValue {
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
                } else if self.maxValue != 1.0 && self.value == 1.0 && previousValue != 1.0 {
                    self.hapticFeedback.impact(.soft)
                } else if self.value == 0.0 && previousValue != 0.0 {
                    self.hapticFeedback.impact(.soft)
                }
                if abs(previousValue - self.value) >= 0.01 {
                    self.valueChanged(self.value, false)
                }
            case .ended:
                let translation: CGFloat = gestureRecognizer.translation(in: gestureRecognizer.view).x
                let delta = translation / self.bounds.width
                self.value = max(self.minValue, min(self.maxValue, self.value + delta))
                self.valueChanged(self.value, true)
            default:
                break
        }
    }
    
    @objc private func tapGesture(_ gestureRecognizer: UITapGestureRecognizer) {
        let location = gestureRecognizer.location(in: gestureRecognizer.view)
        self.value = max(self.minValue, min(self.maxValue, location.x / self.bounds.width))
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

private func findEffectNode(node: ASDisplayNode?) -> NavigationBackgroundNode? {
    if let node = node {
        if let subnodes = node.subnodes {
            for node in subnodes {
                if let effectNode = node as? NavigationBackgroundNode {
                    return effectNode
                }
            }
        }
        return findEffectNode(node: node.supernode)
    } else {
        return nil
    }
}
