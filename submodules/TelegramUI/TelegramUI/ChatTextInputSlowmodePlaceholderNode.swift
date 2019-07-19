import Foundation
import Display
import SwiftSignalKit
import TelegramPresentationData

final class ChatTextInputSlowmodePlaceholderNode: ASDisplayNode {
    private var theme: PresentationTheme
    private let iconNode: ASImageNode
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
        self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Text/AccessoryIconTimer"), color: theme.chat.inputPanel.inputPlaceholderColor)
        
        super.init()
        
        self.isUserInteractionEnabled = false
        
        self.addSubnode(self.iconNode)
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
            let imageSize = image.size.aspectFitted(CGSize(width: 20.0, height: 20.0))
            leftInset += imageSize.width + 2.0
            self.iconNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: imageSize)
        }
        
        let textSize = self.textNode.updateLayout(size)
        self.textNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: textSize)
    }
}
