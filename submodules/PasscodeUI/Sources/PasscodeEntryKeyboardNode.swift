import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit

private let regularTitleFont = Font.regular(36.0)
private let regularSubtitleFont: UIFont = {
    if #available(iOS 8.2, *) {
        return UIFont.systemFont(ofSize: 10.0, weight: UIFont.Weight.bold)
    } else {
        return CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 10.0, nil)
    }
}()

private let largeTitleFont = Font.regular(40.0)
private let largeSubtitleFont: UIFont = {
    if #available(iOS 8.2, *) {
        return UIFont.systemFont(ofSize: 12.0, weight: UIFont.Weight.bold)
    } else {
        return CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 12.0, nil)
    }
}()

private func generateButtonImage(background: PasscodeBackground, frame: CGRect, title: String, subtitle: String, highlighted: Bool) -> UIImage? {
    return generateImage(frame.size, contextGenerator: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let relativeFrame = CGRect(x: -frame.minX, y: frame.minY - background.size.height + frame.size.height
            , width: background.size.width, height: background.size.height)
        
        context.beginPath()
        context.addEllipse(in: bounds)
        context.clip()
        
        context.setAlpha(0.8)
        context.draw(background.foregroundImage.cgImage!, in: relativeFrame)
        
        if highlighted {
            context.setFillColor(UIColor(white: 1.0, alpha: 0.65).cgColor)
            context.fillEllipse(in: bounds)
        }
        
        context.setAlpha(1.0)
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

final class PasscodeEntryButtonNode: HighlightTrackingButtonNode {
    private var background: PasscodeBackground
    let title: String
    private let subtitle: String
    
    private var currentImage: UIImage?
    private var regularImage: UIImage?
    private var highlightedImage: UIImage?
    
    private let backgroundNode: ASImageNode
    
    var action: (() -> Void)?
    
    init(background: PasscodeBackground, title: String, subtitle: String) {
        self.background = background
        self.title = title
        self.subtitle = subtitle
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                strongSelf.updateState(highlighted: highlighted)
            }
        }
        
        self.addTarget(self, action: #selector(self.nop), forControlEvents: .touchUpInside)
    }
    
    @objc private func nop() {
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
    
    func updateBackground(_ background: PasscodeBackground) {
        self.background = background
        self.updateGraphics()
    }
    
    private func updateGraphics() {
        self.regularImage = generateButtonImage(background: self.background, frame: self.frame, title: self.title, subtitle: self.subtitle, highlighted: false)
        self.highlightedImage = generateButtonImage(background: self.background, frame: self.frame, title: self.title, subtitle: self.subtitle, highlighted: true)
        self.updateState(highlighted: self.isHighlighted)
    }
    
    private func updateState(highlighted: Bool) {
        let image = highlighted ? self.highlightedImage : self.regularImage
        if self.currentImage !== image {
            let currentContents = self.backgroundNode.layer.contents
            self.backgroundNode.layer.removeAnimation(forKey: "contents")
            if let currentContents = currentContents, let image = image {
                self.backgroundNode.image = image
                self.backgroundNode.layer.animate(from: currentContents as AnyObject, to: image.cgImage!, keyPath: "contents", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: image === self.regularImage ? 0.45 : 0.05)
            } else {
                self.backgroundNode.image = image
            }
            self.currentImage = image
        }
    }
    
    override func layout() {
        super.layout()
        
        self.backgroundNode.frame = self.bounds
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        self.action?()
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
    private var background: PasscodeBackground?
    
    var charactedEntered: ((String) -> Void)?
    
    private func updateButtons() {
        guard let background = self.background else {
            return
        }
        
        if let subnodes = self.subnodes, !subnodes.isEmpty {
            for case let button as PasscodeEntryButtonNode in subnodes {
                button.updateBackground(background)
            }
        } else {
            for (title, subtitle) in buttonsData {
                let buttonNode = PasscodeEntryButtonNode(background: background, title: title, subtitle: subtitle)
                buttonNode.action = { [weak self] in
                    self?.charactedEntered?(title)
                }
                self.addSubnode(buttonNode)
            }
        }
    }
    
    func updateBackground(_ background: PasscodeBackground) {
        self.background = background
        self.updateButtons()
    }
    
    func animateIn() {
        if let subnodes = self.subnodes {
            for i in 0 ..< subnodes.count {
                let subnode = subnodes[i]
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
                subnode.layer.animateScale(from: 0.0001, to: 1.0, duration: 0.25, delay: delay, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
            }
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
        
        if let subnodes = self.subnodes {
            for i in 0 ..< subnodes.count {
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
                transition.updateFrame(node: subnodes[i], frame: CGRect(origin: origin, size: CGSize(width: buttonSize, height: buttonSize)))
            }
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
