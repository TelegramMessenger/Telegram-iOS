import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import Postbox
import TelegramPresentationData
import TextFormat
import AccountContext
import EncryptionKeyVisualization
import LocalizedPeerData

private func processHexString(_ string: String) -> String {
    var result = ""
    var i = 0
    for c in string {
        if i % 2 == 0 && i != 0 {
            result.append(" ")
        }
        if i % 8 == 0 && i != 0 {
            result.append(" ")
        }
        result.append(c)
        i += 1
    }
    return result
}

final class SecretChatKeyControllerNode: ViewControllerTracingNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    private let fingerprint: SecretChatKeyFingerprint
    private let peer: Peer
    private let getNavigationController: () -> NavigationController?
    
    private let scrollNode: ASScrollNode
    private let imageNode: ASImageNode
    private let keyTextNode: TextNode
    private let infoNode: TextNode
    
    private var validImageSize: CGSize?
    
    init(context: AccountContext, presentationData: PresentationData, fingerprint: SecretChatKeyFingerprint, peer: Peer, getNavigationController: @escaping () -> NavigationController?) {
        self.context = context
        self.presentationData = presentationData
        self.fingerprint = fingerprint
        self.peer = peer
        self.getNavigationController = getNavigationController
        
        self.scrollNode = ASScrollNode()
        
        self.imageNode = ASImageNode()
        self.imageNode.isLayerBacked = true
        self.imageNode.displaysAsynchronously = false
        self.imageNode.displayWithoutProcessing = true
        
        self.keyTextNode = TextNode()
        self.keyTextNode.isUserInteractionEnabled = false
        self.keyTextNode.displaysAsynchronously = false
        
        self.infoNode = TextNode()
        self.infoNode.displaysAsynchronously = false
        
        super.init()
        
        self.backgroundColor = presentationData.theme.list.plainBackgroundColor
        
        self.addSubnode(self.scrollNode)
        self.scrollNode.addSubnode(self.imageNode)
        self.scrollNode.addSubnode(self.keyTextNode)
        self.scrollNode.addSubnode(self.infoNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.infoNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.infoTap(_:))))
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        
        self.scrollNode.frame = CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: layout.size.height - insets.top))
        
        let sideInset: CGFloat = 10.0
        
        var imageSize = CGSize(width: layout.size.width - sideInset * 2.0, height: layout.size.width - sideInset * 2.0)
        if imageSize.height > layout.size.height - insets.top - sideInset * 2.0 - 100.0 {
            let side = layout.size.height - insets.top - sideInset * 2.0 - 100.0
            imageSize = CGSize(width: side, height: side)
        }
        if imageSize.height > 512.0 {
            imageSize = CGSize(width: 512.0, height: 512.0)
        }
        if self.validImageSize != imageSize {
            self.validImageSize = imageSize
            self.imageNode.image = secretChatKeyImage(self.fingerprint, size: imageSize)
        }
        
        let makeKeyTextLayout = TextNode.asyncLayout(self.keyTextNode)
        let makeInfoLayout = TextNode.asyncLayout(self.infoNode)
        
        let keySignatureData = self.fingerprint.sha1.data()
        let additionalSignature = self.fingerprint.sha256.data()
        
        var data = Data()
        data.append(keySignatureData)
        data.append(additionalSignature)
        
        let s1: String = (data.subdata(in: 0 ..< 8) as NSData).stringByEncodingInHex()
        let s2: String = (data.subdata(in: 8 ..< 16) as NSData).stringByEncodingInHex()
        
        let s3: String = (additionalSignature.subdata(in: 0 ..< 8) as NSData).stringByEncodingInHex()
        let s4: String = (additionalSignature.subdata(in : 8 ..< 16) as NSData).stringByEncodingInHex()
        
        let text: String = "\(processHexString(s1))\n\(processHexString(s2))\n\(processHexString(s3))\n\(processHexString(s4))"
        
        let (keyTextLayout, keyTextApply) = makeKeyTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: text, font: Font.semiboldMonospace(15.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: layout.size.width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .left, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
        
        let infoString = self.presentationData.strings.EncryptionKey_Description(EnginePeer(self.peer).compactDisplayTitle, EnginePeer(self.peer).compactDisplayTitle)
        let infoText = NSMutableAttributedString(string: infoString.string, attributes: [.font: Font.regular(14.0), .foregroundColor: self.presentationData.theme.list.itemPrimaryTextColor])
        
        for range in infoString.ranges {
            infoText.addAttributes([.font: Font.semibold(14.0)], range: range.range)
        }
        
        let linkRange = (infoString.string as NSString).range(of: "telegram.org")
        if linkRange.location != NSNotFound {
            infoText.addAttributes([.foregroundColor: self.presentationData.theme.list.itemAccentColor, NSAttributedString.Key(rawValue: TelegramTextAttributes.URL): "https://telegram.org/faq#secret-chats"], range: linkRange)
        }
        
        let (infoLayout, infoApply) = makeInfoLayout(TextNodeLayoutArguments(attributedString: infoText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: layout.size.width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
        
        let _ = keyTextApply()
        let _ = infoApply()
        
        let imageSpacing: CGFloat = 12.0
        let textSpacing: CGFloat = 10.0
        let contentHeight = imageSize.height + imageSpacing + keyTextLayout.size.height + textSpacing + infoLayout.size.height
        
        let contentOrigin = sideInset + max(0, floor((layout.size.height - insets.top - sideInset * 2.0 - contentHeight) / 2.0))
        
        self.scrollNode.view.contentSize = CGSize(width: layout.size.width, height: contentHeight + sideInset * 2.0)
        
        let imageFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - imageSize.width) / 2.0), y: contentOrigin), size: imageSize)
        transition.updateFrame(node: self.imageNode, frame: imageFrame)
        
        let keyTextFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - keyTextLayout.size.width) / 2.0), y: imageFrame.maxY + imageSpacing), size: keyTextLayout.size)
        transition.updateFrame(node: self.keyTextNode, frame: keyTextFrame)
        
        let infoFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - infoLayout.size.width) / 2.0), y: keyTextFrame.maxY + textSpacing), size: infoLayout.size)
        transition.updateFrame(node: self.infoNode, frame: infoFrame)
    }
    
    @objc func infoTap(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            let point = recognizer.location(in: recognizer.view)
            if let attributes = self.infoNode.attributesAtPoint(point)?.1 {
                if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                    self.context.sharedContext.openExternalUrl(context: self.context, urlContext: .generic, url: url, forceExternal: false, presentationData: self.presentationData, navigationController: self.getNavigationController(), dismissInput: { [weak self] in
                        self?.view.endEditing(true)
                    })
                }
            }
        }
    }
}
