import Foundation
import UIKit
import MapKit
import Display
import Postbox
import SyncCore
import TelegramCore
import AvatarNode
import AppBundle
import TelegramPresentationData
import LocationResources

let locationPinReuseIdentifier = "locationPin"

private func generateSmallBackgroundImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 56.0, height: 56.0)) { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setShadow(offset: CGSize(), blur: 4.0, color: UIColor(rgb: 0x000000, alpha: 0.5).cgColor)
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(x: 16.0, y: 16.0, width: 24.0, height: 24.0))
        
        context.setShadow(offset: CGSize(), blur: 0.0, color: nil)
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: CGRect(x: 17.0 + UIScreenPixel, y: 17.0 + UIScreenPixel, width: 22.0 - 2.0 * UIScreenPixel, height: 22.0 - 2.0 * UIScreenPixel))
    }
}

class LocationPinAnnotation: NSObject, MKAnnotation {
    let account: Account
    let theme: PresentationTheme
    var coordinate: CLLocationCoordinate2D
    let location: TelegramMediaMap
    var title: String? = ""
    var subtitle: String? = ""
    
    init(account: Account, theme: PresentationTheme, location: TelegramMediaMap) {
        self.account = account
        self.theme = theme
        self.location = location
        self.coordinate = location.coordinate
        super.init()
    }
}

class LocationPinAnnotationLayer: CALayer {
    var customZPosition: CGFloat?
    
    override var zPosition: CGFloat {
        get {
            if let zPosition = self.customZPosition {
                return zPosition
            } else {
                return super.zPosition
            }
        } set {
            super.zPosition = newValue
        }
    }
}

class LocationPinAnnotationView: MKAnnotationView {
    let shadowNode: ASImageNode
    let backgroundNode: ASImageNode
    let smallNode: ASImageNode
    let iconNode: TransformImageNode
    let smallIconNode: TransformImageNode
    let dotNode: ASImageNode
    var avatarNode: AvatarNode?
    
    var appeared = false
    var animating = false
    
    override class var layerClass: AnyClass {
        return LocationPinAnnotationLayer.self
    }
    
    func setZPosition(_ zPosition: CGFloat?) {
        if let layer = self.layer as? LocationPinAnnotationLayer {
            layer.customZPosition = zPosition
        }
    }
    
    init(annotation: LocationPinAnnotation) {
        self.shadowNode = ASImageNode()
        self.shadowNode.image = UIImage(bundleImageName: "Location/PinShadow")
        if let image = self.shadowNode.image {
            self.shadowNode.bounds = CGRect(origin: CGPoint(), size: image.size)
        }
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.image = UIImage(bundleImageName: "Location/PinBackground")
        if let image = self.backgroundNode.image {
            self.backgroundNode.bounds = CGRect(origin: CGPoint(), size: image.size)
        }
        
        self.smallNode = ASImageNode()
        self.smallNode.image = UIImage(bundleImageName: "Location/PinSmallBackground")
        if let image = self.smallNode.image {
            self.smallNode.bounds = CGRect(origin: CGPoint(), size: image.size)
        }
        
        self.iconNode = TransformImageNode()
        self.iconNode.bounds = CGRect(origin: CGPoint(), size: CGSize(width: 64.0, height: 64.0))
        
        self.smallIconNode = TransformImageNode()
        self.smallIconNode.frame = CGRect(origin: CGPoint(x: 15.0, y: 15.0), size: CGSize(width: 26.0, height: 26.0))
        
        self.dotNode = ASImageNode()
        self.dotNode.image = generateFilledCircleImage(diameter: 6.0, color: annotation.theme.list.itemAccentColor)
        if let image = self.dotNode.image {
            self.dotNode.bounds = CGRect(origin: CGPoint(), size: image.size)
        }
        
        super.init(annotation: annotation, reuseIdentifier: locationPinReuseIdentifier)
        
        self.addSubnode(self.smallNode)
        self.smallNode.addSubnode(self.smallIconNode)
        
        self.addSubnode(self.shadowNode)
        self.shadowNode.addSubnode(self.backgroundNode)
        self.backgroundNode.addSubnode(self.iconNode)
        self.addSubnode(self.dotNode)
        
        self.annotation = annotation
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var annotation: MKAnnotation? {
        didSet {
            if let annotation = self.annotation as? LocationPinAnnotation {
                let venueType = annotation.location.venue?.type ?? ""
                let color = venueType.isEmpty ? annotation.theme.list.itemAccentColor : venueIconColor(type: venueType)
                self.backgroundNode.image = generateTintedImage(image: UIImage(bundleImageName: "Location/PinBackground"), color: color)
                self.iconNode.setSignal(venueIcon(postbox: annotation.account.postbox, type: annotation.location.venue?.type ?? "", background: false))
                self.smallIconNode.setSignal(venueIcon(postbox: annotation.account.postbox, type: annotation.location.venue?.type ?? "", background: false))
                self.smallNode.image = generateSmallBackgroundImage(color: color)
                self.dotNode.image = generateFilledCircleImage(diameter: 6.0, color: color)
                
                self.dotNode.isHidden = false
                
                if !self.isSelected {
                    self.dotNode.alpha = 0.0
                    self.shadowNode.isHidden = true
                    self.smallNode.isHidden = false
                }
            }
        }
    }
    
    override func prepareForReuse() {
        self.smallNode.isHidden = true
        self.backgroundNode.isHidden = false
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        if animated {
            self.layoutSubviews()
            
            self.animating = true
            if selected {
                self.shadowNode.position = CGPoint(x: self.shadowNode.position.x, y: self.shadowNode.position.y + self.shadowNode.frame.height / 2.0)
                self.shadowNode.anchorPoint = CGPoint(x: 0.5, y: 1.0)
                self.shadowNode.isHidden = false
                self.shadowNode.transform = CATransform3DMakeScale(0.1, 0.1, 1.0)
                
                UIView.animate(withDuration: 0.35, delay: 0.0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: [], animations: {
                    self.smallNode.transform = CATransform3DMakeScale(0.001, 0.001, 1.0)
                    self.shadowNode.transform = CATransform3DIdentity
                    
                    if self.dotNode.isHidden {
                        self.smallNode.alpha = 0.0
                    }
                }) { _ in
                    self.animating = false
                    
                    self.shadowNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                    
                    self.smallNode.isHidden = true
                    self.smallNode.transform = CATransform3DIdentity
                }
                                
                self.dotNode.alpha = 1.0
                self.dotNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            } else {
                self.smallNode.isHidden = false
                self.smallNode.transform = CATransform3DMakeScale(0.01, 0.01, 1.0)
                
                self.shadowNode.position = CGPoint(x: self.shadowNode.position.x, y: self.shadowNode.position.y + self.shadowNode.frame.height / 2.0)
                self.shadowNode.anchorPoint = CGPoint(x: 0.5, y: 1.0)
                
                UIView.animate(withDuration: 0.35, delay: 0.0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: [], animations: {
                    self.smallNode.transform = CATransform3DIdentity
                    self.shadowNode.transform = CATransform3DMakeScale(0.1, 0.1, 1.0)
                    
                    if self.dotNode.isHidden {
                        self.smallNode.alpha = 1.0
                    }
                }) { _ in
                    self.animating = false
                    
                    self.shadowNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                    
                    self.shadowNode.isHidden = true
                    self.shadowNode.transform = CATransform3DIdentity
                }
                
                let previousAlpha = self.dotNode.alpha
                self.dotNode.alpha = 0.0
                self.dotNode.layer.animateAlpha(from: previousAlpha, to: 0.0, duration: 0.2)
            }
        } else {
            self.smallNode.isHidden = selected
            self.shadowNode.isHidden = !selected
            self.dotNode.alpha = selected ? 1.0 : 0.0
            self.smallNode.alpha = 1.0
            
            self.layoutSubviews()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    
        guard !self.animating else {
            return
        }
        
        self.dotNode.position = CGPoint()
        self.smallNode.position = CGPoint()
        self.shadowNode.position = CGPoint(x: UIScreenPixel, y: -36.0)
        self.backgroundNode.position = CGPoint(x: self.shadowNode.frame.width / 2.0, y: self.shadowNode.frame.height / 2.0)
        self.iconNode.position = CGPoint(x: self.shadowNode.frame.width / 2.0, y: self.shadowNode.frame.height / 2.0 - 5.0)
       
        let smallIconLayout = self.smallIconNode.asyncLayout()
        let smallIconApply = smallIconLayout(TransformImageArguments(corners: ImageCorners(), imageSize: self.smallIconNode.bounds.size, boundingSize: self.smallIconNode.bounds.size, intrinsicInsets: UIEdgeInsets()))
        smallIconApply()
        
        let iconLayout = self.iconNode.asyncLayout()
        let iconApply = iconLayout(TransformImageArguments(corners: ImageCorners(), imageSize: self.iconNode.bounds.size, boundingSize: self.iconNode.bounds.size, intrinsicInsets: UIEdgeInsets()))
        iconApply()
        
        if let avatarNode = self.avatarNode {
            avatarNode.position = self.isSelected ? CGPoint(x: UIScreenPixel, y: -41.0) : CGPoint()
            avatarNode.transform = self.isSelected ? CATransform3DIdentity : CATransform3DMakeScale(0.64, 0.64, 1.0)
        }
        
        if !self.appeared {
            self.appeared = true
            
            self.smallNode.transform = CATransform3DMakeScale(0.1, 0.1, 1.0)
            UIView.animate(withDuration: 0.55, delay: 0.0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: [], animations: {
                self.smallNode.transform = CATransform3DIdentity
            }) { _ in
            }
        }
    }
    
    func setPeer(account: Account, theme: PresentationTheme, peer: Peer) {
        let avatarNode: AvatarNode
        if let currentAvatarNode = self.avatarNode {
            avatarNode = currentAvatarNode
        } else {
            avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 24.0))
            avatarNode.bounds = CGRect(origin: CGPoint(), size: CGSize(width: 55.0, height: 55.0))
            avatarNode.position = CGPoint()
            self.avatarNode = avatarNode
            self.addSubnode(avatarNode)
        }
        
        avatarNode.setPeer(account: account, theme: theme, peer: peer)
    }
    
    func setRaised(_ raised: Bool, avatar: Bool, animated: Bool, completion: @escaping () -> Void = {}) {
        
    }
}


