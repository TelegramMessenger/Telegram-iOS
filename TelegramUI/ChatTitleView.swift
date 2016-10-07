import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore

final class ChatTitleView: UIView {
    private let titleNode: ASTextNode
    private let infoNode: ASTextNode
    
    var peerView: PeerView? {
        didSet {
            if let peerView = self.peerView, let peer = peerView.peers[peerView.peerId] {
                self.titleNode.attributedText = NSAttributedString(string: peer.displayTitle, font: Font.medium(17.0), textColor: UIColor.black)
                
                if let user = peer as? TelegramUser {
                    self.infoNode.attributedText = NSAttributedString(string: "last seen recently", font: Font.regular(13.0), textColor: UIColor(0x787878))
                } else if let group = peer as? TelegramGroup {
                    self.infoNode.attributedText = NSAttributedString(string: "\(group.participantCount) members", font: Font.regular(13.0), textColor: UIColor(0x787878))
                } else if let channel = peer as? TelegramChannel {
                    if let cachedChannelData = peerView.cachedData as? CachedChannelData, let memberCount = cachedChannelData.participantsSummary.memberCount {
                        self.infoNode.attributedText = NSAttributedString(string: "\(memberCount) members", font: Font.regular(13.0), textColor: UIColor(0x787878))
                    } else {
                        switch channel.info {
                            case .group:
                                self.infoNode.attributedText = NSAttributedString(string: "group", font: Font.regular(13.0), textColor: UIColor(0x787878))
                            case .broadcast:
                                self.infoNode.attributedText = NSAttributedString(string: "channel", font: Font.regular(13.0), textColor: UIColor(0x787878))
                        }
                    }
                }
                
                self.setNeedsLayout()
            }
        }
    }
    
    override init(frame: CGRect) {
        self.titleNode = ASTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationMode = .byTruncatingTail
        self.titleNode.isOpaque = false
        
        self.infoNode = ASTextNode()
        self.infoNode.displaysAsynchronously = false
        self.infoNode.maximumNumberOfLines = 1
        self.infoNode.truncationMode = .byTruncatingTail
        self.infoNode.isOpaque = false
        
        super.init(frame: frame)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.infoNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
        
        if size.height > 40.0 {
            let titleSize = self.titleNode.measure(size)
            let infoSize = self.infoNode.measure(size)
            let titleInfoSpacing: CGFloat = 0.0
            
            let combinedHeight = titleSize.height + infoSize.height + titleInfoSpacing
            
            self.titleNode.frame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: floor((size.height - combinedHeight) / 2.0)), size: titleSize)
            self.infoNode.frame = CGRect(origin: CGPoint(x: floor((size.width - infoSize.width) / 2.0), y: floor((size.height - combinedHeight) / 2.0) + titleSize.height + titleInfoSpacing), size: infoSize)
        } else {
            let titleSize = self.titleNode.measure(CGSize(width: floor(size.width / 2.0), height: size.height))
            let infoSize = self.infoNode.measure(CGSize(width: floor(size.width / 2.0), height: size.height))
            
            let titleInfoSpacing: CGFloat = 8.0
            let combinedWidth = titleSize.width + infoSize.width + titleInfoSpacing
            
            self.titleNode.frame = CGRect(origin: CGPoint(x: floor((size.width - combinedWidth) / 2.0), y: floor((size.height - titleSize.height) / 2.0)), size: titleSize)
            self.infoNode.frame = CGRect(origin: CGPoint(x: floor((size.width - combinedWidth) / 2.0 + titleSize.width + titleInfoSpacing), y: floor((size.height - infoSize.height) / 2.0)), size: infoSize)
        }
    }
}
