import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import AppBundle

final class BrowserToolbarSearchContentNode: ASDisplayNode, BrowserToolbarContentNode {
    private var theme: BrowserToolbarTheme
    private let strings: PresentationStrings
    private var state: BrowserState
    private var interaction: BrowserInteraction?
    
    private let upButton: HighlightableButtonNode
    private let downButton: HighlightableButtonNode
    private let resultsNode: ImmediateTextNode
    
    private var validLayout: CGSize?
        
    init(theme: BrowserToolbarTheme, strings: PresentationStrings, state: BrowserState, interaction: BrowserInteraction?) {
        self.theme = theme
        self.strings = strings
        self.state = state
        self.interaction = interaction
        
        self.upButton = HighlightableButtonNode()
        self.upButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Search/UpButton"), color: theme.buttonColor), for: .normal)
        self.upButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Search/UpButton"), color: theme.disabledButtonColor), for: .disabled)
        self.downButton = HighlightableButtonNode()
        self.downButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Search/DownButton"), color: theme.buttonColor), for: .normal)
        self.downButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Search/DownButton"), color: theme.disabledButtonColor), for: .disabled)
        self.resultsNode = ImmediateTextNode()
        
        super.init()
        
        self.addSubnode(self.upButton)
        self.addSubnode(self.downButton)
        self.addSubnode(self.resultsNode)
        
        self.upButton.addTarget(self, action: #selector(self.upPressed), forControlEvents: .touchUpInside)
        self.downButton.addTarget(self, action: #selector(self.downPressed), forControlEvents: .touchUpInside)
    }
    
    func updateState(_ state: BrowserState) {
        self.state = state
        
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: .immediate)
        }
    }
    
    func updateTheme(_ theme: BrowserToolbarTheme) {
        guard self.theme !== theme else {
            return
        }
        self.theme = theme
        
        self.upButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Search/UpButton"), color: theme.buttonColor), for: .normal)
        self.upButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Search/UpButton"), color: theme.disabledButtonColor), for: .disabled)
        self.downButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Search/DownButton"), color: theme.buttonColor), for: .normal)
        self.downButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Search/DownButton"), color: theme.disabledButtonColor), for: .disabled)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        let buttonSize = CGSize(width: 40.0, height: size.height)
        
        let resultsText: String
        if let results = self.state.search?.results {
            if results.1 > 0 {
                resultsText = self.strings.Items_NOfM("\(results.0 + 1)", "\(results.1)").string
            } else {
                resultsText = self.strings.Conversation_SearchNoResults
            }
        } else {
            resultsText = ""
        }
        
        self.resultsNode.attributedText = NSAttributedString(string: resultsText, font: Font.regular(15.0), textColor: self.theme.buttonColor, paragraphAlignment: .natural)
        let resultsSize = self.resultsNode.updateLayout(size)
        self.resultsNode.frame = CGRect(origin: CGPoint(x: size.width - 48.0 - 43.0 - resultsSize.width - 12.0, y: floor((size.height - resultsSize.height) / 2.0)), size: resultsSize)
        
        self.downButton.frame = CGRect(origin: CGPoint(x: size.width - 48.0, y: 0.0), size: buttonSize)
        self.upButton.frame = CGRect(origin: CGPoint(x: size.width - 48.0 - 43.0, y: 0.0), size: buttonSize)
    }
    
    @objc private func upPressed() {
        self.interaction?.scrollToPreviousSearchResult()
    }
    
    @objc private func downPressed() {
        self.interaction?.scrollToNextSearchResult()
    }
}
