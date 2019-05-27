import Foundation
import Postbox
import TelegramCore
import UIKit

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xff) / 255.0, green: CGFloat((rgb >> 8) & 0xff) / 255.0, blue: CGFloat(rgb & 0xff) / 255.0, alpha: 1.0)
    }
}

private let UIScreenScale = UIScreen.main.scale
private func floorToScreenPixels(_ value: CGFloat) -> CGFloat {
    return floor(value * UIScreenScale) / UIScreenScale
}

private let avatarFont = UIFont(name: ".SFCompactRounded-Semibold", size: 18.0) ?? UIFont.systemFont(ofSize: 18.0)

private let gradientColors: [NSArray] = [
    [UIColor(rgb: 0xff516a).cgColor, UIColor(rgb: 0xff885e).cgColor],
    [UIColor(rgb: 0xffa85c).cgColor, UIColor(rgb: 0xffcd6a).cgColor],
    [UIColor(rgb: 0x665fff).cgColor, UIColor(rgb: 0x82b1ff).cgColor],
    [UIColor(rgb: 0x54cb68).cgColor, UIColor(rgb: 0xa0de7e).cgColor],
    [UIColor(rgb: 0x4acccd).cgColor, UIColor(rgb: 0x00fcfd).cgColor],
    [UIColor(rgb: 0x2a9ef1).cgColor, UIColor(rgb: 0x72d5fd).cgColor],
    [UIColor(rgb: 0xd669ed).cgColor, UIColor(rgb: 0xe0a2f3).cgColor],
]

private func avatarRoundImage(size: CGSize, source: UIImage) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
    let context = UIGraphicsGetCurrentContext()
    
    context?.beginPath()
    context?.addEllipse(in: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
    context?.clip()
    
    source.draw(in: CGRect(origin: CGPoint(), size: size))
    
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return image
}

private func avatarViewLettersImage(size: CGSize, peerId: PeerId, accountPeerId: PeerId, letters: [String]) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
    let context = UIGraphicsGetCurrentContext()
    
    context?.beginPath()
    context?.addEllipse(in: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
    context?.clip()
    
    let colorIndex = abs(Int(accountPeerId.id + peerId.id))
    
    let colorsArray = gradientColors[colorIndex % gradientColors.count]
    var locations: [CGFloat] = [1.0, 0.0]
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colorsArray, locations: &locations)!
    
    context?.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
    
    context?.setBlendMode(.normal)
    
    let string = letters.count == 0 ? "" : (letters[0] + (letters.count == 1 ? "" : letters[1]))
    let attributedString = NSAttributedString(string: string, attributes: [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 20.0), NSAttributedStringKey.foregroundColor: UIColor.white])
    
    let line = CTLineCreateWithAttributedString(attributedString)
    let lineBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    
    let lineOffset = CGPoint(x: string == "B" ? 1.0 : 0.0, y: 0.0)
    let lineOrigin = CGPoint(x: floorToScreenPixels(-lineBounds.origin.x + (size.width - lineBounds.size.width) / 2.0) + lineOffset.x, y: floorToScreenPixels(-lineBounds.origin.y + (size.height - lineBounds.size.height) / 2.0))
    
    context?.translateBy(x: size.width / 2.0, y: size.height / 2.0)
    context?.scaleBy(x: 1.0, y: -1.0)
    context?.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
    
    context?.translateBy(x: lineOrigin.x, y: lineOrigin.y)
    if let context = context {
        CTLineDraw(line, context)
    }
    context?.translateBy(x: -lineOrigin.x, y: -lineOrigin.y)
    
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return image
}

private let avatarSize = CGSize(width: 50.0, height: 50.0)

private final class AvatarView: UIImageView {
    init(account: Account, peer: Peer, size: CGSize) {
        super.init(frame: CGRect())
        
        if let resource = peer.smallProfileImage?.resource, let path = account.postbox.mediaBox.completedResourcePath(resource), let image = UIImage(contentsOfFile: path), let roundImage = avatarRoundImage(size: size, source: image) {
            self.image = roundImage
        } else {
            self.image = avatarViewLettersImage(size: size, peerId: peer.id, accountPeerId: account.peerId, letters: peer.displayLetters)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class PeerView: UIView {
    let peer: Peer
    private let avatarView: AvatarView
    private let titleLabel: UILabel
    
    private let tapped: () -> Void
    
    init(account: Account, peer: Peer, tapped: @escaping () -> Void) {
        self.peer = peer
        self.tapped = tapped
        self.avatarView = AvatarView(account: account, peer: peer, size: avatarSize)
        
        self.titleLabel = UILabel()
        self.titleLabel.text = peer.compactDisplayTitle
        self.titleLabel.textColor = .black
        self.titleLabel.font = UIFont.systemFont(ofSize: 11.0)
        self.titleLabel.lineBreakMode = .byTruncatingTail
        
        super.init(frame: CGRect())
        
        self.addSubview(self.avatarView)
        self.addSubview(self.titleLabel)
        
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateLayout(size: CGSize) {
        self.avatarView.frame = CGRect(origin: CGPoint(x: floor((size.width - avatarSize.width) / 2.0), y: 0.0), size: avatarSize)
        
        var titleSize = self.titleLabel.sizeThatFits(size)
        titleSize.width = min(size.width - 6.0, ceil(titleSize.width))
        titleSize.height = ceil(titleSize.height)
        self.titleLabel.frame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: avatarSize.height + 5.0), size: titleSize)
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.tapped()
        }
    }
}
