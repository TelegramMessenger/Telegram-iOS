import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import TelegramStringFormatting
import AppBundle
import ChatPresentationInterfaceState

final class ChatTextInputSlowmodePlaceholderNode: ASDisplayNode {
    private var theme: PresentationTheme
    private let iconNode: ASImageNode
    private let iconArrowContainerNode: ASDisplayNode
    private let iconArrowNode: ASImageNode
    private let textNode: ImmediateTextNode
    
    private var slowmodeState: ChatSlowmodeState?
    private var validLayout: CGSize?
    
    private var timer: SwiftSignalKit.Timer?
    
    init(theme: PresentationTheme) {
        self.theme = theme
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Text/SlowmodeFrame"), color: theme.chat.inputPanel.inputPlaceholderColor)
        
        self.iconArrowNode = ASImageNode()
        self.iconArrowNode.displaysAsynchronously = false
        self.iconArrowNode.displayWithoutProcessing = true
        self.iconArrowNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Text/SlowmodeArrow"), color: theme.chat.inputPanel.inputPlaceholderColor)
        self.iconArrowNode.frame = CGRect(origin: CGPoint(), size: self.iconArrowNode.image?.size ?? CGSize())
        
        self.iconArrowContainerNode = ASDisplayNode()
        self.iconArrowContainerNode.addSubnode(self.iconArrowNode)
        
        super.init()
        
        self.isUserInteractionEnabled = false
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.iconArrowContainerNode)
        self.addSubnode(self.textNode)
    }
    
    deinit {
        self.timer?.invalidate()
    }
    
    func updateState(_ slowmodeState: ChatSlowmodeState) {
        if self.slowmodeState != slowmodeState {
            self.slowmodeState = slowmodeState
            self.update()
            
            if self.timer == nil {
                let timer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
                    self?.update()
                }, queue: .mainQueue())
                self.timer = timer
                timer.start()
            }
        }
    }
    
    private func update() {
        if let slowmodeState = self.slowmodeState {
            switch slowmodeState.variant {
            case .pendingMessages:
                self.textNode.attributedText = NSAttributedString(string: stringForDuration(slowmodeState.timeout), font: Font.regular(17.0), textColor: self.theme.chat.inputPanel.inputPlaceholderColor)
            case let .timestamp(timeoutTimestamp):
                let timestamp = Int32(Date().timeIntervalSince1970)
                let timeout = max(0, timeoutTimestamp - timestamp)
                self.textNode.attributedText = NSAttributedString(string: stringForDuration(timeout), font: Font.regular(17.0), textColor: self.theme.chat.inputPanel.inputPlaceholderColor)
                if timeout <= 30 {
                    if self.iconArrowNode.layer.animation(forKey: "rotation") == nil {
                        let basicAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
                        basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
                        basicAnimation.duration = 1.0
                        basicAnimation.fromValue = NSNumber(value: Float(0.0))
                        basicAnimation.toValue = NSNumber(value: Float(Double.pi * 2.0))
                        basicAnimation.repeatCount = Float.infinity
                        basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
                        self.iconArrowNode.layer.add(basicAnimation, forKey: "rotation")
                    }
                } else {
                    self.iconArrowNode.layer.removeAnimation(forKey: "rotation")
                }
            }
        }
        if let validLayout = self.validLayout {
            self.updateLayout(size: validLayout)
        }
    }
    
    func updateLayout(size: CGSize) {
        self.validLayout = size
        
        var leftInset: CGFloat = 0.0
        if let image = self.iconNode.image {
            let imageSize = image.size
            leftInset += imageSize.width + 4.0
            let iconArrowFrame = CGRect(origin: CGPoint(x: 0.0, y: 1.0), size: imageSize)
            self.iconNode.frame = iconArrowFrame
            
            if let arrowImage = self.iconArrowNode.image {
                self.iconArrowContainerNode.frame = CGRect(origin: CGPoint(x: iconArrowFrame.minX, y: iconArrowFrame.maxY - arrowImage.size.height), size: arrowImage.size)
            }
        }
        
        let textSize = self.textNode.updateLayout(size)
        self.textNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: textSize)
    }
}
