import Foundation
import UIKit
import WidgetItems

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xff) / 255.0, green: CGFloat((rgb >> 8) & 0xff) / 255.0, blue: CGFloat(rgb & 0xff) / 255.0, alpha: 1.0)
    }
}

private let UIScreenScale = UIScreen.main.scale
private func floorToScreenPixels(_ value: CGFloat) -> CGFloat {
    return floor(value * UIScreenScale) / UIScreenScale
}

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

private let deviceColorSpace: CGColorSpace = {
    if #available(iOSApplicationExtension 9.3, iOS 9.3, *) {
        if let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) {
            return colorSpace
        } else {
            return CGColorSpaceCreateDeviceRGB()
        }
    } else {
        return CGColorSpaceCreateDeviceRGB()
    }
}()

private func avatarViewLettersImage(size: CGSize, peerId: Int64, accountPeerId: Int64, letters: [String]) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
    let context = UIGraphicsGetCurrentContext()
    
    context?.beginPath()
    context?.addEllipse(in: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
    context?.clip()
    
    let colorIndex = abs(Int(accountPeerId + peerId))
    
    let colorsArray = gradientColors[colorIndex % gradientColors.count]
    var locations: [CGFloat] = [1.0, 0.0]
    let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray, locations: &locations)!
    
    context?.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
    
    context?.setBlendMode(.normal)
    
    let string = letters.count == 0 ? "" : (letters[0] + (letters.count == 1 ? "" : letters[1]))
    let attributedString = NSAttributedString(string: string, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 20.0), NSAttributedString.Key.foregroundColor: UIColor.white])
    
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

private func generateTintedImage(image: UIImage?, color: UIColor, backgroundColor: UIColor? = nil) -> UIImage? {
    guard let image = image else {
        return nil
    }
    
    let imageSize = image.size

    UIGraphicsBeginImageContextWithOptions(imageSize, backgroundColor != nil, image.scale)
    if let context = UIGraphicsGetCurrentContext() {
        if let backgroundColor = backgroundColor {
            context.setFillColor(backgroundColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: imageSize))
        }
        
        let imageRect = CGRect(origin: CGPoint(), size: imageSize)
        context.saveGState()
        context.translateBy(x: imageRect.midX, y: imageRect.midY)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: -imageRect.midX, y: -imageRect.midY)
        context.clip(to: imageRect, mask: image.cgImage!)
        context.setFillColor(color.cgColor)
        context.fill(imageRect)
        context.restoreGState()
    }
    
    let tintedImage = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()
    
    return tintedImage
}

private let savedMessagesColors: NSArray = [
    UIColor(rgb: 0x2a9ef1).cgColor, UIColor(rgb: 0x72d5fd).cgColor
]

private func savedMessagesImage(size: CGSize) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
    let context = UIGraphicsGetCurrentContext()
    
    context?.beginPath()
    context?.addEllipse(in: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
    context?.clip()
    
    let colorsArray = savedMessagesColors
    var locations: [CGFloat] = [1.0, 0.0]
    let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray, locations: &locations)!
    
    context?.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
    
    context?.setBlendMode(.normal)
    
    let factor = size.width / 60.0
    context?.translateBy(x: size.width / 2.0, y: size.height / 2.0)
    context?.scaleBy(x: factor, y: -factor)
    context?.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
    
    if let context = context, let icon = generateTintedImage(image: UIImage(named: "Widget/SavedMessages"), color: .white) {
        context.draw(icon.cgImage!, in: CGRect(origin: CGPoint(x: floor((size.width - icon.size.width) / 2.0), y: floor((size.height - icon.size.height) / 2.0)), size: icon.size))
    }
    
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return image
}

private let avatarSize = CGSize(width: 50.0, height: 50.0)

func avatarImage(accountPeerId: Int64?, peer: WidgetDataPeer?, size: CGSize) -> UIImage {
    if let peer = peer, let accountPeerId = accountPeerId, peer.id == accountPeerId {
        return savedMessagesImage(size: size)!
    } else if let path = peer?.avatarPath, let image = UIImage(contentsOfFile: path), let roundImage = avatarRoundImage(size: size, source: image) {
        return roundImage
    } else {
        return avatarViewLettersImage(size: size, peerId: peer?.id ?? 1, accountPeerId: accountPeerId ?? 1, letters: peer?.letters ?? [" "])!
    }
}

private final class AvatarView: UIImageView {
    init(accountPeerId: Int64, peer: WidgetDataPeer, size: CGSize) {
        super.init(frame: CGRect())
        
        if let path = peer.avatarPath, let image = UIImage(contentsOfFile: path), let roundImage = avatarRoundImage(size: size, source: image) {
            self.image = roundImage
        } else {
            self.image = avatarViewLettersImage(size: size, peerId: peer.id, accountPeerId: accountPeerId, letters: peer.letters)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class PeerView: UIView {
    let peer: WidgetDataPeer
    private let avatarView: AvatarView
    private let titleLabel: UILabel
    
    private let tapped: () -> Void
    
    init(primaryColor: UIColor, accountPeerId: Int64, peer: WidgetDataPeer, tapped: @escaping () -> Void) {
        self.peer = peer
        self.tapped = tapped
        self.avatarView = AvatarView(accountPeerId: accountPeerId, peer: peer, size: avatarSize)
        
        self.titleLabel = UILabel()
        var title = peer.name
        if let lastName = peer.lastName, !lastName.isEmpty {
            title.append("\n")
            title.append(lastName)
        }
        
        let systemFontSize = UIFont.preferredFont(forTextStyle: .body).pointSize
        let fontSize = floor(systemFontSize * 11.0 / 17.0)
        
        self.titleLabel.text = title
        if #available(iOSApplicationExtension 13.0, iOS 13.0, *) {
            self.titleLabel.textColor = UIColor.label
        } else {
            self.titleLabel.textColor = primaryColor
        }
        self.titleLabel.font = UIFont.systemFont(ofSize: fontSize)
        self.titleLabel.lineBreakMode = .byTruncatingTail
        self.titleLabel.numberOfLines = 2
        self.titleLabel.textAlignment = .center
        
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
