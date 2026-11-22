import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import GlassBackgroundComponent

private let cancelFont = Font.regular(17.0)

public final class ChatTextInputAudioRecordingCancelIndicator: UIView, GlassBackgroundView.ContentView {
    private let cancel: () -> Void
    
    private let arrowView: GlassBackgroundView.ContentImageView
    private let labelNode: TextNode
    private let tintLabelNode: TextNode
    private let cancelButton: HighlightableButtonNode
    private let strings: PresentationStrings
    
    public let tintMask: UIView
    
    public private(set) var isDisplayingCancel = false
    
    public init(theme: PresentationTheme, strings: PresentationStrings, cancel: @escaping () -> Void) {
        self.tintMask = UIView()
        
        self.cancel = cancel
        
        self.arrowView = GlassBackgroundView.ContentImageView()
        self.arrowView.image = UIImage(bundleImageName: "Chat/Input/Text/AudioRecordingCancelArrow")?.withRenderingMode(.alwaysTemplate)
        self.arrowView.tintColor = theme.chat.inputPanel.panelControlColor
        
        self.labelNode = TextNode()
        self.labelNode.displaysAsynchronously = false
        self.labelNode.isUserInteractionEnabled = false
        
        self.tintLabelNode = TextNode()
        self.tintLabelNode.displaysAsynchronously = false
        self.tintLabelNode.isUserInteractionEnabled = false
        
        self.cancelButton = HighlightableButtonNode()
        self.cancelButton.setTitle(strings.Common_Cancel, with: cancelFont, with: theme.chat.inputPanel.panelControlAccentColor, for: [])
        self.cancelButton.alpha = 0.0
        self.cancelButton.accessibilityLabel = strings.Common_Cancel
        self.cancelButton.accessibilityTraits = [.button]
        
        self.strings = strings
        
        super.init(frame: CGRect())
        
        self.addSubview(self.arrowView)
        self.tintMask.addSubview(self.arrowView.tintMask)
        
        self.addSubview(self.labelNode.view)
        self.tintMask.addSubview(self.tintLabelNode.view)
        self.addSubnode(self.cancelButton)
        
        let makeLayout = TextNode.asyncLayout(self.labelNode)
        let makeTintLayout = TextNode.asyncLayout(self.tintLabelNode)
        let (labelLayout, labelApply) = makeLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: strings.Conversation_SlideToCancel, font: Font.regular(14.0), textColor: theme.chat.inputPanel.panelControlColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 200.0, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        let (_, tintLabelApply) = makeTintLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: strings.Conversation_SlideToCancel, font: Font.regular(14.0), textColor: .black), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 200.0, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        let _ = labelApply()
        let _ = tintLabelApply
        
        let arrowSize = self.arrowView.image?.size ?? CGSize()
        let height = max(arrowSize.height, labelLayout.size.height)
        self.frame = CGRect(origin: CGPoint(), size: CGSize(width: arrowSize.width + 12.0 + labelLayout.size.width, height: height))
        self.arrowView.frame = CGRect(origin: CGPoint(x: 0.0, y: floor((height - arrowSize.height) / 2.0)), size: arrowSize)
        self.labelNode.frame = CGRect(origin: CGPoint(x: arrowSize.width + 6.0, y: 1.0 + floor((height - labelLayout.size.height) / 2.0)), size: labelLayout.size)
        self.tintLabelNode.frame = self.labelNode.frame
        
        let cancelSize = self.cancelButton.measure(CGSize(width: 200.0, height: 100.0))
        self.cancelButton.frame = CGRect(origin: CGPoint(x: floor((self.bounds.size.width - cancelSize.width) / 2.0), y: floor((height - cancelSize.height) / 2.0)), size: cancelSize)
        
        self.cancelButton.addTarget(self, action: #selector(self.cancelPressed), forControlEvents: .touchUpInside)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func updateTheme(theme: PresentationTheme) {
        self.arrowView.tintColor = theme.chat.inputPanel.panelControlColor
        self.cancelButton.setTitle(self.strings.Common_Cancel, with: cancelFont, with: theme.chat.inputPanel.panelControlAccentColor, for: [])
        let makeLayout = TextNode.asyncLayout(self.labelNode)
        let makeTintLayout = TextNode.asyncLayout(self.tintLabelNode)
        let (_, labelApply) = makeLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: strings.Conversation_SlideToCancel, font: Font.regular(14.0), textColor: theme.chat.inputPanel.actionControlForegroundColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 200.0, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        let (_, tintLabelApply) = makeTintLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: strings.Conversation_SlideToCancel, font: Font.regular(14.0), textColor: .black), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 200.0, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        let _ = labelApply()
        let _ = tintLabelApply()
    }
    
    public func updateIsDisplayingCancel(_ isDisplayingCancel: Bool, animated: Bool) {
        if self.isDisplayingCancel != isDisplayingCancel {
            self.isDisplayingCancel = isDisplayingCancel
            if isDisplayingCancel {
                self.arrowView.alpha = 0.0
                self.labelNode.alpha = 0.0
                self.cancelButton.alpha = 1.0
                
                if animated {
                    //CGAffineTransform transform = CGAffineTransformMakeTranslation(0.0f, -22.0f);
                    //transform = CGAffineTransformScale(transform, 0.25f, 0.25f);
                    
                    self.labelNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -22.0), duration: 0.2, removeOnCompletion: false, additive: true)
                    self.labelNode.layer.animateScale(from: 1.0, to: 0.25, duration: 0.25, removeOnCompletion: false)
                    
                    self.cancelButton.layer.animatePosition(from: CGPoint(x: 0.0, y: 22.0), to: CGPoint(), duration: 0.2, additive: true)
                    self.cancelButton.layer.animateScale(from: 0.25, to: 1.0, duration: 0.25)
                    
                    self.arrowView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25)
                    self.labelNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25)
                    self.cancelButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                }
            } else {
                self.arrowView.alpha = 1.0
                self.labelNode.alpha = 1.0
                self.cancelButton.alpha = 0.0
                
                if animated {
                    self.arrowView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                    self.labelNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                    self.cancelButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25)
                }
            }
        }
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.cancelButton.alpha.isZero, self.cancelButton.frame.insetBy(dx: -5.0, dy: -5.0).contains(point) {
            return self.cancelButton.view
        }
        return super.hitTest(point, with: event)
    }
    
    @objc private func cancelPressed() {
        self.cancel()
    }
    
    public func animateIn() {
    }
    
    public func animateOut() {
    }
}
