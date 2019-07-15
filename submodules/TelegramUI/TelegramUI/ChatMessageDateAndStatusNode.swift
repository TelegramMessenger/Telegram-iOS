import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import SwiftSignalKit
import TelegramPresentationData

private let dateFont = UIFont.italicSystemFont(ofSize: 11.0)

private func maybeAddRotationAnimation(_ layer: CALayer, duration: Double) {
    if let _ = layer.animation(forKey: "clockFrameAnimation") {
        return
    }
    
    let basicAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
    basicAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
    basicAnimation.duration = duration
    basicAnimation.fromValue = NSNumber(value: Float(0.0))
    basicAnimation.toValue = NSNumber(value: Float(Double.pi * 2.0))
    basicAnimation.repeatCount = Float.infinity
    basicAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
    basicAnimation.beginTime = 1.0
    layer.add(basicAnimation, forKey: "clockFrameAnimation")
}

enum ChatMessageDateAndStatusOutgoingType: Equatable {
    case Sent(read: Bool)
    case Sending
    case Failed
    
    static func ==(lhs: ChatMessageDateAndStatusOutgoingType, rhs: ChatMessageDateAndStatusOutgoingType) -> Bool {
        switch lhs {
            case let .Sent(read):
                if case .Sent(read) = rhs {
                    return true
                } else {
                    return false
                }
            case .Sending:
                if case .Sending = rhs {
                    return true
                } else {
                    return false
                }
            case .Failed:
                if case .Failed = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

enum ChatMessageDateAndStatusType: Equatable {
    case BubbleIncoming
    case BubbleOutgoing(ChatMessageDateAndStatusOutgoingType)
    case ImageIncoming
    case ImageOutgoing(ChatMessageDateAndStatusOutgoingType)
    case FreeIncoming
    case FreeOutgoing(ChatMessageDateAndStatusOutgoingType)
    
    static func ==(lhs: ChatMessageDateAndStatusType, rhs: ChatMessageDateAndStatusType) -> Bool {
        switch lhs {
            case .BubbleIncoming:
                if case .BubbleIncoming = rhs {
                    return true
                } else {
                    return false
                }
            case let .BubbleOutgoing(type):
                if case .BubbleOutgoing(type) = rhs {
                    return true
                } else {
                    return false
                }
            case .ImageIncoming:
                if case .ImageIncoming = rhs {
                    return true
                } else {
                    return false
                }
            case let .ImageOutgoing(type):
                if case .ImageOutgoing(type) = rhs {
                    return true
                } else {
                    return false
                }
            case .FreeIncoming:
                if case .FreeIncoming = rhs {
                    return true
                } else {
                    return false
                }
            case let .FreeOutgoing(type):
                if case .FreeOutgoing(type) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

class ChatMessageDateAndStatusNode: ASDisplayNode {
    private var backgroundNode: ASImageNode?
    private var checkSentNode: ASImageNode?
    private var checkReadNode: ASImageNode?
    private var clockFrameNode: ASImageNode?
    private var clockMinNode: ASImageNode?
    private let dateNode: TextNode
    private var impressionIcon: ASImageNode?
    
    private var type: ChatMessageDateAndStatusType?
    private var theme: ChatPresentationThemeData?
    
    override init() {
        self.dateNode = TextNode()
        self.dateNode.isUserInteractionEnabled = false
        self.dateNode.displaysAsynchronously = true
        
        super.init()
        
        self.isUserInteractionEnabled = false
        
        self.addSubnode(self.dateNode)
    }
    
    func asyncLayout() -> (_ presentationData: ChatPresentationData, _ edited: Bool, _ impressionCount: Int?, _ dateText: String, _ type: ChatMessageDateAndStatusType, _ constrainedSize: CGSize) -> (CGSize, (Bool) -> Void) {
        let dateLayout = TextNode.asyncLayout(self.dateNode)
        
        var checkReadNode = self.checkReadNode
        var checkSentNode = self.checkSentNode
        var clockFrameNode = self.clockFrameNode
        var clockMinNode = self.clockMinNode
        
        var currentBackgroundNode = self.backgroundNode
        var currentImpressionIcon = self.impressionIcon
        
        let currentType = self.type
        let currentTheme = self.theme
        
        return { presentationData, edited, impressionCount, dateText, type, constrainedSize in
            let dateColor: UIColor
            var backgroundImage: UIImage?
            var outgoingStatus: ChatMessageDateAndStatusOutgoingType?
            let leftInset: CGFloat
            
            let loadedCheckFullImage: UIImage?
            let loadedCheckPartialImage: UIImage?
            let clockFrameImage: UIImage?
            let clockMinImage: UIImage?
            var impressionImage: UIImage?
            
            let themeUpdated = presentationData.theme != currentTheme || type != currentType
            
            let graphics = PresentationResourcesChat.principalGraphics(presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
            let offset: CGFloat = -UIScreenPixel
            
            switch type {
                case .BubbleIncoming:
                    dateColor = presentationData.theme.theme.chat.message.incoming.secondaryTextColor
                    leftInset = 10.0
                    loadedCheckFullImage = graphics.checkBubbleFullImage
                    loadedCheckPartialImage = graphics.checkBubblePartialImage
                    clockFrameImage = graphics.clockBubbleIncomingFrameImage
                    clockMinImage = graphics.clockBubbleIncomingMinImage
                    if impressionCount != nil {
                        impressionImage = graphics.incomingDateAndStatusImpressionIcon
                    }
                case let .BubbleOutgoing(status):
                    dateColor = presentationData.theme.theme.chat.message.outgoing.secondaryTextColor
                    outgoingStatus = status
                    leftInset = 10.0
                    loadedCheckFullImage = graphics.checkBubbleFullImage
                    loadedCheckPartialImage = graphics.checkBubblePartialImage
                    clockFrameImage = graphics.clockBubbleOutgoingFrameImage
                    clockMinImage = graphics.clockBubbleOutgoingMinImage
                    if impressionCount != nil {
                        impressionImage = graphics.outgoingDateAndStatusImpressionIcon
                    }
                case .ImageIncoming:
                    dateColor = presentationData.theme.theme.chat.message.mediaDateAndStatusTextColor
                    backgroundImage = graphics.dateAndStatusMediaBackground
                    leftInset = 0.0
                    loadedCheckFullImage = graphics.checkMediaFullImage
                    loadedCheckPartialImage = graphics.checkMediaPartialImage
                    clockFrameImage = graphics.clockMediaFrameImage
                    clockMinImage = graphics.clockMediaMinImage
                    if impressionCount != nil {
                        impressionImage = graphics.mediaImpressionIcon
                    }
                case let .ImageOutgoing(status):
                    dateColor = presentationData.theme.theme.chat.message.mediaDateAndStatusTextColor
                    outgoingStatus = status
                    backgroundImage = graphics.dateAndStatusMediaBackground
                    leftInset = 0.0
                    loadedCheckFullImage = graphics.checkMediaFullImage
                    loadedCheckPartialImage = graphics.checkMediaPartialImage
                    clockFrameImage = graphics.clockMediaFrameImage
                    clockMinImage = graphics.clockMediaMinImage
                    if impressionCount != nil {
                        impressionImage = graphics.mediaImpressionIcon
                    }
                case .FreeIncoming:
                    let serviceColor = serviceMessageColorComponents(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
                    dateColor = serviceColor.primaryText
                    backgroundImage = graphics.dateAndStatusFreeBackground
                    leftInset = 0.0
                    loadedCheckFullImage = graphics.checkFreeFullImage
                    loadedCheckPartialImage = graphics.checkFreePartialImage
                    clockFrameImage = graphics.clockFreeFrameImage
                    clockMinImage = graphics.clockFreeMinImage
                    if impressionCount != nil {
                        impressionImage = graphics.freeImpressionIcon
                    }
                case let .FreeOutgoing(status):
                    let serviceColor = serviceMessageColorComponents(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
                    dateColor = serviceColor.primaryText
                    outgoingStatus = status
                    backgroundImage = graphics.dateAndStatusFreeBackground
                    leftInset = 0.0
                    loadedCheckFullImage = graphics.checkFreeFullImage
                    loadedCheckPartialImage = graphics.checkFreePartialImage
                    clockFrameImage = graphics.clockFreeFrameImage
                    clockMinImage = graphics.clockFreeMinImage
                    if impressionCount != nil {
                        impressionImage = graphics.freeImpressionIcon
                    }
            }
            
            var updatedDateText = dateText
            if edited {
                updatedDateText = "\(presentationData.strings.Conversation_MessageEditedLabel) \(updatedDateText)"
            }
            if let impressionCount = impressionCount {
                updatedDateText = compactNumericCountString(impressionCount, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator) + " " + updatedDateText
            }
            
            let (date, dateApply) = dateLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: updatedDateText, font: dateFont, textColor: dateColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: constrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let statusWidth: CGFloat
            
            var checkSentFrame: CGRect?
            var checkReadFrame: CGRect?
            
            var clockPosition = CGPoint()
            
            var impressionSize = CGSize()
            var impressionWidth: CGFloat = 0.0
            if let impressionImage = impressionImage {
                if currentImpressionIcon == nil {
                    let iconNode = ASImageNode()
                    iconNode.isLayerBacked = true
                    iconNode.displayWithoutProcessing = true
                    iconNode.displaysAsynchronously = false
                    currentImpressionIcon = iconNode
                }
                impressionSize = impressionImage.size
                impressionWidth = impressionSize.width + 3.0
            } else {
                currentImpressionIcon = nil
            }
            
            if let outgoingStatus = outgoingStatus {
                switch outgoingStatus {
                    case .Sending:
                        statusWidth = 13.0
                        
                        if checkReadNode == nil {
                            checkReadNode = ASImageNode()
                            checkReadNode?.isLayerBacked = true
                            checkReadNode?.displaysAsynchronously = false
                            checkReadNode?.displayWithoutProcessing = true
                        }
                        
                        if checkSentNode == nil {
                            checkSentNode = ASImageNode()
                            checkSentNode?.isLayerBacked = true
                            checkSentNode?.displaysAsynchronously = false
                            checkSentNode?.displayWithoutProcessing = true
                        }
                        
                        if clockFrameNode == nil {
                            clockFrameNode = ASImageNode()
                            clockFrameNode?.isLayerBacked = true
                            clockFrameNode?.displaysAsynchronously = false
                            clockFrameNode?.displayWithoutProcessing = true
                            clockFrameNode?.frame = CGRect(origin: CGPoint(), size: clockFrameImage?.size ?? CGSize())
                        }
                        
                        if clockMinNode == nil {
                            clockMinNode = ASImageNode()
                            clockMinNode?.isLayerBacked = true
                            clockMinNode?.displaysAsynchronously = false
                            clockMinNode?.displayWithoutProcessing = true
                            clockMinNode?.frame = CGRect(origin: CGPoint(), size: clockMinImage?.size ?? CGSize())
                        }
                        clockPosition = CGPoint(x: leftInset + date.size.width + 8.5, y: 7.5 + offset)
                    case let .Sent(read):
                        let hideStatus: Bool
                        switch type {
                            case .BubbleOutgoing, .FreeOutgoing, .ImageOutgoing:
                                hideStatus = false
                            default:
                                hideStatus = impressionCount != nil
                        }
                        
                        if hideStatus {
                            statusWidth = 0.0
                            
                            checkReadNode = nil
                            checkSentNode = nil
                            clockFrameNode = nil
                            clockMinNode = nil
                        } else {
                            statusWidth = 13.0
                            
                            if checkReadNode == nil {
                                checkReadNode = ASImageNode()
                                checkReadNode?.isLayerBacked = true
                                checkReadNode?.displaysAsynchronously = false
                                checkReadNode?.displayWithoutProcessing = true
                            }
                            
                            if checkSentNode == nil {
                                checkSentNode = ASImageNode()
                                checkSentNode?.isLayerBacked = true
                                checkSentNode?.displaysAsynchronously = false
                                checkSentNode?.displayWithoutProcessing = true
                            }
                            
                            clockFrameNode = nil
                            clockMinNode = nil
                            
                            let checkSize = loadedCheckFullImage!.size
                            
                            if read {
                                checkReadFrame = CGRect(origin: CGPoint(x: leftInset + impressionWidth + date.size.width + 5.0 + statusWidth - checkSize.width, y: 3.0 + offset), size: checkSize)
                            }
                            checkSentFrame = CGRect(origin: CGPoint(x: leftInset + impressionWidth + date.size.width + 5.0 + statusWidth - checkSize.width - 6.0, y: 3.0 + offset), size: checkSize)
                        }
                    case .Failed:
                        statusWidth = 0.0
                        
                        checkReadNode = nil
                        checkSentNode = nil
                        clockFrameNode = nil
                        clockMinNode = nil
                }
            } else {
                statusWidth = 0.0
                
                checkReadNode = nil
                checkSentNode = nil
                clockFrameNode = nil
                clockMinNode = nil
            }
            
            var backgroundInsets = UIEdgeInsets()
            
            if let _ = backgroundImage {
                if currentBackgroundNode == nil {
                    let backgroundNode = ASImageNode()
                    backgroundNode.isLayerBacked = true
                    backgroundNode.displayWithoutProcessing = true
                    backgroundNode.displaysAsynchronously = false
                    currentBackgroundNode = backgroundNode
                }
                backgroundInsets = UIEdgeInsets(top: 2.0, left: 7.0, bottom: 2.0, right: 7.0)
            }
            
            let layoutSize = CGSize(width: leftInset + impressionWidth + date.size.width + statusWidth + backgroundInsets.left + backgroundInsets.right, height: date.size.height + backgroundInsets.top + backgroundInsets.bottom)
            
            return (layoutSize, { [weak self] animated in
                if let strongSelf = self {
                    strongSelf.theme = presentationData.theme
                    strongSelf.type = type
                    
                    if backgroundImage != nil {
                        if let currentBackgroundNode = currentBackgroundNode {
                            if currentBackgroundNode.supernode == nil {
                                strongSelf.backgroundNode = currentBackgroundNode
                                currentBackgroundNode.image = backgroundImage
                                strongSelf.insertSubnode(currentBackgroundNode, at: 0)
                            } else if themeUpdated {
                                currentBackgroundNode.image = backgroundImage
                            }
                        }
                        strongSelf.backgroundNode?.frame = CGRect(origin: CGPoint(), size: layoutSize)
                    } else {
                        if let backgroundNode = strongSelf.backgroundNode {
                            backgroundNode.removeFromSupernode()
                            strongSelf.backgroundNode = nil
                        }
                    }
                    
                    let _ = dateApply()
                    
                    if let currentImpressionIcon = currentImpressionIcon {
                        if currentImpressionIcon.image !== impressionImage {
                            currentImpressionIcon.image = impressionImage
                        }
                        if currentImpressionIcon.supernode == nil {
                            strongSelf.impressionIcon = currentImpressionIcon
                            strongSelf.addSubnode(currentImpressionIcon)
                        }
                        currentImpressionIcon.frame = CGRect(origin: CGPoint(x: leftInset + backgroundInsets.left, y: backgroundInsets.top + 3.0 + offset), size: impressionSize)
                    } else if let impressionIcon = strongSelf.impressionIcon {
                        impressionIcon.removeFromSupernode()
                        strongSelf.impressionIcon = nil
                    }
                    
                    strongSelf.dateNode.frame = CGRect(origin: CGPoint(x: leftInset + backgroundInsets.left + impressionWidth, y: backgroundInsets.top + 1.0 + offset), size: date.size)
                    
                    if let clockFrameNode = clockFrameNode {
                        if strongSelf.clockFrameNode == nil {
                            strongSelf.clockFrameNode = clockFrameNode
                            clockFrameNode.image = clockFrameImage
                            strongSelf.addSubnode(clockFrameNode)
                        } else if themeUpdated {
                            clockFrameNode.image = clockFrameImage
                        }
                        clockFrameNode.position = CGPoint(x: backgroundInsets.left + clockPosition.x, y: backgroundInsets.top + clockPosition.y)
                        if let clockFrameNode = strongSelf.clockFrameNode {
                            maybeAddRotationAnimation(clockFrameNode.layer, duration: 6.0)
                        }
                    } else if let clockFrameNode = strongSelf.clockFrameNode {
                        clockFrameNode.removeFromSupernode()
                        strongSelf.clockFrameNode = nil
                    }
                    
                    if let clockMinNode = clockMinNode {
                        if strongSelf.clockMinNode == nil {
                            strongSelf.clockMinNode = clockMinNode
                            clockMinNode.image = clockMinImage
                            strongSelf.addSubnode(clockMinNode)
                        } else if themeUpdated {
                            clockMinNode.image = clockMinImage
                        }
                        clockMinNode.position = CGPoint(x: backgroundInsets.left + clockPosition.x, y: backgroundInsets.top + clockPosition.y)
                        if let clockMinNode = strongSelf.clockMinNode {
                            maybeAddRotationAnimation(clockMinNode.layer, duration: 1.0)
                        }
                    } else if let clockMinNode = strongSelf.clockMinNode {
                        clockMinNode.removeFromSupernode()
                        strongSelf.clockMinNode = nil
                    }
                    
                    if let checkSentNode = checkSentNode, let checkReadNode = checkReadNode {
                        var animateSentNode = false
                        if strongSelf.checkSentNode == nil {
                            checkSentNode.image = loadedCheckFullImage
                            strongSelf.checkSentNode = checkSentNode
                            strongSelf.addSubnode(checkSentNode)
                            animateSentNode = animated
                        } else if themeUpdated {
                            checkSentNode.image = loadedCheckFullImage
                        }
                        
                        if let checkSentFrame = checkSentFrame {
                            if checkSentNode.isHidden {
                                animateSentNode = animated
                            }
                            checkSentNode.isHidden = false
                            checkSentNode.frame = checkSentFrame.offsetBy(dx: backgroundInsets.left, dy: backgroundInsets.top)
                        } else {
                            checkSentNode.isHidden = true
                        }
                        
                        var animateReadNode = false
                        if strongSelf.checkReadNode == nil {
                            animateReadNode = animated
                            checkReadNode.image = loadedCheckPartialImage
                            strongSelf.checkReadNode = checkReadNode
                            strongSelf.addSubnode(checkReadNode)
                        } else if themeUpdated {
                            checkReadNode.image = loadedCheckPartialImage
                        }
                    
                        if let checkReadFrame = checkReadFrame {
                            if checkReadNode.isHidden {
                                animateReadNode = animated
                            }
                            checkReadNode.isHidden = false
                            checkReadNode.frame = checkReadFrame.offsetBy(dx: backgroundInsets.left, dy: backgroundInsets.top)
                        } else {
                            checkReadNode.isHidden = true
                        }
                        
                        if animateSentNode {
                            strongSelf.checkSentNode?.layer.animateScale(from: 1.3, to: 1.0, duration: 0.1)
                        }
                        if animateReadNode {
                            strongSelf.checkReadNode?.layer.animateScale(from: 1.3, to: 1.0, duration: 0.1)
                        }
                    } else if let checkSentNode = strongSelf.checkSentNode, let checkReadNode = strongSelf.checkReadNode {
                        checkSentNode.removeFromSupernode()
                        checkReadNode.removeFromSupernode()
                        strongSelf.checkSentNode = nil
                        strongSelf.checkReadNode = nil
                    }
                }
            })
        }
    }
    
    static func asyncLayout(_ node: ChatMessageDateAndStatusNode?) -> (_ presentationData: ChatPresentationData, _ edited: Bool, _ impressionCount: Int?, _ dateText: String, _ type: ChatMessageDateAndStatusType, _ constrainedSize: CGSize) -> (CGSize, (Bool) -> ChatMessageDateAndStatusNode) {
        let currentLayout = node?.asyncLayout()
        return { presentationData, edited, impressionCount, dateText, type, constrainedSize in
            let resultNode: ChatMessageDateAndStatusNode
            let resultSizeAndApply: (CGSize, (Bool) -> Void)
            if let node = node, let currentLayout = currentLayout {
                resultNode = node
                resultSizeAndApply = currentLayout(presentationData, edited, impressionCount, dateText, type, constrainedSize)
            } else {
                resultNode = ChatMessageDateAndStatusNode()
                resultSizeAndApply = resultNode.asyncLayout()(presentationData, edited, impressionCount, dateText, type, constrainedSize)
            }
            
            return (resultSizeAndApply.0, { animated in
                resultSizeAndApply.1(animated)
                return resultNode
            })
        }
    }
}
