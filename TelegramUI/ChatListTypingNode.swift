import Foundation
import AsyncDisplayKit
import Postbox
import TelegramCore
import Display
import SwiftSignalKit

private let textFont = Font.regular(15.0)

private func generateDotsImage(color: UIColor) -> UIImage? {
    var images: [UIImage] = []
    let size = CGSize(width: 20.0, height: 10.0)
    for i in 0 ..< 4 {
        if let image = generateImage(size, rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(color.cgColor)
            var string = ""
            if i >= 1 {
                for _ in 1 ... i {
                    string.append(".")
                }
            }
            let attributedString = NSAttributedString(string: string, attributes: [.font: textFont, .foregroundColor: color])
            UIGraphicsPushContext(context)
            attributedString.draw(at: CGPoint(x: 1.0, y: -9.0))
            UIGraphicsPopContext()
        }) {
            images.append(image)
        }
    }
    return UIImage.animatedImage(with: images, duration: 0.6)
}

private final class ChatListInputActivitiesDotsNode: ASDisplayNode {
    var image: UIImage? {
        didSet {
            if self.image !== oldValue {
                if self.image != nil && self.isInHierarchy {
                    self.beginAnimation()
                } else {
                    self.layer.removeAnimation(forKey: "image")
                }
            }
        }
    }
    
    override init() {
        super.init()
    }
    
    private func beginAnimation() {
        guard let images = self.image?.images else {
            return
        }
        let animation = CAKeyframeAnimation(keyPath: "contents")
        animation.values = images.map { $0.cgImage! }
        animation.duration = 0.54
        animation.repeatCount = Float.infinity
        animation.calculationMode = kCAAnimationDiscrete
        animation.beginTime = 1.0
        self.layer.add(animation, forKey: "image")
    }
    
    override func willEnterHierarchy() {
        super.willEnterHierarchy()
        
        self.beginAnimation()
    }
    
    override func didExitHierarchy() {
        super.didExitHierarchy()
        
        self.layer.removeAnimation(forKey: "image")
    }
}

private let cachedImages = Atomic<[UInt32: UIImage]>(value: [:])
private func getDotsImage(color: UIColor) -> UIImage? {
    let key = color.argb
    let cached = cachedImages.with { dict -> UIImage? in
        return dict[key]
    }
    if let cached = cached {
        return cached
    } else if let image = generateDotsImage(color: color) {
        let _ = cachedImages.modify { dict in
            var dict = dict
            dict[key] = image
            return dict
        }
        return image
    } else {
        return nil
    }
}

final class ChatListInputActivitiesNode: ASDisplayNode {
    private let textNode: TextNode
    private let dotsNode: ChatListInputActivitiesDotsNode
    
    override init() {
        self.textNode = TextNode()
        
        self.dotsNode = ChatListInputActivitiesDotsNode()
        
        super.init()
        
        self.addSubnode(self.textNode)
        self.addSubnode(self.dotsNode)
    }
    
    func asyncLayout() -> (CGSize, PresentationStrings, UIColor, PeerId, [(Peer, PeerInputActivity)]) -> (CGSize, () -> Void) {
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        return { [weak self] boundingSize, strings, color, peerId, activities in
            let string: NSAttributedString?
            if !activities.isEmpty {
                var commonKey: Int32? = activities[0].1.key
                for i in 1 ..< activities.count {
                    if activities[i].1.key != commonKey {
                        commonKey = nil
                        break
                    }
                }
                
                if activities.count == 1 {
                    if activities[0].0.id == peerId {
                        let text: String
                        switch activities[0].1 {
                            case .uploadingVideo:
                                text = strings.Activity_UploadingVideo
                            case .uploadingInstantVideo:
                                text = strings.Activity_UploadingVideoMessage
                            case .uploadingPhoto:
                                text = strings.Activity_UploadingPhoto
                            case .uploadingFile:
                                text = strings.Activity_UploadingDocument
                            case .recordingVoice:
                                text = strings.Activity_RecordingAudio
                            case .recordingInstantVideo:
                                text = strings.Activity_RecordingVideoMessage
                            case .playingGame:
                                text = strings.Activity_PlayingGame
                            case .typingText:
                                text = strings.DialogList_Typing
                        }
                        string = NSAttributedString(string: text, font: textFont, textColor: color)
                    } else {
                        let text: String
                        if let _ = commonKey {
                            let peerTitle = activities[0].0.compactDisplayTitle
                            switch activities[0].1 {
                                case .uploadingVideo:
                                    text = strings.DialogList_SingleUploadingVideoSuffix(peerTitle).0
                                case .uploadingInstantVideo:
                                    text = strings.DialogList_SingleUploadingVideoSuffix(peerTitle).0
                                case .uploadingPhoto:
                                    text = strings.DialogList_SingleUploadingPhotoSuffix(peerTitle).0
                                case .uploadingFile:
                                    text = strings.DialogList_SingleUploadingFileSuffix(peerTitle).0
                                case .recordingVoice:
                                    text = strings.DialogList_SingleRecordingAudioSuffix(peerTitle).0
                                case .recordingInstantVideo:
                                    text = strings.DialogList_SingleRecordingVideoMessageSuffix(peerTitle).0
                                case .playingGame:
                                    text = strings.DialogList_SinglePlayingGameSuffix(peerTitle).0
                                case .typingText:
                                    text = strings.DialogList_SingleTypingSuffix(peerTitle).0
                            }
                        } else {
                            text = activities[0].0.compactDisplayTitle
                        }
                        string = NSAttributedString(string: text, font: textFont, textColor: color)
                    }
                } else {
                    if activities.count > 1 {
                        let peerTitle = activities[0].0.compactDisplayTitle
                        string = NSAttributedString(string: strings.DialogList_MultipleTyping(peerTitle, strings.DialogList_MultipleTypingSuffix(activities.count - 1).0).0, font: textFont, textColor: color)
                    } else {
                        string = NSAttributedString(string: strings.DialogList_MultipleTypingSuffix(activities.count).0, font: textFont, textColor: color)
                    }
                }
            } else {
                string = nil
            }
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: string, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: boundingSize.width - 12.0, height: boundingSize.height), alignment: .left, cutout: nil, insets: UIEdgeInsets(top: 1.0, left: 0.0, bottom: 1.0, right: 0.0)))
            
            let dots = getDotsImage(color: color)
            
            return (boundingSize, {
                if let strongSelf = self {
                    let _ = textApply()
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(), size: textLayout.size)
                    
                    if let dots = dots {
                        strongSelf.dotsNode.image = dots
                        let dotsSize = CGSize(width: 20.0, height: 10.0)
                        let dotsFrame = CGRect(origin: CGPoint(x: textLayout.size.width - 1.0, y: textLayout.size.height - dotsSize.height - 2.0), size: dotsSize)
                        strongSelf.dotsNode.frame = dotsFrame
                    }
                }
            })
        }
    }
}
