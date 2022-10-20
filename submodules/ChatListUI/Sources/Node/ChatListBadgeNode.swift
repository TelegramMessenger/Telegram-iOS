import Foundation
import UIKit
import AsyncDisplayKit
import Display

enum ChatListBadgeContent: Equatable {
    case none
    case blank
    case text(NSAttributedString)
    case mention
    
    var text: String? {
        if case let .text(text) = self {
            return text.string
        }
        return nil
    }
    
    var isEmpty: Bool {
        if case .none = self {
            return true
        }
        return false
    }
}

private func measureString(_ string: String) -> String {
    let wideChar = "8"
    if string.count < 2 {
        return wideChar
    } else {
        return string[string.startIndex ..< string.index(string.endIndex, offsetBy: -1)] + wideChar
    }
}

final class ChatListBadgeNode: ASDisplayNode {
    private let backgroundNode: ASImageNode
    private let textNode: TextNode
    private let measureTextNode: TextNode
    
    private var text: String?
    private var content: ChatListBadgeContent?
    
    private var isHiddenInternal = false
    
    override init() {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        
        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        
        self.measureTextNode = TextNode()
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.textNode)
    }
    
    func asyncLayout() -> (CGSize, CGFloat, UIFont, UIImage?, ChatListBadgeContent) -> (CGSize, (Bool, Bool) -> Void) {
        let textLayout = TextNode.asyncLayout(self.textNode)
        let measureTextLayout = TextNode.asyncLayout(self.measureTextNode)
        
        let currentContent = self.content
        
        return { [weak self] boundingSize, imageWidth, badgeFont, backgroundImage, content in
            var badgeWidth: CGFloat = 0.0
            
            var textLayoutAndApply: (TextNodeLayout, () -> TextNode)?
            switch content {
                case let .text(text):
                    textLayoutAndApply = textLayout(TextNodeLayoutArguments(attributedString: text, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: boundingSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                    
                    let (measureLayout, _) = measureTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: measureString(text.string), font: badgeFont, textColor: .black), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: boundingSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                    
                    badgeWidth = max(imageWidth, measureLayout.size.width + imageWidth / 2.0)
                case .mention, .blank:
                    badgeWidth = imageWidth
                case .none:
                    badgeWidth = 0.0
            }
            
            return (CGSize(width: badgeWidth, height: imageWidth), { animated, bounce in
                if let strongSelf = self {
                    strongSelf.content = content
                    
                    if let backgroundImage = backgroundImage {
                        strongSelf.backgroundNode.image = backgroundImage
                    }
                    
                    if content == currentContent {
                        return
                    }
                    
                    let badgeWidth = max(imageWidth, badgeWidth)
                    let previousBadgeWidth = !strongSelf.backgroundNode.frame.width.isZero ? strongSelf.backgroundNode.frame.width : badgeWidth
                    
                    var animateTextNode = false
                    if animated {
                        strongSelf.isHidden = false
                        
                        let currentIsEmpty = currentContent?.isEmpty ?? true
                        let nextIsEmpty = content.isEmpty
                        
                        if !nextIsEmpty {
                            if case .text = content {
                                strongSelf.textNode.alpha = 1.0
                            } else {
                                strongSelf.textNode.alpha = 0.0
                            }
                        }
                        
                        if currentIsEmpty && !nextIsEmpty {
                            strongSelf.isHiddenInternal = false
                            if bounce {
                                strongSelf.layer.animateScale(from: 0.0001, to: 1.2, duration: 0.2, removeOnCompletion: false, completion: { [weak self] finished in
                                    if let strongSelf = self {
                                        strongSelf.layer.animateScale(from: 1.15, to: 1.0, duration: 0.12, removeOnCompletion: false)
                                    }
                                })
                            } else {
                                strongSelf.layer.animateScale(from: 0.0001, to: 1.0, duration: 0.2, removeOnCompletion: false)
                            }
                        } else if !currentIsEmpty && !nextIsEmpty && currentContent?.text != content.text {
                            var animateScale = bounce
                            strongSelf.isHiddenInternal = false
                            if let currentText = currentContent?.text, let currentValue = Int(currentText), let text = content.text, let value = Int(text) {
                                if value < currentValue {
                                    animateScale = false
                                }
                            }
                            
                            if animateScale {
                                strongSelf.layer.animateScale(from: 1.0, to: 1.2, duration: 0.12, removeOnCompletion: false, completion: { [weak self] finished in
                                    if let strongSelf = self {
                                        strongSelf.layer.animateScale(from: 1.2, to: 1.0, duration: 0.12, removeOnCompletion: false)
                                    }
                                })
                            }
                            
                            var animateSnapshot = true
                            if let currentContent = currentContent, case .blank = currentContent {
                                animateSnapshot = false
                            }
                            if animateSnapshot, let snapshotView = strongSelf.textNode.view.snapshotContentTree() {
                                snapshotView.frame = strongSelf.textNode.frame
                                strongSelf.textNode.view.superview?.insertSubview(snapshotView, aboveSubview: strongSelf.textNode.view)
                                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                                    snapshotView?.removeFromSuperview()
                                })
                                snapshotView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: (badgeWidth - previousBadgeWidth) / 2.0, y: -8.0), duration: 0.15, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
                            }
                            animateTextNode = true
                        } else if !currentIsEmpty && nextIsEmpty && !strongSelf.isHiddenInternal {
                            strongSelf.isHiddenInternal = true
                            strongSelf.layer.animateScale(from: 1.0, to: 0.0001, duration: 0.12, removeOnCompletion: false, completion: { [weak self] finished in
                                if let strongSelf = self {
                                    strongSelf.isHidden = true
                                    strongSelf.layer.removeAnimation(forKey: "transform.scale")
                                }
                            })
                        }
                    } else {
                        if case .none = content {
                            strongSelf.isHidden = true
                            strongSelf.isHiddenInternal = true
                        } else {
                            strongSelf.isHidden = false
                            strongSelf.isHiddenInternal = false
                        }
                        if case .text = content {
                            strongSelf.textNode.alpha = 1.0
                        } else {
                            strongSelf.textNode.alpha = 0.0
                        }
                    }
                    
                    let _ = textLayoutAndApply?.1()
     
                    let backgroundFrame = CGRect(x: 0.0, y: 0.0, width: badgeWidth, height: strongSelf.backgroundNode.image?.size.height ?? 0.0)
                    if let (textLayout, _) = textLayoutAndApply {
                        let badgeTextFrame = CGRect(origin: CGPoint(x: backgroundFrame.midX - textLayout.size.width / 2.0, y: backgroundFrame.minY + 2.0), size: textLayout.size)
                        strongSelf.textNode.frame = badgeTextFrame
                        if animateTextNode {
                            strongSelf.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                            strongSelf.textNode.layer.animatePosition(from: CGPoint(x: (previousBadgeWidth - badgeWidth) / 2.0, y: 8.0), to: CGPoint(), duration: 0.15, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
                        }
                    }
                    strongSelf.backgroundNode.frame = backgroundFrame
                    
                    if animated && badgeWidth != previousBadgeWidth {
                        let previousBackgroundFrame = CGRect(x: 0.0, y: 0.0, width: previousBadgeWidth, height: backgroundFrame.height)
                        strongSelf.backgroundNode.layer.animateFrame(from: previousBackgroundFrame, to: backgroundFrame, duration: 0.15, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                    }
                }
            })
        }
    }
}
