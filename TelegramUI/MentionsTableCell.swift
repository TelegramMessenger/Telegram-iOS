import Foundation
import UIKit
import Display
import Postbox
import TelegramCore

final class MentionsTableCell: UITableViewCell {
    private let avatarNode = AvatarNode(font: Font.regular(16.0))
    private let labelNode = TextNode()
    private var peer: Peer?
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.contentView.addSubnode(self.avatarNode)
        self.contentView.addSubnode(self.labelNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupPeer(account: Account, peer: Peer) {
        self.peer = peer
        self.avatarNode.setPeer(account: account, peer: peer)
        self.setNeedsLayout()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.avatarNode.frame = CGRect(origin: CGPoint(x: 16.0, y: floor((self.bounds.size.height - 30.0) / 2.0)), size: CGSize(width: 30.0, height: 30.0))
        if let peer = self.peer {
            let makeLayout = TextNode.asyncLayout(self.labelNode)
            let string = NSMutableAttributedString()
            string.append(NSAttributedString(string: peer.displayTitle, font: Font.medium(15.0), textColor: UIColor.black))
            if let addressName = peer.addressName {
                string.append(NSAttributedString(string: "  @" + addressName, font: Font.regular(15.0), textColor: UIColor(0x9099a2)))
            }
            let (layout, apply) = makeLayout(string, nil, 1, .end, CGSize(width: self.bounds.size.width - 61.0 - 10.0, height: self.bounds.size.height), nil)
            self.labelNode.frame = CGRect(origin: CGPoint(x: 61.0, y: floor((self.bounds.size.height - layout.size.height) / 2.0) + 2.0), size: layout.size)
            let _ = apply()
        }
    }
}
