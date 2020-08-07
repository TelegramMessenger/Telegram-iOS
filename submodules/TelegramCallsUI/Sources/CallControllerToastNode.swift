import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData

private let labelFont = Font.regular(17.0)

private enum ToastDescription: Equatable {
    enum Key: Hashable {
        case camera
        case microphone
        case mute
        case battery
    }
    
    case camera
    case microphone
    case mute
    case battery
    
    var key: Key {
        switch self {
        case .camera:
            return .camera
        case .microphone:
            return .microphone
        case .mute:
            return .mute
        case .battery:
            return .battery
        }
    }
}

struct CallControllerToastContent: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let camera = CallControllerToastContent(rawValue: 1 << 0)
    public static let microphone = CallControllerToastContent(rawValue: 1 << 1)
    public static let mute = CallControllerToastContent(rawValue: 1 << 2)
    public static let battery = CallControllerToastContent(rawValue: 1 << 3)
}

final class CallControllerToastContainerNode: ASDisplayNode {
    private var toastNodes: [ToastDescription.Key: CallControllerToastItemNode] = [:]
    
    private let strings: PresentationStrings
    
    private var validLayout: (CGFloat, CGFloat)?
    
    private var content: CallControllerToastContent?
    private var appliedContent: CallControllerToastContent?
    var title: String = ""
    
    init(strings: PresentationStrings) {
        self.strings = strings
        
        super.init()
    }
    
    private func updateToastsLayout(strings: PresentationStrings, content: CallControllerToastContent, width: CGFloat, bottomInset: CGFloat, animated: Bool) -> CGFloat {
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.3, curve: .spring)
        } else {
            transition = .immediate
        }
        
        let previousContent = self.appliedContent
        self.appliedContent = content
        
        let spacing: CGFloat = 18.0
        let bottomSpacing: CGFloat = 22.0
    
        var height: CGFloat = 0.0
        var toasts: [ToastDescription] = []
        
        if content.contains(.camera) {
            toasts.append(.camera)
        }
        if content.contains(.microphone) {
            toasts.append(.microphone)
        }
        if content.contains(.mute) {
            toasts.append(.mute)
        }
        if content.contains(.battery) {
            toasts.append(.battery)
        }
        
        var validKeys: [ToastDescription.Key] = []
        for toast in toasts {
            validKeys.append(toast.key)
            var toastTransition = transition
            var animateToastIn = false
            let toastNode: CallControllerToastItemNode
            if let current = self.toastNodes[toast.key] {
                toastNode = current
            } else {
                toastNode = CallControllerToastItemNode()
                self.toastNodes[toast.key] = toastNode
                self.addSubnode(toastNode)
                toastTransition = .immediate
                animateToastIn = transition.isAnimated
            }
            let toastContent: CallControllerToastItemNode.Content
            let toastText: String
            switch toast {
                case .camera:
                    toastContent = CallControllerToastItemNode.Content(
                        image: .camera,
                        text: strings.Call_CameraOff(self.title).0
                    )
                case .microphone:
                    toastContent = CallControllerToastItemNode.Content(
                        image: .microphone,
                        text: strings.Call_MicrophoneOff(self.title).0
                    )
                case .mute:
                    toastContent = CallControllerToastItemNode.Content(
                        image: .microphone,
                        text: strings.Call_YourMicrophoneOff
                    )
                case .battery:
                    toastContent = CallControllerToastItemNode.Content(
                        image: .battery,
                        text: strings.Call_BatteryLow(self.title).0
                    )
            }
            let toastHeight = toastNode.update(width: width, content: buttonContent, text: buttonText, transition: buttonTransition)
            let toastFrame = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 20.0)
            toastTransition.updateFrame(node: toastNode, frame: toastFrame)
            
            height += toastHeight +
            
            if animateToastIn {
                toastNode.animateIn()
            }
        }
        
        var removedKeys: [ToastDescription.Key] = []
        for (key, toast) in self.toastNodes {
            if !validKeys.contains(key) {
                removedKeys.append(key)
                if animated {
                    toast.animateOut(transition: transition) { [weak toast] in
                        toast?.removeFromSupernode()
                    }
                } else {
                    toast.removeFromSupernode()
                }
            }
        }
        for key in removedKeys {
            self.toastNodes.removeValue(forKey: key)
        }
        
        return height
    }
    
    func updateLayout(strings: PresentationStrings, content: CallControllerToastContent?, constrainedWidth: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = (constrainedWidth, bottomInset)
        
        self.content = content
        
        if let content = self.content {
            return self.updateToastsLayout(strings: strings, content: content, width: constrainedWidth, bottomInset: bottomInset, animated: transition.isAnimated)
        } else {
            return 0.0
        }
    }
}

final class CallControllerToastItemNode: ASDisplayNode {
    struct Content: Equatable {
        enum Image {
            case camera
            case microphone
            case battery
        }
        
        var image: Image
        var text: String
        
        init(image: Image, text: String) {
            self.image = image
            self.text = text
        }
    }
    
    let effectView: UIVisualEffectView
    let iconNode: ASImageNode
    let textNode: ImmediateTextNode
    
    private(set) var currentContent: Content?
    private(set) var currentWidth: CGFloat?
    
    override init() {
        self.effectView = UIVisualEffectView()
        self.effectView.effect = UIBlurEffect(style: .light)
        self.effectView.layer.cornerRadius = 16.0
        self.effectView.clipsToBounds = true
        self.effectView.isUserInteractionEnabled = false
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.view.addSubview(self.effectView)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.textNode)
    }
    
    func update(width: CGFloat, content: Content, transition: ContainedViewLayoutTransition) -> CGFloat {
        let inset: CGFloat = 24.0
        
        self.currentWidth = size.width
        
        if self.currentContent != content {
            let previousContent = self.currentContent
            self.currentContent = content
            
            var image: UIImage?
            switch content.image {
                case .camera:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Call/CallToastCamera"), color: .white)
                case .microphone:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Call/CallToastMicrophone"), color: .white)
                case .battery:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Call/CallToastBattery"), color: .white)
            }
            
            if transition.isAnimated, let image = image, let previousContent = self.iconNode.image {
                self.iconNode.image = image
                self.iconNode.layer.animate(from: previousContent.cgImage!, to: image.cgImage!, keyPath: "contents", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
            } else {
                self.iconNode.image = image
            }
            
            if previousContent?.text != content.text {
                let textSize = self.textNode.updateLayout(CGSize(width: size.width - inset * 2.0, height: 100.0))
                let textFrame = CGRect(origin: CGPoint(x: floor((size.width - textSize.width) / 2.0), y: size.height), size: textSize)
                
                if previousContent?.text.isEmpty ?? true {
                    self.textNode.frame = textFrame
                    if transition.isAnimated {
                        self.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                    }
                } else {
                    transition.updateFrameAdditiveToCenter(node: self.textNode, frame: textFrame)
                }
            }
        }
        return 28.0
    }
    
    func animateIn() {
        self.layer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.45, damping: 105.0, completion: { _ in
            
        })
    }
    
    func animateOut(transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        transition.updateTransformScale(node: self, scale: 0.1)
        transition.updateAlpha(node: self, alpha: 0.0, completion: { _ in
            completion()
        })
    }
}
