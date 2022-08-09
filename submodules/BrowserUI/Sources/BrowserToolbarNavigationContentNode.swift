import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import AppBundle

final class BrowserToolbarNavigationContentNode: ASDisplayNode, BrowserToolbarContentNode {
    private var theme: BrowserToolbarTheme
    private var state: BrowserState
    private var interaction: BrowserInteraction?
    
    private let backButton: HighlightableButtonNode
    private let forwardButton: HighlightableButtonNode
    private let shareButton: HighlightableButtonNode
    private let minimizeButton: HighlightableButtonNode
    
    private var validLayout: CGSize?
    
    init(theme: BrowserToolbarTheme, strings: PresentationStrings, state: BrowserState, interaction: BrowserInteraction?) {
        self.theme = theme
        self.state = state
        self.interaction = interaction
        
        self.backButton = HighlightableButtonNode()
        self.backButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Instant View/Back"), color: theme.buttonColor), for: [])
        self.backButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Instant View/Back"), color: theme.disabledButtonColor), for: [.disabled])
        self.forwardButton = HighlightableButtonNode()
        self.forwardButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Instant View/Forward"), color: theme.buttonColor), for: [])
        self.forwardButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Instant View/Forward"), color: theme.disabledButtonColor), for: [.disabled])
        self.shareButton = HighlightableButtonNode()
        self.shareButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat List/NavigationShare"), color: theme.buttonColor), for: [])
        self.minimizeButton = HighlightableButtonNode()
        self.minimizeButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Instant View/Minimize"), color: theme.buttonColor), for: [])
        
        super.init()
        
        self.addSubnode(self.backButton)
        self.addSubnode(self.forwardButton)
        self.addSubnode(self.shareButton)
        self.addSubnode(self.minimizeButton)
        
        self.backButton.isEnabled = false
        self.forwardButton.isEnabled = false
        
        self.backButton.addTarget(self, action: #selector(self.backPressed), forControlEvents: .touchUpInside)
        self.forwardButton.addTarget(self, action: #selector(self.forwardPressed), forControlEvents: .touchUpInside)
        self.shareButton.addTarget(self, action: #selector(self.sharePressed), forControlEvents: .touchUpInside)
        self.minimizeButton.addTarget(self, action: #selector(self.minimizePressed), forControlEvents: .touchUpInside)
    }
    
    func updateState(_ state: BrowserState) {
        self.state = state
        
        self.backButton.isEnabled = state.content?.canGoBack ?? false
        self.forwardButton.isEnabled = state.content?.canGoForward ?? false
    }
    
    func updateTheme(_ theme: BrowserToolbarTheme) {
        guard self.theme !== theme else {
            return
        }
        self.theme = theme
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        let isFirstLayout = self.validLayout == nil
        self.validLayout = size
        
        var transition = transition
        if isFirstLayout {
            transition = .immediate
        }
        
        let buttons = [self.backButton, self.forwardButton, self.shareButton, self.minimizeButton]
        let sideInset: CGFloat = 5.0
        let buttonSize = CGSize(width: 50.0, height: size.height)
        
        let spacing: CGFloat = (size.width - buttonSize.width * CGFloat(buttons.count) - sideInset * 2.0) / CGFloat(buttons.count - 1)
        var offset: CGFloat = sideInset
        for button in buttons {
            transition.updateFrame(node: button, frame: CGRect(origin: CGPoint(x: offset, y: 0.0), size: buttonSize))
            offset += buttonSize.width + spacing
        }
    }
    
    @objc private func backPressed() {
        self.interaction?.navigateBack()
    }
    
    @objc private func forwardPressed() {
        self.interaction?.navigateForward()
    }
    
    @objc private func sharePressed() {
        self.interaction?.share()
    }
    
    @objc private func minimizePressed() {
        self.interaction?.minimize()
    }
}
 
