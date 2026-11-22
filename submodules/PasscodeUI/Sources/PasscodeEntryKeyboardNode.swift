import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import GlassBackgroundComponent

private let regularTitleFont = Font.regular(36.0)
private let regularSubtitleFont: UIFont = {
    return UIFont.systemFont(ofSize: 10.0, weight: UIFont.Weight.bold)
}()

private let largeTitleFont = Font.regular(40.0)
private let largeSubtitleFont: UIFont = {
    return UIFont.systemFont(ofSize: 12.0, weight: UIFont.Weight.bold)
}()

private func generateButtonContentImage(size: CGSize, title: String, subtitle: String) -> UIImage? {
    return generateImage(size, contextGenerator: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        context.beginPath()
        context.addEllipse(in: bounds)
        context.clip()
        
        context.textMatrix = .identity
        
        let titleFont: UIFont
        let subtitleFont: UIFont
        let titleOffset: CGFloat
        let subtitleOffset: CGFloat
        if size.width > 80.0 {
            titleFont = largeTitleFont
            subtitleFont = largeSubtitleFont
            if subtitle.isEmpty {
                titleOffset = -18.0
            } else {
                titleOffset = -11.0
            }
            subtitleOffset = -54.0
        } else if size.width > 70.0 {
            titleFont = regularTitleFont
            subtitleFont = regularSubtitleFont
            if subtitle.isEmpty {
                titleOffset = -17.0
            } else {
                titleOffset = -10.0
            }
            subtitleOffset = -48.0
        }
        else {
            titleFont = regularTitleFont
            subtitleFont = regularSubtitleFont
            if subtitle.isEmpty {
                titleOffset = -11.0
            } else {
                titleOffset = -4.0
            }
            subtitleOffset = -41.0
        }
        
        let titlePath = CGMutablePath()
        titlePath.addRect(bounds.offsetBy(dx: 0.0, dy: titleOffset))
        let titleString = NSAttributedString(string: title, font: titleFont, textColor: .white, paragraphAlignment: .center)
        let titleFramesetter = CTFramesetterCreateWithAttributedString(titleString as CFAttributedString)
        let titleFrame = CTFramesetterCreateFrame(titleFramesetter, CFRangeMake(0, titleString.length), titlePath, nil)
        CTFrameDraw(titleFrame, context)
        
        if !subtitle.isEmpty {
            let subtitlePath = CGMutablePath()
            subtitlePath.addRect(bounds.offsetBy(dx: 0.0, dy: subtitleOffset))
            let subtitleString = NSAttributedString(string: subtitle, font: subtitleFont, textColor: .white, paragraphAlignment: .center)
            let subtitleFramesetter = CTFramesetterCreateWithAttributedString(subtitleString as CFAttributedString)
            let subtitleFrame = CTFramesetterCreateFrame(subtitleFramesetter, CFRangeMake(0, subtitleString.length), subtitlePath, nil)
            CTFrameDraw(subtitleFrame, context)
        }
    })
}

final class PasscodeEntryButtonNode: ASDisplayNode {
    private var presentationData: PresentationData
    let title: String
    private let subtitle: String
    
    private let backgroundView: GlassBackgroundView
    private let button: HighlightTrackingButton
    private let contentNode: ASImageNode
    
    var action: (() -> Void)?
    var cancelAction: (() -> Void)?
    
    init(presentationData: PresentationData, title: String, subtitle: String) {
        self.presentationData = presentationData
        self.title = title
        self.subtitle = subtitle
        
        self.backgroundView = GlassBackgroundView()

        self.button = HighlightTrackingButton()
        self.button.accessibilityLabel = title
        self.button.accessibilityTraits = .keyboardKey
        
        self.contentNode = ASImageNode()
        self.contentNode.displaysAsynchronously = false
        self.contentNode.displayWithoutProcessing = true
        self.contentNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchDown)
        self.button.addTarget(self, action: #selector(self.buttonCancelled), for: [.touchUpOutside, .touchCancel])
    }
    
    override func didLoad() {
        super.didLoad()

        self.view.addSubview(self.backgroundView)
        self.backgroundView.contentView.addSubview(self.button)
        self.button.addSubview(self.contentNode.view)
    }

    @objc private func buttonPressed() {
        self.action?()
    }

    @objc private func buttonCancelled() {
        self.cancelAction?()
    }
    
    override var frame: CGRect {
        get {
            return super.frame
        }
        set {
            super.frame = newValue
            self.updateGraphics()
        }
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.updateGraphics()
        self.setNeedsLayout()
    }
    
    private func updateGraphics() {
        self.contentNode.image = generateButtonContentImage(size: self.bounds.size, title: self.title, subtitle: self.subtitle)
    }
    
    override func layout() {
        super.layout()
        
        self.backgroundView.frame = self.bounds
        self.backgroundView.update(size: self.bounds.size, cornerRadius: self.bounds.height / 2.0, isDark: self.presentationData.theme.overallDarkAppearance, tintColor: .init(kind: .clear), isInteractive: true, transition: .immediate)
        self.button.frame = self.bounds
        self.contentNode.frame = self.bounds
    }
}

private let buttonsData = [
    ("1", " "),
    ("2", "A B C"),
    ("3", "D E F"),
    ("4", "G H I"),
    ("5", "J K L"),
    ("6", "M N O"),
    ("7", "P Q R S"),
    ("8", "T U V"),
    ("9", "W X Y Z"),
    ("0", "")
]

final class PasscodeEntryKeyboardNode: ASDisplayNode {
    private var presentationData: PresentationData?
    private var background: PasscodeBackground?

    private let backgroundContainer = GlassBackgroundContainerView()
    private var buttonNodes: [PasscodeEntryButtonNode] = []
    
    var charactedEntered: ((String) -> Void)?
    var backspace: (() -> Void)?

    override func didLoad() {
        super.didLoad()

        self.view.addSubview(self.backgroundContainer)
        for buttonNode in self.buttonNodes {
            self.backgroundContainer.contentView.addSubview(buttonNode.view)
        }
    }

    override func layout() {
        super.layout()

        self.backgroundContainer.frame = self.bounds
        self.backgroundContainer.update(size: self.bounds.size, isDark: self.presentationData?.theme.overallDarkAppearance ?? false, transition: .immediate)
    }
    
    private func updateButtons() {
        guard let presentationData = self.presentationData, self.background != nil else {
            return
        }
        
        if !self.buttonNodes.isEmpty {
            for button in self.buttonNodes {
                button.updatePresentationData(presentationData)
            }
        } else {
            for (title, subtitle) in buttonsData {
                let buttonNode = PasscodeEntryButtonNode(presentationData: presentationData, title: title, subtitle: subtitle)
                buttonNode.action = { [weak self] in
                    self?.charactedEntered?(title)
                }
                buttonNode.cancelAction = { [weak self] in
                    self?.backspace?()
                }
                self.buttonNodes.append(buttonNode)
                if self.isNodeLoaded {
                    self.backgroundContainer.contentView.addSubview(buttonNode.view)
                }
            }
        }
    }
    
    func updateBackground(_ presentationData: PresentationData, _ background: PasscodeBackground) {
        self.presentationData = presentationData
        self.background = background
        self.updateButtons()
        self.setNeedsLayout()
    }
    
    func animateIn() {
        for (i, buttonNode) in self.buttonNodes.enumerated() {
            var delay: Double = 0.001
            if i / 3 == 1 {
                delay = 0.05
            }
            else if i / 3 == 2 {
                delay = 0.1
            }
            else if i / 3 == 3 {
                delay = 0.15
            }
            buttonNode.layer.animateScale(from: 0.0001, to: 1.0, duration: 0.25, delay: delay, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
        }
    }
    
    func updateLayout(layout: PasscodeLayout, transition: ContainedViewLayoutTransition) -> (CGRect, CGSize) {
        let origin: CGPoint
        let buttonSize: CGFloat
        let horizontalSecond: CGFloat
        let horizontalThird: CGFloat
        let verticalSecond: CGFloat
        let verticalThird: CGFloat
        let verticalFourth: CGFloat
        let keyboardSize: CGSize
        
        if layout.layout.orientation == .landscape && layout.layout.deviceMetrics.type != .tablet {
            let horizontalSpacing: CGFloat = 20.0
            let verticalSpacing: CGFloat = 12.0
            buttonSize = 65.0
            keyboardSize = CGSize(width: buttonSize * 3.0 + horizontalSpacing * 2.0, height: buttonSize * 4.0 + verticalSpacing * 3.0)
            horizontalSecond = buttonSize + horizontalSpacing
            horizontalThird = buttonSize * 2.0 + horizontalSpacing * 2.0
            verticalSecond = buttonSize + verticalSpacing
            verticalThird = buttonSize * 2.0 + verticalSpacing * 2.0
            verticalFourth = buttonSize * 3.0 + verticalSpacing * 3.0
            origin = CGPoint(x: floor(layout.layout.size.width / 2.0 + (layout.layout.size.width / 2.0 - keyboardSize.width) / 2.0) - layout.layout.safeInsets.right, y: floor((layout.layout.size.height - keyboardSize.height) / 2.0))
        } else {
            origin = CGPoint(x: floor((layout.layout.size.width - layout.keyboard.size.width) / 2.0), y: layout.keyboard.topOffset)
            buttonSize = layout.keyboard.buttonSize
            horizontalSecond = layout.keyboard.horizontalSecond
            horizontalThird = layout.keyboard.horizontalThird
            verticalSecond = layout.keyboard.verticalSecond
            verticalThird = layout.keyboard.verticalThird
            verticalFourth = layout.keyboard.verticalFourth
            keyboardSize = layout.keyboard.size
        }
        
        for (i, buttonNode) in self.buttonNodes.enumerated() {
            var origin = origin
            if i % 3 == 0 {
                origin.x += 0.0
            } else if (i % 3 == 1) {
                origin.x += horizontalSecond
            }
            else {
                origin.x += horizontalThird
            }

            if i / 3 == 0 {
                origin.y += 0.0
            }
            else if i / 3 == 1 {
                origin.y += verticalSecond
            }
            else if i / 3 == 2 {
                origin.y += verticalThird
            }
            else if i / 3 == 3 {
                origin.x += horizontalSecond
                origin.y += verticalFourth
            }
            transition.updateFrame(node: buttonNode, frame: CGRect(origin: origin, size: CGSize(width: buttonSize, height: buttonSize)))
        }
        return (CGRect(origin: origin, size: keyboardSize), CGSize(width: buttonSize, height: buttonSize))
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if let result = result, result.isDescendant(of: self.view) {
            return result
        }
        return nil
    }
}
