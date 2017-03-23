import Foundation
import AsyncDisplayKit
import Postbox
import Display
import SwiftSignalKit

private let dateFont = UIFont.italicSystemFont(ofSize: 11.0)

private func generateCheckImage(partial: Bool, color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 11.0, height: 9.0), contextGenerator: { size, context in
        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
        
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.scaleBy(x: 0.5, y: 0.5)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(2.5)
        if partial {
            let _ = try? drawSvgPath(context, path: "M1,14.5 L2.5,16 L16.4985125,1 ")
        } else {
            let _ = try? drawSvgPath(context, path: "M1,10 L7,16 L20.9985125,1 ")
        }
        context.strokePath()
    })
}

private func generateClockFrameImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 11.0, height: 11.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(color.cgColor)
        context.setFillColor(color.cgColor)
        let strokeWidth: CGFloat = 1.0
        context.setLineWidth(strokeWidth)
        context.strokeEllipse(in: CGRect(x: strokeWidth / 2.0, y: strokeWidth / 2.0, width: size.width - strokeWidth, height: size.height - strokeWidth))
        context.fill(CGRect(x: (11.0 - strokeWidth) / 2.0, y: strokeWidth * 3.0, width: strokeWidth, height: 11.0 / 2.0 - strokeWidth * 3.0))
    })
}

private func generateClockMinImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 11.0, height: 11.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        let strokeWidth: CGFloat = 1.0
        context.fill(CGRect(x: (11.0 - strokeWidth) / 2.0, y: (11.0 - strokeWidth) / 2.0, width: 11.0 / 2.0 - strokeWidth, height: strokeWidth))
    })
}

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
    layer.add(basicAnimation, forKey: "clockFrameAnimation")
}

private let checkBubbleFullImage = generateCheckImage(partial: false, color: UIColor(0x19C700))
private let checkBubblePartialImage = generateCheckImage(partial: true, color: UIColor(0x19C700))

private let checkMediaFullImage = generateCheckImage(partial: false, color: .white)
private let checkMediaPartialImage = generateCheckImage(partial: true, color: .white)

private let incomingDateColor = UIColor(0x525252, 0.6)
private let outgoingDateColor = UIColor(0x008c09, 0.8)

private let imageBackground = generateStretchableFilledCircleImage(diameter: 18.0, color: UIColor(white: 0.0, alpha: 0.5))

private let clockBubbleFrameImage = generateClockFrameImage(color: UIColor(0x42b649))
private let clockBubbleMinImage = generateClockMinImage(color: UIColor(0x42b649))
private let clockMediaFrameImage = generateClockFrameImage(color: .white)
private let clockMediaMinImage = generateClockMinImage(color: .white)

private let incomingImpressionIcon = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/ImpressionCount"), color: incomingDateColor)
private let outgoingImpressionIcon = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/ImpressionCount"), color: outgoingDateColor)
private let mediaImpressionIcon = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/ImpressionCount"), color: .white)

enum ChatMessageDateAndStatusOutgoingType {
    case Sent(read: Bool)
    case Sending
    case Failed
}

enum ChatMessageDateAndStatusType {
    case BubbleIncoming
    case BubbleOutgoing(ChatMessageDateAndStatusOutgoingType)
    case ImageIncoming
    case ImageOutgoing(ChatMessageDateAndStatusOutgoingType)
}

class ChatMessageDateAndStatusNode: ASTransformLayerNode {
    private var backgroundNode: ASImageNode?
    private var checkSentNode: ASImageNode?
    private var checkReadNode: ASImageNode?
    private var clockFrameNode: ASImageNode?
    private var clockMinNode: ASImageNode?
    private let dateNode: TextNode
    private var impressionIcon: ASImageNode?
    
    override init() {
        self.dateNode = TextNode()
        self.dateNode.isLayerBacked = true
        self.dateNode.displaysAsynchronously = true
        
        super.init()
        
        self.addSubnode(self.dateNode)
    }
    
    func asyncLayout() -> (_ edited: Bool, _ impressionCount: Int?, _ dateText: String, _ type: ChatMessageDateAndStatusType, _ constrainedSize: CGSize) -> (CGSize, (Bool) -> Void) {
        let dateLayout = TextNode.asyncLayout(self.dateNode)
        
        var checkReadNode = self.checkReadNode
        var checkSentNode = self.checkSentNode
        var clockFrameNode = self.clockFrameNode
        var clockMinNode = self.clockMinNode
        
        var currentBackgroundNode = self.backgroundNode
        var currentImpressionIcon = self.impressionIcon
        
        return { edited, impressionCount, dateText, type, constrainedSize in
            let dateColor: UIColor
            var backgroundImage: UIImage?
            var outgoingStatus: ChatMessageDateAndStatusOutgoingType?
            let leftInset: CGFloat
            
            let loadedCheckFullImage: UIImage?
            let loadedCheckPartialImage: UIImage?
            let clockFrameImage: UIImage?
            let clockMinImage: UIImage?
            var impressionImage: UIImage?
            
            switch type {
                case .BubbleIncoming:
                    dateColor = incomingDateColor
                    leftInset = 10.0
                    loadedCheckFullImage = checkBubbleFullImage
                    loadedCheckPartialImage = checkBubblePartialImage
                    clockFrameImage = clockBubbleFrameImage
                    clockMinImage = clockBubbleMinImage
                    if impressionCount != nil {
                        impressionImage = incomingImpressionIcon
                    }
                case let .BubbleOutgoing(status):
                    dateColor = outgoingDateColor
                    outgoingStatus = status
                    leftInset = 10.0
                    loadedCheckFullImage = checkBubbleFullImage
                    loadedCheckPartialImage = checkBubblePartialImage
                    clockFrameImage = clockBubbleFrameImage
                    clockMinImage = clockBubbleMinImage
                    if impressionCount != nil {
                        impressionImage = outgoingImpressionIcon
                    }
                case .ImageIncoming:
                    dateColor = .white
                    backgroundImage = imageBackground
                    leftInset = 0.0
                    loadedCheckFullImage = checkMediaFullImage
                    loadedCheckPartialImage = checkMediaPartialImage
                    clockFrameImage = clockMediaFrameImage
                    clockMinImage = clockMediaMinImage
                    if impressionCount != nil {
                        impressionImage = mediaImpressionIcon
                    }
                case let .ImageOutgoing(status):
                    dateColor = .white
                    outgoingStatus = status
                    backgroundImage = imageBackground
                    leftInset = 0.0
                    loadedCheckFullImage = checkMediaFullImage
                    loadedCheckPartialImage = checkMediaPartialImage
                    clockFrameImage = clockMediaFrameImage
                    clockMinImage = clockMediaMinImage
                    if impressionCount != nil {
                        impressionImage = mediaImpressionIcon
                    }
            }
            
            var updatedDateText = dateText
            if let impressionCount = impressionCount {
                updatedDateText = compactNumericCountString(impressionCount) + " " + updatedDateText
            }
            
            if edited {
                updatedDateText = "edited " + updatedDateText
            }
            
            let (date, dateApply) = dateLayout(NSAttributedString(string: updatedDateText, font: dateFont, textColor: dateColor), nil, 1, .end, constrainedSize, .natural, nil)
            
            let statusWidth: CGFloat
            
            var checkSentFrame: CGRect?
            var checkReadFrame: CGRect?
            
            var clockPosition = CGPoint()
            
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
                            clockFrameNode?.image = clockFrameImage
                            clockFrameNode?.frame = CGRect(origin: CGPoint(), size: clockFrameImage?.size ?? CGSize())
                        }
                        
                        if clockMinNode == nil {
                            clockMinNode = ASImageNode()
                            clockMinNode?.isLayerBacked = true
                            clockMinNode?.displaysAsynchronously = false
                            clockMinNode?.displayWithoutProcessing = true
                            clockMinNode?.image = clockMinImage
                            clockMinNode?.frame = CGRect(origin: CGPoint(), size: clockMinImage?.size ?? CGSize())
                        }
                        clockPosition = CGPoint(x: leftInset + date.size.width + 8.5, y: 7.5)
                    case let .Sent(read):
                        if impressionCount != nil {
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
                                checkReadFrame = CGRect(origin: CGPoint(x: leftInset + date.size.width + 5.0 + statusWidth - checkSize.width, y: 3.0), size: checkSize)
                            }
                            checkSentFrame = CGRect(origin: CGPoint(x: leftInset + date.size.width + 5.0 + statusWidth - checkSize.width - 6.0, y: 3.0), size: checkSize)
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
            
            if let backgroundImage = backgroundImage {
                if currentBackgroundNode == nil {
                    let backgroundNode = ASImageNode()
                    backgroundNode.isLayerBacked = true
                    backgroundNode.displayWithoutProcessing = true
                    backgroundNode.displaysAsynchronously = false
                    backgroundNode.image = backgroundImage
                    currentBackgroundNode = backgroundNode
                }
                backgroundInsets = UIEdgeInsets(top: 2.0, left: 7.0, bottom: 2.0, right: 7.0)
            }
            
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
            
            let layoutSize = CGSize(width: leftInset + impressionWidth + date.size.width + statusWidth + backgroundInsets.left + backgroundInsets.right, height: date.size.height + backgroundInsets.top + backgroundInsets.bottom)
            
            return (layoutSize, { [weak self] animated in
                if let strongSelf = self {
                    if backgroundImage != nil {
                        if let currentBackgroundNode = currentBackgroundNode {
                            if currentBackgroundNode.supernode == nil {
                                strongSelf.backgroundNode = currentBackgroundNode
                                strongSelf.insertSubnode(currentBackgroundNode, at: 0)
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
                        currentImpressionIcon.frame = CGRect(origin: CGPoint(x: leftInset + backgroundInsets.left, y: backgroundInsets.top + 3.0), size: impressionSize)
                    } else if let impressionIcon = strongSelf.impressionIcon {
                        impressionIcon.removeFromSupernode()
                        strongSelf.impressionIcon = nil
                    }
                    
                    strongSelf.dateNode.frame = CGRect(origin: CGPoint(x: leftInset + backgroundInsets.left + impressionWidth, y: backgroundInsets.top), size: date.size)
                    
                    if let clockFrameNode = clockFrameNode {
                        if strongSelf.clockFrameNode == nil {
                            strongSelf.clockFrameNode = clockFrameNode
                            strongSelf.addSubnode(clockFrameNode)
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
                            strongSelf.addSubnode(clockMinNode)
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
}
